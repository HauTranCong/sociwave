#!/bin/bash

# Build script for Sociwave Flutter app

set -e

echo "🚀 Building Sociwave..."

# Navigate to app directory
cd "$(dirname "$0")/../app"

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Run tests
echo "🧪 Running tests..."
flutter test

# Build for web
echo "🌐 Building web version..."
flutter build web --release

# Build for Android (optional)
# echo "📱 Building Android APK..."
# flutter build apk --release

echo "✅ Build complete!"
