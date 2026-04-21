import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tts_service.dart';
import 'vosk_service.dart';
import 'connectivity_service.dart';
import 'battery_service.dart';
import 'location_service.dart';
import 'permission_service.dart';
import 'time_date_service.dart';
import 'camera_service.dart';
import 'object_detection_service.dart';

final ttsServiceProvider = Provider((ref) => TtsService());
final voskServiceProvider = Provider((ref) => VoskService());
final batteryServiceProvider = Provider((ref) => BatteryService());
final locationServiceProvider = Provider((ref) => LocationService());
final permissionServiceProvider = Provider((ref) => PermissionService());
final timeDateServiceProvider = Provider((ref) => TimeDateService());
final connectivityServiceProvider = Provider((ref) => ConnectivityService());
final objectDetectionServiceProvider = Provider((ref) => ObjectDetectionService());

final cameraServiceProvider = Provider((ref) {
  final tts = ref.read(ttsServiceProvider);
  return CameraService(tts);
});
