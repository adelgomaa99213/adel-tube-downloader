package com.adel.adel_tube_downloader

import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import androidx.core.content.ContextCompat
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.io.File
import java.util.concurrent.ConcurrentHashMap

class YtDlpPlugin(private val ctx: Context) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        fun register(engine: FlutterEngine, ctx: Context) {
            val p = YtDlpPlugin(ctx)
            MethodChannel(engine.dartExecutor.binaryMessenger, "adel_tube/engine")
                .setMethodCallHandler(p)
            EventChannel(engine.dartExecutor.binaryMessenger, "adel_tube/progress")
                .setStreamHandler(p)
        }
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null

    private val running = ConcurrentHashMap.newKeySet<String>()
    private val stopReason = ConcurrentHashMap<String, String>() // paused | canceled
    @Volatile private var initialized = false

    /** مجلد مؤقت ثابت: يحتفظ بالملفات الجزئية (.part) لتمكين الاستئناف. */
    private val staging: File
        get() = File(ctx.getExternalFilesDir(null) ?: ctx.filesDir, "staging").apply { mkdirs() }

    override fun onListen(args: Any?, events: EventChannel.EventSink?) { sink = events }
    override fun onCancel(args: Any?) { sink = null }
    private fun emit(m: Map<String, Any?>) = main.post { sink?.success(m) }

    @Synchronized
    private fun ensureInit() {
        if (initialized) return
        YoutubeDL.getInstance().init(ctx)
        FFmpeg.getInstance().init(ctx)
        initialized = true
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getInfo" -> scope.launch {
                try {
                    ensureInit()
                    val info = YoutubeDL.getInstance().getInfo(call.argument<String>("url")!!)
                    val formats = info.formats?.map {
                        mapOf(
                            "id" to it.formatId, "ext" to it.ext, "height" to it.height,
                            "vcodec" to it.vcodec, "acodec" to it.acodec,
                            "size" to (if (it.fileSize > 0) it.fileSize else it.fileSizeApproximate),
                            "abr" to it.abr, "note" to it.formatNote,
                        )
                    } ?: emptyList()
                    val out = mapOf(
                        "title" to info.title, "thumbnail" to info.thumbnail,
                        "uploader" to info.uploader, "duration" to info.duration,
                        "formats" to formats,
                    )
                    main.post { result.success(out) }
                } catch (e: Exception) {
                    main.post { result.error("EXTRACT_FAILED", e.message ?: "تعذّر تحليل الرابط", null) }
                }
            }

            "download" -> {
                val id = call.argument<String>("id")!!
                if (running.add(id)) {
                    startDownload(
                        id, call.argument("url")!!, call.argument("title") ?: "download",
                        call.argument("selector")!!, call.argument<Boolean>("audioOnly") ?: false,
                        call.argument("audioFormat"),
                    )
                }
                result.success(null)
            }

            "pause" -> {
                val id = call.argument<String>("id")!!
                if (running.contains(id)) {
                    stopReason[id] = "paused"
                    YoutubeDL.getInstance().destroyProcessById(id)
                }
                result.success(null)
            }

            "cancel" -> {
                val id = call.argument<String>("id")!!
                if (running.contains(id)) {
                    stopReason[id] = "canceled"
                    YoutubeDL.getInstance().destroyProcessById(id)
                } else {
                    deletePartials(id)
                    emit(mapOf("id" to id, "type" to "canceled"))
                }
                result.success(null)
            }

            "open" -> {
                val i = Intent(Intent.ACTION_VIEW)
                    .setDataAndType(Uri.parse(call.argument<String>("uri")), call.argument<String>("mime"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
                try { ctx.startActivity(i); result.success(true) }
                catch (e: ActivityNotFoundException) { result.success(false) }
            }

            "update" -> scope.launch {
                try {
                    ensureInit()
                    val s = YoutubeDL.getInstance().updateYoutubeDL(ctx, YoutubeDL.UpdateChannel.STABLE)
                    main.post { result.success(s?.name ?: "UP_TO_DATE") }
                } catch (e: Exception) {
                    main.post { result.error("UPDATE_FAILED", e.message, null) }
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun startDownload(
        id: String, url: String, title: String, selector: String,
        audioOnly: Boolean, audioFormat: String?,
    ) {
        // خدمة أمامية واحدة تبقى حيّة ما دام هناك تحميل نشط
        if (running.size == 1) {
            ContextCompat.startForegroundService(ctx, Intent(ctx, DownloadService::class.java))
        }
        scope.launch {
            try {
                ensureInit()
                val req = YoutubeDLRequest(url)
                req.addOption("-f", selector)
                req.addOption("--continue")               // استئناف من الملف الجزئي
                req.addOption("--retries", "20")          // إعادة محاولة تلقائية عند تقطّع الشبكة
                req.addOption("--fragment-retries", "20")
                req.addOption("--retry-sleep", "3")
                req.addOption("--socket-timeout", "30")
                req.addOption("--no-mtime")
                // اسم ثابت = معرّف المهمة، حتى يجد yt-dlp نفس الملف الجزئي عند الاستئناف
                req.addOption("-o", "${staging.absolutePath}/$id.%(ext)s")
                if (audioOnly) {
                    req.addOption("-x")
                    req.addOption("--audio-format", audioFormat ?: "best")
                } else {
                    req.addOption("--merge-output-format", "mp4")
                }

                var lastEmit = 0L
                YoutubeDL.getInstance().execute(req, id) { progress, eta, _ ->
                    val now = System.currentTimeMillis()
                    if (now - lastEmit > 500) {
                        lastEmit = now
                        emit(mapOf("id" to id, "type" to "progress",
                            "progress" to progress.toDouble(), "eta" to eta))
                    }
                }

                val finalFile = staging.listFiles()?.firstOrNull {
                    Regex("^" + Regex.escape(id) + "\\.[A-Za-z0-9]+$").matches(it.name)
                } ?: throw IllegalStateException("لم يُعثر على الملف الناتج")

                emit(mapOf("id" to id, "type" to "saving"))
                val (uri, mime) = saveToGallery(finalFile, title, audioOnly)
                emit(mapOf("id" to id, "type" to "done", "uri" to uri, "mime" to mime))
            } catch (e: Exception) {
                when (stopReason.remove(id)) {
                    "paused" -> emit(mapOf("id" to id, "type" to "paused"))
                    "canceled" -> {
                        deletePartials(id)
                        emit(mapOf("id" to id, "type" to "canceled"))
                    }
                    // انقطاع/فشل: الملفات الجزئية تبقى، والاستئناف يكمل منها
                    else -> emit(mapOf("id" to id, "type" to "failed",
                        "error" to (e.message?.take(160) ?: "فشل التحميل")))
                }
            } finally {
                running.remove(id)
                if (running.isEmpty()) ctx.stopService(Intent(ctx, DownloadService::class.java))
            }
        }
    }

    private fun deletePartials(id: String) {
        staging.listFiles()?.filter { it.name.startsWith("$id.") }?.forEach { it.delete() }
    }

    /** ينسخ الملف إلى المعرض (Movies أو Music) عبر MediaStore ثم يحذف المؤقت. يتطلب API 29+. */
    private fun saveToGallery(file: File, title: String, audioOnly: Boolean): Pair<String, String> {
        val ext = file.extension.lowercase()
        var mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
            ?: if (audioOnly) "audio/mpeg" else "video/mp4"
        if (audioOnly && mime.startsWith("video/")) mime = mime.replaceFirst("video/", "audio/")

        val safe = title.replace(Regex("[\\\\/:*?\"<>|]"), "_").trim().take(80).ifEmpty { "download" }
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, "$safe.$ext")
            put(MediaStore.MediaColumns.MIME_TYPE, mime)
            put(
                MediaStore.MediaColumns.RELATIVE_PATH,
                (if (audioOnly) Environment.DIRECTORY_MUSIC else Environment.DIRECTORY_MOVIES) +
                    "/adel_tube_downloader"
            )
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val collection = if (audioOnly)
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        else MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)

        val resolver = ctx.contentResolver
        val uri = resolver.insert(collection, values)
            ?: throw IllegalStateException("تعذّر الحفظ في المعرض")
        try {
            resolver.openOutputStream(uri)!!.use { out ->
                file.inputStream().use { it.copyTo(out, 1 shl 16) }
            }
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            throw e
        }
        file.delete()
        return uri.toString() to mime
    }
}
