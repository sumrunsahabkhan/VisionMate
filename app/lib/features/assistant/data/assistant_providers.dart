import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'assistant_remote_service.dart';
import 'assistant_repository.dart';
import '../domain/walkthrough_usecase.dart';
import '../domain/handle_intent_usecase.dart';
import '../../emergency/domain/emergency_setup_usecase.dart';
import '../../emergency/domain/emergency_usecase.dart';
import '../../settings/domain/settings_usecase.dart';
import '../../../core/services/service_providers.dart';
import '../../settings/data/settings_repository.dart';

final assistantRemoteServiceProvider = Provider((ref) => AssistantRemoteService());

final assistantRepositoryProvider = Provider((ref) {
  final remoteService = ref.watch(assistantRemoteServiceProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  return AssistantRepository(remoteService, connectivity);
});

final walkthroughUseCaseProvider = Provider((ref) => WalkthroughUseCase());

final emergencyUseCaseProvider = Provider((ref) {
  final tts = ref.watch(ttsServiceProvider);
  final settingsRepo = ref.watch(settingsRepositoryProvider.notifier);
  return EmergencyUseCase(tts, settingsRepo);
});

final emergencySetupUseCaseProvider = Provider((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider.notifier);
  return EmergencySetupUseCase(settingsRepo);
});

final handleIntentUseCaseProvider = Provider((ref) {
  final timeDateService = ref.watch(timeDateServiceProvider);
  final batteryService = ref.watch(batteryServiceProvider);
  return HandleIntentUseCase(timeDateService, batteryService);
});

final settingsUseCaseProvider = Provider((ref) => SettingsUseCase());
