// Anteprime delle schermate (caratteri veri) in build/anteprime/, per controllarle senza telefono.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tktv/canali.dart';
import 'package:tktv/impostazioni.dart';
import 'package:tktv/lista.dart';
import 'package:tktv/tema.dart';

import 'caratteri.dart';

Future<void> _scatta(WidgetTester t, Widget w, String nome) async {
  final k = GlobalKey();
  await t.pumpWidget(RepaintBoundary(
      key: k, child: MaterialApp(debugShowCheckedModeBanner: false, theme: temaKit(), home: w)));
  await t.pump(const Duration(milliseconds: 500));
  await t.runAsync(() async {
    final img = await (k.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: 2);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/anteprime').createSync(recursive: true);
    File('build/anteprime/$nome.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    configTk = configTv;
    await caricaCaratteri();
  });

  testWidgets('anteprime', (t) async {
    t.view.physicalSize = const Size(780, 1688);
    t.view.devicePixelRatio = 2;
    final canali = [
      const Canale(1, 'Rai 1', 'Rai', 'u', '', ''),
      const Canale(2, 'Rai 2', 'Rai', 'u', '', ''),
      const Canale(3, 'Rai 3', 'Rai', 'u', '', ''),
      const Canale(5, 'Canale 5', 'Mediaset', 'u', '', ''),
      const Canale(6, 'Italia 1', 'Mediaset', 'u', '', ''),
      const Canale(7, 'La7', 'La7', 'u', '', ''),
      const Canale(48, 'Rai News 24', 'Rai', 'u', '', ''),
      const Canale(1000, 'Radio Kiss Kiss', '', 'u', '', ''),
    ];
    await _scatta(
        t,
        SchermataLista(
          canali: canali,
          totale: canali.length,
          preferiti: const {'Rai News 24'},
          onCanale: (_) {},
          onPreferito: (_) {},
          onRicarica: () {},
          onImpostazioni: () {},
          onInfo: () {},
        ),
        'lista');
    await _scatta(
        t,
        SchermataImpostazioni(
            urlIniziale: 'http://esempio.it/lista.m3u',
            caricamento: false,
            errore: 'Errore HTTP 404',
            onIndietro: () {},
            onSalva: (_) {}),
        'impostazioni');
    await _scatta(
        t,
        const SchermataAvvio(),
        'avvio');
  });
}
