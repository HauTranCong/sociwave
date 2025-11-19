#!/bin/bash

# Docker build script for Sociwave

set -e

echo "🐳 Building Docker image..."

# Navigate to project root
cd "$(dirname "$0")/.."

# Build the Docker image
docker build -f docker/Dockerfile -t sociwave:latest .

echo "✅ Docker image built successfully!"
echo "Run with: docker-compose -f docker/docker-compose.yml up"
