#!/bin/bash

# Docker build script for Sociwave Full-Stack Application

set -e

echo "🐳 Building Sociwave Docker services..."

# Navigate to project root
cd "$(dirname "$0")/.."

# Use Docker Compose to build the images for all services defined
# in the docker-compose.yml file.
# The --no-cache option ensures a fresh build.
echo "Building 'sociwave-frontend' and 'sociwave-backend' images..."
docker-compose -f docker/docker-compose.yml build --no-cache

echo "✅ Docker images built successfully!"
echo "To run the application, use: docker-compose -f docker/docker-compose.yml up"
echo "To run in detached mode, use: docker-compose -f docker/docker-compose.yml up -d"
