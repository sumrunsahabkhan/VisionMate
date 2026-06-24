import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<Map<Permission, PermissionStatus>> requestAssistantPermissions() async {
    return await [
      Permission.microphone,
      Permission.location,
      Permission.phone,
      Permission.camera,
      Permission.notification,
    ].request();
  }

  Future<bool> hasMicrophonePermission() async {
    return await Permission.microphone.isGranted;
  }
}
