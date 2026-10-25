// Impostazioni: inserire o cambiare a mano il link della lista M3U.
import 'package:flutter/material.dart';

import 'avviso.dart';
import 'tema.dart';

class SchermataImpostazioni extends StatefulWidget {
  const SchermataImpostazioni({
    super.key,
    required this.urlIniziale,
    required this.caricamento,
    required this.errore,
    required this.onIndietro,
    required this.onSalva,
  });

  final String urlIniziale;
  final bool caricamento;
  final String? errore;
  final VoidCallback onIndietro;
  final void Function(String) onSalva;

  @override
  State<SchermataImpostazioni> createState() => _SchermataImpostazioniState();
}

class _SchermataImpostazioniState extends State<SchermataImpostazioni> {
  late final _url = TextEditingController(text: widget.urlIniziale);

  @override
  Widget build(BuildContext context) {
    final haUrl = widget.urlIniziale.trim().isNotEmpty;
    final cambiato = _url.text.trim() != widget.urlIniziale.trim();
    final pronto = !widget.caricamento && _url.text.trim().isNotEmpty;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (fatto, _) {
        if (!fatto) widget.onIndietro();
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [navy, navy2], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
          child: Column(children: [
            TestataSemplice(titolo: 'Impostazioni', indietro: widget.onIndietro),
            Expanded(
              child: ListView(
                // spazio per la barra di navigazione di Android (l'app è disegnata anche sotto)
                padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
                children: [
                const Center(child: LogoTk(lato: 76)),
                const SizedBox(height: 14),
                const Center(child: Text('tk-tv', style: TextStyle(color: bianco, fontSize: 24, fontWeight: FontWeight.bold))),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                      haUrl ? 'Modifica la tua lista quando vuoi' : 'Inserisci il link della tua lista M3U per iniziare',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: grigio300, fontSize: 13)),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: navy2, borderRadius: BorderRadius.circular(16)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Row(children: [
                      Icon(Icons.link, color: accento, size: 18),
                      SizedBox(width: 8),
                      Text('LINK DELLA TUA LISTA',
                          style: TextStyle(color: accento, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: .8)),
                    ]),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _url,
                      enabled: !widget.caricamento,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => pronto ? widget.onSalva(_url.text.trim()) : null,
                      style: const TextStyle(color: bianco),
                      cursorColor: accento,
                      decoration: InputDecoration(
                        labelText: 'Link della lista M3U',
                        labelStyle: const TextStyle(color: grigio300),
                        floatingLabelStyle: const TextStyle(color: accento),
                        hintText: 'https://…/lista.m3u',
                        hintStyle: const TextStyle(color: grigio500),
                        filled: true,
                        fillColor: navy,
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: navy3)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: accento)),
                        disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: navy3)),
                      ),
                    ),
                    if (widget.errore != null) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        const Icon(Icons.info, color: accentoChiaro, size: 16),
                        const SizedBox(width: 6),
                        Expanded(child: Text(widget.errore!, style: const TextStyle(color: accentoChiaro, fontSize: 13))),
                      ]),
                    ],
                    const SizedBox(height: 18),
                    Selezionabile(
                      raggio: 12,
                      colore: pronto ? accento : navy3,
                      onTap: pronto ? () => widget.onSalva(_url.text.trim()) : null,
                      child: SizedBox(
                        height: 52,
                        child: Center(
                          child: widget.caricamento
                              ? const SizedBox(
                                  width: 22, height: 22, child: CircularProgressIndicator(color: bianco, strokeWidth: 2))
                              : Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.check_circle, color: bianco, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                      haUrl && !cambiato
                                          ? 'Ricarica canali'
                                          : (haUrl ? 'Salva e ricarica' : 'Carica canali'),
                                      style: const TextStyle(color: bianco, fontWeight: FontWeight.bold)),
                                ]),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                const AvvisoListe(),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: navy2.withValues(alpha: .6), borderRadius: BorderRadius.circular(12)),
                  child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.info, color: grigio500, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          'Incolla il link diretto al file .m3u o .m3u8 della tua lista (http o https). '
                          'Il link resta salvato solo su questo dispositivo.',
                          style: TextStyle(color: grigio500, fontSize: 12)),
                    ),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
