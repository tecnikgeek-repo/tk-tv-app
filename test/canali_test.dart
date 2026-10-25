// Lettura della playlist e canali in evidenza: stesso comportamento della versione Kotlin.
import 'package:flutter_test/flutter_test.dart';
import 'package:tktv/canali.dart';

const _m3u = '''#EXTM3U
#EXTINF:-1 tvg-chno="1" tvg-logo="https://l/rai1.png" group-title="Rai",Rai 1 HD
http://x/rai1.m3u8
#EXTINF:-1 group-title="Mediaset",[5] Canale 5
#EXTVLCOPT:http-user-agent=VLC/3.0
http://x/c5.mpd
#EXTINF:-1 group-title="Regionali",Rai 3 Lazio
http://x/r3lazio.m3u8
#EXTINF:-1,Senza gruppo
http://x/altro.m3u8
#EXTINF:-1 group-title="Rai",Rai Tre
http://x/rai3.m3u8
#EXTINF:-1 tvg-logo="file:///etc/passwd",Locale
file:///sdcard/video.mp4
#EXTINF:-1 tvg-logo="javascript:alert(1)",Senza logo
rtsp://x/cam
''';

void main() {
  test('lettura M3U', () {
    final c = leggiM3u(_m3u);
    expect(c.length, 6); // il flusso file:// si scarta
    expect(c[0].numero, 1);
    expect(c[0].nome, 'Rai 1 HD');
    expect(c[0].logo, 'https://l/rai1.png');
    expect(c[0].gruppo, 'Rai');
    expect(c[1].numero, 5);
    expect(c[1].nome, 'Canale 5');
    expect(c[1].userAgent, 'VLC/3.0');
    expect(c[1].url, 'http://x/c5.mpd');
    expect(c[2].numero, 1000); // numero automatico dal 1000
    expect(c[3].numero, 1001);
    expect(c[3].gruppo, '');
    expect(c[2].userAgent, ''); // lo user-agent non passa al canale successivo
    expect(c[5].url, 'rtsp://x/cam');
    expect(c[5].logo, '', reason: 'loghi solo http/https');
    expect(c.any((x) => x.url.startsWith('file:')), isFalse);
  });

  test('flussi ammessi', () {
    for (final u in ['http://a/b', 'https://a/b', 'udp://@239.0.0.1:1234', 'rtp://a', 'rtsp://a', 'rtmp://a']) {
      expect(flussoAmmesso(u), isTrue, reason: u);
    }
    for (final u in ['file:///x', 'content://x', 'javascript:x', 'ftp://a', 'nulla']) {
      expect(flussoAmmesso(u), isFalse, reason: u);
    }
  });

  test('generalisti nell\'ordine giusto', () {
    expect(posizioneGeneralista('Rai 1 HD'), 0);
    expect(posizioneGeneralista('Rai Tre'), 2);
    expect(posizioneGeneralista('Canale 5'), 4);
    expect(posizioneGeneralista('Italia 1 FHD'), 5);
    expect(posizioneGeneralista('La7'), 6);
    expect(posizioneGeneralista('Rai 3 Lazio'), -1);
    expect(posizioneGeneralista('Rai News 24'), -1);
  });
}
