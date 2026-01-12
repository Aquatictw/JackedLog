#!/usr/bin/env pwsh
# Tight formatting script for JackedLog (PowerShell)
# Formats the entire codebase with consistent style

Write-Host "Formatting Dart code with line length 80..." -ForegroundColor Cyan
dart format --line-length 80 lib test

Write-Host "Fixing lint issues..." -ForegroundColor Cyan
dart fix .\lib\ --apply

Write-Host "Formatting complete!" -ForegroundColor Green
Write-Host "Run 'dart analyze lib' to verify no issues remain." -ForegroundColor Yellow
