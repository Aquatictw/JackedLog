package com.aquatic.jackedlog

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.documentfile.provider.DocumentFile
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class BackupReceiver : BroadcastReceiver() {
    @RequiresApi(Build.VERSION_CODES.O)
    override fun onReceive(context: Context?, intent: Intent?) {
        Log.d("BackupReceiver", "onReceive")
        if (context == null) return

        val (enabled, backupPath) = getSettings(context)
        if (!enabled || backupPath == null) return

        val channelId = "backup_channel"
        var notificationBuilder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.baseline_arrow_downward_24)
            .setAutoCancel(true)

        val notificationManager = NotificationManagerCompat.from(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Backup channel",
                NotificationManager.IMPORTANCE_DEFAULT
            )
            channel.description = "Automatic backups of the database"
            notificationManager.createNotificationChannel(channel)
        }

        if (ActivityCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS
            ) != PackageManager.PERMISSION_GRANTED
        ) return

        try {
            // Get source database file
            val parentDir = context.filesDir.parentFile
            if (parentDir == null) {
                Log.e("BackupReceiver", "Failed to get parent directory")
                return
            }

            val dbFolder = File(parentDir, "app_flutter")
            val sourceDbFile = File(dbFolder, "jackedlog.sqlite")

            if (!sourceDbFile.exists()) {
                Log.e("BackupReceiver", "Database file does not exist: ${sourceDbFile.absolutePath}")
                return
            }

            val backupFileName: String

            // Use SAF if backup path is a content:// URI
            if (backupPath.startsWith("content://")) {
                // Parse backup directory URI
                val backupUri = Uri.parse(backupPath)
                val backupDir = DocumentFile.fromTreeUri(context, backupUri)

                if (backupDir == null || !backupDir.exists()) {
                    throw IllegalStateException("Cannot access backup directory")
                }

                // Generate backup filename with date
                val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
                val dateStr = dateFormat.format(Date())
                backupFileName = "jackedlog_backup_$dateStr.db"

                // Check if file already exists and delete it
                val existingFile = backupDir.findFile(backupFileName)
                existingFile?.delete()

                // Create new backup file
                val backupFile = backupDir.createFile("application/octet-stream", backupFileName)
                    ?: throw IllegalStateException("Failed to create backup file")

                // Copy database to backup location using content resolver
                sourceDbFile.inputStream().use { input ->
                    context.contentResolver.openOutputStream(backupFile.uri)?.use { output ->
                        input.copyTo(output)
                    } ?: throw IllegalStateException("Failed to open output stream")
                }

                Log.d("BackupReceiver", "Backup created: $backupFileName")
            } else {
                // Fallback for non-SAF paths (legacy)
                val backupDir = File(backupPath)
                if (!backupDir.exists()) {
                    backupDir.mkdirs()
                }

                val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
                val dateStr = dateFormat.format(Date())
                backupFileName = "jackedlog_backup_$dateStr.db"
                val backupFile = File(backupDir, backupFileName)

                sourceDbFile.inputStream().use { input ->
                    backupFile.outputStream().use { output ->
                        input.copyTo(output)
                    }
                }

                Log.d("BackupReceiver", "Backup created: ${backupFile.absolutePath}")
            }

            // Show notification
            notificationBuilder = notificationBuilder
                .setContentTitle("Backup completed")
                .setContentText(backupFileName)

            // Open backup directory on click
            val openIntent = Intent().apply {
                action = Intent.ACTION_VIEW
                if (backupPath.startsWith("content://")) {
                    data = Uri.parse(backupPath)
                    flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
                } else {
                    setDataAndType(Uri.fromFile(File(backupPath)), "resource/folder")
                }
            }
            val pendingOpen = PendingIntent.getActivity(
                context,
                0,
                openIntent,
                PendingIntent.FLAG_IMMUTABLE
            )
            notificationBuilder = notificationBuilder.setContentIntent(pendingOpen)

            notificationManager.notify(2, notificationBuilder.build())
        } catch (e: Exception) {
            Log.e("BackupReceiver", "Error during backup: ${e.message}", e)
            notificationBuilder = notificationBuilder
                .setContentTitle("Backup failed")
                .setContentText(e.message ?: "Unknown error")
            notificationManager.notify(2, notificationBuilder.build())
        }
    }
}