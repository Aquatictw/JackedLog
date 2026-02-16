import 'dart:io';

class ServerConfig {
  final String apiKey;
  final int port;
  final String dataDir;
  final DateTime startTime;

  ServerConfig._({
    required this.apiKey,
    required this.port,
    required this.dataDir,
    required this.startTime,
  });

  factory ServerConfig.fromEnvironment() {
    final apiKey = Platform.environment['JACKED_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('JACKED_API_KEY environment variable is required');
    }

    final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
    final dataDir = Platform.environment['DATA_DIR'] ?? '/data';

    return ServerConfig._(
      apiKey: apiKey,
      port: port,
      dataDir: dataDir,
      startTime: DateTime.now(),
    );
  }
}
