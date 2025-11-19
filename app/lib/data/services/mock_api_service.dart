import '../../core/utils/logger.dart';
import '../../domain/models/reel.dart';
import '../../domain/models/comment.dart';

/// Mock API service for development and testing
/// 
/// Corresponds to Python's mock_api.py
class MockApiService {
  /// Simulate network delay
  Future<void> _delay([Duration duration = const Duration(milliseconds: 500)]) {
    return Future.delayed(duration);
  }

  /// Get mock user info
  Future<Map<String, dynamic>> getUserInfo() async {
    await _delay();
    AppLogger.info('[MOCK] Fetching user info');
    
    return {
      'id': '123456789',
      'name': 'Test Page',
    };
  }

  /// Get mock reels
  Future<List<Reel>> getReels({int limit = 25}) async {
    await _delay();
    AppLogger.info('[MOCK] Fetching reels');
    
    final now = DateTime.now();
    return [
      Reel(
        id: '1001',
        description: 'Welcome to our community! Check out this amazing video.',
        updatedTime: now.subtract(const Duration(hours: 2)),
      ),
      Reel(
        id: '1002',
        description: 'Behind the scenes of our latest project.',
        updatedTime: now.subtract(const Duration(hours: 5)),
      ),
      Reel(
        id: '1003',
        description: 'Quick tutorial on how to use our product.',
        updatedTime: now.subtract(const Duration(days: 1)),
      ),
      Reel(
        id: '1004',
        description: 'Customer success story - hear from our users!',
        updatedTime: now.subtract(const Duration(days: 2)),
      ),
      Reel(
        id: '1005',
        description: null, // Test null description
        updatedTime: now.subtract(const Duration(days: 3)),
      ),
    ];
  }

  /// Get mock comments for an object
  Future<List<Comment>> getComments(String objectId, {int limit = 100}) async {
    await _delay();
    AppLogger.info('[MOCK] Fetching comments for $objectId');
    
    final now = DateTime.now();
    
    // Return different comments based on object ID
    switch (objectId) {
      case '1001':
        return [
          Comment(
            id: 'c1001',
            message: 'Great content! Keep it up!',
            from: const CommentAuthor(id: 'u1', name: 'John Doe'),
            createdTime: now.subtract(const Duration(minutes: 30)),
          ),
          Comment(
            id: 'c1002',
            message: 'Love this!',
            from: const CommentAuthor(id: 'u2', name: 'Jane Smith'),
            createdTime: now.subtract(const Duration(hours: 1)),
          ),
          Comment(
            id: 'c1003',
            message: 'Thanks for sharing',
            from: const CommentAuthor(id: 'u3', name: 'Bob Johnson'),
            createdTime: now.subtract(const Duration(hours: 2)),
          ),
        ];
        
      case '1002':
        return [
          Comment(
            id: 'c2001',
            message: 'Amazing behind the scenes! 🎬',
            from: const CommentAuthor(id: 'u4', name: 'Alice Brown'),
            createdTime: now.subtract(const Duration(hours: 3)),
          ),
          Comment(
            id: 'c2002',
            message: 'hello world',
            from: const CommentAuthor(id: 'u5', name: 'Charlie Wilson'),
            createdTime: now.subtract(const Duration(hours: 4)),
          ),
        ];
        
      case '1003':
        return [
          Comment(
            id: 'c3001',
            message: 'Very helpful tutorial, thank you!',
            from: const CommentAuthor(id: 'u6', name: 'Diana Martinez'),
            createdTime: now.subtract(const Duration(days: 1)),
          ),
        ];
        
      default:
        return [];
    }
  }

  /// Mock reply to comment
  Future<Map<String, dynamic>> replyToComment(
    String commentId,
    String message,
  ) async {
    await _delay(const Duration(milliseconds: 300));
    AppLogger.info('[MOCK] Replying to comment $commentId: $message');
    
    return {
      'id': 'reply_${DateTime.now().millisecondsSinceEpoch}',
      'success': true,
    };
  }

  /// Get mock posts
  Future<List<Map<String, dynamic>>> getPosts({int limit = 25}) async {
    await _delay();
    AppLogger.info('[MOCK] Fetching posts');
    
    final now = DateTime.now();
    return [
      {
        'id': 'p1001',
        'message': 'Exciting news coming soon!',
        'updated_time': now.subtract(const Duration(hours: 6)).toIso8601String(),
      },
      {
        'id': 'p1002',
        'message': 'Check out our latest blog post',
        'updated_time': now.subtract(const Duration(days: 1)).toIso8601String(),
      },
    ];
  }

  /// Test connection (always succeeds for mock)
  Future<bool> testConnection() async {
    await _delay(const Duration(milliseconds: 200));
    AppLogger.info('[MOCK] Testing connection');
    return true;
  }
}
