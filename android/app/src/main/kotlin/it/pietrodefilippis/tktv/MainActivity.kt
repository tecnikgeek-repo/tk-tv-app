package it.pietrodefilippis.tktv

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import androidx.core.graphics.drawable.toBitmap
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import java.io.ByteArrayOutputStream

// Archivio della versione precedente (Kotlin): stesso nome, così chi aggiorna ritrova i suoi dati.
private val Context.vecchioArchivio by preferencesDataStore(name = "tk_tv")

/**
 * L'app è scritta in Flutter; qui resta solo quello che esiste solo su Android:
 * le pay TV installate (aprire l'app ufficiale) e la lettura una tantum dei dati della versione precedente.
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        TkAggiornamento.registra(flutterEngine, this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tktv/nativo").setMethodCallHandler { call, result ->
            when (call.method) {
                "appInstallate" -> Thread {
                    val lista = runCatching { CatalogoApp.installate(applicationContext) }.getOrDefault(emptyList())
                    runOnUiThread { result.success(lista) }
                }.start()
                "apriApp" -> result.success(CatalogoApp.apri(this, call.argument<String>("pacchetto") ?: ""))
                "vecchiDati" -> Thread {
                    val dati = runCatching {
                        runBlocking {
                            val p = applicationContext.vecchioArchivio.data.first()
                            mapOf(
                                "url" to (p[stringPreferencesKey("playlist_url")] ?: ""),
                                "preferiti" to (p[stringSetPreferencesKey("favorites")]?.toList() ?: emptyList())
                            )
                        }
                    }.getOrNull()
                    runOnUiThread { result.success(dati) }
                }.start()
                else -> result.notImplemented()
            }
        }
    }
}

/**
 * Catalogo delle app pay TV / streaming. I loro contenuti hanno il DRM e nessuna API pubblica: non si
 * riproducono dentro tk-tv, si apre l'app nativa già installata. Vengono mostrate SOLO quelle installate.
 * (Stesso catalogo e stesse regole della versione Kotlin.)
 */
object CatalogoApp {

    private data class Voce(val id: String, val nome: String, val pacchetti: List<String>, val chiavi: List<String>)

    private val CATALOGO = listOf(
        Voce("netflix", "Netflix", listOf("com.netflix.mediaclient", "com.netflix.ninja"), listOf("netflix")),
        Voce("prime", "Prime Video",
            listOf("com.amazon.avod.thirdpartyclient", "com.amazon.amazonvideo.livingroom", "com.amazon.avod"),
            listOf("amazon.avod", "amazonvideo")),
        Voce("disney", "Disney+", listOf("com.disney.disneyplus"), listOf("disneyplus")),
        Voce("max", "HBO Max", listOf("com.wbd.stream", "com.hbo.hbonow"), listOf("wbd.stream", "hbonow", "hbomax")),
        Voce("now", "NOW", listOf("com.nowtv.it", "com.bskyb.nowtv.it", "com.nowtv"), listOf("nowtv")),
        Voce("skygo", "Sky Go", listOf("it.sky.skygo", "com.sky.skygo"), listOf("skygo")),
        Voce("dazn", "DAZN", listOf("com.dazn"), listOf("dazn")),
        Voce("appletv", "Apple TV",
            listOf("com.apple.atve.androidtv.appletv", "com.apple.atve.android.appletv"), listOf("apple.atve")),
        Voce("paramount", "Paramount+", listOf("com.cbs.ott", "com.cbs.app"), listOf("cbs.ott", "paramount")),
        Voce("discovery", "discovery+",
            listOf("com.discovery.dplay", "com.discovery.discoveryplus.mobile", "com.discovery.discoveryplus.androidtv"),
            listOf("discoveryplus", "discovery.dplay")),
        Voce("raiplay", "RaiPlay", listOf("it.rai.mobile", "it.rai.raiplay.tv"), listOf("rai.mobile", "raiplay")),
        Voce("mediaset", "Mediaset Infinity",
            listOf("it.mediaset.infinityapp", "it.fabbricadigitale.android.mediasetplay"), listOf("mediaset")),
        Voce("youtube", "YouTube", listOf("com.google.android.youtube", "com.google.android.youtube.tv"),
            listOf("android.youtube")),
        Voce("plex", "Plex", listOf("com.plexapp.android"), listOf("plexapp")),
        Voce("twitch", "Twitch", listOf("tv.twitch.android.app"), listOf("twitch.android"))
    )

    /** Le app del catalogo presenti sul dispositivo, nell'ordine del catalogo (icona come PNG). */
    fun installate(context: Context): List<Map<String, Any?>> {
        val pm = context.packageManager
        val lanciabili = pacchettiLanciabili(pm)
        if (lanciabili.isEmpty()) return emptyList()
        val visti = HashSet<String>()
        return CATALOGO.mapNotNull { voce ->
            val pacchetto = voce.pacchetti.firstOrNull { lanciabili.contains(it) }
                ?: lanciabili.firstOrNull { p -> voce.chiavi.any { p.contains(it, ignoreCase = true) } }
                ?: return@mapNotNull null
            if (!visti.add(pacchetto)) return@mapNotNull null
            mapOf("id" to voce.id, "nome" to voce.nome, "pacchetto" to pacchetto, "icona" to iconaPng(pm, pacchetto))
        }
    }

    /** Apre l'app: su TV si preferisce l'avvio leanback (interfaccia da telecomando), sul telefono quello normale. */
    fun apri(context: Context, pacchetto: String): Boolean {
        val pm = context.packageManager
        val intent = runCatching { pm.getLeanbackLaunchIntentForPackage(pacchetto) }.getOrNull()
            ?: pm.getLaunchIntentForPackage(pacchetto)
            ?: return false
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return runCatching { context.startActivity(intent); true }.getOrDefault(false)
    }

    // Da Android 11 la visibilità è filtrata: il manifest dichiara le <queries> corrispondenti.
    private fun pacchettiLanciabili(pm: PackageManager): Set<String> {
        val set = LinkedHashSet<String>()
        listOf(Intent.CATEGORY_LAUNCHER, Intent.CATEGORY_LEANBACK_LAUNCHER).forEach { categoria ->
            runCatching {
                pm.queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(categoria), 0)
                    .forEach { set.add(it.activityInfo.packageName) }
            }
        }
        return set
    }

    // Le icone adattive non hanno dimensione propria: si disegnano a 144 px.
    private fun iconaPng(pm: PackageManager, pacchetto: String): ByteArray? = runCatching {
        val bmp = pm.getApplicationInfo(pacchetto, 0).loadIcon(pm).toBitmap(width = 144, height = 144)
        ByteArrayOutputStream().also { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }.toByteArray()
    }.getOrNull()
}
