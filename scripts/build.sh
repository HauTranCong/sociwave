#!/bin/bash

# Build script for Sociwave Flutter app and Backend

set -e

echo "🚀 Starting Sociwave full build..."

# --- Flutter Web App Build ---
echo "--- Building Flutter Web App ---"
# Navigate to webapp directory
cd "$(dirname "$0")/../webapp"

# Get dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Run tests (optional, can be enabled if you have a solid test suite)
# echo "🧪 Running Flutter tests..."
# flutter test

# Build for web
echo "🌐 Building web release..."
flutter build web --release
echo "✅ Flutter Web App build complete."
echo "--------------------------------"


# --- Backend Build (Placeholder) ---
# For a Python/FastAPI backend, there isn't a traditional "build" step like with compiled languages.
# The process is more about ensuring dependencies are installed and the environment is ready.
# This section is a placeholder for any backend build-related tasks you might add,
# such as generating documentation or running linters.
echo "--- Preparing Backend ---"
echo "📦 Checking/installing Python dependencies..."
# Assuming your virtual environment is at backend/.venv
# This command will install dependencies if they are not already present.
python3 -m venv ../backend/.venv
source ../backend/.venv/bin/activate
pip install -r ../backend/requirements.txt
echo "✅ Backend dependencies are up to date."
echo "--------------------------"

echo "🎉 Sociwave full build process finished."
