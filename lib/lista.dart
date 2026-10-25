// Lista canali: App (pay TV) + Generalisti (caroselli), Preferiti, poi i gruppi in ordine alfabetico.
import 'package:flutter/material.dart';

import 'app_streaming.dart';
import 'canali.dart';
import 'tema.dart';

class SchermataLista extends StatefulWidget {
  const SchermataLista({
    super.key,
    required this.canali,
    required this.totale,
    required this.preferiti,
    required this.onCanale,
    required this.onPreferito,
    required this.onRicarica,
    required this.onImpostazioni,
    required this.onInfo,
  });

  final List<Canale> canali;
  final int totale;
  final Set<String> preferiti;
  final void Function(Canale) onCanale;
  final void Function(String) onPreferito;
  final VoidCallback onRicarica, onImpostazioni, onInfo;

  @override
  State<SchermataLista> createState() => _SchermataListaState();
}

class _Riga {
  _Riga({this.titolo, this.canale, this.evidenza, this.app});
  final String? titolo;
  final Canale? canale;
  final List<Canale>? evidenza;
  final List<AppStreaming>? app;
}

class _SchermataListaState extends State<SchermataLista> with WidgetsBindingObserver {
  String _cerca = '';
  bool _cercando = false;
  List<AppStreaming> _app = [];
  final _primoFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _rilevaApp();
    // Focus iniziale sul primo canale: su TV/proiettore si vede subito dove si è col telecomando.
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _primoFocus.context != null) _primoFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _primoFocus.dispose();
    super.dispose();
  }

  // Se l'utente installa Netflix mentre tk-tv è in background, al rientro la card c'è già.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _rilevaApp();
  }

  Future<void> _rilevaApp() async {
    final a = await appInstallate();
    if (mounted) setState(() => _app = a);
  }

  List<_Riga> _righe() {
    final q = _cerca.toLowerCase();
    final filtrati = q.isEmpty ? widget.canali : widget.canali.where((c) => c.nome.toLowerCase().contains(q)).toList();
    final righe = <_Riga>[];
    final app = q.isEmpty ? _app : _app.where((a) => a.nome.toLowerCase().contains(q)).toList();
    if (app.isNotEmpty) righe.add(_Riga(titolo: 'App', app: app));
    if (q.isEmpty) {
      final gen = [
        for (final c in filtrati)
          if (posizioneGeneralista(c.nome) >= 0) c
      ]..sort((a, b) => posizioneGeneralista(a.nome).compareTo(posizioneGeneralista(b.nome)));
      final visti = <String>{};
      final unici = [for (final c in gen) if (visti.add(c.nome)) c];
      if (unici.isNotEmpty) righe.add(_Riga(titolo: 'Generalisti', evidenza: unici));
    }
    final pref = filtrati.where((c) => widget.preferiti.contains(c.nome)).toList();
    if (pref.isNotEmpty) {
      righe.add(_Riga(titolo: 'Preferiti'));
      righe.addAll(pref.map((c) => _Riga(canale: c)));
    }
    final gruppi = <String, List<Canale>>{};
    for (final c in filtrati) {
      gruppi.putIfAbsent(c.gruppo.trim().isEmpty ? 'Altri canali' : c.gruppo, () => []).add(c);
    }
    for (final g in gruppi.keys.toList()..sort()) {
      righe.add(_Riga(titolo: g));
      righe.addAll(gruppi[g]!.map((c) => _Riga(canale: c)));
    }
    return righe;
  }

  @override
  Widget build(BuildContext context) {
    final righe = _righe();
    final primo = righe.indexWhere((r) => r.canale != null);
    return Scaffold(
      backgroundColor: navy,
      body: Column(children: [
        _testata(),
        Expanded(
          child: righe.isEmpty
              ? const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Text('Nessun canale trovato', style: TextStyle(color: grigio300, fontSize: 16)))
              : ListView.builder(
                  padding: EdgeInsets.only(bottom: 24 + MediaQuery.of(context).padding.bottom),
                  itemCount: righe.length,
                  itemBuilder: (_, i) {
                    final r = righe[i];
                    if (r.app != null) {
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _Sezione(r.titolo!, r.app!.length),
                        _CaroselloApp(app: r.app!),
                      ]);
                    }
                    if (r.evidenza != null) {
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _Sezione(r.titolo!, r.evidenza!.length),
                        _CaroselloCanali(canali: r.evidenza!, onCanale: widget.onCanale),
                      ]);
                    }
                    if (r.titolo != null) return _Sezione(r.titolo!, null);
                    final c = r.canale!;
                    return _CardCanale(
                      canale: c,
                      preferito: widget.preferiti.contains(c.nome),
                      focusNode: i == primo ? _primoFocus : null,
                      onTap: () => widget.onCanale(c),
                      onPreferito: () => widget.onPreferito(c.nome),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _testata() => Container(
        decoration: const BoxDecoration(gradient: gradienteTestata),
        padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 14, 10, 14),
        child: Column(children: [
          Row(children: [
            const LogoTk(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('tk-tv', style: TextStyle(color: bianco, fontSize: 19, fontWeight: FontWeight.bold)),
                Text('${widget.totale} canali', style: const TextStyle(color: grigio300, fontSize: 12)),
              ]),
            ),
            AzioneTk(_cercando ? Icons.close : Icons.search, 'Cerca', () {
              setState(() {
                _cercando = !_cercando;
                if (!_cercando) _cerca = '';
              });
            }),
            AzioneTk(Icons.refresh, 'Ricarica', widget.onRicarica),
            AzioneTk(Icons.settings, 'Impostazioni', widget.onImpostazioni),
            AzioneTk(Icons.info, 'Info', widget.onInfo),
          ]),
          if (_cercando) ...[
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              onChanged: (t) => setState(() => _cerca = t),
              style: const TextStyle(color: bianco),
              cursorColor: accento,
              decoration: InputDecoration(
                hintText: 'Cerca canale…',
                hintStyle: const TextStyle(color: grigio300),
                prefixIcon: const Icon(Icons.search, color: grigio300),
                filled: true,
                fillColor: navy2,
                enabledBorder:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: navy3)),
                focusedBorder:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: accento)),
              ),
            ),
          ],
        ]),
      );
}

class _Sezione extends StatelessWidget {
  const _Sezione(this.titolo, this.conta);

  final String titolo;
  final int? conta;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Row(children: [
          Container(
              width: 4, height: 16, decoration: BoxDecoration(color: accento, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 8),
          Text(titolo.toUpperCase(),
              style: const TextStyle(color: grigio300, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
          if (conta != null) ...[
            const SizedBox(width: 8),
            Text('$conta', style: const TextStyle(color: grigio500, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ]),
      );
}

class _CaroselloCanali extends StatelessWidget {
  const _CaroselloCanali({required this.canali, required this.onCanale});

  final List<Canale> canali;
  final void Function(Canale) onCanale;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 126,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: canali.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) {
            final c = canali[i];
            return SizedBox(
              width: 108,
              child: Selezionabile(
                colore: navy2,
                bordo: Border.all(color: navy3, width: 1),
                onTap: () => onCanale(c),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(children: [
                    LogoCanale(canale: c, lato: 64),
                    const SizedBox(height: 8),
                    Text(c.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: bianco, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            );
          },
        ),
      );
}

class _CaroselloApp extends StatelessWidget {
  const _CaroselloApp({required this.app});

  final List<AppStreaming> app;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 126,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: app.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) {
            final a = app[i];
            return SizedBox(
              width: 108,
              child: Selezionabile(
                colore: navy2,
                bordo: Border.all(color: navy3, width: 1),
                onTap: () async {
                  if (!await apriApp(a) && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impossibile aprire ${a.nome}')));
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 64,
                        height: 64,
                        color: navy3,
                        child: a.icona != null
                            ? Image.memory(a.icona!, fit: BoxFit.contain)
                            : const Icon(Icons.apps, color: grigio300, size: 28),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(a.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: bianco, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            );
          },
        ),
      );
}

class _CardCanale extends StatelessWidget {
  const _CardCanale({
    required this.canale,
    required this.preferito,
    required this.onTap,
    required this.onPreferito,
    this.focusNode,
  });

  final Canale canale;
  final bool preferito;
  final VoidCallback onTap, onPreferito;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Selezionabile(
          colore: navy2,
          focusNode: focusNode,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 2, 8),
            child: Row(children: [
              LogoCanale(canale: canale, lato: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(canale.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: bianco, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: navy3, borderRadius: BorderRadius.circular(20)),
                      child: Text('CH ${canale.numero}',
                          style: const TextStyle(color: grigio300, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    if (canale.gruppo.trim().isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(canale.gruppo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: grigio500, fontSize: 11)),
                      ),
                    ],
                  ]),
                ]),
              ),
              IconButton(
                onPressed: onPreferito,
                tooltip: 'Preferito',
                icon: Icon(preferito ? Icons.star : Icons.star_border, color: preferito ? accento : grigio500),
              ),
            ]),
          ),
        ),
      );
}

/// Logo del canale; se manca o non si carica, il numero su fondo navy.
class LogoCanale extends StatelessWidget {
  const LogoCanale({super.key, required this.canale, required this.lato});

  final Canale canale;
  final double lato;

  @override
  Widget build(BuildContext context) {
    final numero = Center(
        child: Text('${canale.numero}',
            style: const TextStyle(color: grigio300, fontSize: 13, fontWeight: FontWeight.bold)));
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: lato,
        height: lato,
        color: navy3,
        child: canale.logo.trim().isEmpty
            ? numero
            : Padding(
                padding: const EdgeInsets.all(6),
                child: Image.network(
                  canale.logo,
                  fit: BoxFit.contain,
                  cacheWidth: (lato * 3).round(),
                  errorBuilder: (_, _, _) => numero,
                ),
              ),
      ),
    );
  }
}
