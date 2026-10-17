import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:salao_core/salao_core.dart';

void main() {
  const installed = (name: '1.0.0', code: 3);

  AppUpdateService service(MockClient client, {Directory? dir, ApkInstaller? installer}) => AppUpdateService(
        app: 'gestao',
        baseUrl: 'https://api.test',
        httpClient: client,
        installedVersion: () async => installed,
        downloadDir: () async => dir ?? Directory.systemTemp,
        installer: installer ?? (_) async => true,
      );

  group('AppUpdateInfo', () {
    test('lê a resposta de /api/app/version e resolve downloadUrl relativo', () {
      final info = AppUpdateInfo.fromJson({
        'versionName': '1.2.0',
        'versionCode': 7,
        'downloadUrl': '/api/app/releases/7/apk',
        'releaseNotes': '  Agenda mais rápida ',
        'forceUpdate': true,
        'sha256': 'ABC123',
      }, currentVersionName: '1.0.0', currentVersionCode: 3, baseUrl: 'https://api.test/');

      expect(info.latestVersionName, '1.2.0');
      expect(info.latestVersionCode, 7);
      expect(info.downloadUrl, 'https://api.test/api/app/releases/7/apk');
      expect(info.releaseNotes, 'Agenda mais rápida');
      expect(info.forceUpdate, isTrue);
      expect(info.sha256, 'abc123');
      expect(info.currentLabel, '1.0.0 (3)');
    });

    test('campos opcionais ausentes ou nulos', () {
      final info = AppUpdateInfo.fromJson({
        'versionName': '1.0.1',
        'versionCode': 4,
        'downloadUrl': 'https://cdn.test/app.apk',
        'releaseNotes': null,
        'sha256': '',
      }, currentVersionName: '1.0.0', currentVersionCode: 3, baseUrl: 'https://api.test');
      expect(info.downloadUrl, 'https://cdn.test/app.apk');
      expect(info.releaseNotes, isNull);
      expect(info.sha256, isNull);
      expect(info.forceUpdate, isFalse);
    });

    AppUpdateInfo info(int latest, {bool force = false}) => AppUpdateInfo(
          currentVersionName: '1.0.0',
          currentVersionCode: 5,
          latestVersionName: 'x',
          latestVersionCode: latest,
          downloadUrl: 'https://x',
          forceUpdate: force,
        );

    test('hasUpdate compara versionCode com o buildNumber instalado', () {
      expect(info(6).hasUpdate, isTrue);
      expect(info(5).hasUpdate, isFalse);
      expect(info(4).hasUpdate, isFalse);
    });

    test('forceUpdate só obriga quando a versão é mais nova', () {
      expect(info(6, force: true).mustUpdate, isTrue);
      expect(info(5, force: true).mustUpdate, isFalse);
      expect(info(6).mustUpdate, isFalse);
    });
  });

  group('AppUpdateService', () {
    test('consulta a versão do app certo', () async {
      late Uri asked;
      final s = service(MockClient((req) async {
        asked = req.url;
        return http.Response(
            jsonEncode({'versionName': '1.1.0', 'versionCode': 4, 'downloadUrl': '/apk', 'forceUpdate': false}), 200);
      }));
      final update = await s.checkForUpdate();
      expect(asked.toString(), 'https://api.test/api/app/version?app=gestao');
      expect(update!.hasUpdate, isTrue);
      expect(update.currentVersionCode, 3);
      expect(update.downloadUrl, 'https://api.test/apk');
    });

    test('404 = nenhuma versão publicada', () async {
      final s = service(MockClient((_) async => http.Response('', 404)));
      expect(await s.checkForUpdate(), isNull);
    });

    test('erro do servidor vira AppUpdateException', () async {
      final s = service(MockClient((_) async => http.Response('', 500)));
      await expectLater(s.checkForUpdate(), throwsA(isA<AppUpdateException>()));
    });

    group('download', () {
      late Directory dir;
      final apk = utf8.encode('apk-bytes');

      setUp(() async => dir = await Directory.systemTemp.createTemp('salao_update_test'));
      tearDown(() async => dir.delete(recursive: true));

      AppUpdateInfo update(String? sha) => AppUpdateInfo(
            currentVersionName: '1.0.0',
            currentVersionCode: 3,
            latestVersionName: '1.1.0',
            latestVersionCode: 4,
            downloadUrl: 'https://api.test/apk',
            sha256: sha,
          );

      test('baixa, confere o sha256, reaproveita o cache e instala', () async {
        var downloads = 0;
        String? installedPath;
        final s = service(
          MockClient((_) async {
            downloads++;
            return http.Response.bytes(apk, 200);
          }),
          dir: dir,
          installer: (path) async {
            installedPath = path;
            return true;
          },
        );
        final u = update(sha256.convert(apk).toString());
        final progress = <double>[];
        final file = await s.download(u, onProgress: progress.add);
        expect(await file.readAsBytes(), apk);
        expect(progress.last, 1);

        await s.download(u);
        expect(downloads, 1, reason: 'APK íntegro já baixado não baixa de novo');

        expect(await s.install(file), isTrue);
        expect(installedPath, file.path);
      });

      test('checksum diferente apaga o arquivo e falha', () async {
        final s = service(MockClient((_) async => http.Response.bytes(apk, 200)), dir: dir);
        await expectLater(s.download(update('0' * 64)), throwsA(isA<AppUpdateException>()));
        expect(dir.listSync(), isEmpty);
      });
    });
  });
}
