import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jackedlog/spotify/spotify_service.dart';
import 'package:jackedlog/spotify/spotify_web_api_service.dart';
import 'package:palette_generator/palette_generator.dart';
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
  final Color? dominantColor;

  Track({
    required this.title,
    required this.artist,
    required this.album,
    this.artworkUrl,
    this.dominantColor,
  });

  /// Create Track from Spotify SDK PlayerState
  factory Track.fromPlayerState(PlayerState playerState) {
    // Convert Spotify URI to HTTP URL
    String? artworkUrl;
    final imageUri = playerState.track?.imageUri.raw;
    if (imageUri != null && imageUri.startsWith('spotify:image:')) {
      // Extract image ID and convert to Spotify CDN URL
      final imageId = imageUri.replaceFirst('spotify:image:', '');
      if (imageId.isNotEmpty) {
        artworkUrl = 'https://i.scdn.co/image/$imageId';
      }
    }

    return Track(
      title: playerState.track?.name ?? 'Unknown Track',
      artist: playerState.track?.artist.name ?? 'Unknown Artist',
      album: playerState.track?.album.name ?? 'Unknown Album',
      artworkUrl: artworkUrl,
      dominantColor: null, // Will be extracted async
    );
  }

  /// Create placeholder Track for no playback state
  factory Track.placeholder() {
    return Track(
      title: 'No track playing',
      artist: 'Open Spotify and start playing',
      album: '',
      artworkUrl: null,
      dominantColor: null,
    );
  }

  /// Create copy with updated dominantColor
  Track copyWith({Color? dominantColor}) {
    return Track(
      title: title,
      artist: artist,
      album: album,
      artworkUrl: artworkUrl,
      dominantColor: dominantColor ?? this.dominantColor,
    );
  }
}

/// Provider for Spotify playback state management
/// Uses ChangeNotifier pattern following WorkoutState conventions
class SpotifyState extends ChangeNotifier {
  final SpotifyService _service = SpotifyService();
  final SpotifyWebApiService _webApiService = SpotifyWebApiService();
  Timer? _pollingTimer;
  int _pollingTick = 0;

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
  List<Track> _queue = [];
  List<Track> _recentlyPlayed = [];
  String? _playingFromType; // 'playlist', 'album', 'artist'
  String? _playingFromName;

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
  List<Track> get queue => _queue;
  List<Track> get recentlyPlayed => _recentlyPlayed;
  String? get playingFromType => _playingFromType;
  String? get playingFromName => _playingFromName;

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

    // Reset tick counter
    _pollingTick = 0;

    // Poll every 1 second
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      await _pollPlayerState();
      _pollingTick++;
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

        // Fetch Web API data every 5 seconds (reduce API calls)
        if (_pollingTick % 5 == 0) {
          _fetchWebApiData();
        }
      } else {
        // No active playback
        _currentTrack = Track.placeholder();
        _positionMs = 0;
        _durationMs = 0;
        _isPaused = true;
        _queue = [];
        _recentlyPlayed = [];
        _playingFromType = null;
        _playingFromName = null;
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

  /// Extract dominant color from album artwork
  Future<void> _extractDominantColor(String imageUrl) async {
    try {
      final imageProvider = NetworkImage(imageUrl);
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 10,
      );

      // Get dominant or vibrant color
      final dominantColor = paletteGenerator.dominantColor?.color ??
          paletteGenerator.vibrantColor?.color;

      if (dominantColor != null) {
        _currentTrack = _currentTrack.copyWith(dominantColor: dominantColor);
        notifyListeners();
      }
    } catch (e) {
      // Ignore color extraction errors
    }
  }

  /// Fetch queue, recently played, and context from Web API
  Future<void> _fetchWebApiData() async {
    // Fetch queue
    final queueData = await _webApiService.getQueue();
    _queue = queueData.map((item) {
      return Track(
        title: item['title'] as String,
        artist: item['artist'] as String,
        album: item['album'] as String,
        artworkUrl: item['artworkUrl'] as String?,
      );
    }).toList();

    // Fetch recently played
    final recentlyPlayedData = await _webApiService.getRecentlyPlayed(limit: 10);
    _recentlyPlayed = recentlyPlayedData.map((item) {
      return Track(
        title: item['title'] as String,
        artist: item['artist'] as String,
        album: item['album'] as String,
        artworkUrl: item['artworkUrl'] as String?,
      );
    }).toList();

    // Fetch playback context
    final context = await _webApiService.getPlaybackContext();
    if (context != null) {
      _playingFromType = context['type'];
      _playingFromName = context['name'];
    } else {
      _playingFromType = null;
      _playingFromName = null;
    }

    notifyListeners();
  }

  /// Update state properties from PlayerState object
  void _updateFromPlayerState(PlayerState playerState) {
    final newTrack = Track.fromPlayerState(playerState);

    // Extract color if artwork URL changed
    if (newTrack.artworkUrl != null &&
        newTrack.artworkUrl != _currentTrack.artworkUrl) {
      _extractDominantColor(newTrack.artworkUrl!);
    }

    _currentPlayerState = playerState;
    _currentTrack = newTrack;
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
    _webApiService.clearCache();
    _connectionStatus = ConnectionStatus.disconnected;
    _errorMessage = null;
    _currentPlayerState = null;
    _currentTrack = Track.placeholder();
    _positionMs = 0;
    _durationMs = 0;
    _isPaused = true;
    _isShuffling = false;
    _repeatMode = player_options.RepeatMode.off;
    _queue = [];
    _recentlyPlayed = [];
    _playingFromType = null;
    _playingFromName = null;
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
