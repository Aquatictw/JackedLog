import 'package:shelf/shelf.dart';

Middleware authMiddleware(String apiKey) {
  return (Handler innerHandler) {
    return (Request request) async {
      // Health check is public
      if (request.url.path == 'api/health') {
        return innerHandler(request);
      }

      // Dashboard pages use query parameter auth
      if (request.url.path.startsWith('dashboard')) {
        final key = request.url.queryParameters['key'];
        if (key != apiKey) {
          return Response.forbidden(
            '{"error": "Invalid API key"}',
            headers: {'content-type': 'application/json'},
          );
        }
        return innerHandler(request);
      }

      // Manage page uses query parameter auth
      if (request.url.path == 'manage') {
        final key = request.url.queryParameters['key'];
        if (key != apiKey) {
          return Response.forbidden(
            '{"error": "Invalid API key"}',
            headers: {'content-type': 'application/json'},
          );
        }
        return innerHandler(request);
      }

      // All other routes use Bearer token
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response(401,
          body: '{"error": "Missing authorization"}',
          headers: {'content-type': 'application/json'},
        );
      }

      final token = authHeader.substring(7);
      if (token != apiKey) {
        return Response.forbidden(
          '{"error": "Invalid API key"}',
          headers: {'content-type': 'application/json'},
        );
      }

      return innerHandler(request);
    };
  };
}
