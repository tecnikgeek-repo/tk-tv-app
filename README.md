# tk-tv per Android, Android TV e iPhone

Lettore di liste M3U per TV, proiettori, telefoni e tablet: canali in evidenza, preferiti, ricerca, zapping col
telecomando e lancio delle app di streaming installate. Il link della lista si può mandare dal telefono con un QR,
sulla rete di casa. Tutte le funzioni sono gratis, per tutti.

> **tk-tv è solo un lettore:** non contiene e non fornisce canali né liste. Sei l'unico responsabile delle liste e
> dei contenuti che usi: usa solo canali che hai il diritto di vedere. Siamo contro la pirateria.

- **Piattaforme:** Android, Android TV e iPhone. C'è anche per Windows e Mac: [tk-tv per computer](https://pietrodefilippis.it/software/).
- **Licenza:** software libero sotto [GNU AGPL-3.0](COPYING), fornito così com'è, senza alcuna garanzia.
- **Abbinamento col telefono:** la TV apre un piccolo server sulla rete di casa e mostra un QR con il suo indirizzo
  locale (`http://<ip>:<porta>/?k=<codice>`); il telefono, sulla stessa rete, apre la pagina e invia il link. Nessun
  server esterno; il codice è casuale, vale 5 minuti e una volta sola.
- **Privacy:** il link della lista e i preferiti restano sul dispositivo. In rete l'app contatta gli indirizzi della
  tua lista (canali e loghi) e Dropbox per gli aggiornamenti. Le statistiche anonime (una volta al giorno: nome,
  versione, sistema e un codice casuale) partono solo se dici sì nel benvenuto o in Informazioni.

## Compilare dal sorgente

Serve [Flutter](https://flutter.dev) (versione indicata in `.github/workflows/android.yml`):

```
flutter pub get
flutter test
flutter build apk --release
```

Senza la variabile `ANDROID_KEYSTORE` l'APK si firma con la chiave di debug di Flutter.

Il nome «tk-tv» e il logo non sono coperti dalla licenza (AGPL sez. 7): una versione modificata deve avere un
nome diverso.

© 2026 Pietro De Filippis (TecnikGeek) — [pietrodefilippis.it](https://pietrodefilippis.it)
