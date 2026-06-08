#!/bin/bash
# Local runner helper for LociHub.
# Automatically injects ~/.env for Gemini API Key configuration.

echo "🚀 Running LociHub with local .env file..."
flutter run --dart-define-from-file=/home/thehans.han/.env "$@"
