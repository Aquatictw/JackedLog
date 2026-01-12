import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:jackedlog/database/database.dart';
import 'package:jackedlog/main.dart';
import 'package:jackedlog/settings/settings_state.dart';
import 'package:jackedlog/spotify/spotify_state.dart';
import 'package:jackedlog/utils.dart';
import 'package:provider/provider.dart';

/// Get Spotify settings widgets for search functionality
List<Widget> getSpotifySettings(
  BuildContext context,
  String term,
  SettingsState settings,
) {
  final tabSplit = settings.value.tabs.split(',');
  final bool isMusicTabVisible = tabSplit.contains('MusicPage');

  return [
    if ('show music tab'.contains(term.toLowerCase()) ||
        'spotify'.contains(term.toLowerCase()))
      ListTile(
        leading: Icon(
          isMusicTabVisible ? Icons.music_note : Icons.music_note_outlined,
        ),
        title: const Text('Show Music tab'),
        subtitle: const Text('Display Music tab in navigation'),
        trailing: Switch(
          value: isMusicTabVisible,
          onChanged: (value) => _toggleMusicTab(value, settings),
        ),
      ),
  ];
}

/// Toggle Music tab visibility (helper for search functionality)
void _toggleMusicTab(bool visible, SettingsState settings) {
  final tabSplit = settings.value.tabs.split(',');
  List<String> newTabs = List.from(tabSplit);

  if (visible && !tabSplit.contains('MusicPage')) {
    // Add MusicPage after PlansPage (position 2)
    final plansIndex = newTabs.indexOf('PlansPage');
    if (plansIndex >= 0) {
      newTabs.insert(plansIndex + 1, 'MusicPage');
    } else {
      newTabs.add('MusicPage');
    }
  } else if (!visible && tabSplit.contains('MusicPage')) {
    newTabs.remove('MusicPage');
  }

  db.settings.update().write(
        SettingsCompanion(
          tabs: Value(newTabs.join(',')),
        ),
      );
}

class SpotifySettings extends StatefulWidget {
  const SpotifySettings({super.key});

  @override
  State<SpotifySettings> createState() => _SpotifySettingsState();
}

class _SpotifySettingsState extends State<SpotifySettings> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();
    final spotifyState = context.watch<SpotifyState>();

    // Check if connected by checking for valid, non-expired token
    final bool hasToken = settings.value.spotifyAccessToken != null;
    final bool isTokenExpired = hasToken &&
        settings.value.spotifyTokenExpiry != null &&
        DateTime.now().isAfter(
            DateTime.fromMillisecondsSinceEpoch(settings.value.spotifyTokenExpiry!));

    final bool isConnected = hasToken && !isTokenExpired;

    final bool hasError =
        spotifyState.connectionStatus == ConnectionStatus.error;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spotify'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView(
          children: [
            // Connection status indicator
            Card(
              child: ListTile(
                leading: Icon(
                  isConnected
                      ? Icons.check_circle
                      : hasError
                          ? Icons.error
                          : isTokenExpired
                              ? Icons.schedule
                              : Icons.music_note_outlined,
                  color: isConnected
                      ? Colors.green
                      : hasError
                          ? Theme.of(context).colorScheme.error
                          : isTokenExpired
                              ? Colors.orange
                              : Colors.grey,
                ),
                title: Text(
                  isConnected
                      ? 'Connected to Spotify'
                      : hasError
                          ? 'Connection error'
                          : isTokenExpired
                              ? 'Token expired'
                              : 'Not connected',
                ),
                subtitle: hasError && spotifyState.errorMessage != null
                    ? Text(spotifyState.errorMessage!)
                    : isTokenExpired
                        ? const Text('Reconnect to continue using Spotify')
                        : null,
              ),
            ),
            const SizedBox(height: 8),

            // Disconnect button (visible when connected)
            if (isConnected)
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Disconnect Spotify'),
                onTap: _isProcessing ? null : () => _showDisconnectDialog(),
              ),

            // Reconnect button (visible when error state or token expired)
            if (hasError || isTokenExpired)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Reconnect'),
                onTap: _isProcessing ? null : () => _reconnectSpotify(),
              ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Show confirmation dialog before disconnecting
  void _showDisconnectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Spotify'),
        content: const Text(
          'Are you sure you want to disconnect Spotify? You will need to reconnect to use music controls.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _disconnectSpotify();
            },
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  /// Disconnect from Spotify and clear tokens
  Future<void> _disconnectSpotify() async {
    setState(() => _isProcessing = true);

    try {
      // Disconnect via SpotifyState (which handles SpotifyService)
      final spotifyState = context.read<SpotifyState>();
      await spotifyState.disconnect();

      // Clear tokens from database
      await db.settings.update().write(
            const SettingsCompanion(
              spotifyAccessToken: Value(null),
              spotifyRefreshToken: Value(null),
              spotifyTokenExpiry: Value(null),
            ),
          );

      if (mounted) {
        toast('Disconnected from Spotify');
      }
    } catch (e) {
      if (mounted) {
        toast('Failed to disconnect: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Reconnect to Spotify
  Future<void> _reconnectSpotify() async {
    setState(() => _isProcessing = true);

    try {
      final spotifyState = context.read<SpotifyState>();
      final success = await spotifyState.connect();

      if (mounted) {
        if (success) {
          toast('Reconnected to Spotify');
        } else {
          toast('Failed to reconnect');
        }
      }
    } catch (e) {
      if (mounted) {
        toast('Failed to reconnect: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
}
