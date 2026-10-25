// Canali della lista M3U: modello, lettura del file e scaricamento (stessa logica della versione Kotlin).
import 'dart:convert';

import 'package:http/http.dart' as http;

class Canale {
  const Canale(this.numero, this.nome, this.gruppo, this.url, this.userAgent, this.logo);

  final int numero;
  final String nome;
  final String gruppo;
  final String url;
  final String userAgent;
  final String logo;
}

final _reChno = RegExp(r'tvg-chno="([^"]*)"');
final _reGroup = RegExp(r'group-title="([^"]*)"');
final _reLogo = RegExp(r'tvg-logo="([^"]*)"');
final _reNumNome = RegExp(r'^\[(\d+)]\s*(.+)$');

// flussi accettati dalla lista (come il programma per computer); i loghi solo dal web
const _schemiFlusso = {'http', 'https', 'udp', 'rtp', 'rtsp', 'rtmp'};

bool _schema(String url, Set<String> ammessi) {
  final u = Uri.tryParse(url.trim());
  return u != null && ammessi.contains(u.scheme.toLowerCase());
}

/// Il flusso del canale ha un indirizzo accettato (http, https, udp, rtp, rtsp, rtmp)?
bool flussoAmmesso(String url) => _schema(url, _schemiFlusso);

/// Analizza il testo di una playlist M3U e ritorna la lista dei canali.
List<Canale> leggiM3u(String testo) {
  final canali = <Canale>[];
  var numero = 0;
  var nome = '', gruppo = '', logo = '', ua = '';
  var auto = 1000;
  for (final grezza in testo.split('\n')) {
    final riga = grezza.trim();
    if (riga.isEmpty || riga.startsWith('#EXTM3U')) continue;
    if (riga.startsWith('#EXTINF')) {
      numero = 0;
      nome = gruppo = logo = ua = '';
      final c = _reChno.firstMatch(riga);
      if (c != null) numero = int.tryParse(c.group(1)!) ?? 0;
      gruppo = _reGroup.firstMatch(riga)?.group(1) ?? '';
      logo = _reLogo.firstMatch(riga)?.group(1) ?? '';
      if (!_schema(logo, const {'http', 'https'})) logo = '';
      final etichetta = riga.substring(riga.lastIndexOf(',') + 1).trim();
      final m = _reNumNome.firstMatch(etichetta);
      if (m != null) {
        numero = int.tryParse(m.group(1)!) ?? numero;
        nome = m.group(2)!.trim();
      } else {
        nome = etichetta;
      }
      if (numero == 0) numero = auto++;
    } else if (riga.startsWith('#EXTVLCOPT:http-user-agent=')) {
      ua = riga.substring(riga.indexOf('=') + 1).trim();
    } else if (riga.startsWith('#')) {
      continue;
    } else if (flussoAmmesso(riga)) {
      canali.add(Canale(numero, nome, gruppo, riga, ua, logo));
    }
  }
  return canali;
}

/// Scarica e legge la lista. Lancia un messaggio leggibile in caso di errore.
Future<List<Canale>> scaricaCanali(String url) async {
  final http.Response r;
  try {
    r = await http.get(Uri.parse(url.trim()), headers: {'User-Agent': 'tk-tv'}).timeout(const Duration(seconds: 15));
  } on FormatException {
    throw 'Link non valido';
  } catch (_) {
    throw 'Lista non raggiungibile: controlla il link e la connessione';
  }
  if (r.statusCode < 200 || r.statusCode > 299) throw 'Errore HTTP ${r.statusCode}';
  // come la versione Kotlin (readText): il file si legge in UTF-8
  final canali = leggiM3u(utf8.decode(r.bodyBytes, allowMalformed: true));
  if (canali.isEmpty) throw 'Nessun canale trovato nella lista';
  return canali;
}

// Canali «generalisti» in evidenza, in quest'ordine.
const _generalisti = ['rai1', 'rai2', 'rai3', 'rete4', 'canale5', 'italia1', 'la7', 'tv8', 'nove'];

/// Posizione del canale tra i generalisti (0 = primo) oppure -1 se non lo è.
int posizioneGeneralista(String nome) {
  final n = nome
      .toLowerCase()
      .replaceAll('uno', '1')
      .replaceAll('due', '2')
      .replaceAll('tre', '3')
      .replaceAll('quattro', '4')
      .replaceAll('cinque', '5')
      .replaceAll(RegExp(r'[^a-z0-9]'), '')
      .replaceAll(RegExp(r'(fhd|uhd|hd|4k)+$'), '');
  for (var i = 0; i < _generalisti.length; i++) {
    final k = _generalisti[i];
    if (n == k || (n.endsWith(k) && n.length - k.length <= 3)) return i;
  }
  return -1;
}
