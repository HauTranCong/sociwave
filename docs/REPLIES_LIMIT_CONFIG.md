# Configurable Replies Limit

## Overview
Added configuration option to control how many nested replies (comments on comments) are fetched from Facebook API per comment.

## What Changed

### 1. **Config Model** (`lib/domain/models/config.dart`)
Added new field:
```dart
/// Maximum number of replies to fetch per comment (1-100)
@JsonKey(name: 'replies_limit', defaultValue: 100)
final int repliesLimit;
```

**Default Value**: 100 replies per comment

### 2. **Facebook API Service** (`lib/data/services/facebook_api_service.dart`)
Added dynamic field builder:
```dart
/// Build comment fields with dynamic replies limit
String _buildCommentFields() {
  return 'id,message,from,created_time,updated_time,comments.limit(${config.repliesLimit}).summary(true){id,message,from,created_time}';
}
```

This dynamically constructs the API fields parameter using the configured limit.

### 3. **Settings Screen** (`lib/screens/settings_screen.dart`)
Added UI field for user configuration:
- **Field**: "Replies Limit"
- **Icon**: Reply icon
- **Range**: 1-100
- **Default**: 100
- **Help Text**: "Number of replies to fetch per comment (default: 100)"

## Usage

### For Users:
1. Open the app
2. Go to **Settings**
3. Scroll to **API Request Limits** section
4. Set **Replies Limit** to your desired value (1-100)
5. Click **Save Configuration**

### Examples:
- **Set to 10**: Each comment will show up to 10 nested replies
- **Set to 50**: Each comment will show up to 50 nested replies
- **Set to 100**: Each comment will show up to 100 nested replies (maximum)

## Benefits

### Performance Control
- **Lower Values (10-20)**: Faster API responses, less data transferred
- **Higher Values (50-100)**: More complete data, but slower responses

### Use Cases
1. **High Activity Posts**: Set lower limit (10-20) for posts with many replies
2. **Normal Posts**: Keep default (100) for complete data
3. **Limited Bandwidth**: Lower value reduces data usage
4. **Testing**: Adjust to test with different amounts of data

## Technical Details

### Facebook API Request Format
```
/{comment-id}?fields=id,message,from,created_time,updated_time,comments.limit(100).summary(true){id,message,from,created_time}
```

The `comments.limit(X)` parameter controls how many nested replies are returned.

### Flattening Behavior
All replies are flattened into the main comments list:
- Parent comments are displayed
- Nested replies are displayed as separate items
- Total count includes both parent comments and replies

### Data Structure
```
Comment
├── id
├── message
├── from
├── created_time
├── updated_time
└── replies: List<Comment>  // Nested replies (parsed but flattened for display)
```

## Configuration File
When saved, the setting is stored in:
- **Location**: `~/.local/share/sociwave/config.json`
- **Key**: `replies_limit`
- **Format**: JSON integer

Example:
```json
{
  "token": "...",
  "version": "v24.0",
  "page_id": "...",
  "reels_limit": 25,
  "comments_limit": 100,
  "replies_limit": 50
}
```

## Recommendations

### Optimal Settings by Scenario:

**Scenario 1: Active Community**
- Comments Limit: 100
- Replies Limit: 20
- Rationale: Many comments, moderate replies per comment

**Scenario 2: Discussion-Heavy**
- Comments Limit: 50
- Replies Limit: 100
- Rationale: Fewer comments but deep discussions

**Scenario 3: Performance Priority**
- Comments Limit: 50
- Replies Limit: 10
- Rationale: Fast loading, reduced API usage

**Scenario 4: Complete Data**
- Comments Limit: 100
- Replies Limit: 100
- Rationale: Fetch everything (default)

## Notes
- Facebook API enforces a maximum of 100 for limit parameters
- Setting too high may cause slower API responses
- The app filters out comments/replies from deleted users automatically
- Changes take effect immediately after saving configuration
