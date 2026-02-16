import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../database/database.dart';
import '../main.dart';
import '../settings/settings_state.dart';
import '../utils.dart';
import '../server/backup_push_service.dart';
import 'auto_backup_service.dart';

class AutoBackupSettings extends StatefulWidget {
  const AutoBackupSettings({super.key});

  @override
  State<AutoBackupSettings> createState() => _AutoBackupSettingsState();
}

class _AutoBackupSettingsState extends State<AutoBackupSettings> {
  bool _isBackingUp = false;
  bool _isPushing = false;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer.withValues(alpha: 0.3),
              colorScheme.secondaryContainer.withValues(alpha: 0.2),
              colorScheme.tertiaryContainer.withValues(alpha: 0.1),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.backup_rounded,
                      color: colorScheme.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Automatic Backups',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Keep your workout data safe',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Enable toggle
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                  ),
                ),
                child: SwitchListTile(
                  title: Text(
                    'Enable Auto-Backup',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Automatically backup your data daily',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  value: settings.value.automaticBackups,
                  onChanged: (value) async {
                    await db.settings.update().write(
                          SettingsCompanion(
                            automaticBackups: Value(value),
                          ),
                        );
                    await settings.init();
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              if (settings.value.automaticBackups) ...[
                const SizedBox(height: 16),

                // Backup location
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outlineVariant,
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.folder_rounded,
                      color: colorScheme.tertiary,
                    ),
                    title: Text(
                      'Backup Location',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      settings.value.backupPath?.isNotEmpty ?? false
                          ? settings.value.backupPath!
                          : 'No folder selected',
                      style: TextStyle(
                        color: settings.value.backupPath?.isNotEmpty ?? false
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.error,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    onTap: _selectBackupFolder,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Last backup time with status indicator
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        color: colorScheme.secondary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Last Backup',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              settings.value.lastAutoBackupTime != null
                                  ? timeago.format(settings.value.lastAutoBackupTime!)
                                  : 'Never',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      _buildBackupStatusIndicator(
                        context,
                        settings.value.lastBackupStatus,
                        settings.value.lastAutoBackupTime,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Manual backup button
                FilledButton.icon(
                  onPressed: _isBackingUp ||
                          (settings.value.backupPath?.isEmpty ?? true)
                      ? null
                      : _performManualBackup,
                  icon: _isBackingUp
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.backup_rounded),
                  label: Text(_isBackingUp ? 'Backing up...' : 'Backup Now'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Retention policy info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Retention Policy',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildRetentionItem(
                        context,
                        Icons.today_rounded,
                        'Daily',
                        'Last 7 days',
                        colorScheme,
                      ),
                      const SizedBox(height: 8),
                      _buildRetentionItem(
                        context,
                        Icons.date_range_rounded,
                        'Weekly',
                        'Last 4 weeks',
                        colorScheme,
                      ),
                      const SizedBox(height: 8),
                      _buildRetentionItem(
                        context,
                        Icons.calendar_month_rounded,
                        'Monthly',
                        'Last 12 months',
                        colorScheme,
                      ),
                    ],
                  ),
                ),
              ],

              // Server push section — visible when server URL is configured
              if (settings.value.serverUrl != null &&
                  settings.value.serverUrl!.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // Push to server header
                Row(
                  children: [
                    Icon(
                      Icons.cloud_upload_rounded,
                      color: colorScheme.tertiary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Push to Server',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Push status display
                _buildPushStatus(context, settings.value, colorScheme),

                const SizedBox(height: 16),

                // Progress bar (only during push)
                if (_isPushing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: LinearProgressIndicator(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),

                // Push button
                FilledButton.icon(
                  onPressed: _isPushing ? null : _performPush,
                  icon: _isPushing
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.cloud_upload_rounded),
                  label: Text(_isPushing ? 'Pushing...' : 'Push Backup'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRetentionItem(
    BuildContext context,
    IconData icon,
    String label,
    String description,
    ColorScheme colorScheme,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: colorScheme.secondary,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
        ),
        const SizedBox(width: 8),
        Text(
          '•',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(width: 8),
        Text(
          description,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildBackupStatusIndicator(
    BuildContext context,
    String? status,
    DateTime? lastBackupTime,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    IconData icon;
    String label;
    Color color;

    if (lastBackupTime == null) {
      icon = Icons.backup_outlined;
      label = 'Never';
      color = colorScheme.outline;
    } else if (status == 'failed') {
      icon = Icons.error_outline_rounded;
      label = 'Failed';
      color = colorScheme.error;
    } else {
      icon = Icons.check_circle_outline_rounded;
      label = 'Success';
      color = colorScheme.primary;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildPushStatus(
    BuildContext context,
    Setting settings,
    ColorScheme colorScheme,
  ) {
    final lastPushTime = settings.lastPushTime;
    final lastPushStatus = settings.lastPushStatus;

    IconData icon;
    String statusText;
    Color color;

    if (lastPushStatus == 'failed') {
      icon = Icons.error_outline_rounded;
      statusText = lastPushTime != null
          ? 'Push failed ${timeago.format(lastPushTime)}'
          : 'Push failed';
      color = colorScheme.error;
    } else if (lastPushTime == null) {
      icon = Icons.cloud_off_rounded;
      statusText = 'Never pushed';
      color = colorScheme.outline;
    } else {
      icon = Icons.check_circle_outline_rounded;
      statusText = 'Last pushed: ${timeago.format(lastPushTime)}';
      color = colorScheme.primary;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Server Backup',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          Icon(icon, size: 16, color: color),
        ],
      ),
    );
  }

  Future<void> _performPush() async {
    final settings = context.read<SettingsState>();
    final serverUrl = settings.value.serverUrl;
    final apiKey = settings.value.serverApiKey;

    if (serverUrl == null ||
        serverUrl.isEmpty ||
        apiKey == null ||
        apiKey.isEmpty) {
      return;
    }

    setState(() {
      _isPushing = true;
    });

    try {
      await BackupPushService.pushBackup(serverUrl, apiKey);
      if (mounted) {
        await settings.init();
      }
    } catch (e) {
      print('Push backup failed: $e');
      if (mounted) {
        await settings.init();
        toast('Push failed: ${e.toString().replaceFirst('Exception: ', '')}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPushing = false;
        });
      }
    }
  }

  Future<void> _selectBackupFolder() async {
    try {
      print('🔵 Opening folder picker...');
      if (Platform.isAndroid) {
        // Use native picker for Android SAF
        const platform = MethodChannel('com.presley.jackedlog/android');

        // Get database path to pass to native method
        final dbFolder = await getApplicationDocumentsDirectory();
        final dbPath = p.join(dbFolder.path, 'jackedlog.sqlite');

        print('🔵 Calling native pick method with dbPath: $dbPath');
        await platform.invokeMethod('pick', {
          'dbPath': dbPath,
        });

        print('🟢 Native pick completed, refreshing settings...');
        // The native code will handle updating the database and scheduling backups
        // We just need to refresh the settings state
        if (mounted) {
          final settings = context.read<SettingsState>();
          await settings.init();
          print('🟢 New backup path: ${settings.value.backupPath}');
          toast('Backup folder selected');
        }
      }
    } on PlatformException catch (e) {
      print('🔴 Platform exception in folder picker: ${e.code} - ${e.message}');
      if (mounted) {
        toast('Failed to select folder: ${e.message}');
      }
    } catch (e) {
      print('🔴 Error in folder picker: $e');
      if (mounted) {
        toast('Failed to select folder: ${e.toString()}');
      }
    }
  }

  Future<void> _performManualBackup() async {
    final settings = context.read<SettingsState>();
    final backupPath = settings.value.backupPath;

    if (backupPath == null || backupPath.isEmpty) {
      if (mounted) {
        toast('Please select a backup folder first');
      }
      return;
    }

    setState(() {
      _isBackingUp = true;
    });

    try {
      await AutoBackupService.performManualBackup(backupPath);
      if (mounted) {
        await settings.init();
        toast('Backup completed successfully!');
      }
    } catch (e) {
      print('ERROR [ManualBackup] Backup failed');
      print('  Backup path: $backupPath');
      print('  Exception type: ${e.runtimeType}');
      print('  Message: $e');
      if (e is FileSystemException) {
        print('  OS Error: ${e.osError}');
      }
      if (e is PlatformException) {
        print('  Platform code: ${e.code}');
        print('  Platform message: ${e.message}');
      }
      if (mounted) {
        toast(_getBackupErrorMessage(e), duration: const Duration(seconds: 10));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
        });
      }
    }
  }

  String _getBackupErrorMessage(Object error) {
    final msg = error.toString().toLowerCase();

    if (error is PlatformException) {
      final platformMsg = error.message?.toLowerCase() ?? '';
      if (platformMsg.contains('permission') || platformMsg.contains('denied')) {
        return 'Backup failed: Permission denied. Please re-select the backup folder.';
      }
      if (platformMsg.contains('no space') || platformMsg.contains('full')) {
        return 'Backup failed: Not enough storage space.';
      }
      return 'Backup failed: ${error.message ?? 'Unknown error'}';
    }

    if (error is FileSystemException) {
      final osError = error.osError;
      if (osError != null) {
        if (osError.errorCode == 13) {
          return 'Backup failed: Permission denied.';
        }
        if (osError.errorCode == 28) {
          return 'Backup failed: Not enough storage space.';
        }
        if (osError.errorCode == 2) {
          return 'Backup failed: Folder not found. Please select a new backup folder.';
        }
      }
      return 'Backup failed: Could not write to backup location.';
    }

    if (msg.contains('permission') || msg.contains('denied')) {
      return 'Backup failed: Permission denied. Please re-select the backup folder.';
    }
    if (msg.contains('no space') ||
        msg.contains('disk full') ||
        msg.contains('storage')) {
      return 'Backup failed: Not enough storage space.';
    }
    if (msg.contains('not found') || msg.contains('no such')) {
      return 'Backup failed: Backup folder not found. Please select a new folder.';
    }

    final firstLine = error.toString().split('\n').first;
    return 'Backup failed: ${firstLine.length > 80 ? '${firstLine.substring(0, 80)}...' : firstLine}';
  }
}
