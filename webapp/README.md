# SociWave - Flutter App

This is the Flutter application source code for SociWave.

**📚 For architecture and design details, see: [`ARCHITECTURE_DESIGN.md`](../docs/ARCHITECTURE_DESIGN.md)**

## 📁 Directory Structure

```
app/
├── lib/
│   ├── core/                     # Core utilities & constants
│   │   ├── constants/
│   │   │   ├── app_constants.dart
│   │   │   ├── api_constants.dart
│   │   │   └── storage_constants.dart
│   │   └── utils/
│   │       ├── logger.dart
│   │       ├── validators.dart
│   │       └── date_formatter.dart
│   ├── data/
│   │   ├── models/               # Data models
│   │   │   ├── comment_model.dart
│   │   │   ├── config_model.dart
│   │   │   ├── reel_model.dart
│   │   │   └── rule_model.dart
│   │   └── services/             # API & Storage
│   │       ├── facebook_api_service.dart
│   │       ├── mock_api_service.dart
│   │       └── storage_service.dart
│   ├── providers/                # State management
│   │   ├── auth_provider.dart
│   │   ├── comments_provider.dart
│   │   ├── config_provider.dart
│   │   ├── monitor_provider.dart
│   │   ├── reels_provider.dart
│   │   └── rules_provider.dart
│   ├── screens/                  # UI screens
│   │   ├── comments_screen.dart
│   │   ├── dashboard_screen.dart
│   │   ├── login_screen.dart
│   │   ├── rule_editor_screen.dart
│   │   ├── settings_screen.dart
│   │   └── splash_screen.dart
│   ├── services/                 # Background services
│   │   └── background_monitor_service.dart
│   ├── widgets/                  # Reusable components
│   │   ├── comment_card.dart
│   │   ├── empty_state.dart
│   │   ├── error_display.dart
│   │   ├── loading_indicator.dart
│   │   ├── loading_overlay.dart
│   │   ├── main_layout.dart
│   │   ├── reel_card.dart
│   │   └── stat_card.dart
│   └── main.dart                 # Web app entry point
├── test/                         # Unit tests
├── web/                          # Web-specific files
└── pubspec.yaml                  # Dependencies
```

## 🚀 Quick Commands

### Development
```bash
# Install dependencies
flutter pub get

# Run in debug mode
flutter run -d web-server --web-port 8080

# Hot reload (automatic in debug mode)
# Press 'r' to hot reload
# Press 'R' to hot restart
```

### Testing
```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Code analysis
flutter analyze
```

### Build
```bash
# Build for web (production)
flutter build web --release --tree-shake-icons

# Build with HTML renderer (smaller size)
flutter build web --release --web-renderer html

# Clean build
flutter clean && flutter pub get && flutter build web --release
```

## 📦 Dependencies

### Core
- `flutter` - Framework
- `provider` - State management
- `dio` - HTTP client
- `shared_preferences` - Local storage
- `flutter_secure_storage` - Secure token storage
- `logger` - Logging

### UI
- `flutter_svg` - SVG support
- `cached_network_image` - Image caching
- `shimmer` - Loading animations

### Dev Dependencies
- `flutter_test` - Testing framework
- `flutter_lints` - Linting rules

## 🔧 Configuration

### API Configuration
Edit `lib/core/constants/api_constants.dart`:
```dart
class ApiConstants {
  static const String baseUrl = 'https://graph.facebook.com/v21.0';
  static const int timeout = 30000;
}
```

### Web App Configuration
Edit `lib/core/constants/app_constants.dart`:
```dart
class AppConstants {
  static const String appName = 'SociWave';
  static const String appVersion = '1.0.0';
}
```

## 🐛 Debugging

### Enable Verbose Logging
```dart
// In lib/core/utils/logger.dart
final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,  // Increase for more stack trace
    errorMethodCount: 8,
    lineLength: 120,
  ),
);
```

### Check API Calls
```bash
# Run with network logging
flutter run -d chrome --web-port 8080 -v
```

## 📝 Code Style

Follow the [Flutter style guide](https://flutter.dev/docs/development/tools/formatting):

```bash
# Format code
flutter format lib/

# Analyze code
flutter analyze --no-fatal-infos
```

## 🧪 Testing Strategy

### Unit Tests
- Test business logic
- Test data models
- Test services

### Widget Tests
- Test UI components
- Test user interactions
- Test navigation

### Integration Tests
- Test complete user flows
- Test API integration

## 🔒 Security

- API tokens stored in FlutterSecureStorage
- HTTPS only for API calls
- No sensitive data in logs
- No hardcoded credentials

## 📄 License

See [LICENSE](../LICENSE) in the root directory.

## 📚 Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Provider Documentation](https://pub.dev/packages/provider)
- [Dio Documentation](https://pub.dev/packages/dio)
- [Facebook Graph API](https://developers.facebook.com/docs/graph-api)

---

For more information, see the main [README](../README.md) in the root directory.
