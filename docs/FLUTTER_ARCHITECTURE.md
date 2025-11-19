# Flutter Application Architecture Design

## Overview
This document outlines the architecture for the Flutter version of the CommentReplier application, designed to provide cross-platform support (mobile, desktop, web) with modern Flutter best practices.

## Design Principles

1. **Clean Architecture**: Separation of concerns with clear boundaries
2. **Reactive State Management**: Provider/Riverpod for predictable state
3. **Platform Adaptive**: Works on Android, iOS, Web, Desktop
4. **Offline-First**: Local data persistence with sync
5. **Material Design 3**: Modern, consistent UI/UX

## Architecture Layers

### 1. Presentation Layer (UI)
**Location**: `lib/presentation/`

#### Screens
- **Splash Screen** (`screens/splash_screen.dart`)
  - App initialization
  - Check authentication
  - Load cached data

- **Dashboard Screen** (`screens/dashboard_screen.dart`)
  - List of video reels/posts
  - Rule status indicators
  - Quick actions (toggle, configure)
  - Pull-to-refresh
  - Search/filter functionality

- **Settings Screen** (`screens/settings_screen.dart`)
  - API configuration
  - App preferences
  - Theme settings
  - About section

- **Rule Editor Screen** (`screens/rule_editor_screen.dart`)
  - Keyword input (chips)
  - Reply message editor
  - Preview functionality
  - Save/cancel actions

- **Comments Screen** (`screens/comments_screen.dart`)
  - Comment list
  - Manual reply interface
  - Comment metadata
  - Reply history

- **Login Screen** (`screens/login_screen.dart`)
  - API token input
  - Validation
  - Save credentials

#### Widgets
- **Reusable Components** (`widgets/`)
  - `reel_card.dart` - Display individual reel
  - `comment_card.dart` - Comment display
  - `rule_status_indicator.dart` - Active/inactive badge
  - `loading_shimmer.dart` - Loading placeholder
  - `error_view.dart` - Error state display
  - `empty_state.dart` - Empty list display
  - `custom_app_bar.dart` - Consistent app bar
  - `action_button.dart` - Common button styles

### 2. Business Logic Layer
**Location**: `lib/providers/` (using Provider/Riverpod)

#### State Providers

**ConfigProvider** (`providers/config_provider.dart`)
- Manages API configuration
- Persists settings
- Validates credentials
- Notifies UI of changes

**ReelsProvider** (`providers/reels_provider.dart`)
- Fetches reels from API
- Caches reel data
- Manages loading/error states
- Implements pagination

**RulesProvider** (`providers/rules_provider.dart`)
- CRUD operations for rules
- Rule validation
- Sync with local storage
- Batch operations

**CommentsProvider** (`providers/comments_provider.dart`)
- Fetch comments per reel
- Manual reply functionality
- Comment filtering
- Track replied comments

**MonitorProvider** (`providers/monitor_provider.dart`)
- Background monitoring status
- Start/stop monitoring
- Monitor statistics
- Real-time updates

**ThemeProvider** (`providers/theme_provider.dart`)
- Dark/light mode toggle
- Color scheme customization
- Persistence

### 3. Domain Layer
**Location**: `lib/domain/`

#### Models (`models/`)

**Config Model** (`config.dart`)
```dart
class Config {
  final String token;
  final String version;
  final String pageId;
  final bool useMockData;
  
  Config({
    required this.token,
    required this.version,
    required this.pageId,
    this.useMockData = false,
  });
  
  factory Config.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
  Config copyWith({...});
}
```

**Reel Model** (`reel.dart`)
```dart
class Reel {
  final String id;
  final String? description;
  final DateTime updatedTime;
  final bool hasRule;
  final bool ruleEnabled;
  
  Reel({
    required this.id,
    this.description,
    required this.updatedTime,
    this.hasRule = false,
    this.ruleEnabled = false,
  });
  
  factory Reel.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}
```

**Rule Model** (`rule.dart`)
```dart
class Rule {
  final String objectId;
  final List<String> matchWords;
  final String replyMessage;
  final String? inboxMessage;
  final bool enabled;
  
  Rule({
    required this.objectId,
    required this.matchWords,
    required this.replyMessage,
    this.inboxMessage,
    this.enabled = false,
  });
  
  factory Rule.fromJson(String objectId, Map<String, dynamic> json);
  Map<String, dynamic> toJson();
  bool matches(String commentText);
}
```

**Comment Model** (`comment.dart`)
```dart
class Comment {
  final String id;
  final String message;
  final CommentAuthor from;
  final DateTime createdTime;
  final DateTime? updatedTime;
  final bool hasReplied;
  
  Comment({
    required this.id,
    required this.message,
    required this.from,
    required this.createdTime,
    this.updatedTime,
    this.hasReplied = false,
  });
  
  factory Comment.fromJson(Map<String, dynamic> json);
}

class CommentAuthor {
  final String id;
  final String name;
  
  CommentAuthor({required this.id, required this.name});
  factory CommentAuthor.fromJson(Map<String, dynamic> json);
}
```

**Monitor Status Model** (`monitor_status.dart`)
```dart
class MonitorStatus {
  final bool isRunning;
  final DateTime? lastCheck;
  final int totalChecks;
  final int totalReplies;
  final String? lastError;
  
  MonitorStatus({
    this.isRunning = false,
    this.lastCheck,
    this.totalChecks = 0,
    this.totalReplies = 0,
    this.lastError,
  });
}
```

#### Repositories (`repositories/`)

**ConfigRepository** (`config_repository.dart`)
- Abstract interface for config operations
- Implementation: Local storage (shared_preferences)

**ReelRepository** (`reel_repository.dart`)
- Abstract interface for reel operations
- Implementation: API + local cache

**RuleRepository** (`rule_repository.dart`)
- Abstract interface for rule operations
- Implementation: Local JSON storage

**CommentRepository** (`comment_repository.dart`)
- Abstract interface for comment operations
- Implementation: API with caching

### 4. Data Layer
**Location**: `lib/data/`

#### Services

**Facebook API Service** (`services/facebook_api_service.dart`)
- HTTP client configuration (using `dio` package)
- API endpoints implementation
- Error handling and retry logic
- Request/response interceptors
- Mock mode support

```dart
class FacebookApiService {
  final Dio _dio;
  final Config config;
  
  Future<UserInfo> getUserInfo();
  Future<List<Reel>> getReels({int limit = 25});
  Future<List<Comment>> getComments(String objectId);
  Future<void> replyToComment(String commentId, String message);
  Future<void> sendPrivateMessage(String userId, String message);
}
```

**Storage Service** (`services/storage_service.dart`)
- Local data persistence
- JSON file operations
- SharedPreferences wrapper
- Secure storage for tokens

```dart
class StorageService {
  Future<void> saveConfig(Config config);
  Future<Config?> loadConfig();
  Future<void> saveRules(Map<String, Rule> rules);
  Future<Map<String, Rule>> loadRules();
  Future<void> saveRepliedComments(Set<String> commentIds);
  Future<Set<String>> loadRepliedComments();
  Future<void> cacheReels(List<Reel> reels);
  Future<List<Reel>?> loadCachedReels();
}
```

**Background Service** (`services/background_service.dart`)
- Platform-specific background execution
- Android: WorkManager
- iOS: Background Fetch
- Desktop: Isolate-based timer
- Comment monitoring logic
- Notification support

```dart
class BackgroundMonitorService {
  static const Duration pollInterval = Duration(minutes: 1);
  
  Future<void> initialize();
  Future<void> startMonitoring();
  Future<void> stopMonitoring();
  Future<void> performMonitorCycle();
  Stream<MonitorStatus> get statusStream;
}
```

**Notification Service** (`services/notification_service.dart`)
- Local notifications for new comments
- Reply success notifications
- Error notifications

### 5. Core Layer
**Location**: `lib/core/`

#### Constants (`constants/`)
- `app_constants.dart` - App-wide constants
- `api_constants.dart` - API endpoints, versions
- `storage_keys.dart` - Storage key names
- `theme_constants.dart` - Colors, text styles

#### Utils (`utils/`)
- `date_formatter.dart` - Date/time formatting
- `validators.dart` - Input validation
- `logger.dart` - Logging utility
- `error_handler.dart` - Global error handling

#### Extensions (`extensions/`)
- `string_extensions.dart` - String helpers
- `datetime_extensions.dart` - DateTime helpers
- `build_context_extensions.dart` - Context helpers

## Navigation Structure

Using **go_router** for declarative routing:

```dart
GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => LoginScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => DashboardScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => SettingsScreen(),
    ),
    GoRoute(
      path: '/reel/:id/rule',
      builder: (context, state) => RuleEditorScreen(
        reelId: state.params['id']!,
      ),
    ),
    GoRoute(
      path: '/reel/:id/comments',
      builder: (context, state) => CommentsScreen(
        reelId: state.params['id']!,
      ),
    ),
  ],
);
```

## State Management Flow

Using **Provider** pattern:

1. **UI Event** → User interacts with widget
2. **Provider Method Call** → Widget calls provider method
3. **Business Logic** → Provider executes logic
4. **Repository Call** → Provider uses repository
5. **Data Layer** → Repository calls API/storage
6. **State Update** → Provider notifies listeners
7. **UI Rebuild** → Widget rebuilds with new state

## Data Flow

### Fetching Reels
```
UI Request → ReelsProvider.fetchReels()
  → ReelRepository.getReels()
    → Check cache (StorageService)
    → If expired: FacebookApiService.getReels()
    → Update cache
    → Return reels
  → Update provider state
→ UI rebuilds with reels
```

### Background Monitoring
```
BackgroundService (timer/WorkManager)
  → Load rules (RuleRepository)
  → For each enabled rule:
    → Fetch comments (CommentRepository)
    → Filter unreplied
    → Match against keywords
    → Post reply (FacebookApiService)
    → Save replied ID (StorageService)
    → Send notification
  → Update monitor status
```

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── app.dart                     # App widget configuration
│
├── core/                        # Core utilities
│   ├── constants/
│   │   ├── app_constants.dart
│   │   ├── api_constants.dart
│   │   └── storage_keys.dart
│   ├── utils/
│   │   ├── logger.dart
│   │   ├── validators.dart
│   │   └── error_handler.dart
│   └── extensions/
│       └── string_extensions.dart
│
├── data/                        # Data layer
│   ├── services/
│   │   ├── facebook_api_service.dart
│   │   ├── storage_service.dart
│   │   ├── background_service.dart
│   │   └── notification_service.dart
│   └── datasources/
│       ├── local/
│       │   └── local_storage_datasource.dart
│       └── remote/
│           └── facebook_api_datasource.dart
│
├── domain/                      # Domain layer
│   ├── models/
│   │   ├── config.dart
│   │   ├── reel.dart
│   │   ├── rule.dart
│   │   ├── comment.dart
│   │   └── monitor_status.dart
│   └── repositories/
│       ├── config_repository.dart
│       ├── reel_repository.dart
│       ├── rule_repository.dart
│       └── comment_repository.dart
│
├── providers/                   # State management
│   ├── config_provider.dart
│   ├── reels_provider.dart
│   ├── rules_provider.dart
│   ├── comments_provider.dart
│   ├── monitor_provider.dart
│   └── theme_provider.dart
│
└── presentation/                # UI layer
    ├── screens/
    │   ├── splash_screen.dart
    │   ├── login_screen.dart
    │   ├── dashboard_screen.dart
    │   ├── settings_screen.dart
    │   ├── rule_editor_screen.dart
    │   └── comments_screen.dart
    └── widgets/
        ├── reel_card.dart
        ├── comment_card.dart
        ├── rule_status_indicator.dart
        ├── loading_shimmer.dart
        ├── error_view.dart
        └── empty_state.dart
```

## Key Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  provider: ^6.0.0
  
  # Navigation
  go_router: ^13.0.0
  
  # Network
  dio: ^5.4.0
  
  # Local Storage
  shared_preferences: ^2.2.0
  flutter_secure_storage: ^9.0.0
  path_provider: ^2.1.0
  
  # Background Processing
  workmanager: ^0.5.0  # Android
  
  # Notifications
  flutter_local_notifications: ^16.0.0
  
  # JSON
  json_annotation: ^4.8.0
  
  # Utilities
  intl: ^0.19.0  # Date formatting
  uuid: ^4.0.0
  logger: ^2.0.0

dev_dependencies:
  # Code Generation
  json_serializable: ^6.7.0
  build_runner: ^2.4.0
  
  # Testing
  flutter_test:
    sdk: flutter
  mockito: ^5.4.0
  
  # Linting
  flutter_lints: ^3.0.0
```

## Platform-Specific Considerations

### Android
- WorkManager for background tasks
- Notification channels
- Permission handling

### iOS
- Background Fetch API
- Notification permissions
- App Store guidelines for background execution

### Desktop (Windows/macOS/Linux)
- Isolate-based background processing
- System tray integration
- Auto-start option

### Web
- Web workers for background tasks
- Progressive Web App (PWA) support
- Browser notifications

## Testing Strategy

### Unit Tests
- Model serialization/deserialization
- Business logic in providers
- Utility functions

### Widget Tests
- Individual widget behavior
- User interactions
- State changes

### Integration Tests
- Complete user flows
- API integration
- Background service

## Performance Optimization

1. **Lazy Loading**: Load reels in batches
2. **Image Caching**: Cache profile images
3. **Debouncing**: Search input debouncing
4. **Memoization**: Cache computed values
5. **Background Isolates**: Heavy processing off main thread

## Security Considerations

1. **Token Storage**: Use flutter_secure_storage for API tokens
2. **SSL Pinning**: Secure API communication
3. **Input Validation**: Sanitize all user inputs
4. **Rate Limiting**: Respect Facebook API limits
5. **Error Messages**: Don't expose sensitive information

## Accessibility

1. **Semantic Labels**: All interactive elements
2. **Screen Reader Support**: Proper widget descriptions
3. **Keyboard Navigation**: Desktop support
4. **Color Contrast**: WCAG AA compliance
5. **Text Scaling**: Support dynamic text sizes

## Summary

This architecture provides a solid foundation for a scalable, maintainable Flutter application that can run on all platforms while maintaining clean separation of concerns and following Flutter best practices.
