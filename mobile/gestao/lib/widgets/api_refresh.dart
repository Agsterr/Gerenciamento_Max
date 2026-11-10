import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:salao_core/salao_core.dart';

/// Recarrega a tela quando chegam dados novos do servidor para ela (ou quando a internet volta e a fila foi
/// enviada). A tela abre com o que está guardado no celular e se atualiza sozinha depois.
mixin ApiRefresh<T extends StatefulWidget> on State<T> {
  StreamSubscription<String>? _apiSub;
  Timer? _debounce;

  /// [prefixes]: caminhos que interessam (ex.: '/api/appointments'). [reload] busca de novo.
  void listenApi(ApiClient api, List<String> prefixes, VoidCallback reload) {
    _apiSub?.cancel();
    _apiSub = api.refreshed.where((p) => p == '*' || prefixes.any(p.startsWith)).listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        if (mounted) reload();
      });
    });
  }

  @override
  void dispose() {
    _apiSub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }
}
