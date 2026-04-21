import '../data/assistant_remote_service.dart';

class OnlineIntentLogic {
  static Future<String> execute(String query, String type, String? city, String? country, AssistantRemoteService service) async {
    try {
      final response = await service.askAI(query, type: type, city: city, country: country);
      return response.text ?? "I couldn't get a response.";
    } catch (e) {
      return "Internet is not available or server is down.";
    }
  }
}
