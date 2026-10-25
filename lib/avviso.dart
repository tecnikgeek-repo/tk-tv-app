// Avviso sulle liste (Pietro, 25/10): tk-tv è solo un lettore. Riquadro ambra con l'icona di avviso, uguale a
// quello del programma per computer: nel benvenuto, nella schermata di abbinamento e accanto al campo del link.
import 'package:flutter/material.dart';

import 'tema.dart';
import 'tk_licenza.dart';
import 'tk_pro.dart';

const avvisoTitolo = 'tk-tv è solo un lettore';
const avvisoTesto = "Non contiene e non fornisce canali né liste. Sei l'unico responsabile delle liste e dei contenuti "
    'che usi: usa solo canali che hai il diritto di vedere.';
const avvisoFine = 'Siamo contro la pirateria.';

const ambra = Color(0xFFF59E0B);

class AvvisoListe extends StatelessWidget {
  const AvvisoListe({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
        decoration: BoxDecoration(
          color: ambra.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ambra.withValues(alpha: .40)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: ambra.withValues(alpha: .18), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.warning_amber_rounded, color: ambra, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(avvisoTitolo, style: TextStyle(color: bianco, fontSize: 14.5, fontWeight: FontWeight.w800)),
              SizedBox(height: 4),
              Text(avvisoTesto, style: TextStyle(color: grigio300, fontSize: 13, height: 1.4)),
              SizedBox(height: 4),
              Text(avvisoFine, style: TextStyle(color: ambra, fontSize: 13, fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
      );
}

/// Frase in più del benvenuto di tk-tv: cosa resta sul dispositivo e cosa va in rete.
const righeBenvenutoTv = [
  'Il link della tua lista resta solo su questo dispositivo. In rete tk-tv contatta gli indirizzi della tua lista '
      "(canali e loghi) e Dropbox per controllare gli aggiornamenti. L'abbinamento col telefono passa solo dalla "
      'tua rete di casa, senza nessun server esterno.',
];

/// Benvenuto del primo avvio (quello comune di tk_pro, una volta sola) con sopra il riquadro ambra delle liste.
Future<void> benvenutoTv(BuildContext context) async {
  final lic = proTk?.lic;
  if (lic == null || lic.benvenutoVisto) return;
  await Navigator.of(context)
      .push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => BenvenutoTv(lic: lic)));
}

class BenvenutoTv extends StatelessWidget {
  const BenvenutoTv({super.key, required this.lic});

  final Licenza lic;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: navy,
        body: Column(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(22, MediaQuery.of(context).padding.top + 18, 22, 0),
            child: const AvvisoListe(),
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: SchermataBenvenuto(lic: lic, righeExtra: righeBenvenutoTv),
            ),
          ),
        ]),
      );
}
