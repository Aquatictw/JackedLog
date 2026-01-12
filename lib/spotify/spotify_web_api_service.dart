import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:spotify_sdk/spotify_sdk.dart';
import 'spotify_config.dart';

/// Service for Spotify Web API REST calls
/// Uses OAuth token from App Remote SDK for authentication
class SpotifyWebApiService {
  static final SpotifyWebApiService _instance =
      SpotifyWebApiService._internal();
  factory SpotifyWebApiService() => _instance;
  SpotifyWebApiService._internal();

  static const String _baseUrl = 'https://api.spotify.com/v1';
  String? _cachedToken;
  DateTime? _tokenExpiry;
  bool _isAuthenticating = false;

  /// Get valid access token (cached or fresh)
  Future<String?> _getAccessToken() async {
    // Return cached token if still valid (5 min buffer)
    if (_cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!.subtract(const Duration(minutes: 5)))) {
      return _cachedToken;
    }

    // Prevent concurrent authentication attempts
    if (_isAuthenticating) {
      return null;
    }

    // Fetch fresh token from SDK
    try {
      _isAuthenticating = true;
      _cachedToken = await SpotifySdk.getAccessToken(
        clientId: SpotifyConfig.clientId,
        redirectUrl: SpotifyConfig.redirectUrl,
      );
      _tokenExpiry = DateTime.now().add(const Duration(hours: 1));
      return _cachedToken;
    } catch (e) {
      return null;
    } finally {
      _isAuthenticating = false;
    }
  }

  /// Make authenticated GET request to Spotify Web API
  Future<Map<String, dynamic>?> _get(String endpoint) async {
    final token = await _getAccessToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        // Token expired, clear cache and retry once
        _cachedToken = null;
        _tokenExpiry = null;
        return null;
      } else if (response.statusCode == 429) {
        // Rate limited, return cached data (handled by caller)
        return null;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Fetch current user's playback queue
  /// Returns list of tracks: {title, artist, album, artworkUrl}
  Future<List<Map<String, dynamic>>> getQueue() async {
    final data = await _get('/me/player/queue');
    if (data == null) {
      print('🎵 Queue fetch returned null');
      return [];
    }

    final List<dynamic> queue = data['queue'] ?? [];
    print('🎵 Queue fetched: ${queue.length} tracks');
    return queue.map((item) {
      return {
        'title': item['name'] ?? 'Unknown Track',
        'artist': (item['artists'] as List?)?.first['name'] ?? 'Unknown Artist',
        'album': item['album']?['name'] ?? 'Unknown Album',
        'artworkUrl': (item['album']?['images'] as List?)?.first['url'],
      };
    }).toList();
  }

  /// Fetch recently played tracks (last 10)
  /// Returns list of tracks: {title, artist, album, artworkUrl, playedAt}
  Future<List<Map<String, dynamic>>> getRecentlyPlayed({int limit = 10}) async {
    final data = await _get('/me/player/recently-played?limit=$limit');
    if (data == null) {
      print('🎵 Recently played fetch returned null');
      return [];
    }

    final List<dynamic> items = data['items'] ?? [];
    print('🎵 Recently played fetched: ${items.length} tracks');
    return items.map((item) {
      final track = item['track'];
      return {
        'title': track['name'] ?? 'Unknown Track',
        'artist': (track['artists'] as List?)?.first['name'] ?? 'Unknown Artist',
        'album': track['album']?['name'] ?? 'Unknown Album',
        'artworkUrl': (track['album']?['images'] as List?)?.first['url'],
        'playedAt': item['played_at'],
      };
    }).toList();
  }

  /// Fetch current playback context (playlist/album name)
  /// Returns {type: 'playlist'|'album', name: 'Name', uri: 'spotify:...'}
  Future<Map<String, String>?> getPlaybackContext() async {
    final data = await _get('/me/player');
    if (data == null) {
      print('🎵 Playback context fetch returned null');
      return null;
    }

    final context = data['context'];
    if (context == null) {
      print('🎵 No playback context (single track or radio)');
      return null;
    }

    final String type = context['type'] ?? '';
    final String uri = context['uri'] ?? '';

    // Extract context name based on type
    if (type == 'playlist') {
      final playlistId = uri.split(':').last;
      final playlistData = await _get('/playlists/$playlistId?fields=name');
      final name = playlistData?['name'] ?? 'Unknown Playlist';
      print('🎵 Playing from playlist: $name');
      return {
        'type': 'playlist',
        'name': name,
        'uri': uri,
      };
    } else if (type == 'album') {
      final albumId = uri.split(':').last;
      final albumData = await _get('/albums/$albumId?fields=name');
      final name = albumData?['name'] ?? 'Unknown Album';
      print('🎵 Playing from album: $name');
      return {
        'type': 'album',
        'name': name,
        'uri': uri,
      };
    } else if (type == 'artist') {
      print('🎵 Playing from artist radio');
      return {
        'type': 'artist',
        'name': 'Artist Radio',
        'uri': uri,
      };
    }

    return null;
  }

  /// Clear cached token (useful for logout/reconnect)
  void clearCache() {
    _cachedToken = null;
    _tokenExpiry = null;
    _isAuthenticating = false;
  }
}
