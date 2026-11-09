import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salao_core/salao_core.dart';

/// Captura de telas para conferir o visual de verdade (regra do CLAUDE.md: toda mudança visual é vista antes de entregar).
/// Só roda com `SHOTS=1`; as imagens vão para `SHOT_DIR` (padrão `build/shots`).
final shotsEnabled = Platform.environment['SHOTS'] == '1';

bool _fontsLoaded = false;

/// Fonte da marca e ícones do Material, para a imagem sair como no celular (sem quadradinhos).
Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;
  final brand = FontLoader('packages/salao_core/PlusJakartaSans');
  for (final f in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final bytes = File('../core/fonts/PlusJakartaSans-$f.ttf').readAsBytesSync();
    brand.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await brand.load();
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/opt/sdk/flutter';
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.view(File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytesSync().buffer)));
  await icons.load();
  _fontsLoaded = true;
}

/// Deixa as respostas de rede (de verdade ou de mentira) chegarem e a tela redesenhar. Só `pumpAndSettle` não basta quando a
/// requisição é real: o relógio de teste não anda enquanto a rede responde.
Future<void> settleNetwork(WidgetTester tester, {int rounds = 12}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

/// Renderiza [home] com o tema do app e salva `SHOT_DIR/<name>.png`. [width] em dp (360 = celular pequeno);
/// [textScale] simula a fonte grande do sistema; [dark] escolhe o tema.
Future<String> shot(
  WidgetTester tester,
  Widget home,
  String name, {
  double width = 390,
  double height = 844,
  double textScale = 1,
  bool dark = true,
  Future<void> Function(WidgetTester tester)? before,
}) async {
  await loadAppFonts();
  tester.view.physicalSize = Size(width * 2, height * 2);
  tester.view.devicePixelRatio = 2;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAllTestValues();
  });
  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(
    key: key,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: home,
    ),
  ));
  await settleNetwork(tester);
  if (before != null) {
    await before(tester);
    await settleNetwork(tester, rounds: 6);
  }
  final dir = Platform.environment['SHOT_DIR'] ?? 'build/shots';
  Directory(dir).createSync(recursive: true);
  final path = '$dir/$name.png';
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(data!.buffer.asUint8List());
  });
  // solta a tela e deixa passar o tempo: conexões de rede de verdade deixam timers de 15 s pendentes
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 30));
  return path;
}
