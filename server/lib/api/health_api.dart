import 'package:shelf/shelf.dart';

late DateTime _serverStartTime;

void initHealthApi(DateTime startTime) {
  _serverStartTime = startTime;
}

Response healthHandler(Request request) {
  final uptime = DateTime.now().difference(_serverStartTime).inSeconds;
  return Response.ok(
    '{"status": "ok", "version": "1.0.0", "uptime": $uptime}',
    headers: {'content-type': 'application/json'},
  );
}
