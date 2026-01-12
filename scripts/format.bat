@echo off
REM Tight formatting script for JackedLog (Windows batch)
REM Formats the entire codebase with consistent style

echo Formatting Dart code with line length 80...
dart format --line-length 80 lib test

echo Fixing lint issues...
dart fix .\lib\ --apply

echo Formatting complete!
echo Run 'dart analyze lib' to verify no issues remain.
