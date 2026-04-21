import 'package:battery_plus/battery_plus.dart';

class BatteryService {
  final Battery _battery = Battery();

  Future<int> get batteryLevel => _battery.batteryLevel;
  
  Stream<BatteryState> get onBatteryStateChanged => _battery.onBatteryStateChanged;

  Future<bool> isCharging() async {
    final state = await _battery.batteryState;
    return state == BatteryState.charging;
  }
}
