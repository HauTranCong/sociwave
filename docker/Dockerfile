# ===================================
# Multi-stage Dockerfile for SociWave
# Flutter Web Application
# ===================================

# Stage 1: Build the Flutter web app
FROM ghcr.io/cirruslabs/flutter:stable AS build

ARG API_BASE_URL="http://127.0.0.1:8000/api"
ENV API_BASE_URL=${API_BASE_URL}

# Set working directory
WORKDIR /app

# Copy pubspec files first for better caching
COPY webapp/pubspec.yaml webapp/pubspec.lock ./

# Get dependencies
RUN flutter pub get

# Copy the rest of the Flutter app
COPY webapp/ .

# Build the optimized web app with tree-shaking. Inject API URL so the bundle
# knows how to reach the backend when deployed.
RUN flutter build web --release --tree-shake-icons --dart-define=API_BASE_URL=$API_BASE_URL

# Remove unnecessary files to reduce image size
RUN cd build/web && \
    rm -rf .dart_tool .packages

# Stage 2: Serve with Nginx
FROM nginx:alpine

# Install curl for healthcheck
RUN apk add --no-cache curl

# Copy the built web app to Nginx
COPY --from=build /app/build/web /usr/share/nginx/html

# Copy custom Nginx configuration
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf

# Create nginx cache directory
RUN mkdir -p /var/cache/nginx

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/index.html || exit 1

# Expose port 80
EXPOSE 80

# Run Nginx in foreground
CMD ["nginx", "-g", "daemon off;"]
