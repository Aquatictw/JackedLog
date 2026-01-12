import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jackedlog/spotify/spotify_state.dart';
import 'package:jackedlog/music/widgets/auth_prompt.dart';
import 'package:jackedlog/music/widgets/no_playback_state.dart';
import 'package:jackedlog/music/widgets/player_controls.dart';
import 'package:jackedlog/music/widgets/seek_bar.dart';
import 'package:jackedlog/music/widgets/queue_bottom_sheet.dart';

/// Main UI widget for the Music tab
/// Provides Spotify remote control interface during workouts
class MusicPage extends StatefulWidget {
  const MusicPage({super.key});

  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> {
  @override
  void initState() {
    super.initState();
    // Start polling when page initializes if already connected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final spotifyState = context.read<SpotifyState>();
      if (spotifyState.connectionStatus == ConnectionStatus.connected) {
        spotifyState.startPolling();
      }
    });
  }

  @override
  void dispose() {
    // Stop polling when page is disposed
    context.read<SpotifyState>().stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spotifyState = context.watch<SpotifyState>();
    final theme = Theme.of(context);

    // Determine which UI to render based on connection status
    if (spotifyState.connectionStatus == ConnectionStatus.disconnected ||
        spotifyState.connectionStatus == ConnectionStatus.connecting) {
      return const AuthPrompt();
    }

    // Connected but no active playback
    if (spotifyState.currentPlayerState == null ||
        spotifyState.currentTrack.artworkUrl == null) {
      return const NoPlaybackState();
    }

    // Active playback - render full player UI
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Large album art
                    _buildAlbumArt(context, spotifyState),
                    const SizedBox(height: 16),

                    // Track name (bold, large text)
                    _buildTrackTitle(theme, spotifyState),
                    const SizedBox(height: 4),

                    // Artist name (medium gray text)
                    _buildArtistName(theme, spotifyState),
                    const SizedBox(height: 20),

                    // Seek bar with position/duration
                    const SeekBar(),
                    const SizedBox(height: 16),

                    // Player controls (shuffle, previous, play/pause, next, repeat)
                    const PlayerControls(),
                    const SizedBox(height: 16),

                    // View Queue button
                    _buildViewQueueButton(context),

                    // Add bottom padding to clear navigation bar
                    const SizedBox(height: 96),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build album art widget with fallback placeholder
  Widget _buildAlbumArt(BuildContext context, SpotifyState spotifyState) {
    final screenWidth = MediaQuery.of(context).size.width;
    final artSize = (screenWidth * 0.65).clamp(200.0, 300.0);

    return Container(
      width: artSize,
      height: artSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: spotifyState.currentTrack.artworkUrl != null
            ? Image.network(
                spotifyState.currentTrack.artworkUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholderArt();
                },
              )
            : _buildPlaceholderArt(),
      ),
    );
  }

  /// Placeholder album art for when image is unavailable
  Widget _buildPlaceholderArt() {
    return Container(
      color: Colors.grey[800],
      child: Center(
        child: Icon(
          Icons.music_note,
          size: 120,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  /// Build track title with marquee scrolling for long text
  Widget _buildTrackTitle(ThemeData theme, SpotifyState spotifyState) {
    return Text(
      spotifyState.currentTrack.title,
      style: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Build artist name with medium gray styling
  Widget _buildArtistName(ThemeData theme, SpotifyState spotifyState) {
    return Text(
      spotifyState.currentTrack.artist,
      style: theme.textTheme.titleMedium?.copyWith(
        color: Colors.grey[600],
      ),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Build "View Queue" button that opens queue bottom sheet
  Widget _buildViewQueueButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          useRootNavigator: true,
          isScrollControlled: true,
          builder: (context) => const QueueBottomSheet(),
        );
      },
      icon: const Icon(Icons.queue_music),
      label: const Text('View Queue'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }
}
