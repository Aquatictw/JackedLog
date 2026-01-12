import 'package:spotify_sdk/spotify_sdk.dart';
import 'package:spotify_sdk/models/player_state.dart';
import 'package:spotify_sdk/models/player_options.dart' as player_options;

/// Singleton service wrapping Spotify SDK
/// Manages connection lifecycle and playback controls
class SpotifyService {
  static final SpotifyService _instance = SpotifyService._internal();
  factory SpotifyService() => _instance;
  SpotifyService._internal();

  // Spotify Client ID - TODO: Replace with your app's client ID from developer.spotify.com
  static const String clientId = 'YOUR_SPOTIFY_CLIENT_ID';
  static const String redirectUrl = 'jackedlog://spotify-auth-callback';

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  /// Connect to Spotify with OAuth flow
  /// Opens Spotify app (or browser) for authorization
  /// Returns true if connection successful
  Future<bool> connect() async {
    try {
      final result = await SpotifySdk.connectToSpotifyRemote(
        clientId: clientId,
        redirectUrl: redirectUrl,
      );
      _isConnected = result;
      return result;
    } catch (e) {
      _isConnected = false;
      rethrow;
    }
  }

  /// Disconnect from Spotify and clean up connection
  Future<void> disconnect() async {
    try {
      await SpotifySdk.disconnect();
      _isConnected = false;
    } catch (e) {
      // Ignore disconnect errors
      _isConnected = false;
    }
  }

  /// Toggle play/pause based on current playback state
  Future<void> togglePlayPause() async {
    try {
      final state = await SpotifySdk.getPlayerState();
      if (state?.isPaused ?? true) {
        await SpotifySdk.resume();
      } else {
        await SpotifySdk.pause();
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Skip to next track
  Future<void> skipNext() async {
    try {
      await SpotifySdk.skipNext();
    } catch (e) {
      rethrow;
    }
  }

  /// Skip to previous track
  Future<void> skipPrevious() async {
    try {
      await SpotifySdk.skipPrevious();
    } catch (e) {
      rethrow;
    }
  }

  /// Seek to specific position in current track
  Future<void> seekTo(int positionMs) async {
    try {
      await SpotifySdk.seekTo(positionedMilliseconds: positionMs);
    } catch (e) {
      rethrow;
    }
  }

  /// Toggle shuffle on/off
  Future<void> toggleShuffle() async {
    try {
      final state = await SpotifySdk.getPlayerState();
      final currentShuffle = state?.playbackOptions.isShuffling ?? false;
      await SpotifySdk.setShuffle(shuffle: !currentShuffle);
    } catch (e) {
      rethrow;
    }
  }

  /// Cycle through repeat modes: off → context → track → off
  Future<void> toggleRepeat() async {
    try {
      final state = await SpotifySdk.getPlayerState();
      final currentRepeat = state?.playbackOptions.repeatMode ?? player_options.RepeatMode.off;

      final player_options.RepeatMode nextMode;
      switch (currentRepeat) {
        case player_options.RepeatMode.off:
          nextMode = player_options.RepeatMode.context;
          break;
        case player_options.RepeatMode.context:
          nextMode = player_options.RepeatMode.track;
          break;
        case player_options.RepeatMode.track:
          nextMode = player_options.RepeatMode.off;
          break;
        default:
          nextMode = player_options.RepeatMode.off;
          break;
      }

      // Convert to SDK's RepeatMode enum for the API call
      final sdkRepeatMode = _convertToSdkRepeatMode(nextMode);
      await SpotifySdk.setRepeatMode(repeatMode: sdkRepeatMode);
    } catch (e) {
      rethrow;
    }
  }

  /// Convert player_options.RepeatMode to SDK's RepeatMode enum
  RepeatMode _convertToSdkRepeatMode(player_options.RepeatMode mode) {
    switch (mode) {
      case player_options.RepeatMode.off:
        return RepeatMode.off;
      case player_options.RepeatMode.track:
        return RepeatMode.track;
      case player_options.RepeatMode.context:
        return RepeatMode.context;
    }
  }

  /// Get current player state from Spotify
  /// Returns null if no active playback
  Future<PlayerState?> getPlayerState() async {
    try {
      return await SpotifySdk.getPlayerState();
    } catch (e) {
      return null;
    }
  }

  // Note: Queue API is not available in spotify_sdk package
  // Queue functionality has been removed as it's not supported
}
