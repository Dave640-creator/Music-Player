package com.example.smart_music_player

import android.net.Uri
import android.provider.MediaStore
import java.io.File
import java.io.FileOutputStream
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private companion object {
		const val CHANNEL = "smart_music_player/media_store"
	}

	private fun cacheArtwork(albumId: Long): String? {
		if (albumId <= 0) return null
		val directory = File(cacheDir, "music_artwork")
		if (!directory.exists()) directory.mkdirs()
		val output = File(directory, "$albumId.jpg")
		if (output.exists()) return output.absolutePath
		return try {
			val uri = Uri.parse("content://media/external/audio/albumart/$albumId")
			contentResolver.openInputStream(uri)?.use { input ->
				FileOutputStream(output).use { outputStream -> input.copyTo(outputStream) }
			}
			if (output.exists() && output.length() > 0) output.absolutePath else null
		} catch (_: Exception) {
			output.delete()
			null
		}
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
			.setMethodCallHandler { call, result ->
				if (call.method != "queryDeviceMusic") {
					result.notImplemented()
					return@setMethodCallHandler
				}

				val projection = arrayOf(
					MediaStore.Audio.Media.DATA,
					MediaStore.Audio.Media.TITLE,
					MediaStore.Audio.Media.ARTIST,
					MediaStore.Audio.Media.ALBUM,
					MediaStore.Audio.Media.ALBUM_ID,
					MediaStore.Audio.Media.ALBUM_ARTIST,
					MediaStore.Audio.Media.YEAR,
					MediaStore.Audio.Media.TRACK,
					MediaStore.Audio.Media.BITRATE,
					MediaStore.Audio.Media.DURATION,
					MediaStore.Audio.Media.DATE_MODIFIED,
				)
				val songs = ArrayList<Map<String, Any?>>()
				try {
					contentResolver.query(
						MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
						projection,
						"${MediaStore.Audio.Media.IS_MUSIC} != 0",
						null,
						"${MediaStore.Audio.Media.DATE_MODIFIED} DESC",
					)?.use { cursor ->
						val pathIndex = cursor.getColumnIndex(MediaStore.Audio.Media.DATA)
						val titleIndex = cursor.getColumnIndex(MediaStore.Audio.Media.TITLE)
						val artistIndex = cursor.getColumnIndex(MediaStore.Audio.Media.ARTIST)
						val albumIndex = cursor.getColumnIndex(MediaStore.Audio.Media.ALBUM)
						val albumIdIndex = cursor.getColumnIndex(MediaStore.Audio.Media.ALBUM_ID)
						val albumArtistIndex = cursor.getColumnIndex(MediaStore.Audio.Media.ALBUM_ARTIST)
						val yearIndex = cursor.getColumnIndex(MediaStore.Audio.Media.YEAR)
						val trackIndex = cursor.getColumnIndex(MediaStore.Audio.Media.TRACK)
						val bitrateIndex = cursor.getColumnIndex(MediaStore.Audio.Media.BITRATE)
						val durationIndex = cursor.getColumnIndex(MediaStore.Audio.Media.DURATION)
						val modifiedIndex = cursor.getColumnIndex(MediaStore.Audio.Media.DATE_MODIFIED)
						while (cursor.moveToNext()) {
							val path = cursor.getString(pathIndex) ?: continue
							val albumId = cursor.getLong(albumIdIndex)
							val artworkPath = cacheArtwork(albumId)
							songs.add(
								mapOf(
									"path" to path,
									"title" to cursor.getString(titleIndex),
									"artist" to cursor.getString(artistIndex),
									"album" to cursor.getString(albumIndex),
									"albumArtist" to cursor.getString(albumArtistIndex),
									"year" to cursor.getInt(yearIndex),
									"trackNumber" to cursor.getInt(trackIndex),
									"bitrate" to cursor.getInt(bitrateIndex),
									"artwork" to artworkPath,
									"duration" to cursor.getLong(durationIndex),
									"modified" to cursor.getLong(modifiedIndex),
								),
							)
						}

					}
					result.success(songs)
				} catch (error: Exception) {
					result.error("MEDIA_STORE_QUERY_FAILED", error.message, null)
				}
			}
	}
}
