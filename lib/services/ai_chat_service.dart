import 'dart:convert';
import 'package:http/http.dart' as http;

class AIChatService {
  // Supabase project URL and anon key (same as in main.dart)
  static const String _supabaseUrl = 'https://tdxmhtxlhekauustcwku.supabase.co';
  static const String _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRkeG1odHhsaGVrYXV1c3Rjd2t1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMzNTM0MzUsImV4cCI6MjA3ODkyOTQzNX0.UpTX0024v5XjvmtaZKt61fdmkkas7WV0lLHvL_evdxk';

  /// Send a message to the AI chatbot via Supabase Edge Function
  /// 
  /// [message] - The user's question/message
  /// [userId] - The current user's ID
  /// 
  /// Returns the AI's response text
  Future<String> sendMessage(String message, String userId) async {
    try {
      // Call the Edge Function
      final response = await http.post(
        Uri.parse('$_supabaseUrl/functions/v1/gemini-chat'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_supabaseAnonKey',
          'apikey': _supabaseAnonKey,
        },
        body: jsonEncode({
          'message': message,
          'userId': userId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return data['response'] as String;
        } else {
          throw Exception(data['error'] ?? 'Unknown error');
        }
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>?;
        throw Exception(
          errorData?['error'] ?? 'Failed to get response: ${response.statusCode}',
        );
      }
    } catch (e) {
      // Handle network errors or other exceptions
      if (e.toString().contains('SocketException') || 
          e.toString().contains('Failed host lookup')) {
        throw Exception('No internet connection. Please check your network.');
      }
      throw Exception('Error: ${e.toString()}');
    }
  }
}

