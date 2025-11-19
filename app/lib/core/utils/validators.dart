/// Input validators for the application
class Validators {
  /// Validates Facebook API token format
  static String? validateApiToken(String? value) {
    if (value == null || value.isEmpty) {
      return 'API token is required';
    }
    
    if (value.length < 20) {
      return 'API token seems too short';
    }
    
    return null;
  }
  
  /// Validates token (alias for validateApiToken)
  static String? validateToken(String? value) {
    return validateApiToken(value);
  }

  /// Validates API version format
  static String? validateApiVersion(String? value) {
    if (value == null || value.isEmpty) {
      return 'API version is required';
    }
    
    final versionPattern = RegExp(r'^v\d+\.\d+$');
    if (!versionPattern.hasMatch(value)) {
      return 'Invalid format. Use format like: v18.0';
    }
    
    return null;
  }

  /// Validates Page ID
  static String? validatePageId(String? value) {
    if (value == null || value.isEmpty) {
      return 'Page ID is required';
    }
    
    // 'me' is a valid special value
    if (value.toLowerCase() == 'me') {
      return null;
    }
    
    // Otherwise, should be numeric
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return 'Page ID should be numeric or "me"';
    }
    
    return null;
  }

  /// Validates reply message
  static String? validateReplyMessage(String? value) {
    if (value == null || value.isEmpty) {
      return 'Reply message is required';
    }
    
    if (value.length > 8000) {
      return 'Reply message is too long (max 8000 characters)';
    }
    
    return null;
  }

  /// Validates keyword (for rule matching)
  static String? validateKeyword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Keyword cannot be empty';
    }
    
    if (value.length > 100) {
      return 'Keyword is too long (max 100 characters)';
    }
    
    return null;
  }

  /// Validates email format
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    
    final emailPattern = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailPattern.hasMatch(value)) {
      return 'Invalid email format';
    }
    
    return null;
  }

  /// Validates URL format
  static String? validateUrl(String? value) {
    if (value == null || value.isEmpty) {
      return null; // URL is optional
    }
    
    try {
      final uri = Uri.parse(value);
      if (!uri.hasScheme || !uri.hasAuthority) {
        return 'Invalid URL format';
      }
      return null;
    } catch (e) {
      return 'Invalid URL format';
    }
  }

  /// Validates non-empty string
  static String? validateNotEmpty(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validates string length
  static String? validateLength(
    String? value,
    String fieldName, {
    int? min,
    int? max,
  }) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    
    if (min != null && value.length < min) {
      return '$fieldName must be at least $min characters';
    }
    
    if (max != null && value.length > max) {
      return '$fieldName must not exceed $max characters';
    }
    
    return null;
  }
}
