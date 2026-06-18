/// Formats a duration stored as decimal minutes (e.g. 3.5 → "3:30") as M:SS.
String formatDurationMinutes(double minutes) {
  final whole = minutes.floor();
  final seconds = ((minutes * 60) % 60).floor().toString().padLeft(2, '0');
  return '$whole:$seconds';
}
