import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salao_core/salao_core.dart';

import 'booking_store.dart';
import 'confirm_reminders.dart';
import 'screens/booking_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  await LocalReminders.instance.init();
  final store = await BookingStore.load();
  runApp(ClienteApp(store: store, api: ApiClient(), updates: AppUpdateService(app: 'cliente')));
}

class ClienteApp extends StatefulWidget {
  const ClienteApp({super.key, required this.store, required this.api, required this.updates});

  final BookingStore store;
  final ApiClient api;
  final AppUpdateService updates;

  @override
  State<ClienteApp> createState() => _ClienteAppState();
}

class _ClienteAppState extends State<ClienteApp> {
  final _navigator = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    LocalReminders.instance.tapped.addListener(_openFromNotification);
    // notificação que abriu o app: espera a primeira tela
    WidgetsBinding.instance.addPostFrameCallback((_) => _openFromNotification());
  }

  @override
  void dispose() {
    LocalReminders.instance.tapped.removeListener(_openFromNotification);
    super.dispose();
  }

  /// Toque em "Seu horário é amanhã": abre o agendamento com o botão Confirmar presença.
  void _openFromNotification() {
    final payload = LocalReminders.payloadOf(LocalReminders.instance.tapped.value, confirmGroup);
    final parts = payload?.split('/');
    if (parts == null || parts.length != 2) return;
    LocalReminders.instance.tapped.value = null;
    final saved = widget.store.bookings.where((b) => b.token == parts[1]).firstOrNull;
    _navigator.currentState?.push(MaterialPageRoute(
      builder: (_) => BookingScreen(slug: parts[0], token: parts[1], api: widget.api, salonName: saved?.salonName),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Salão Max',
      navigatorKey: _navigator,
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
        child: AppUpdateListener(service: widget.updates, navigatorKey: _navigator, child: child!),
      ),
      home: HomeScreen(store: widget.store, api: widget.api),
    );
  }
}
