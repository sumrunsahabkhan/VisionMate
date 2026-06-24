import '../../../core/services/connectivity_service.dart';
import 'assistant_remote_service.dart';

class AssistantRepository {
  final AssistantRemoteService _remoteService;
  final ConnectivityService _connectivityService;

  AssistantRepository(this._remoteService, this._connectivityService);

  Future<AssistantResponse> getAssistantResponse(String text, {
    String type = "ai", 
    String? city, 
    String? country
  }) async {
    // 🔥 Connectivity check moved to Repository layer
    // This is more professional as the data layer decides if it can fetch data
    return _remoteService.askAI(text, type: type, city: city, country: country);
  }
}
