import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../config.dart';

/// Versão publicada (resposta de `GET /api/app/version?app=...`) comparada com a instalada.
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersionName,
    required this.currentVersionCode,
    required this.latestVersionName,
    required this.latestVersionCode,
    required this.downloadUrl,
    this.releaseNotes,
    this.forceUpdate = false,
    this.sha256,
  });

  /// [baseUrl] resolve `downloadUrl` relativo (ex.: `/api/app/releases/7/apk`).
  factory AppUpdateInfo.fromJson(
    Map<String, dynamic> json, {
    required String currentVersionName,
    required int currentVersionCode,
    required String baseUrl,
  }) {
    final notes = json['releaseNotes'];
    final sha = json['sha256'];
    return AppUpdateInfo(
      currentVersionName: currentVersionName,
      currentVersionCode: currentVersionCode,
      latestVersionName: json['versionName'] as String? ?? '',
      latestVersionCode: (json['versionCode'] as num).toInt(),
      downloadUrl: resolveUrl(baseUrl, json['downloadUrl'] as String),
      releaseNotes: notes is String && notes.trim().isNotEmpty ? notes.trim() : null,
      forceUpdate: json['forceUpdate'] as bool? ?? false,
      sha256: sha is String && sha.trim().isNotEmpty ? sha.trim().toLowerCase() : null,
    );
  }

  final String currentVersionName;
  final int currentVersionCode;
  final String latestVersionName;
  final int latestVersionCode;
  final String downloadUrl;
  final String? releaseNotes;
  final bool forceUpdate;
  final String? sha256;

  bool get hasUpdate => latestVersionCode > currentVersionCode;

  /// Só bloqueia o app quando há versão mais nova E ela é obrigatória.
  bool get mustUpdate => hasUpdate && forceUpdate;

  String get currentLabel => '$currentVersionName ($currentVersionCode)';
  String get latestLabel => '$latestVersionName ($latestVersionCode)';

  static String resolveUrl(String base, String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final b = base.replaceAll(RegExp(r'/+$'), '');
    return url.startsWith('/') ? '$b$url' : '$b/$url';
  }
}

class AppUpdateException implements Exception {
  AppUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Versão instalada: nome (`1.2.0`) e código (`buildNumber`, o versionCode do Android).
typedef InstalledVersion = ({String name, int code});

/// Abre o instalador do Android (canal nativo do flavor `direct`). Retorna `false` quando o usuário
/// precisa liberar "instalar apps desconhecidos" — o Android já abriu essa tela.
typedef ApkInstaller = Future<bool> Function(String path);

/// Atualização fora da loja (APK baixado do site): checa a versão publicada na API,
/// baixa o APK com progresso, confere o sha256 e abre o instalador.
class AppUpdateService {
  AppUpdateService({
    required this.app,
    String? baseUrl,
    http.Client? httpClient,
    Future<InstalledVersion> Function()? installedVersion,
    Future<Directory> Function()? downloadDir,
    ApkInstaller? installer,
  })  : baseUrl = baseUrl ?? AppConfig.apiUrl,
        _http = httpClient ?? http.Client(),
        _installedVersion = installedVersion ?? readInstalledVersion,
        _downloadDir = downloadDir ?? _defaultDownloadDir,
        _installer = installer ?? _nativeInstall;

  /// `gestao` ou `cliente`.
  final String app;
  final String baseUrl;
  final http.Client _http;
  final Future<InstalledVersion> Function() _installedVersion;
  final Future<Directory> Function() _downloadDir;
  final ApkInstaller _installer;

  static const _channel = MethodChannel('salaomax/apk_installer');

  static Future<InstalledVersion> readInstalledVersion() async {
    final info = await PackageInfo.fromPlatform();
    return (name: info.version, code: int.tryParse(info.buildNumber) ?? 0);
  }

  static Future<Directory> _defaultDownloadDir() async {
    // Precisa bater com res/xml/update_paths.xml (cache-path "updates/").
    final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
    return dir.create(recursive: true);
  }

  static Future<bool> _nativeInstall(String path) async {
    try {
      return await _channel.invokeMethod<String>('install', {'path': path}) == 'started';
    } on MissingPluginException {
      throw AppUpdateException('Este build não instala atualizações (use o APK do canal direct).');
    } on PlatformException catch (e) {
      throw AppUpdateException(e.message ?? 'Não foi possível abrir o instalador.');
    }
  }

  String _fileName(int versionCode) => 'salao-max-$app-$versionCode.apk';

  /// Null = nenhuma versão publicada (404).
  Future<AppUpdateInfo?> checkForUpdate() async {
    final installed = await _installedVersion();
    final uri = Uri.parse('$baseUrl/api/app/version').replace(queryParameters: {'app': app});
    final http.Response res;
    try {
      res = await _http.get(uri, headers: const {'Accept': 'application/json'}).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw AppUpdateException('O servidor demorou para responder.');
    } on SocketException {
      throw AppUpdateException('Sem conexão com a internet.');
    } on http.ClientException {
      throw AppUpdateException('Não foi possível conectar ao servidor.');
    }
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw AppUpdateException('Não foi possível verificar atualizações (${res.statusCode}).');
    final json = jsonDecode(utf8.decode(res.bodyBytes));
    if (json is! Map<String, dynamic>) throw AppUpdateException('Resposta inválida do servidor.');
    return AppUpdateInfo.fromJson(json, currentVersionName: installed.name, currentVersionCode: installed.code, baseUrl: baseUrl);
  }

  /// APK desta versão já baixado e íntegro.
  Future<File?> cachedApk(AppUpdateInfo update) async {
    final file = File('${(await _downloadDir()).path}/${_fileName(update.latestVersionCode)}');
    if (!await file.exists()) return null;
    return await _checksumOk(file, update.sha256) ? file : null;
  }

  /// Baixa (ou reaproveita) o APK, confere o sha256 e retorna o arquivo.
  Future<File> download(AppUpdateInfo update, {void Function(double progress)? onProgress, bool force = false}) async {
    if (!force) {
      final cached = await cachedApk(update);
      if (cached != null) {
        onProgress?.call(1);
        return cached;
      }
    }
    final dir = await _downloadDir();
    await _purgeOthers(dir, keep: _fileName(update.latestVersionCode));
    final file = File('${dir.path}/${_fileName(update.latestVersionCode)}');
    final partial = File('${file.path}.part');

    final http.StreamedResponse res;
    try {
      res = await _http.send(http.Request('GET', Uri.parse(update.downloadUrl))).timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw AppUpdateException('O download não começou. Tente novamente.');
    } on SocketException {
      throw AppUpdateException('Sem conexão com a internet.');
    } on http.ClientException {
      throw AppUpdateException('Falha ao baixar a atualização.');
    }
    if (res.statusCode != 200) throw AppUpdateException('Falha ao baixar a atualização (${res.statusCode}).');

    final total = res.contentLength ?? 0;
    var received = 0;
    final sink = partial.openWrite();
    try {
      await for (final chunk in res.stream.timeout(const Duration(seconds: 60))) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
      await sink.flush();
    } catch (_) {
      await sink.close();
      if (await partial.exists()) await partial.delete();
      throw AppUpdateException('O download foi interrompido. Tente novamente.');
    }
    await sink.close();

    if (!await _checksumOk(partial, update.sha256)) {
      await partial.delete();
      throw AppUpdateException('Arquivo corrompido (checksum inválido). Tente novamente.');
    }
    if (await file.exists()) await file.delete();
    final done = await partial.rename(file.path);
    onProgress?.call(1);
    return done;
  }

  /// Abre o instalador. `false` = o Android pediu para liberar "instalar apps desconhecidos";
  /// depois de liberar, chame de novo.
  Future<bool> install(File apk) => _installer(apk.path);

  Future<bool> _checksumOk(File file, String? expected) async {
    if (expected == null) return true;
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString() == expected;
  }

  Future<void> _purgeOthers(Directory dir, {required String keep}) async {
    try {
      await for (final entity in dir.list()) {
        final name = entity.uri.pathSegments.last;
        if (entity is File && name.startsWith('salao-max-$app-') && name != keep) await entity.delete();
      }
    } catch (_) {
      // Melhor esforço: não impede a atualização.
    }
  }
}
