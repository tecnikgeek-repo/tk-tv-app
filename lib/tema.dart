// Colori di tk-tv (accento rosa/rosso, tema scuro per il televisore); il resto è nel kit comune delle app TK.
import 'package:flutter/material.dart';

import 'kit_tk.dart';

export 'kit_tk.dart';

const accento = Color(0xFFE11D48);
const accentoScuro = Color(0xFFBE123C);
const accentoChiaro = Color(0xFFFB7185);

const gradienteAccento = LinearGradient(colors: [accento, accentoScuro]);

const configTv = ConfigTk(
  nome: 'tk-tv',
  motto: 'Lettore di liste M3U',
  descrizione: 'Lettore di liste M3U per TV, telefono e tablet',
  accento: accento,
  accentoScuro: accentoScuro,
  simbolo: simboloTv,
  manifestUrl:
      'https://dl.dropboxusercontent.com/scl/fi/wi6jhxoa2cyszr4k1aumb/tv-version.json?rlkey=t2rohkvq5y075r2jnzedif7l9',
  scuro: true,
  altrove: ("C'è anche per Windows e Mac", 'https://pietrodefilippis.it/software/'),
);

/// Simbolo di tk-tv: televisore bianco.
Widget simboloTv(double lato) => Icon(Icons.live_tv, color: bianco, size: lato * .57);
