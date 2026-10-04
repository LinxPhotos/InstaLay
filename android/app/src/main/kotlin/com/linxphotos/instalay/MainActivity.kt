package com.linxphotos.instalay

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val pendingShares = mutableListOf<Map<String, String>>()
    private var shareChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        shareChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "drainPendingShares" -> {
                        result.success(ArrayList(pendingShares))
                        pendingShares.clear()
                    }
                    else -> result.notImplemented()
                }
            }
        }
        ingestIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val added = ingestIntent(intent)
        if (added > 0) {
            shareChannel?.invokeMethod("onShareReceived", null)
        }
    }

    private fun ingestIntent(intent: Intent?): Int {
        if (intent == null) return 0
        val action = intent.action ?: return 0
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) {
            return 0
        }

        val fallbackType = intent.type
        val uris = linkedSetOf<Uri>()
        when (action) {
            Intent.ACTION_SEND -> {
                intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)?.let { uris.add(it) }
                intent.clipData?.let { clip ->
                    for (i in 0 until clip.itemCount) {
                        uris.add(clip.getItemAt(i).uri)
                    }
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                    ?.let { uris.addAll(it) }
                intent.clipData?.let { clip ->
                    for (i in 0 until clip.itemCount) {
                        uris.add(clip.getItemAt(i).uri)
                    }
                }
            }
        }

        var added = 0
        for (uri in uris) {
            val mime = contentResolver.getType(uri) ?: fallbackType ?: continue
            if (!mime.startsWith("image/") && !mime.startsWith("video/")) continue
            val displayName = queryDisplayName(uri) ?: "shared"
            val cachePath = copyUriToCache(uri, displayName, mime) ?: continue
            pendingShares.add(
                mapOf(
                    "cachePath" to cachePath,
                    "displayName" to displayName,
                    "mimeType" to mime,
                ),
            )
            added++
        }
        return added
    }

    private fun queryDisplayName(uri: Uri): String? {
        val projection = arrayOf(OpenableColumns.DISPLAY_NAME)
        contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index < 0) return null
            if (cursor.moveToFirst()) {
                return cursor.getString(index)
            }
        }
        return null
    }

    private fun copyUriToCache(uri: Uri, displayName: String, mime: String): String? {
        val dir = File(cacheDir, "share_import").apply { mkdirs() }
        val safeBase = displayName
            .replace(Regex("[\\\\/:*?\"<>|]"), "_")
            .trim()
            .ifEmpty { "shared" }
        val extFromMime = MimeTypeMap.getSingleton().getExtensionFromMimeType(mime)
        val storedName = if (safeBase.contains('.')) {
            safeBase
        } else if (!extFromMime.isNullOrEmpty()) {
            "$safeBase.$extFromMime"
        } else {
            safeBase
        }
        val out = File(dir, "${UUID.randomUUID()}_$storedName")
        return try {
            contentResolver.openInputStream(uri)?.use { input ->
                out.outputStream().use { output -> input.copyTo(output) }
            } ?: return null
            out.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    companion object {
        private const val CHANNEL = "com.linxphotos.instalay/share"
    }
}
