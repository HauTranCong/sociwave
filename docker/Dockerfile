# Multi-stage Dockerfile for Flutter Web Application

# Stage 1: Build the Flutter web app
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Copy the Flutter app
COPY app/ .

# Get dependencies
RUN flutter pub get

# Build the web app
RUN flutter build web --release

# Stage 2: Serve with Nginx
FROM nginx:alpine

# Copy the built web app to Nginx
COPY --from=build /app/build/web /usr/share/nginx/html

# Copy custom Nginx configuration (optional)
# COPY docker/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
