import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salao_core/salao_core.dart';

import 'session.dart';
import 'screens/blocked_screen.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  final session = Session();
  session.restore();
  runApp(GestaoApp(session: session, updates: AppUpdateService(app: 'gestao')));
}

class GestaoApp extends StatefulWidget {
  const GestaoApp({super.key, required this.session, required this.updates});

  final Session session;
  final AppUpdateService updates;

  @override
  State<GestaoApp> createState() => _GestaoAppState();
}

class _GestaoAppState extends State<GestaoApp> {
  final _navigator = GlobalKey<NavigatorState>();

  Session get session => widget.session;

  @override
  void initState() {
    super.initState();
    session.addListener(_closeRoutesWhenBlocked);
  }

  @override
  void dispose() {
    session.removeListener(_closeRoutesWhenBlocked);
    super.dispose();
  }

  /// Bloqueio pode chegar com uma folha/diálogo aberto: volta para a raiz, onde fica a tela de bloqueio.
  void _closeRoutesWhenBlocked() {
    if (session.state == SessionState.blocked) _navigator.currentState?.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Salão Max Gestão',
      navigatorKey: _navigator,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => AppUpdateListener(service: widget.updates, navigatorKey: _navigator, child: child!),
      home: ListenableBuilder(
        listenable: session,
        builder: (context, _) => switch (session.state) {
          SessionState.restoring => const Scaffold(body: Center(child: CircularProgressIndicator())),
          SessionState.offline => Scaffold(body: ErrorRetry(message: 'Sem conexão com o servidor.', onRetry: session.restore)),
          SessionState.signedOut => LoginScreen(session: session),
          SessionState.signedIn => Shell(session: session),
          SessionState.blocked => BlockedScreen(
              reason: session.blockedReason ?? AccountBlockedException.defaultReason,
              onSignOut: session.signOut,
            ),
        },
      ),
    );
  }
}
