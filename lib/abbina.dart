// «Collega il telefono»: la TV apre un piccolo server sulla rete di casa e mostra il QR con il suo indirizzo
// locale. Dal telefono (stessa rete) si apre la pagina, si incolla il link della lista e lo si invia: arriva qui.
// Pensata per proiettori e TV, dove scrivere un link col telecomando è un incubo. Nessun server esterno.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'abbina_server.dart';
import 'avviso.dart';
import 'tema.dart';

enum _Fase { avvio, pronto, ricevuto, scaduto, nessunaRete, errore }

class SchermataAbbina extends StatefulWidget {
  const SchermataAbbina({
    super.key,
    required this.puoTornare,
    required this.onRicevuto,
    required this.onManuale,
    required this.onIndietro,
    this.caricamento = false,
    this.errore,
    this.avvia = ServerAbbinamento.avviaSuRete,
  });

  final bool puoTornare;
  final void Function(String) onRicevuto;
  final VoidCallback onManuale, onIndietro;

  /// La lista ricevuta si sta caricando / non si è caricata (messaggio): se fallisce si riparte con un QR nuovo.
  final bool caricamento;
  final String? errore;

  /// Chi apre il server (nei test uno finto).
  final AvviaAbbinamento avvia;

  @override
  State<SchermataAbbina> createState() => _SchermataAbbinaState();
}

class _SchermataAbbinaState extends State<SchermataAbbina> {
  _Fase _fase = _Fase.avvio;
  Abbinamento? _abb;
  int _tentativo = 0;
  Timer? _orologio;
  Duration _resta = validitaAbbinamento;
  String? _erroreLista;

  @override
  void initState() {
    super.initState();
    _avvia();
  }

  @override
  void didUpdateWidget(SchermataAbbina vecchio) {
    super.didUpdateWidget(vecchio);
    // la lista mandata dal telefono non si è caricata: si dice perché e si riparte con un codice nuovo
    if (_fase == _Fase.ricevuto && vecchio.caricamento && !widget.caricamento && widget.errore != null) {
      _erroreLista = widget.errore;
      _avvia();
    }
  }

  @override
  void dispose() {
    _tentativo++;
    _orologio?.cancel();
    _abb?.chiudi(); // il server si chiude sempre quando si esce dalla schermata
    super.dispose();
  }

  Future<void> _avvia() async {
    final mio = ++_tentativo;
    _orologio?.cancel();
    await _abb?.chiudi();
    _abb = null;
    if (!mounted) return;
    setState(() => _fase = _Fase.avvio);
    try {
      final a = await widget.avvia(
        onLink: (link) {
          if (!mounted || mio != _tentativo) return;
          _orologio?.cancel();
          setState(() {
            _fase = _Fase.ricevuto;
            _erroreLista = null;
          });
          widget.onRicevuto(link);
        },
        onFine: () {
          if (!mounted || mio != _tentativo) return;
          _orologio?.cancel();
          setState(() => _fase = _Fase.scaduto);
        },
      );
      if (!mounted || mio != _tentativo) {
        await a.chiudi();
        return;
      }
      _abb = a;
      _conta();
      _orologio = Timer.periodic(const Duration(seconds: 1), (_) => _conta());
      setState(() => _fase = _Fase.pronto);
    } on NessunaReteLocale {
      if (mounted && mio == _tentativo) setState(() => _fase = _Fase.nessunaRete);
    } catch (_) {
      if (mounted && mio == _tentativo) setState(() => _fase = _Fase.errore);
    }
  }

  void _conta() {
    final a = _abb;
    if (a == null || !mounted) return;
    var r = a.scadenza.difference(DateTime.now());
    if (r.isNegative) r = Duration.zero;
    setState(() => _resta = r);
  }

  String get _tempo {
    final s = (_resta.inMilliseconds / 1000).ceil();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (fatto, _) {
        if (!fatto && widget.puoTornare) widget.onIndietro();
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [navy, navy2], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
          child: Column(children: [
            TestataSemplice(titolo: 'Collega il telefono', indietro: widget.puoTornare ? widget.onIndietro : null),
            Expanded(
              child: LayoutBuilder(builder: (context, spazio) {
                final largo = spazio.maxWidth >= 760; // TV e proiettori: QR a sinistra, spiegazione a destra
                final basso = 20 + MediaQuery.of(context).padding.bottom;
                if (!largo) {
                  return ListView(padding: EdgeInsets.fromLTRB(20, 20, 20, basso), children: [
                    _intestazione(),
                    const SizedBox(height: 20),
                    Center(child: _riquadro()),
                    const SizedBox(height: 20),
                    ..._spiegazione(),
                  ]);
                }
                return ListView(padding: EdgeInsets.fromLTRB(32, 24, 32, basso), children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _riquadro(),
                    const SizedBox(width: 28),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        _intestazione(centrata: false),
                        const SizedBox(height: 18),
                        ..._spiegazione(),
                      ]),
                    ),
                  ]),
                ]);
              }),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _intestazione({bool centrata = true}) => Column(
        crossAxisAlignment: centrata ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          const Text('Manda la lista dal telefono',
              style: TextStyle(color: bianco, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Niente link da scrivere col telecomando: telefono e TV sulla stessa rete di casa.',
              textAlign: centrata ? TextAlign.center : TextAlign.start,
              style: const TextStyle(color: grigio300, fontSize: 13)),
        ],
      );

  List<Widget> _spiegazione() => [
        if (_erroreLista != null) ...[
          _Messaggio(icona: Icons.error_outline, colore: accentoChiaro, testo: 'La lista non si è caricata: $_erroreLista'),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: navy2.withValues(alpha: .6), borderRadius: BorderRadius.circular(16)),
          child: const Column(children: [
            _Passo(1, 'Collega il telefono alla stessa rete Wi-Fi della TV.'),
            SizedBox(height: 12),
            _Passo(2, 'Inquadra il QR con la fotocamera, oppure scrivi l\'indirizzo nel browser del telefono.'),
            SizedBox(height: 12),
            _Passo(3, 'Incolla il link della tua lista M3U e premi «Invia alla TV»: i canali si caricano qui.'),
          ]),
        ),
        const SizedBox(height: 12),
        const AvvisoListe(),
        const SizedBox(height: 16),
        Selezionabile(
          raggio: 12,
          bordo: Border.all(color: grigio500, width: 1),
          onTap: widget.onManuale,
          child: const SizedBox(
            height: 50,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.edit, size: 18, color: bianco),
              SizedBox(width: 8),
              Text('Inserisci il link a mano', style: TextStyle(color: bianco, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ];

  Widget _riquadro() => Container(
        width: 300,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: navy2, borderRadius: BorderRadius.circular(20)),
        child: switch (_fase) {
          _Fase.avvio => const SizedBox(height: 256, child: Center(child: CircularProgressIndicator(color: accento))),
          _Fase.pronto => _qr(),
          _Fase.ricevuto => const SizedBox(
              height: 256,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                CircularProgressIndicator(color: accento),
                SizedBox(height: 18),
                Text('Lista ricevuta', style: TextStyle(color: bianco, fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Carico i canali…', style: TextStyle(color: grigio300, fontSize: 13)),
              ])),
          _Fase.scaduto => _stato(Icons.timer_off_outlined, 'Codice scaduto',
              'Per sicurezza il QR vale 5 minuti. Creane uno nuovo.', 'Nuovo QR'),
          _Fase.nessunaRete => _stato(
              Icons.wifi_off,
              'Nessuna rete Wi-Fi',
              'Collega la TV alla rete Wi-Fi (o al cavo) di casa, la stessa del telefono, e riprova. '
                  'Oppure inserisci il link a mano.',
              'Riprova'),
          _Fase.errore => _stato(Icons.error_outline, 'Abbinamento non disponibile',
              'Non riesco ad aprire la connessione sulla rete di casa. Riprova o inserisci il link a mano.', 'Riprova'),
        },
      );

  Widget _qr() {
    final indirizzo = _abb!.indirizzo;
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: bianco, borderRadius: BorderRadius.circular(12)),
        child: QrImageView(data: indirizzo, size: 236, backgroundColor: bianco),
      ),
      const SizedBox(height: 16),
      const Text('OPPURE APRI SUL TELEFONO',
          style: TextStyle(color: grigio300, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
      const SizedBox(height: 6),
      SelectableText(indirizzo,
          textAlign: TextAlign.center,
          style: const TextStyle(color: bianco, fontSize: 15, fontWeight: FontWeight.bold, height: 1.35)),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.timer_outlined, color: grigio500, size: 15),
        const SizedBox(width: 6),
        Text('Vale ancora $_tempo · una volta sola', style: const TextStyle(color: grigio500, fontSize: 12)),
      ]),
    ]);
  }

  Widget _stato(IconData icona, String titolo, String testo, String pulsante) => SizedBox(
        height: 256,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icona, color: accentoChiaro, size: 40),
          const SizedBox(height: 12),
          Text(titolo,
              textAlign: TextAlign.center,
              style: const TextStyle(color: bianco, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(testo, textAlign: TextAlign.center, style: const TextStyle(color: grigio300, fontSize: 12.5, height: 1.4)),
          const SizedBox(height: 16),
          Selezionabile(
            raggio: 12,
            colore: accento,
            autofocus: true,
            onTap: _avvia,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.refresh, size: 18, color: bianco),
                const SizedBox(width: 8),
                Text(pulsante, style: const TextStyle(color: bianco, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
      );
}

class _Messaggio extends StatelessWidget {
  const _Messaggio({required this.icona, required this.colore, required this.testo});

  final IconData icona;
  final Color colore;
  final String testo;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icona, color: colore, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(testo, style: TextStyle(color: colore, fontSize: 13))),
      ]);
}

class _Passo extends StatelessWidget {
  const _Passo(this.numero, this.testo);

  final int numero;
  final String testo;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(color: accento, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text('$numero', style: const TextStyle(color: bianco, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(testo, style: const TextStyle(color: grigio300, fontSize: 14)))),
      ]);
}
