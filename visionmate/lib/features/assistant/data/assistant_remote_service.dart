import 'dart:convert';
import 'package:http/http.dart' as http;

class AssistantRemoteService {
  // Using the live Render URL for production
  static const String _baseUrl = "https://visionmate-api.onrender.com/assistant"; 

  Future<AssistantResponse> askAI(String text, {String type = "ai", String? city, String? country}) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "text": text,
          "type": type,
          "city": city,
          "country": country,
        }),
      ).timeout(const Duration(seconds: 60)); // Increased timeout as Render free tier can take time to wake up

      if (response.statusCode == 200) {
        if (response.headers['content-type']?.contains('audio/mpeg') ?? false) {
          final replyText = Uri.decodeComponent(response.headers['x-reply-text'] ?? "");
          return AssistantResponse(text: replyText, audioBytes: response.bodyBytes, isAudio: true);
        }
        final data = jsonDecode(response.body);
        return AssistantResponse(text: data['text'], isAudio: false);
      }
      throw Exception("Server returned status code ${response.statusCode}");
    } catch (e) {
      print("💥 Assistant Remote Service Error: $e");
      rethrow;
    }
  }
}

class AssistantResponse {
  final String? text;
  final List<int>? audioBytes;
  final bool isAudio;
  AssistantResponse({this.text, this.audioBytes, this.isAudio = false});
}
