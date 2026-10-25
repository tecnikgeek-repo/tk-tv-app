// tk-tv per Android, Android TV e iPhone — TecnikGeek (pietrodefilippis.it)
// Copyright (C) 2026 Pietro De Filippis (TecnikGeek) — AGPL-3.0-or-later, vedi COPYING
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'abbina.dart';
import 'avviso.dart';
import 'canali.dart';
import 'impostazioni.dart';
import 'lista.dart';
import 'player.dart';
import 'stato.dart';
import 'tema.dart';
import 'tk_licenza.dart';
import 'tk_pro.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configTk = configTv;
  registraLicenzaAgpl();
  await _avviaLicenza();
  runApp(const AppTkTv());
}

/// Benvenuto, statistiche (solo col consenso) e invito al caffè: tutte le funzioni sono per tutti.
Future<void> _avviaLicenza() async {
  try {
    final info = await PackageInfo.fromPlatform();
    final lic = Licenza(slug: 'tk-tv-app', versione: info.version);
    await lic.carica();
    proTk = ProTk(lic);
    lic.avvia(); // segnale del giorno in sottofondo, SOLO se l'utente ha detto sì alle statistiche
  } catch (_) {
    proTk = null; // senza memoria niente benvenuto né statistiche: l'app funziona lo stesso
  }
}

class AppTkTv extends StatelessWidget {
  const AppTkTv({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'tk-tv',
        debugShowCheckedModeBanner: false,
        theme: temaKit(),
        // menu del testo («Incolla», «Copia») e messaggi di sistema in italiano
        locale: const Locale('it'),
        supportedLocales: const [Locale('it')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Regia(),
      );
}

/// Decide quale schermata mostrare: avvio, collega/impostazioni o lista (il player si apre sopra la lista).
class Regia extends StatefulWidget {
  const Regia({super.key});

  @override
  State<Regia> createState() => _RegiaState();
}

class _RegiaState extends State<Regia> {
  final _stato = StatoApp();
  bool _avvioMinimo = false;
  bool _manuale = false; // in configurazione: false = QR (predefinito), true = link a mano
  bool _aggiornamentoVisto = false;

  @override
  void initState() {
    super.initState();
    _stato.addListener(_cambio);
    _stato.avvia();
    // L'avvio resta almeno 1,8 secondi e finché la prima playlist si carica: niente lampeggi.
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _avvioMinimo = true);
    });
  }

  @override
  void dispose() {
    _stato.removeListener(_cambio);
    super.dispose();
  }

  void _cambio() {
    if (mounted) setState(() {});
  }

  Future<void> _riproduci(Canale c) async {
    final i = _stato.canali.indexOf(c);
    if (i < 0) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SchermataPlayer(canali: _stato.canali, inizio: i)));
  }

  @override
  Widget build(BuildContext context) {
    final s = _stato;
    final avvio = !_avvioMinimo || (s.caricamento && s.canali.isEmpty);
    if (avvio) {
      return const SchermataAvvio();
    }

    // una volta, quando la prima schermata è pronta: benvenuto PRIMA di qualunque chiamata in rete
    // dell'app, poi il controllo aggiornamenti silenzioso
    if (!_aggiornamentoVisto) {
      _aggiornamentoVisto = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (context.mounted) await benvenutoTv(context);
        if (context.mounted) proponiAggiornamento(context, avvisaSeAggiornata: false);
        // invito al caffè: al primo avvio e poi al massimo una volta al mese, mai sopra un'altra finestra
        if (context.mounted) invitoCaffe(context);
      });
    }

    if (s.daConfigurare || s.canali.isEmpty) {
      if (_manuale) {
        return SchermataImpostazioni(
          key: ValueKey('imp${s.playlistUrl}'),
          urlIniziale: s.playlistUrl,
          caricamento: s.caricamento,
          errore: s.errore,
          onIndietro: () => setState(() => _manuale = false),
          onSalva: s.carica,
        );
      }
      return SchermataAbbina(
        puoTornare: s.canali.isNotEmpty,
        caricamento: s.caricamento,
        errore: s.errore,
        onRicevuto: s.carica,
        onManuale: () => setState(() => _manuale = true),
        onIndietro: s.annullaConfigurazione,
      );
    }
    return SchermataLista(
      canali: s.canali,
      totale: s.canali.length,
      preferiti: s.preferiti,
      onCanale: _riproduci,
      onPreferito: s.cambiaPreferito,
      onRicarica: s.ricarica,
      onImpostazioni: () {
        _manuale = false;
        s.apriConfigurazione();
      },
      onInfo: () => apriInformazioni(context,
          righe: () async => [('Canali caricati', '${s.canali.length}'), ('Preferiti', '${s.preferiti.length}')],
          notaDati: 'Il link della lista e i preferiti restano su questo dispositivo.'),
    );
  }
}
