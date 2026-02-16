import 'package:sqlite3/sqlite3.dart';

class ValidationResult {
  final bool isValid;
  final int? dbVersion;
  final String? error;

  ValidationResult({required this.isValid, this.dbVersion, this.error});
}

ValidationResult validateBackup(String filePath) {
  Database? db;
  try {
    db = sqlite3.open(filePath, mode: OpenMode.readOnly);

    // Integrity check
    final checkResult = db.select('PRAGMA quick_check');
    if (checkResult.isEmpty || checkResult.first.values.first != 'ok') {
      final msg = checkResult.isNotEmpty
          ? checkResult.first.values.first.toString()
          : 'Unknown integrity error';
      return ValidationResult(isValid: false, error: 'Integrity check failed: $msg');
    }

    // Read database version
    final versionResult = db.select('PRAGMA user_version');
    final version = versionResult.isNotEmpty
        ? versionResult.first.values.first as int
        : null;

    return ValidationResult(isValid: true, dbVersion: version);
  } catch (e) {
    return ValidationResult(isValid: false, error: e.toString());
  } finally {
    db?.close();
  }
}
