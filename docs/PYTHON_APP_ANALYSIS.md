# Python Application Analysis

## Overview
The CommentReplier is a Python desktop application built with CustomTkinter that automates Facebook comment monitoring and replies using the Facebook Graph API.

## Application Architecture

### Design Pattern
- **MVC Pattern**: Model-View-Controller architecture
  - **Model**: `facebook/api.py` - Business logic and data
  - **View**: `gui/` - User interface components
  - **Controller**: `main.py` - Application orchestration

### Core Components

#### 1. Main Application (`main.py`)
- Application entry point
- Initializes GUI and monitoring service
- Sets up logging and theme
- Manages application lifecycle

#### 2. Facebook API Layer (`facebook/api.py`)
**Class: `FacebookAPI`**
- **Responsibilities**:
  - Facebook Graph API communication
  - Configuration management
  - Mock data support for development
  
- **Key Methods**:
  - `get_user_info()` - Fetch user/page information
  - `get_posts()` - Retrieve posts
  - `get_reels()` - Retrieve video reels (with caching)
  - `get_comments(object_id)` - Get comments for specific content
  - `reply_to_comment(comment_id, message)` - Reply to a comment
  - `send_private_message(user_id, message)` - Send DM (placeholder)

- **Configuration**:
  - API token
  - API version (v18.0+)
  - Page ID
  - Mock data toggle

#### 3. Background Monitoring Service (`services/comment_monitor_service.py`)
**Class: `CommentMonitorService`**
- **Type**: Thread-based background service
- **Responsibilities**:
  - Periodic comment checking (default: 60s interval)
  - Rule-based comment matching
  - Automated reply posting
  - Tracking replied comments to avoid duplicates

- **Key Features**:
  - Runs as daemon thread
  - Graceful shutdown on app exit
  - Persistent storage of replied comments
  - Error handling and logging

- **Process Flow**:
  1. Load rules from `data/rules.json`
  2. For each enabled rule:
     - Fetch comments for the target object
     - Filter out already-replied comments
     - Match comments against keywords
     - Post automated replies
  3. Save replied comment IDs
  4. Sleep for poll interval

#### 4. GUI Components

##### Main Application Window (`gui/app.py`)
- **Layout**: 1x2 grid (navigation + content)
- **Components**:
  - Navigation sidebar
  - Content area (Dashboard or Settings)
- **Window Size**: 1200x900

##### Dashboard Frame (`gui/dashboard_frame.py`)
- **Features**:
  - User welcome message
  - Scrollable list of video reels/posts
  - Per-item controls:
    - Active/Inactive toggle switch
    - Configure button (opens rule editor)
    - View Comments button
  - Refresh button with threaded data loading
  - Status messages for errors

- **Data Display**:
  - Post/Reel message or description
  - Updated timestamp
  - Rule status indicator

##### Settings Frame (`gui/settings_frame.py`)
- **Configuration Options**:
  - Facebook Graph API Token
  - API Version
  - Page ID
  - Mock Data toggle (for development)
- **Actions**:
  - Save configuration to `data/config.json`
  - Success feedback message

##### Rule Editor Window (`gui/rule_editor_window.py`)
- **Purpose**: Configure auto-reply rules per post/reel
- **Fields**:
  - Match keywords (list of trigger words)
  - Reply message
  - Inbox message (for DM - not implemented)
  - Enable/Disable toggle

##### Comments Window (`gui/comments_window.py`)
- **Purpose**: View and manually reply to comments
- **Features**:
  - List all comments for a specific post/reel
  - Manual reply interface
  - Comment metadata (author, timestamp)

### Data Models

#### Configuration (`data/config.json`)
```json
{
  "token": "string",
  "version": "string (e.g., v24.0)",
  "page_id": "string",
  "use_mock_data": boolean
}
```

#### Rules (`data/rules.json`)
```json
{
  "object_id": {
    "match_words": ["array", "of", "keywords"],
    "reply_message": "string",
    "inbox_message": "string",
    "enabled": boolean
  }
}
```

#### Replied Comments (`data/replied_comments.json`)
```json
["comment_id_1", "comment_id_2", ...]
```

#### Video Reels Cache (`data/video_reels.json`)
```json
[
  {
    "id": "string",
    "description": "string",
    "updated_time": "string"
  }
]
```

### Key Features

1. **Automated Comment Monitoring**
   - Background thread checks for new comments periodically
   - Rule-based keyword matching
   - Automated reply posting

2. **Manual Comment Management**
   - View all comments on posts/reels
   - Manually reply to specific comments
   - Override automated replies

3. **Rule Configuration**
   - Per-post/reel rule setup
   - Keyword-based triggers
   - Custom reply messages
   - Enable/disable per rule

4. **Mock Data Support**
   - Development mode without real API calls
   - Mock API responses for testing

5. **Caching**
   - Reels data cached locally
   - Reduces API calls
   - Improves performance

### Dependencies
- `requests` - HTTP client for Facebook Graph API
- `customtkinter` - Modern UI framework for desktop
- `Pillow` - Image processing for assets
- `threading` - Background service
- `json` - Data persistence
- `logging` - Application logging

### Application Flow

1. **Startup**:
   - Load configuration
   - Initialize Facebook API client
   - Create GUI
   - Start comment monitor service

2. **Dashboard Usage**:
   - Fetch user info and reels
   - Display in scrollable list
   - User can toggle rules, configure, or view comments

3. **Settings Usage**:
   - User updates API configuration
   - Save to config.json
   - Restart required for changes to take effect

4. **Background Monitoring**:
   - Continuously runs in separate thread
   - Checks for new comments
   - Applies rules and posts replies
   - Logs activity

5. **Shutdown**:
   - Stop monitor service gracefully
   - Save replied comments
   - Close GUI

### Technical Considerations

#### Strengths
- Clear separation of concerns (MVC)
- Threaded background processing
- Persistent data storage
- Mock data for development
- Comprehensive logging

#### Limitations
- Desktop-only (no mobile)
- Single-threaded UI (can freeze during API calls)
- Limited error recovery
- No real-time updates (polling-based)
- Private messaging not implemented
- No user authentication beyond API token
- No multi-account support

#### Error Handling
- Try-catch blocks around API calls
- Logging of exceptions
- User-facing error messages in UI
- Graceful degradation with mock data

### File Structure
```
CommentReplier/
├── main.py                          # Entry point
├── requirements.txt                  # Dependencies
├── data/                             # Persistent storage
│   ├── config.json                  # API configuration
│   ├── rules.json                   # Reply rules
│   ├── replied_comments.json        # Tracking
│   └── video_reels.json             # Cache
├── facebook/                         # API layer
│   ├── api.py                       # Facebook API client
│   └── mock_api.py                  # Mock responses
├── gui/                              # UI components
│   ├── app.py                       # Main window
│   ├── dashboard_frame.py           # Dashboard view
│   ├── settings_frame.py            # Settings view
│   ├── navigation_frame.py          # Sidebar
│   ├── rule_editor_window.py        # Rule config dialog
│   └── comments_window.py           # Comments viewer
├── services/                         # Background services
│   └── comment_monitor_service.py   # Auto-reply service
└── tests/                            # Unit tests
    └── test_api.py
```

## Summary

This is a well-structured desktop application with clear separation of concerns, background processing capabilities, and a user-friendly interface. The main limitations are its desktop-only nature and lack of mobile support, which Flutter will address perfectly.
