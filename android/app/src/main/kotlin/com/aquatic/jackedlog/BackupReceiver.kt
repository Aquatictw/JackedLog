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
import java.io.File

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

            // Create backup directory if it doesn't exist
            val backupDir = File(backupPath)
            if (!backupDir.exists()) {
                backupDir.mkdirs()
            }

            // Generate backup filename with date
            val dateFormat = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US)
            val dateStr = dateFormat.format(java.util.Date())
            val backupFileName = "jackedlog_backup_$dateStr.db"
            val backupFile = File(backupDir, backupFileName)

            // Copy database file to backup location
            sourceDbFile.inputStream().use { input ->
                backupFile.outputStream().use { output ->
                    input.copyTo(output)
                }
            }

            Log.d("BackupReceiver", "Backup created: ${backupFile.absolutePath}")

            // Show notification
            notificationBuilder = notificationBuilder
                .setContentTitle("Backup completed")
                .setContentText(backupFileName)

            val openIntent = Intent().apply {
                action = Intent.ACTION_VIEW
                setDataAndType(Uri.fromFile(backupDir), "resource/folder")
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