// Stato dell'app (link della lista, canali, preferiti) e salvataggio sul dispositivo.
// Su Android, al primo avvio, recupera i dati della versione precedente (Kotlin, DataStore «tk_tv»):
// chi aggiorna ritrova link e preferiti senza rifare niente.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'abbina_server.dart' show linkListaValido;
import 'canali.dart';

const nativo = MethodChannel('tktv/nativo');

class StatoApp extends ChangeNotifier {
  String playlistUrl = '';
  List<Canale> canali = [];
  Set<String> preferiti = {};
  bool caricamento = false;
  String? errore;
  bool daConfigurare = true;

  late SharedPreferences _pref;

  Future<void> avvia() async {
    _pref = await SharedPreferences.getInstance();
    if (Platform.isAndroid && !(_pref.getBool('migrato') ?? false)) {
      try {
        final vecchi = await nativo.invokeMapMethod<String, Object?>('vecchiDati');
        if (vecchi != null) {
          final url = '${vecchi['url'] ?? ''}';
          if (url.isNotEmpty) await _pref.setString('playlist_url', url);
          final pref = (vecchi['preferiti'] as List?)?.map((e) => '$e').toList() ?? [];
          if (pref.isNotEmpty) await _pref.setStringList('favorites', pref);
        }
      } catch (_) {}
      await _pref.setBool('migrato', true);
    }
    playlistUrl = _pref.getString('playlist_url') ?? '';
    preferiti = (_pref.getStringList('favorites') ?? []).toSet();
    notifyListeners();
    if (playlistUrl.trim().isNotEmpty) await carica(playlistUrl);
  }

  Future<void> carica(String url) async {
    if (!linkListaValido(url)) {
      errore = 'Il link deve iniziare con http:// o https://';
      notifyListeners();
      return;
    }
    caricamento = true;
    errore = null;
    notifyListeners();
    try {
      await _pref.setString('playlist_url', url.trim());
      final nuovi = await scaricaCanali(url);
      playlistUrl = url.trim();
      canali = nuovi;
      caricamento = false;
      daConfigurare = false;
    } catch (e) {
      caricamento = false;
      errore = '$e';
      daConfigurare = canali.isEmpty;
    }
    notifyListeners();
  }

  void ricarica() {
    if (playlistUrl.trim().isNotEmpty) carica(playlistUrl);
  }

  void apriConfigurazione() {
    daConfigurare = true;
    errore = null;
    notifyListeners();
  }

  /// Chiude la configurazione e torna alla lista (solo se ci sono già canali).
  void annullaConfigurazione() {
    if (canali.isNotEmpty) {
      daConfigurare = false;
      errore = null;
      notifyListeners();
    }
  }

  Future<void> cambiaPreferito(String nome) async {
    if (!preferiti.remove(nome)) preferiti.add(nome);
    await _pref.setStringList('favorites', preferiti.toList());
    notifyListeners();
  }
}
