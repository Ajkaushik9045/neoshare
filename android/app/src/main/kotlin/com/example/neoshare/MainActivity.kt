package com.example.neoshare

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.os.StatFs
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import java.io.File

class MainActivity : FlutterActivity(), FileHostApi {

    private var pendingPickCallback: ((Result<List<PickedFileInfo>>) -> Unit)? = null

    companion object {
        private const val FILE_PICK_CODE = 1001
        private const val TAG = "NeoShare[Pigeon]"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FileHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, this)
        android.util.Log.i(TAG, "FileHostApi registered on binary messenger")
    }

    // ─── pickFiles ─────────────────────────────────────────────────────────────

    override fun pickFiles(callback: (Result<List<PickedFileInfo>>) -> Unit) {
        android.util.Log.i(TAG, "pickFiles() called via Pigeon")
        pendingPickCallback = callback
        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            type = "*/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            addCategory(Intent.CATEGORY_OPENABLE)
        }
        startActivityForResult(Intent.createChooser(intent, "Select files"), FILE_PICK_CODE)
    }

    @Suppress("OVERRIDE_DEPRECATION", "DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != FILE_PICK_CODE) return

        val callback = pendingPickCallback ?: return
        pendingPickCallback = null

        if (resultCode != Activity.RESULT_OK || data == null) {
            android.util.Log.w(TAG, "pickFiles: user cancelled or no data")
            callback(Result.success(emptyList()))
            return
        }

        val uris = mutableListOf<Uri>()
        val clipData = data.clipData
        if (clipData != null) {
            for (i in 0 until clipData.itemCount) uris.add(clipData.getItemAt(i).uri)
        } else {
            data.data?.let { uris.add(it) }
        }

        android.util.Log.i(TAG, "pickFiles: ${uris.size} file(s) selected")

        val results = mutableListOf<PickedFileInfo>()
        for (uri in uris) {
            val info = uriToPickedFileInfo(uri)
            if (info != null) {
                results.add(info)
                android.util.Log.i(TAG, "Pigeon pickFiles: staged '${info.name}' (${info.sizeBytes} bytes, ${info.mimeType}) at ${info.path}")
            } else {
                android.util.Log.w(TAG, "pickFiles: could not resolve URI $uri")
            }
        }
        callback(Result.success(results))
    }

    private fun uriToPickedFileInfo(uri: Uri): PickedFileInfo? {
        return try {
            var displayName = "file_${System.currentTimeMillis()}"
            var sizeBytes = 0L
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val nameIdx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                val sizeIdx = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (cursor.moveToFirst()) {
                    if (nameIdx != -1) displayName = cursor.getString(nameIdx)
                    if (sizeIdx != -1) sizeBytes = cursor.getLong(sizeIdx)
                }
            }

            val mimeType = contentResolver.getType(uri)
                ?: guessMimeType(displayName)
                ?: "application/octet-stream"

            // Copy to cache so Dart's File API can read it (content URIs are not real paths)
            val cacheFile = File(cacheDir, "pick_${System.currentTimeMillis()}_$displayName")
            contentResolver.openInputStream(uri)?.use { input ->
                cacheFile.outputStream().use { output -> input.copyTo(output) }
            }

            PickedFileInfo(
                path = cacheFile.absolutePath,
                name = displayName,
                sizeBytes = cacheFile.length(),
                mimeType = mimeType,
            )
        } catch (e: Exception) {
            android.util.Log.e(TAG, "uriToPickedFileInfo failed: ${e.message}")
            null
        }
    }

    private fun guessMimeType(name: String): String? {
        val ext = name.substringAfterLast('.', "")
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext.lowercase())
    }

    // ─── saveToDownloads ───────────────────────────────────────────────────────

    override fun saveToDownloads(
        tempPath: String,
        mimeType: String,
        fileName: String,
        callback: (Result<String>) -> Unit,
    ) {
        android.util.Log.i(TAG, "saveToDownloads() '$fileName' mimeType='$mimeType' from '$tempPath'")
        try {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw Exception("MediaStore.insert returned null for '$fileName'")

            contentResolver.openOutputStream(uri)?.use { out ->
                File(tempPath).inputStream().copyTo(out)
            }

            // Clear IS_PENDING so the file appears in Downloads app
            contentResolver.update(uri, ContentValues().apply {
                put(MediaStore.Downloads.IS_PENDING, 0)
            }, null, null)

            android.util.Log.i(TAG, "saveToDownloads: '$fileName' saved → $uri")
            callback(Result.success(uri.toString()))
        } catch (e: Exception) {
            android.util.Log.e(TAG, "saveToDownloads failed for '$fileName': ${e.message}")
            callback(Result.failure(e))
        }
    }

    // ─── getFreeSpace ──────────────────────────────────────────────────────────

    override fun getFreeSpace(callback: (Result<Long>) -> Unit) {
        android.util.Log.i(TAG, "getFreeSpace() called via Pigeon")
        try {
            val stat = StatFs(Environment.getExternalStorageDirectory().path)
            val free = stat.blockSizeLong * stat.availableBlocksLong
            android.util.Log.i(TAG, "getFreeSpace: ${free / 1024 / 1024} MB available")
            callback(Result.success(free))
        } catch (e: Exception) {
            android.util.Log.e(TAG, "getFreeSpace failed: ${e.message}")
            callback(Result.failure(e))
        }
    }
}
