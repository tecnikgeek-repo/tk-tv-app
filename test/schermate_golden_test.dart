// Foto di Benvenuto, Informazioni, Licenze, abbinamento col QR e Impostazioni con i caratteri veri, sul telefono
// (412×915) e sulla TV (960×540), per guardarle senza dispositivo. Gira solo con
// `flutter test --update-goldens test/schermate_golden_test.dart` (in CI sul ramo): le PNG finiscono in
// test/goldens/ e la CI le carica come artefatto. Con `flutter test` normale si salta.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tktv/abbina.dart';
import 'package:tktv/abbina_server.dart';
import 'package:tktv/avviso.dart';
import 'package:tktv/impostazioni.dart';
import 'package:tktv/tema.dart';
import 'package:tktv/tk_licenza.dart';
import 'package:tktv/tk_pro.dart';

import 'caratteri.dart';

const _telefono = Size(412, 915);
const _tv = Size(960, 540);

/// Abbinamento finto: stesso aspetto di quello vero, senza aprire nessun server.
class _Finto implements Abbinamento {
  @override
  final String indirizzo = 'http://192.168.1.20:41234/?k=ab3dk7mnp2qx';
  @override
  final DateTime scadenza = DateTime.now().add(const Duration(minutes: 4, seconds: 32));
  @override
  Future<void> chiudi() async {}
}

Future<Abbinamento> _avviaFinto({required void Function(String) onLink, required void Function() onFine}) async =>
    _Finto();

Future<Abbinamento> _senzaRete({required void Function(String) onLink, required void Function() onFine}) async =>
    throw const NessunaReteLocale();

Future<void> _mostra(WidgetTester t, Widget schermata, {Size lato = _telefono}) async {
  t.view.physicalSize = lato * 2;
  t.view.devicePixelRatio = 2;
  await t.pumpWidget(MaterialApp(
      key: UniqueKey(),
      debugShowCheckedModeBanner: false,
      theme: temaKit(),
      home: schermata));
  await t.pump(const Duration(milliseconds: 300));
  await t.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await t.pump(const Duration(milliseconds: 300));
}

Widget _abbina(AvviaAbbinamento avvia) =>
    SchermataAbbina(puoTornare: true, onRicevuto: (_) {}, onManuale: () {}, onIndietro: () {}, avvia: avvia);

void main() {
  setUpAll(caricaCaratteri);

  testWidgets('foto delle schermate', skip: !autoUpdateGoldenFiles, (t) async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
        appName: 'tk-tv', packageName: 'it.pietrodefilippis.tktv', version: '2.2.0', buildNumber: '63', buildSignature: '');
    configTk = configTv;
    final lic = Licenza(slug: 'tk-tv-app', versione: '2.2.0');
    await t.runAsync(lic.carica);
    proTk = ProTk(lic);
    addTearDown(t.view.reset);

    await _mostra(t, BenvenutoTv(lic: lic));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/benvenuto.png'));

    await t.tap(find.byType(Switch));
    await t.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/benvenuto-statistiche.png'));

    await _mostra(t, BenvenutoTv(lic: lic), lato: _tv);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/benvenuto-tv.png'));

    Future<List<(String, String)>> righe() async => [('Canali caricati', '248'), ('Preferiti', '6')];
    await _mostra(t,
        SchermataInformazioni(righe: righe, notaDati: 'Il link della lista e i preferiti restano su questo dispositivo.'),
        lato: const Size(412, 1700));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/informazioni-intera.png'));

    await _mostra(t, const SchermataLicenze(versione: '2.2.0'));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/licenze.png'));

    await _mostra(t, _abbina(_avviaFinto), lato: const Size(412, 1500));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/abbina-telefono.png'));

    await _mostra(t, _abbina(_avviaFinto), lato: _tv);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/abbina-tv.png'));

    await _mostra(t, _abbina(_senzaRete));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/abbina-senza-rete.png'));

    await _mostra(
        t,
        SchermataImpostazioni(
            urlIniziale: 'https://esempio.it/lista.m3u',
            caricamento: false,
            errore: null,
            onIndietro: () {},
            onSalva: (_) {}),
        lato: const Size(412, 1100));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/impostazioni.png'));

    await t.pumpWidget(const SizedBox());
  });
}
