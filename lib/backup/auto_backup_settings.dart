import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:jackedlog/backup/auto_backup_service.dart';
import 'package:jackedlog/database/database.dart';
import 'package:jackedlog/main.dart';
import 'package:jackedlog/settings/settings_state.dart';
import 'package:jackedlog/utils.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

class AutoBackupSettings extends StatefulWidget {
  const AutoBackupSettings({super.key});

  @override
  State<AutoBackupSettings> createState() => _AutoBackupSettingsState();
}

class _AutoBackupSettingsState extends State<AutoBackupSettings> {
  bool _isBackingUp = false;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.all(16.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer.withOpacity(0.3),
              colorScheme.secondaryContainer.withOpacity(0.2),
              colorScheme.tertiaryContainer.withOpacity(0.1),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
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
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Keep your workout data safe',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                    width: 1,
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
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outlineVariant,
                      width: 1,
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
                      settings.value.backupPath?.isNotEmpty == true
                          ? settings.value.backupPath!
                          : 'No folder selected',
                      style: TextStyle(
                        color: settings.value.backupPath?.isNotEmpty == true
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

                // Last backup time
                if (settings.value.lastAutoBackupTime != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.outlineVariant,
                        width: 1,
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
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                timeago.format(settings.value.lastAutoBackupTime!),
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Manual backup button
                FilledButton.icon(
                  onPressed: _isBackingUp ||
                          settings.value.backupPath?.isEmpty != false
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
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withOpacity(0.5),
                      width: 1,
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
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
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

  Future<void> _selectBackupFolder() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory != null) {
        // Verify directory is writable
        final testDir = Directory(selectedDirectory);
        if (!await testDir.exists()) {
          if (mounted) {
            toast('Selected folder does not exist');
          }
          return;
        }

        await db.settings.update().write(
          SettingsCompanion(
            backupPath: Value(selectedDirectory),
          ),
        );

        if (mounted) {
          final settings = context.read<SettingsState>();
          await settings.init();
          toast('Backup folder selected');
        }
      }
    } catch (e) {
      if (mounted) {
        toast('Failed to select folder: ${e.toString()}');
      }
    }
  }

  Future<void> _performManualBackup() async {
    final settings = context.read<SettingsState>();
    final backupPath = settings.value.backupPath;

    if (backupPath == null || backupPath.isEmpty) {
      toast('Please select a backup folder first');
      return;
    }

    setState(() {
      _isBackingUp = true;
    });

    try {
      await AutoBackupService.performManualBackup(backupPath);
      if (mounted) {
        await settings.init();
      }
    } catch (e) {
      if (mounted) {
        toast('Backup failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
        });
      }
    }
  }
}
