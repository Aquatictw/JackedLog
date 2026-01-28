package com.aquatic.jackedlog

import android.Manifest
import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.database.sqlite.SQLiteDatabase
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@RequiresApi(Build.VERSION_CODES.O)
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var timerBound = false
    private var timerService: TimerService? = null
    private var savedPath: String? = null

    private val timerConnection = object : ServiceConnection {
        override fun onServiceConnected(className: ComponentName, service: IBinder) {
            val binder = service as TimerService.LocalBinder
            timerService = binder.getService()
            timerBound = true
        }

        override fun onServiceDisconnected(arg0: ComponentName) {
            timerBound = false
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        val controller = WindowInsetsControllerCompat(window, window.decorView)
        controller.isAppearanceLightStatusBars = false // Set to true if your app's theme is light
        controller.isAppearanceLightNavigationBars = false // Set to true if your app's theme is light
        window.statusBarColor = android.graphics.Color.TRANSPARENT
        window.navigationBarColor = android.graphics.Color.TRANSPARENT

        val (automaticBackups, backupPath) = getSettings(context)
        if (!automaticBackups) return
        if (backupPath != null) {
            scheduleBackups(context)
        }
    }

    @SuppressLint("WrongConstant")
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            FLUTTER_CHANNEL
        )
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "timer" -> {
                    val title = call.argument<String>("title")!!
                    val timestamp = call.argument<Long>("timestamp")!!
                    val threeMinutesThirtySeconds = 210000
                    val restMs = call.argument<Int>("restMs") ?: threeMinutesThirtySeconds
                    val alarmSound = call.argument<String>("alarmSound")!!
                    val vibrate = call.argument<Boolean>("vibrate")!!
                    timer(restMs, title, timestamp, alarmSound, vibrate)
                }

                "pick" -> {
                    val dbPath = call.argument<String>("dbPath")!!
                    pick(dbPath)
                }

                "getProgress" -> {
                    if (timerBound && timerService?.flexifyTimer?.isRunning() == true)
                        result.success(
                            intArrayOf(
                                timerService?.flexifyTimer!!.getRemainingSeconds(),
                                timerService?.flexifyTimer!!.getDurationSeconds()
                            )
                        )
                    else result.success(intArrayOf(0, 0))
                }

                "add" -> {
                    if (timerService?.flexifyTimer?.isRunning() == true) {
                        val intent = Intent(TimerService.ADD_BROADCAST)
                        intent.setPackage(applicationContext.packageName)
                        sendBroadcast(intent)
                    } else {
                        val timestamp = call.argument<Long>("timestamp")
                        val alarmSound = call.argument<String>("alarmSound")
                        val vibrate = call.argument<Boolean>("vibrate")
                        timer(1000 * 60, "Rest timer", timestamp!!, alarmSound!!, vibrate!!)
                    }
                }

                "stop" -> {
                    Log.d("MainActivity", "Request to stop")
                    val intent = Intent(TimerService.STOP_BROADCAST)
                    intent.setPackage(applicationContext.packageName)
                    sendBroadcast(intent)
                }

                "requestTimerPermissions" -> {
                    requestTimerPermissions()
                    result.success(true)
                }

                "previewVibration" -> {
                    previewVibration()
                    result.success(true)
                }

                "performBackup" -> {
                    val backupUri = call.argument<String>("backupUri")!!
                    try {
                        performBackup(backupUri)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("BACKUP_ERROR", e.message, null)
                    }
                }

                "cleanupOldBackups" -> {
                    val backupUri = call.argument<String>("backupUri")!!
                    try {
                        cleanupOldBackups(backupUri)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CLEANUP_ERROR", e.message, null)
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }

        ContextCompat.registerReceiver(
            applicationContext,
            tickReceiver, IntentFilter(TICK_BROADCAST),
            ContextCompat.RECEIVER_NOT_EXPORTED
        )
    }

    private val tickReceiver =
        object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                channel?.invokeMethod(
                    "tick",
                    timerService?.flexifyTimer?.generateMethodChannelPayload()
                )
            }
        }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        timerService?.apply {
            mainActivityVisible = hasFocus
            updateTimerNotificationRefreshRate()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        applicationContext.unregisterReceiver(tickReceiver)

        if (timerBound) {
            unbindService(timerConnection)
            timerBound = false
        }
    }

    private fun timer(
        durationMs: Int,
        description: String,
        timeStamp: Long,
        alarmSound: String,
        vibrate: Boolean
    ) {
        Log.d("MainActivity", "Queue $description for $durationMs delay")
        val intent = Intent(context, TimerService::class.java).also { intent ->
            bindService(
                intent,
                timerConnection,
                Context.BIND_AUTO_CREATE
            )
        }.apply {
            putExtra("milliseconds", durationMs)
            putExtra("description", description)
            putExtra("timeStamp", timeStamp)
            putExtra("alarmSound", alarmSound)
            putExtra("vibrate", vibrate)
        }

        context.startForegroundService(intent)
    }

    private fun pick(path: String) {
        Log.d("MainActivity.pick", "dbPath=$path")
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        savedPath = path
        activity.startActivityForResult(intent, WRITE_REQUEST_CODE)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        data?.data?.also { uri ->
            if (requestCode != WRITE_REQUEST_CODE) return

            val contentResolver = applicationContext.contentResolver
            val takeFlags: Int =
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            contentResolver.takePersistableUriPermission(uri, takeFlags)
            Log.d("auto backup", "uri=$uri")
            scheduleBackups(context)

            val db = openDb(context)!!
            val values = ContentValues().apply {
                put("backup_path", uri.toString())
            }
            db.update("settings", values, null, null)
            db.close()
        }
    }

    override fun onResume() {
        super.onResume()
        if (timerService?.flexifyTimer?.isRunning() != true) {
            val intent = Intent(TimerService.STOP_BROADCAST)
            intent.setPackage(applicationContext.packageName)
            sendBroadcast(intent)
        }
    }

    private fun requestTimerPermissions() {
        val permissions = mutableListOf<String>()
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                permissions.add(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
        
        if (permissions.isNotEmpty()) {
            ActivityCompat.requestPermissions(
                this,
                permissions.toTypedArray(),
                TIMER_PERMISSION_REQUEST_CODE
            )
        }
        
        if (timerBound && timerService != null) {
            timerService?.battery()
        } else {
            val intent = Intent(context, TimerService::class.java)
            bindService(intent, object : ServiceConnection {
                override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
                    val binder = service as TimerService.LocalBinder
                    binder.getService().battery()
                    unbindService(this)
                }
                
                override fun onServiceDisconnected(name: ComponentName?) {}
            }, Context.BIND_AUTO_CREATE)
        }
    }

    private fun previewVibration() {
        Log.d("MainActivity", "Preview vibration requested")

        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as android.os.VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(VIBRATOR_SERVICE) as android.os.Vibrator
        }

        if (vibrator.hasVibrator()) {
            try {
                val pattern = longArrayOf(0, 500, 200, 300)
                vibrator.vibrate(android.os.VibrationEffect.createWaveform(pattern, -1))
                Log.d("MainActivity", "Preview vibration triggered successfully")
            } catch (e: Exception) {
                Log.e("MainActivity", "Failed to trigger preview vibration", e)
            }
        } else {
            Log.w("MainActivity", "Device does not support vibration")
        }
    }

    private fun performBackup(backupUriString: String) {
        Log.d("MainActivity", "Starting backup to URI: $backupUriString")

        // Get source database file
        val parentDir = applicationContext.filesDir.parentFile
            ?: throw IllegalStateException("Failed to get parent directory")

        val dbFolder = File(parentDir, "app_flutter")
        val sourceDbFile = File(dbFolder, "jackedlog.sqlite")

        if (!sourceDbFile.exists()) {
            throw IllegalStateException("Database file does not exist: ${sourceDbFile.absolutePath}")
        }

        // Parse backup directory URI
        val backupUri = Uri.parse(backupUriString)
        val backupDir = DocumentFile.fromTreeUri(applicationContext, backupUri)
            ?: throw IllegalStateException("Cannot access backup directory")

        // Generate backup filename with date
        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        val dateStr = dateFormat.format(Date())
        val backupFileName = "jackedlog_backup_$dateStr.db"

        // Check if file already exists and delete it
        var existingFile = backupDir.findFile(backupFileName)
        if (existingFile != null) {
            existingFile.delete()
        }

        // Create new backup file
        val backupFile = backupDir.createFile("application/octet-stream", backupFileName)
            ?: throw IllegalStateException("Failed to create backup file")

        // Copy database to backup location using content resolver
        sourceDbFile.inputStream().use { input ->
            applicationContext.contentResolver.openOutputStream(backupFile.uri)?.use { output ->
                input.copyTo(output)
            } ?: throw IllegalStateException("Failed to open output stream")
        }

        Log.d("MainActivity", "Backup completed: $backupFileName")
    }

    private fun cleanupOldBackups(backupUriString: String) {
        try {
            val backupUri = Uri.parse(backupUriString)
            val backupDir = DocumentFile.fromTreeUri(applicationContext, backupUri) ?: return

            val now = Date()
            val calendar = java.util.Calendar.getInstance()

            // Get all backup files
            val backups = mutableMapOf<Date, DocumentFile>()
            val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)

            backupDir.listFiles().forEach { file ->
                if (file.isFile && file.name?.endsWith(".db") == true) {
                    // Extract date from filename: jackedlog_backup_YYYY-MM-DD.db
                    val regex = Regex("jackedlog_backup_(\\d{4}-\\d{2}-\\d{2})\\.db")
                    val match = regex.find(file.name ?: "")
                    if (match != null) {
                        try {
                            val date = dateFormat.parse(match.groupValues[1])
                            if (date != null) {
                                backups[date] = file
                            }
                        } catch (_: Exception) {
                        }
                    }
                }
            }

            if (backups.isEmpty()) return

            val sortedDates = backups.keys.sortedDescending()
            val filesToKeep = mutableSetOf<String>()

            // 1. Daily backups: Keep last 7 days
            sortedDates.take(7).forEach { date ->
                backups[date]?.uri?.toString()?.let { filesToKeep.add(it) }
            }

            // 2. Weekly backups: Keep last 4 weeks (Sunday of each week)
            val weeklySundays = mutableSetOf<Date>()
            calendar.time = now
            calendar.add(java.util.Calendar.DAY_OF_YEAR, -7)

            sortedDates.filter { date ->
                date.before(calendar.time)
            }.forEach { date ->
                calendar.time = date
                val dayOfWeek = calendar.get(java.util.Calendar.DAY_OF_WEEK)
                calendar.add(java.util.Calendar.DAY_OF_YEAR, -(dayOfWeek - java.util.Calendar.SUNDAY))
                val sunday = calendar.time
                calendar.time = date
                weeklySundays.add(Date(sunday.year, sunday.month, sunday.date))
            }

            weeklySundays.sortedDescending().take(4).forEach { sunday ->
                val closest = findClosestBackup(sunday, sortedDates)
                closest?.let { date ->
                    backups[date]?.uri?.toString()?.let { filesToKeep.add(it) }
                }
            }

            // 3. Monthly backups: Keep last 12 months
            val monthlyBackups = mutableSetOf<Date>()
            calendar.time = now
            calendar.add(java.util.Calendar.DAY_OF_YEAR, -35)

            sortedDates.filter { date ->
                date.before(calendar.time)
            }.forEach { date ->
                calendar.time = date
                calendar.set(java.util.Calendar.DAY_OF_MONTH, calendar.getActualMaximum(java.util.Calendar.DAY_OF_MONTH))
                val lastDay = calendar.time
                calendar.time = date
                monthlyBackups.add(Date(lastDay.year, lastDay.month, lastDay.date))
            }

            monthlyBackups.sortedDescending().take(12).forEach { monthEnd ->
                val closest = findClosestBackup(monthEnd, sortedDates)
                closest?.let { date ->
                    backups[date]?.uri?.toString()?.let { filesToKeep.add(it) }
                }
            }

            // Delete files not in retention policy
            backups.values.forEach { file ->
                if (!filesToKeep.contains(file.uri.toString())) {
                    try {
                        file.delete()
                    } catch (_: Exception) {
                    }
                }
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Error cleaning up backups: ${e.message}")
        }
    }

    private fun findClosestBackup(target: Date, dates: List<Date>): Date? {
        if (dates.isEmpty()) return null

        var closest: Date? = null
        var minDiff = Long.MAX_VALUE

        dates.forEach { date ->
            val diff = Math.abs(date.time - target.time)
            if (diff < minDiff) {
                minDiff = diff
                closest = date
            }
        }

        return closest
    }

    companion object {
        const val FLUTTER_CHANNEL = "com.presley.jackedlog/android"
        const val WRITE_REQUEST_CODE = 43
        const val TIMER_PERMISSION_REQUEST_CODE = 44
        const val TICK_BROADCAST = "tick-event"
    }
}
