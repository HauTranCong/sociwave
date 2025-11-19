# SociWave - Python to Flutter Refactoring

> 🎯 **Status**: Analysis & Planning Complete | Ready for Implementation

A cross-platform Flutter application for automated social media comment management, refactored from the CommentReplier Python desktop application.

## Project Structure

```
sociwave/
├── app/              # Flutter application source code
├── docker/           # Docker configuration files
├── docs/             # Documentation
├── scripts/          # Build and deployment scripts
└── README.md         # This file
```

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Dart SDK
- Docker (for containerization)

### Running the App

```bash
cd app
flutter pub get
flutter run
```

### Running Tests

```bash
cd app
flutter test
```

### Building for Production

```bash
cd app
flutter build apk          # For Android
flutter build web          # For Web
flutter build ios          # For iOS (requires macOS)
```

## Docker

Docker configuration files are located in the `docker/` directory.

## Documentation

Additional documentation can be found in the `docs/` directory.

## License

TBD
