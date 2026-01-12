import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:jackedlog/spotify/spotify_service.dart';
import 'package:spotify_sdk/models/player_options.dart' as player_options;
import 'package:spotify_sdk/models/player_state.dart';

/// Connection status for Spotify
enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

/// Track information for display
class Track {
  final String title;
  final String artist;
  final String album;
  final String? artworkUrl;

  Track({
    required this.title,
    required this.artist,
    required this.album,
    this.artworkUrl,
  });

  /// Create Track from Spotify SDK PlayerState
  factory Track.fromPlayerState(PlayerState playerState) {
    return Track(
      title: playerState.track?.name ?? 'Unknown Track',
      artist: playerState.track?.artist.name ?? 'Unknown Artist',
      album: playerState.track?.album.name ?? 'Unknown Album',
      artworkUrl: playerState.track?.imageUri.raw,
    );
  }

  /// Create placeholder Track for no playback state
  factory Track.placeholder() {
    return Track(
      title: 'No track playing',
      artist: 'Open Spotify and start playing',
      album: '',
      artworkUrl: null,
    );
  }
}

/// Provider for Spotify playback state management
/// Uses ChangeNotifier pattern following WorkoutState conventions
class SpotifyState extends ChangeNotifier {
  final SpotifyService _service = SpotifyService();
  Timer? _pollingTimer;

  // State properties
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  PlayerState? _currentPlayerState;
  String? _errorMessage;
  Track _currentTrack = Track.placeholder();
  int _positionMs = 0;
  int _durationMs = 0;
  bool _isPaused = true;
  bool _isShuffling = false;
  player_options.RepeatMode _repeatMode = player_options.RepeatMode.off;

  // Getters
  ConnectionStatus get connectionStatus => _connectionStatus;
  PlayerState? get currentPlayerState => _currentPlayerState;
  String? get errorMessage => _errorMessage;
  Track get currentTrack => _currentTrack;
  int get positionMs => _positionMs;
  int get durationMs => _durationMs;
  bool get isPaused => _isPaused;
  bool get isShuffling => _isShuffling;
  player_options.RepeatMode get repeatMode => _repeatMode;
  List<Track> get queue => []; // Queue API not available in spotify_sdk

  /// Initialize SpotifyState and check for existing connection
  SpotifyState() {
    _initialize();
  }

  Future<void> _initialize() async {
    // Check if already connected
    if (_service.isConnected) {
      _connectionStatus = ConnectionStatus.connected;
      notifyListeners();
    }
  }

  /// Start polling for player state updates
  /// Should be called when MusicPage becomes visible
  void startPolling() {
    // Cancel existing timer if any
    stopPolling();

    // Poll every 1 second
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      await _pollPlayerState();
    });
  }

  /// Stop polling for player state updates
  /// Should be called when MusicPage is disposed or backgrounded
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Poll current player state from Spotify
  Future<void> _pollPlayerState() async {
    try {
      final playerState = await _service.getPlayerState();

      if (playerState != null) {
        _updateFromPlayerState(playerState);
      } else {
        // No active playback
        _currentTrack = Track.placeholder();
        _positionMs = 0;
        _durationMs = 0;
        _isPaused = true;
        notifyListeners();
      }
    } catch (e) {
      // Connection lost or other error
      if (_connectionStatus == ConnectionStatus.connected) {
        _connectionStatus = ConnectionStatus.error;
        _errorMessage = 'Connection lost';
        notifyListeners();
      }
    }
  }

  /// Update state properties from PlayerState object
  void _updateFromPlayerState(PlayerState playerState) {
    _currentPlayerState = playerState;
    _currentTrack = Track.fromPlayerState(playerState);
    _positionMs = playerState.playbackPosition;
    _durationMs = playerState.track?.duration ?? 0;
    _isPaused = playerState.isPaused;
    _isShuffling = playerState.playbackOptions.isShuffling;
    _repeatMode = playerState.playbackOptions.repeatMode;

    // Clear error if we successfully got state
    if (_connectionStatus == ConnectionStatus.error) {
      _connectionStatus = ConnectionStatus.connected;
      _errorMessage = null;
    }

    notifyListeners();
  }

  /// Connect to Spotify
  /// Returns true if connection successful
  Future<bool> connect() async {
    _connectionStatus = ConnectionStatus.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _service.connect();
      if (success) {
        _connectionStatus = ConnectionStatus.connected;
        notifyListeners();
        return true;
      } else {
        _connectionStatus = ConnectionStatus.error;
        _errorMessage = 'Failed to connect';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _connectionStatus = ConnectionStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Disconnect from Spotify
  Future<void> disconnect() async {
    stopPolling();
    await _service.disconnect();
    _connectionStatus = ConnectionStatus.disconnected;
    _errorMessage = null;
    _currentPlayerState = null;
    _currentTrack = Track.placeholder();
    _positionMs = 0;
    _durationMs = 0;
    _isPaused = true;
    _isShuffling = false;
    _repeatMode = player_options.RepeatMode.off;
    notifyListeners();
  }

  /// Refresh player state immediately (useful for manual refresh)
  Future<void> refresh() async {
    await _pollPlayerState();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
