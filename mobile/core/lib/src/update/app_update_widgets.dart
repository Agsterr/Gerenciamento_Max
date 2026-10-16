import 'package:flutter/material.dart';

import '../config.dart';
import '../theme.dart';
import '../widgets.dart';
import 'app_update_service.dart';

/// Checa atualização ao abrir o app e ao voltar para ele (canal `direct`).
///
/// - versão nova opcional → diálogo "Atualização disponível" (pode adiar), só na abertura;
/// - versão nova com `forceUpdate` → tela cheia "Atualização obrigatória" que não fecha.
///
/// Use em `MaterialApp.builder`, passando o mesmo [navigatorKey] do `MaterialApp`.
class AppUpdateListener extends StatefulWidget {
  const AppUpdateListener({super.key, required this.service, required this.navigatorKey, required this.child, this.enabled});

  final AppUpdateService service;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  /// Padrão: [AppConfig.selfUpdateEnabled].
  final bool? enabled;

  @override
  State<AppUpdateListener> createState() => _AppUpdateListenerState();
}

class _AppUpdateListenerState extends State<AppUpdateListener> with WidgetsBindingObserver {
  bool _checking = false;
  bool _dialogOpen = false;
  AppUpdateInfo? _force;

  bool get _enabled => widget.enabled ?? AppConfig.selfUpdateEnabled;

  @override
  void initState() {
    super.initState();
    if (!_enabled) return;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check(startup: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check(startup: false);
  }

  Future<void> _check({required bool startup}) async {
    if (_checking || !mounted) return;
    _checking = true;
    try {
      final update = await widget.service.checkForUpdate();
      if (!mounted) return;
      setState(() => _force = update != null && update.mustUpdate ? update : null);
      // O aviso opcional aparece uma vez por abertura; ao voltar ao app só reavaliamos o obrigatório.
      if (update != null && update.hasUpdate && !update.forceUpdate && startup && !_dialogOpen) {
        final context = widget.navigatorKey.currentContext;
        if (context == null || !context.mounted) return;
        _dialogOpen = true;
        _checking = false;
        await showAppUpdateDialog(context, service: widget.service, update: update);
        _dialogOpen = false;
      }
    } catch (_) {
      // Silencioso na checagem automática: sem rede o app segue normalmente.
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final force = _force;
    return Stack(children: [
      widget.child,
      if (force != null) Positioned.fill(child: ForceUpdateScreen(service: widget.service, update: force)),
    ]);
  }
}

/// Tela cheia de atualização obrigatória (não tem "Agora não").
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key, required this.service, required this.update});

  final AppUpdateService service;
  final AppUpdateInfo update;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      child: Container(
        decoration: const BoxDecoration(gradient: Brand.nightGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Icon(Icons.system_update_rounded, size: 52, color: Brand.rose),
                    const SizedBox(height: 12),
                    Text('Atualização obrigatória', textAlign: TextAlign.center, style: text.titleLarge),
                    const SizedBox(height: 6),
                    Text('Instale a versão nova para continuar usando o app.', textAlign: TextAlign.center, style: text.bodyMedium),
                    const SizedBox(height: 16),
                    AppUpdatePanel(service: service, update: update, autoStart: true),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Diálogo "Atualização disponível" (pode adiar).
Future<void> showAppUpdateDialog(BuildContext context, {required AppUpdateService service, required AppUpdateInfo update}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Atualização disponível'),
      content: SingleChildScrollView(
        child: AppUpdatePanel(service: service, update: update, onLater: () => Navigator.pop(context)),
      ),
    ),
  );
}

/// Versões, novidades, progresso do download e botões Atualizar/Instalar.
class AppUpdatePanel extends StatefulWidget {
  const AppUpdatePanel({super.key, required this.service, required this.update, this.onLater, this.autoStart = false});

  final AppUpdateService service;
  final AppUpdateInfo update;

  /// Null = obrigatória (sem "Agora não").
  final VoidCallback? onLater;
  final bool autoStart;

  @override
  State<AppUpdatePanel> createState() => _AppUpdatePanelState();
}

class _AppUpdatePanelState extends State<AppUpdatePanel> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;
  String? _hint;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  Future<void> _update({bool redownload = false}) async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
      _hint = null;
    });
    try {
      final apk = await widget.service.download(widget.update, force: redownload, onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _ready = true;
      });
      final started = await widget.service.install(apk);
      if (!mounted) return;
      setState(() => _hint = started
          ? 'Conclua a instalação na tela do Android.'
          : 'Permita "instalar apps desconhecidos" para o Salão Max e toque em Instalar.');
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.update;
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: Brand.muted);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Nova versão: ${u.latestLabel}', style: text.titleSmall),
      Text('Instalada: ${u.currentLabel}', style: muted),
      if (u.releaseNotes != null) ...[
        const SizedBox(height: 12),
        Text(u.releaseNotes!, style: text.bodyMedium),
      ],
      if (_downloading) ...[
        const SizedBox(height: 16),
        LinearProgressIndicator(value: _progress > 0 ? _progress : null),
        const SizedBox(height: 6),
        Text('${(_progress * 100).clamp(0, 100).toStringAsFixed(0)}% baixado', style: muted),
      ],
      if (_hint != null) ...[const SizedBox(height: 12), Text(_hint!, style: text.bodySmall)],
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error)),
      ],
      const SizedBox(height: 16),
      GradientButton(
        label: _downloading ? 'Baixando...' : (_ready ? 'Instalar' : 'Atualizar agora'),
        icon: _ready ? Icons.install_mobile_rounded : Icons.download_rounded,
        loading: _downloading,
        onPressed: _update,
      ),
      if (_ready && !_downloading)
        TextButton(onPressed: () => _update(redownload: true), child: const Text('Baixar de novo')),
      if (widget.onLater != null)
        TextButton(onPressed: _downloading ? null : widget.onLater, child: const Text('Agora não')),
    ]);
  }
}

/// Item "Versão" para Ajustes/Sobre: mostra a versão instalada e, no canal `direct`,
/// o botão "Verificar atualização".
class AppVersionTile extends StatefulWidget {
  const AppVersionTile({super.key, required this.app, this.service, this.selfUpdate});

  /// `gestao` ou `cliente` (usado quando [service] é nulo).
  final String app;
  final AppUpdateService? service;

  /// Padrão: [AppConfig.selfUpdateEnabled].
  final bool? selfUpdate;

  @override
  State<AppVersionTile> createState() => _AppVersionTileState();
}

class _AppVersionTileState extends State<AppVersionTile> {
  String? _version;
  bool _checking = false;

  late final AppUpdateService _service = widget.service ?? AppUpdateService(app: widget.app);

  bool get _selfUpdate => widget.selfUpdate ?? AppConfig.selfUpdateEnabled;

  @override
  void initState() {
    super.initState();
    AppUpdateService.readInstalledVersion().then((v) {
      if (mounted) setState(() => _version = '${v.name} (${v.code})');
    }).catchError((_) {});
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      final update = await _service.checkForUpdate();
      if (!mounted) return;
      if (update == null) {
        showMessage(context, 'Nenhuma versão publicada ainda.');
      } else if (!update.hasUpdate) {
        showMessage(context, 'Você já está na versão mais recente (${update.currentLabel}).');
      } else {
        await showAppUpdateDialog(context, service: _service, update: update);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: Brand.rose.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.info_outline_rounded, color: Brand.rose, size: 20),
      ),
      title: Text('Versão', style: text.titleSmall),
      subtitle: Text(_version ?? '...'),
      trailing: _selfUpdate
          ? (_checking
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
              : TextButton(onPressed: _check, child: const Text('Verificar atualização')))
          : null,
    );
  }
}
