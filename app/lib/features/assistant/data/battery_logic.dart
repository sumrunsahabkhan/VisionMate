import 'package:battery_plus/battery_plus.dart';

class BatteryIntentLogic {
  static Future<String> execute() async {
    final battery = Battery();
    final level = await battery.batteryLevel;
    return "Battery level is $level percent";
  }
}
