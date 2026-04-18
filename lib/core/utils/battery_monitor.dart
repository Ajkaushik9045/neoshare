import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:rxdart/rxdart.dart';

/// Represents the battery warning state for the UI.
enum BatteryWarningState {
  /// No warning — battery is fine.
  none,

  /// Device is in Low Power / Battery Saver mode.
  lowPowerMode,

  /// Battery level is at or below 15% and Low Power Mode is not active.
  lowBattery,
}

/// Monitors device battery state and emits [BatteryWarningState] changes.
///
/// - Emits [BatteryWarningState.lowPowerMode] when the OS battery saver is on.
/// - Emits [BatteryWarningState.lowBattery] when level ≤ 15% and saver is off.
/// - Emits [BatteryWarningState.none] otherwise.
class BatteryMonitor {
  BatteryMonitor({Battery? battery}) : _battery = battery ?? Battery();

  final Battery _battery;

  static const int _lowBatteryThreshold = 15;

  Stream<BatteryWarningState>? _warningStream;

  /// A broadcast stream of [BatteryWarningState].
  ///
  /// Evaluates state on every battery state change event and emits only
  /// distinct consecutive values.
  Stream<BatteryWarningState> get warningStream {
    _warningStream ??= _battery.onBatteryStateChanged
        .asyncMap((_) => _evaluate())
        .startWith(BatteryWarningState.none)
        .asyncMap((_) => _evaluate()) // evaluate immediately on subscribe
        .distinct()
        .asBroadcastStream();
    return _warningStream!;
  }

  Future<BatteryWarningState> _evaluate() async {
    final isInSaveMode = await _battery.isInBatterySaveMode;
    if (isInSaveMode) return BatteryWarningState.lowPowerMode;

    final level = await _battery.batteryLevel;
    if (level <= _lowBatteryThreshold) return BatteryWarningState.lowBattery;

    return BatteryWarningState.none;
  }
}
