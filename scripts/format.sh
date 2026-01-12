#!/bin/bash
# Tight formatting script for JackedLog
# Formats the entire codebase with consistent style

echo "Formatting Dart code with line length 80..."
dart format --line-length 80 --set-exit-if-changed lib/ test/

echo "Fixing lint issues..."
dart fix ./lib/ --apply

echo "Organizing imports..."
# Note: dart format already organizes imports

echo "Formatting complete!"
echo "Run 'dart analyze lib/' to verify no issues remain."
