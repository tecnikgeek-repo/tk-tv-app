// Prove del server di abbinamento in rete locale (su 127.0.0.1): codice giusto/sbagliato, scadenza, una volta
// sola, solo link http/https, chiusura. Niente binding di Flutter: l'HttpClient qui è quello vero.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tktv/abbina_server.dart';

class _Risposta {
  _Risposta(this.stato, this.testo);
  final int stato;
  final String testo;
}

final _client = HttpClient();

Future<_Risposta> _get(ServerAbbinamento s, String percorso) async {
  final req = await _client.getUrl(Uri.parse('http://127.0.0.1:${s.porta}$percorso'));
  final r = await req.close();
  return _Risposta(r.statusCode, await r.transform(utf8.decoder).join());
}

Future<_Risposta> _post(ServerAbbinamento s, Map<String, String> campi,
    {String tipo = 'application/x-www-form-urlencoded'}) async {
  final req = await _client.postUrl(Uri.parse('http://127.0.0.1:${s.porta}/'));
  req.headers.set(HttpHeaders.contentTypeHeader, tipo);
  req.write(Uri(queryParameters: campi).query);
  final r = await req.close();
  return _Risposta(r.statusCode, await r.transform(utf8.decoder).join());
}

void main() {
  late List<String> ricevuti;
  late int fini;
  late DateTime adesso;
  ServerAbbinamento? server;

  Future<ServerAbbinamento> avvia({Duration validita = validitaAbbinamento}) async {
    final s = await ServerAbbinamento.avvia(
      onLink: ricevuti.add,
      onFine: () => fini++,
      ip: InternetAddress.loopbackIPv4,
      validita: validita,
      ora: () => adesso,
      codice: 'abcdefgh2345',
    );
    server = s;
    return s;
  }

  setUp(() {
    ricevuti = [];
    fini = 0;
    adesso = DateTime(2026, 10, 25, 12);
  });

  tearDown(() async {
    await server?.chiudi();
    server = null;
  });

  test('indirizzo da mettere nel QR: ip locale, porta e codice', () async {
    final s = await avvia();
    expect(s.indirizzo, 'http://127.0.0.1:${s.porta}/?k=abcdefgh2345');
    expect(s.scadenza, adesso.add(const Duration(minutes: 5)));
  });

  test('codice giusto: la pagina col campo del link e l\'avviso', () async {
    final s = await avvia();
    final r = await _get(s, '/?k=abcdefgh2345');
    expect(r.stato, 200);
    expect(r.testo, contains('name="link"'));
    expect(r.testo, contains('Invia alla TV'));
    expect(r.testo, contains('tk-tv è solo un lettore'));
    expect(r.testo, contains('Siamo contro la pirateria.'));
    expect(r.testo, contains('lang="it"'));
  });

  test('codice sbagliato o mancante: rifiutato', () async {
    final s = await avvia();
    expect((await _get(s, '/?k=sbagliato000')).stato, 403);
    expect((await _get(s, '/')).stato, 403);
    expect((await _get(s, '/?k=abcdefgh234')).stato, 403, reason: 'codice troppo corto');
    expect((await _get(s, '/altro?k=abcdefgh2345')).stato, 404);
    final p = await _post(s, {'k': 'sbagliato000', 'link': 'https://esempio.it/lista.m3u'});
    expect(p.stato, 403);
    expect(ricevuti, isEmpty);
  });

  test('invio giusto: il link arriva all\'app, poi il codice non vale più e il server si chiude', () async {
    final s = await avvia();
    final r = await _post(s, {'k': 'abcdefgh2345', 'link': '  https://esempio.it/lista.m3u?u=1&p=2  '});
    expect(r.stato, 200);
    expect(r.testo, contains('Lista inviata'));
    expect(ricevuti, ['https://esempio.it/lista.m3u?u=1&p=2']);
    expect((await _get(s, '/?k=abcdefgh2345')).stato, 403, reason: 'una volta sola');
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(s.chiuso, isTrue);
    expect(fini, 0, reason: 'chiuso perché usato, non scaduto');
    await expectLater(_get(s, '/?k=abcdefgh2345'), throwsA(isA<IOException>()));
  });

  test('link non valido: rifiutato, il codice resta buono', () async {
    final s = await avvia();
    for (final l in ['', 'ftp://esempio.it/l.m3u', 'javascript:alert(1)', 'file:///sdcard/l.m3u', 'esempio.it/l.m3u',
      'http://', 'https://esempio.it/con spazio.m3u']) {
      final r = await _post(s, {'k': 'abcdefgh2345', 'link': l});
      expect(r.stato, 400, reason: l);
      expect(r.testo, contains('http:// o https://'), reason: l);
    }
    expect(ricevuti, isEmpty);
    final ok = await _post(s, {'k': 'abcdefgh2345', 'link': 'http://192.168.1.5/lista.m3u'});
    expect(ok.stato, 200);
    expect(ricevuti, ['http://192.168.1.5/lista.m3u']);
  });

  test('quello che si scrive torna nella pagina senza diventare codice', () async {
    final s = await avvia();
    final r = await _post(s, {'k': 'abcdefgh2345', 'link': '"><script>alert(1)</script>'});
    expect(r.stato, 400);
    expect(r.testo, isNot(contains('<script>')));
    expect(r.testo, contains('&quot;&gt;&lt;script&gt;'));
  });

  test('solo moduli veri: altri tipi di invio rifiutati', () async {
    final s = await avvia();
    final r = await _post(s, {'k': 'abcdefgh2345', 'link': 'https://esempio.it/l.m3u'}, tipo: 'application/json');
    expect(r.stato, 415);
    expect(ricevuti, isEmpty);
  });

  test('dopo 5 minuti il codice scade', () async {
    final s = await avvia();
    adesso = adesso.add(const Duration(minutes: 4, seconds: 59));
    expect((await _get(s, '/?k=abcdefgh2345')).stato, 200);
    adesso = adesso.add(const Duration(seconds: 2));
    expect((await _get(s, '/?k=abcdefgh2345')).stato, 403);
    final p = await _post(s, {'k': 'abcdefgh2345', 'link': 'https://esempio.it/l.m3u'});
    expect(p.stato, 403);
    expect(p.testo, contains('scaduto'));
    expect(ricevuti, isEmpty);
  });

  test('alla scadenza il server si chiude da solo e lo dice', () async {
    final s = await avvia(validita: const Duration(milliseconds: 200));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(s.chiuso, isTrue);
    expect(fini, 1);
    await expectLater(_get(s, '/?k=abcdefgh2345'), throwsA(isA<IOException>()));
  });

  test('troppi tentativi sbagliati: il server si chiude', () async {
    final s = await avvia();
    for (var i = 0; i < 30; i++) {
      try {
        await _get(s, '/?k=tentativo${i.toString().padLeft(3, '0')}');
      } on IOException {
        break;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(s.chiuso, isTrue);
    expect(fini, 1);
  });

  test('chiudere a mano non conta come scadenza', () async {
    final s = await avvia();
    await s.chiudi();
    expect(s.chiuso, isTrue);
    expect(fini, 0);
  });

  test('controllo dei link', () {
    expect(linkListaValido('http://esempio.it/l.m3u'), isTrue);
    expect(linkListaValido('https://esempio.it:8080/get.php?u=a&p=b&type=m3u_plus'), isTrue);
    expect(linkListaValido('HTTPS://ESEMPIO.IT/L.M3U'), isTrue);
    expect(linkListaValido('rtsp://esempio.it/l'), isFalse);
    expect(linkListaValido('data:text/plain,ciao'), isFalse);
    expect(linkListaValido('https://${'a' * 5000}.it'), isFalse);
  });

  test('codici casuali, lunghi 12, solo lettere e cifre facili da leggere', () {
    final visti = <String>{};
    for (var i = 0; i < 200; i++) {
      final c = nuovoCodiceAbbinamento();
      expect(c, matches(RegExp(r'^[a-hjkmnp-z2-9]{12}$')));
      visti.add(c);
    }
    expect(visti.length, 200);
  });
}
