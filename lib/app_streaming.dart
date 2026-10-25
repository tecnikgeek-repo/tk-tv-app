// Pay TV installate (Netflix, Prime Video, Disney+…): solo Android, tramite il codice nativo.
// I loro contenuti hanno il DRM e nessuna API pubblica: non si riproducono dentro tk-tv, si apre l'app ufficiale.
import 'dart:io';
import 'dart:typed_data';

import 'stato.dart' show nativo;

class AppStreaming {
  AppStreaming(this.id, this.nome, this.pacchetto, this.icona);

  final String id, nome, pacchetto;
  final Uint8List? icona;
}

Future<List<AppStreaming>> appInstallate() async {
  if (!Platform.isAndroid) return [];
  try {
    final r = await nativo.invokeListMethod<Map<Object?, Object?>>('appInstallate') ?? [];
    return [
      for (final m in r)
        AppStreaming('${m['id']}', '${m['nome']}', '${m['pacchetto']}', m['icona'] as Uint8List?)
    ];
  } catch (_) {
    return [];
  }
}

Future<bool> apriApp(AppStreaming app) async {
  try {
    return await nativo.invokeMethod<bool>('apriApp', {'pacchetto': app.pacchetto}) ?? false;
  } catch (_) {
    return false;
  }
}
