// Abbinamento col telefono in RETE LOCALE, senza nessun server esterno.
// La TV apre un piccolo server web sul suo indirizzo della rete di casa (Wi-Fi o cavo) e mostra il QR con
// http://<ip-locale>:<porta>/?k=<codice>. Il telefono, sulla stessa rete, apre la pagina servita da qui,
// incolla il link della lista e lo invia: il link arriva all'app. Il codice è casuale, vale 5 minuti e una sola
// volta; si accettano solo link http/https; il server si chiude all'invio, alla scadenza o all'uscita.
// Copyright (C) 2026 Pietro De Filippis (TecnikGeek) — AGPL-3.0-or-later, vedi COPYING
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Nessuna rete locale (Wi-Fi o cavo) su cui il telefono possa raggiungere la TV.
class NessunaReteLocale implements Exception {
  const NessunaReteLocale();

  @override
  String toString() => 'Nessuna rete Wi-Fi';
}

/// Quello che la schermata deve sapere di un abbinamento in corso (nei test se ne usa uno finto).
abstract class Abbinamento {
  /// Indirizzo da aprire sul telefono (anche nel QR): `http://192.168.1.20:41234/?k=abcd…`
  String get indirizzo;

  /// Quando il codice smette di valere.
  DateTime get scadenza;

  Future<void> chiudi();
}

/// Avvia un abbinamento: [onLink] riceve il link della lista inviato dal telefono, [onFine] scatta quando il
/// server si chiude da solo (scaduto o troppi tentativi sbagliati), non quando lo chiude chi l'ha aperto.
typedef AvviaAbbinamento = Future<Abbinamento> Function(
    {required void Function(String link) onLink, required void Function() onFine});

const validitaAbbinamento = Duration(minutes: 5);
const _tentativiMassimi = 30; // poi il server si chiude: niente prove a raffica sul codice
const _corpoMassimo = 16 * 1024;

// lettere e cifre facili da leggere (niente 0/o, 1/l/i): il codice si può anche scrivere a mano
const _alfabeto = 'abcdefghjkmnpqrstuvwxyz23456789';

/// Codice casuale di [lunghezza] caratteri (generatore sicuro).
String nuovoCodiceAbbinamento([int lunghezza = 12]) {
  final r = Random.secure();
  return String.fromCharCodes(Iterable.generate(lunghezza, (_) => _alfabeto.codeUnitAt(r.nextInt(_alfabeto.length))));
}

/// Il link della lista è accettabile? Solo http/https con un host, senza spazi, non troppo lungo.
bool linkListaValido(String link) {
  final t = link.trim();
  if (t.isEmpty || t.length > 4096 || t.contains(RegExp(r'\s'))) return false;
  final u = Uri.tryParse(t);
  if (u == null) return false;
  return (u.scheme == 'http' || u.scheme == 'https') && u.host.isNotEmpty;
}

bool _privato(InternetAddress a) {
  final b = a.rawAddress;
  if (b.length != 4) return false;
  return b[0] == 10 || (b[0] == 172 && b[1] >= 16 && b[1] <= 31) || (b[0] == 192 && b[1] == 168);
}

/// Indirizzo IPv4 della TV sulla rete di casa: prima il Wi-Fi (wlan), poi il cavo (eth), poi qualunque
/// indirizzo privato. Null se non c'è nessuna rete locale.
Future<InternetAddress?> indirizzoLocale() async {
  final List<NetworkInterface> schede;
  try {
    schede = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
  } catch (_) {
    return null;
  }
  int peso(NetworkInterface n) {
    final nome = n.name.toLowerCase();
    if (nome.startsWith('wlan') || nome.startsWith('wl') || nome.startsWith('en0')) return 0;
    if (nome.startsWith('eth') || nome.startsWith('en')) return 1;
    return 2;
  }

  final ordinate = [...schede]..sort((a, b) => peso(a).compareTo(peso(b)));
  for (final n in ordinate) {
    for (final a in n.addresses) {
      if (_privato(a)) return a;
    }
  }
  return null;
}

class ServerAbbinamento implements Abbinamento {
  ServerAbbinamento._(this._server, this._ip, this.codice, this.scadenza, this._onLink, this._onFine, this._ora);

  final HttpServer _server;
  final InternetAddress _ip;
  final String codice;
  @override
  final DateTime scadenza;
  final void Function(String) _onLink;
  final void Function() _onFine;
  final DateTime Function() _ora;
  Timer? _timer;
  bool _chiuso = false;
  bool _usato = false;
  int _sbagliati = 0;

  int get porta => _server.port;
  bool get chiuso => _chiuso;

  @override
  String get indirizzo => 'http://${_ip.address}:$porta/?k=$codice';

  /// Apre il server. [ip] e [ora] servono ai test (127.0.0.1, orologio finto); di serie l'indirizzo locale.
  /// Lancia [NessunaReteLocale] se la TV non è collegata a nessuna rete di casa.
  static Future<ServerAbbinamento> avvia({
    required void Function(String link) onLink,
    required void Function() onFine,
    InternetAddress? ip,
    Duration validita = validitaAbbinamento,
    DateTime Function()? ora,
    String? codice,
  }) async {
    final indirizzo = ip ?? await indirizzoLocale();
    if (indirizzo == null) throw const NessunaReteLocale();
    // solo su quell'indirizzo (non su tutte le schede) e su una porta libera scelta dal sistema
    final server = await HttpServer.bind(indirizzo, 0);
    server.autoCompress = false;
    server.serverHeader = null;
    final orologio = ora ?? DateTime.now;
    final s = ServerAbbinamento._(
        server, indirizzo, codice ?? nuovoCodiceAbbinamento(), orologio().add(validita), onLink, onFine, orologio);
    s._timer = Timer(validita, () => s._chiudi(daSolo: true));
    server.listen(s._richiesta, onError: (_) {});
    return s;
  }

  /// Avvio di serie per la schermata.
  static Future<Abbinamento> avviaSuRete(
          {required void Function(String link) onLink, required void Function() onFine}) =>
      avvia(onLink: onLink, onFine: onFine);

  bool get _valido => !_chiuso && !_usato && _ora().isBefore(scadenza);

  @override
  Future<void> chiudi() => _chiudi(daSolo: false);

  Future<void> _chiudi({required bool daSolo}) async {
    if (_chiuso) return;
    _chiuso = true;
    _timer?.cancel();
    try {
      await _server.close(force: true);
    } catch (_) {}
    if (daSolo) _onFine();
  }

  bool _codiceGiusto(String? k) {
    if (k == null || k.length != codice.length) return false;
    var diverso = 0;
    for (var i = 0; i < k.length; i++) {
      diverso |= k.codeUnitAt(i) ^ codice.codeUnitAt(i);
    }
    return diverso == 0;
  }

  Future<void> _richiesta(HttpRequest req) async {
    try {
      if (req.uri.path != '/') {
        await _rispondi(req, HttpStatus.notFound, _pagina('Pagina non trovata', _messaggio('Pagina non trovata.')));
        return;
      }
      if (req.method == 'GET' || req.method == 'HEAD') {
        await _get(req);
      } else if (req.method == 'POST') {
        await _post(req);
      } else {
        req.response.headers.set(HttpHeaders.allowHeader, 'GET, POST');
        await _rispondi(req, HttpStatus.methodNotAllowed, _pagina('Non consentito', _messaggio('Richiesta non valida.')));
      }
    } catch (_) {
      try {
        await req.response.close();
      } catch (_) {}
    }
  }

  Future<void> _get(HttpRequest req) async {
    if (!_controlla(req.uri.queryParameters['k'])) {
      await _rispondi(req, HttpStatus.forbidden, _paginaScaduta());
      return;
    }
    await _rispondi(req, HttpStatus.ok, _paginaModulo());
  }

  Future<void> _post(HttpRequest req) async {
    final tipo = req.headers.contentType;
    if (tipo == null || tipo.mimeType != 'application/x-www-form-urlencoded') {
      await _rispondi(req, HttpStatus.unsupportedMediaType, _pagina('Non valido', _messaggio('Richiesta non valida.')));
      return;
    }
    final byte = <int>[];
    await for (final pezzo in req) {
      byte.addAll(pezzo);
      if (byte.length > _corpoMassimo) {
        await _rispondi(req, HttpStatus.requestEntityTooLarge, _pagina('Troppo lungo', _messaggio('Link troppo lungo.')));
        return;
      }
    }
    final Map<String, String> campi;
    try {
      campi = Uri.splitQueryString(utf8.decode(byte, allowMalformed: true));
    } catch (_) {
      await _rispondi(req, HttpStatus.badRequest, _pagina('Non valido', _messaggio('Richiesta non valida.')));
      return;
    }
    if (!_controlla(campi['k'])) {
      await _rispondi(req, HttpStatus.forbidden, _paginaScaduta());
      return;
    }
    final link = (campi['link'] ?? '').trim();
    if (!linkListaValido(link)) {
      await _rispondi(req, HttpStatus.badRequest,
          _paginaModulo(errore: 'Il link deve iniziare con http:// o https://', valore: link));
      return;
    }
    _usato = true; // una volta sola: da qui il codice non vale più
    await _rispondi(req, HttpStatus.ok, _paginaInviato());
    _onLink(link);
    // un attimo di respiro perché la pagina «Lista inviata» arrivi intera al telefono, poi si chiude
    unawaited(Future<void>.delayed(const Duration(milliseconds: 300), () => _chiudi(daSolo: false)));
  }

  /// Codice giusto e ancora valido? I tentativi sbagliati si contano: oltre [_tentativiMassimi] si chiude.
  bool _controlla(String? k) {
    if (!_valido) return false;
    if (_codiceGiusto(k)) return true;
    if (++_sbagliati >= _tentativiMassimi) unawaited(_chiudi(daSolo: true));
    return false;
  }

  Future<void> _rispondi(HttpRequest req, int stato, String html) async {
    final r = req.response
      ..statusCode = stato
      ..headers.contentType = ContentType.html
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
      ..headers.set('X-Content-Type-Options', 'nosniff')
      ..headers.set('X-Frame-Options', 'DENY')
      ..headers.set('Referrer-Policy', 'no-referrer')
      ..headers.set('Content-Security-Policy',
          "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'");
    if (req.method != 'HEAD') r.write(html);
    await r.close();
  }

  // ───────────────────────── pagine per il telefono ─────────────────────────

  String _paginaModulo({String? errore, String valore = ''}) => _pagina('Invia la lista a tk-tv', '''
<h1>Invia la lista alla TV</h1>
<p class="sotto">Incolla il link della tua lista M3U e premi «Invia»: i canali si caricano sulla TV.</p>
<form method="post" action="/" autocomplete="off">
  <input type="hidden" name="k" value="${_esc(codice)}">
  <label for="link">Link della lista</label>
  <input id="link" name="link" type="url" inputmode="url" required autofocus placeholder="https://…/lista.m3u"
    value="${_esc(valore)}" autocapitalize="off" autocorrect="off" spellcheck="false">
  ${errore == null ? '' : '<p class="errore">${_esc(errore)}</p>'}
  <button type="submit">Invia alla TV</button>
</form>
$_avviso
<p class="nota">Il link va solo alla TV, sulla tua rete di casa: non passa da nessun server. Questa pagina vale
5 minuti e una volta sola.</p>''');

  String _paginaInviato() => _pagina('Lista inviata', '''
<div class="fatto">&#10003;</div>
<h1>Lista inviata</h1>
<p class="sotto">Guarda la TV: tk-tv sta caricando i canali. Puoi chiudere questa pagina.</p>''');

  String _paginaScaduta() => _pagina('Codice non valido', '''
<h1>Codice scaduto o non valido</h1>
<p class="sotto">Sulla TV apri di nuovo «Collega il telefono» e inquadra il QR nuovo.</p>''');

  String _messaggio(String testo) => '<h1>${_esc(testo)}</h1>';

  static const _avviso = '''
<div class="avviso"><div class="icona">!</div><div><b>tk-tv è solo un lettore</b><br>
Non contiene e non fornisce canali né liste. Sei l'unico responsabile delle liste e dei contenuti che usi:
usa solo canali che hai il diritto di vedere.<br><b class="ambra">Siamo contro la pirateria.</b></div></div>''';

  static String _pagina(String titolo, String corpo) => '''<!doctype html>
<html lang="it"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>${_esc(titolo)} · tk-tv</title>
<style>
*{box-sizing:border-box}
body{margin:0;background:#0F172A;color:#CBD5E1;font:16px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;
  padding:24px 16px 32px}
main{max-width:480px;margin:0 auto}
.marchio{display:flex;align-items:center;gap:12px;margin-bottom:22px}
.logo{width:44px;height:44px;border-radius:12px;background:linear-gradient(135deg,#E11D48,#BE123C);
  display:flex;align-items:center;justify-content:center;color:#fff;font-weight:800;font-size:15px}
.nome{color:#fff;font-weight:800;font-size:20px}
h1{color:#fff;font-size:22px;line-height:1.25;margin:0 0 6px}
.sotto{margin:0 0 20px}
form{background:#1E293B;border-radius:16px;padding:18px;margin-bottom:16px}
label{display:block;color:#FB7185;font-size:12px;font-weight:800;letter-spacing:.8px;text-transform:uppercase;
  margin-bottom:8px}
input[type=url]{width:100%;font-size:16px;padding:14px;border-radius:12px;border:1px solid #334155;
  background:#0F172A;color:#fff;outline:none}
input[type=url]:focus{border-color:#E11D48}
button{width:100%;margin-top:14px;padding:15px;border:0;border-radius:12px;background:#E11D48;color:#fff;
  font-size:16px;font-weight:800}
.errore{color:#FB7185;font-size:14px;margin:10px 0 0}
.avviso{display:flex;gap:14px;background:rgba(245,158,11,.10);border:1px solid rgba(245,158,11,.40);
  border-radius:14px;padding:14px 16px;font-size:14px;margin-bottom:16px}
.avviso b{color:#fff}.avviso .ambra{color:#F59E0B}
.icona{flex:none;width:36px;height:36px;border-radius:10px;background:rgba(245,158,11,.18);color:#F59E0B;
  font-weight:900;font-size:20px;display:flex;align-items:center;justify-content:center}
.nota{color:#64748B;font-size:13px;margin:0}
.fatto{width:64px;height:64px;border-radius:50%;background:#16A34A;color:#fff;font-size:34px;font-weight:800;
  display:flex;align-items:center;justify-content:center;margin:8px 0 18px}
</style></head>
<body><main>
<div class="marchio"><div class="logo">tk</div><div class="nome">tk-tv</div></div>
$corpo
</main></body></html>''';

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}
