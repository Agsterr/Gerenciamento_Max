import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salao_core/salao_core.dart';

import 'booking_store.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  final store = await BookingStore.load();
  runApp(ClienteApp(store: store, api: ApiClient()));
}

class ClienteApp extends StatelessWidget {
  const ClienteApp({super.key, required this.store, required this.api});

  final BookingStore store;
  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Salão Max',
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
      home: HomeScreen(store: store, api: api),
    );
  }
}
