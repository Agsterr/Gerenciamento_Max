import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salao_core/salao_core.dart';

import 'session.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  final session = Session();
  session.restore();
  runApp(GestaoApp(session: session));
}

class GestaoApp extends StatelessWidget {
  const GestaoApp({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Salão Max Gestão',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // respeita a fonte grande do celular, mas sem deixar botões e diálogos saírem da tela
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
        ),
        child: child!,
      ),
      home: ListenableBuilder(
        listenable: session,
        builder: (context, _) => switch (session.state) {
          SessionState.restoring => const Scaffold(body: Center(child: CircularProgressIndicator())),
          SessionState.offline => Scaffold(body: ErrorRetry(message: 'Sem conexão com o servidor.', onRetry: session.restore)),
          SessionState.signedOut => LoginScreen(session: session),
          SessionState.signedIn => Shell(session: session),
        },
      ),
    );
  }
}
