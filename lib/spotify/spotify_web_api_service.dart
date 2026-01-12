import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for Spotify Web API REST calls
/// Uses OAuth token from App Remote SDK for authentication
class SpotifyWebApiService {
  static final SpotifyWebApiService _instance =
      SpotifyWebApiService._internal();
  factory SpotifyWebApiService() => _instance;
  SpotifyWebApiService._internal();

  /// Set the access token to use for API requests
  /// Should be called with token from SpotifyService after connection
  void setAccessToken(String token) {
    _currentToken = token;
  }

  static const String _baseUrl = 'https://api.spotify.com/v1';
  String? _currentToken;

  /// Get current access token
  /// Returns null if token not set
  String? _getAccessToken() {
    if (_currentToken == null) {
      print('🎵 No access token set in Web API service');
    }
    return _currentToken;
  }

  /// Make authenticated GET request to Spotify Web API
  Future<Map<String, dynamic>?> _get(String endpoint) async {
    final token = _getAccessToken();
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
        // Token expired or invalid
        print('🎵 Token expired (401), need to reconnect to Spotify');
        _currentToken = null;
        return null;
      } else if (response.statusCode == 429) {
        // Rate limited, return null (handled by caller)
        print('🎵 Rate limited (429), skipping this fetch');
        return null;
      } else {
        print('🎵 API error ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      print('🎵 Network error: $e');
      return null;
    }
  }

  /// Fetch current user's playback queue
  /// Returns list of tracks: {title, artist, album, artworkUrl, uri}
  Future<List<Map<String, dynamic>>> getQueue() async {
    final data = await _get('/me/player/queue');
    if (data == null) {
      return [];
    }

    final List<dynamic> queue = data['queue'] ?? [];
    return queue.map((item) {
      return {
        'title': item['name'] ?? 'Unknown Track',
        'artist': (item['artists'] as List?)?.first['name'] ?? 'Unknown Artist',
        'album': item['album']?['name'] ?? 'Unknown Album',
        'artworkUrl': (item['album']?['images'] as List?)?.first['url'],
        'uri': item['uri'] ?? '',
      };
    }).toList();
  }

  /// Fetch recently played tracks (last 10)
  /// Returns list of tracks: {title, artist, album, artworkUrl, playedAt, uri}
  Future<List<Map<String, dynamic>>> getRecentlyPlayed({int limit = 10}) async {
    final data = await _get('/me/player/recently-played?limit=$limit');
    if (data == null) {
      return [];
    }

    final List<dynamic> items = data['items'] ?? [];
    return items.map((item) {
      final track = item['track'];
      return {
        'title': track['name'] ?? 'Unknown Track',
        'artist': (track['artists'] as List?)?.first['name'] ?? 'Unknown Artist',
        'album': track['album']?['name'] ?? 'Unknown Album',
        'artworkUrl': (track['album']?['images'] as List?)?.first['url'],
        'playedAt': item['played_at'],
        'uri': track['uri'] ?? '',
      };
    }).toList();
  }

  /// Fetch current playback context (playlist/album name)
  /// Returns {type: 'playlist'|'album', name: 'Name', uri: 'spotify:...'}
  Future<Map<String, String>?> getPlaybackContext() async {
    final data = await _get('/me/player');
    if (data == null) {
      return null;
    }

    final context = data['context'];
    if (context == null) {
      return null;
    }

    final String type = context['type'] ?? '';
    final String uri = context['uri'] ?? '';

    // Extract context name based on type
    if (type == 'playlist') {
      final playlistId = uri.split(':').last;
      final playlistData = await _get('/playlists/$playlistId?fields=name');
      final name = playlistData?['name'] ?? 'Unknown Playlist';
      return {
        'type': 'playlist',
        'name': name,
        'uri': uri,
      };
    } else if (type == 'album') {
      final albumId = uri.split(':').last;
      final albumData = await _get('/albums/$albumId?fields=name');
      final name = albumData?['name'] ?? 'Unknown Album';
      return {
        'type': 'album',
        'name': name,
        'uri': uri,
      };
    } else if (type == 'artist') {
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
    _currentToken = null;
  }
}
