// Player a tutto schermo: orizzontale, barre di sistema nascoste, comandi a scomparsa, zapping col telecomando.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'canali.dart';

const _uaPredefinito = 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) tk-tv';
const _attesaComandi = Duration(milliseconds: 4000);

class SchermataPlayer extends StatefulWidget {
  const SchermataPlayer({super.key, required this.canali, required this.inizio});

  final List<Canale> canali;
  final int inizio;

  @override
  State<SchermataPlayer> createState() => _SchermataPlayerState();
}

class _SchermataPlayerState extends State<SchermataPlayer> with WidgetsBindingObserver {
  late int _indice = widget.inizio;
  VideoPlayerController? _video;
  String? _errore;
  bool _comandi = true;
  Timer? _timerComandi;
  int _giro = 0; // evita che un canale lento finisca sopra quello scelto dopo
  final _focus = FocusNode();

  Canale? get _corrente => _indice >= 0 && _indice < widget.canali.length ? widget.canali[_indice] : null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    _apri();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timerComandi?.cancel();
    _video?.dispose();
    _focus.dispose();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // Se si lascia l'app (schermo spento, altra app) la riproduzione si ferma: niente audio di nascosto.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.hidden) _video?.pause();
    if (s == AppLifecycleState.resumed) _video?.play();
  }

  Future<void> _apri() async {
    final c = _corrente;
    if (c == null) return;
    final giro = ++_giro;
    _mostraComandi();
    setState(() => _errore = null);
    final vecchio = _video;
    _video = null;
    await vecchio?.dispose();
    final mpd = c.url.toLowerCase().contains('.mpd');
    final v = VideoPlayerController.networkUrl(
      Uri.parse(c.url),
      formatHint: mpd ? VideoFormat.dash : VideoFormat.hls,
      httpHeaders: {'User-Agent': c.userAgent.trim().isEmpty ? _uaPredefinito : c.userAgent},
      // SurfaceView su Android: il video non passa dal disegno dell'app (più fluido su TV e proiettori)
      viewType: Platform.isAndroid ? VideoViewType.platformView : VideoViewType.textureView,
    );
    v.addListener(() {
      if (!mounted || giro != _giro) return;
      final err = v.value.hasError ? 'Questo canale non è raggiungibile' : null;
      if (err != _errore) setState(() => _errore = err);
    });
    try {
      await v.initialize();
      if (giro != _giro) {
        await v.dispose();
        return;
      }
      await v.play();
      setState(() => _video = v);
    } catch (_) {
      if (giro == _giro && mounted) {
        setState(() {
          _video = v;
          _errore = 'Questo canale non è raggiungibile';
        });
      } else {
        await v.dispose();
      }
    }
  }

  void _mostraComandi() {
    _timerComandi?.cancel();
    setState(() => _comandi = true);
    _timerComandi = Timer(_attesaComandi, () {
      if (mounted) setState(() => _comandi = false);
    });
  }

  void _alternaComandi() {
    if (_comandi) {
      _timerComandi?.cancel();
      setState(() => _comandi = false);
    } else {
      _mostraComandi();
    }
  }

  void _precedente() {
    if (_indice > 0) {
      _indice--;
      _apri();
    }
  }

  void _successivo() {
    if (_indice < widget.canali.length - 1) {
      _indice++;
      _apri();
    }
  }

  // Tasti del telecomando: frecce, canale +/−, traccia precedente/successiva, OK.
  KeyEventResult _tasto(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.channelDown ||
        k == LogicalKeyboardKey.mediaTrackPrevious) {
      _precedente();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.arrowRight ||
        k == LogicalKeyboardKey.channelUp ||
        k == LogicalKeyboardKey.mediaTrackNext) {
      _successivo();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      _alternaComandi();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final c = _corrente;
    final v = _video;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _tasto,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _alternaComandi,
          child: Stack(fit: StackFit.expand, children: [
            if (v != null && v.value.isInitialized)
              Center(child: AspectRatio(aspectRatio: v.value.aspectRatio, child: VideoPlayer(v)))
            else if (_errore == null)
              const Center(child: CircularProgressIndicator(color: Colors.white)),
            if (_errore != null)
              Center(
                child: Container(
                  color: Colors.black.withValues(alpha: .6),
                  padding: const EdgeInsets.all(16),
                  child: Text(_errore!, style: const TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            AnimatedOpacity(
              opacity: _comandi ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_comandi,
                child: Stack(children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.black.withValues(alpha: .45),
                      padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 8, 8, 8),
                      child: Row(children: [
                        IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: 'Indietro',
                            icon: const Icon(Icons.arrow_back, color: Colors.white)),
                        Expanded(
                          child: Text(c == null ? '' : '[${c.numero}] ${c.nome}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                        IconButton(
                            onPressed: _apri,
                            tooltip: 'Aggiorna',
                            icon: const Icon(Icons.refresh, color: Colors.white)),
                      ]),
                    ),
                  ),
                  Positioned(
                    bottom: 40 + MediaQuery.of(context).padding.bottom,
                    left: 0,
                    right: 0,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      IconButton.filledTonal(
                          onPressed: _indice > 0 ? _precedente : null,
                          tooltip: 'Precedente',
                          icon: const Icon(Icons.skip_previous)),
                      const SizedBox(width: 40),
                      IconButton.filledTonal(
                          onPressed: _indice < widget.canali.length - 1 ? _successivo : null,
                          tooltip: 'Successivo',
                          icon: const Icon(Icons.skip_next)),
                    ]),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
