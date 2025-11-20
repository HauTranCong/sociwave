/// Facebook Graph API constants
class ApiConstants {
  // Base URL
  static const String baseUrl = 'https://graph.facebook.com';
  
  // Default API Version
  static const String defaultVersion = 'v24.0';
  
  // Supported API Versions
  static const List<String> supportedVersions = [
    'v24.0',
    'v23.0',
    'v22.0',
    'v21.0',
    'v20.0',
    'v19.0',
    'v18.0',
  ];
  
  // Endpoints
  static const String userInfoEndpoint = 'me';
  static const String postsEndpoint = 'posts';
  static const String reelsEndpoint = 'video_reels';
  static const String commentsEndpoint = 'comments';
  
  // Query Parameters
  static const String accessTokenParam = 'access_token';
  static const String fieldsParam = 'fields';
  static const String limitParam = 'limit';
  static const String afterParam = 'after';
  static const String messageParam = 'message';
  
  // Field Names
  static const String idField = 'id';
  static const String nameField = 'name';
  static const String messageField = 'message';
  static const String descriptionField = 'description';
  static const String createdTimeField = 'created_time';
  static const String updatedTimeField = 'updated_time';
  static const String fromField = 'from';
  
  // Reel Fields
  static const String reelFields = 'id,description,updated_time';
  
  // Comment Fields
  static const String commentFields = 'id,message,from,created_time,updated_time';
  
  // User Fields
  static const String userFields = 'id,name';
  
  // Error Codes
  static const int unauthorizedError = 401;
  static const int forbiddenError = 403;
  static const int notFoundError = 404;
  static const int rateLimitError = 429;
  static const int serverError = 500;
  
  // Rate Limiting
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  
  // Default Values
  static const String defaultPageId = 'me';
}
