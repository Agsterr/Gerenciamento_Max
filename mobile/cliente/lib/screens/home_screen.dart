import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

import '../booking_store.dart';
import 'about_screen.dart';
import 'my_bookings_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store, required this.api});

  final BookingStore store;
  final ApiClient api;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tab == 0 ? 'Agendar' : 'Meus horários'),
        actions: [
          IconButton(
            tooltip: 'Sobre e privacidade',
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AboutScreen(store: widget.store)),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          SearchScreen(store: widget.store, api: widget.api),
          MyBookingsScreen(store: widget.store, api: widget.api),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Salões'),
          NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: 'Meus horários'),
        ],
      ),
    );
  }
}
