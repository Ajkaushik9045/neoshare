import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:neoshare/core/utils/battery_monitor.dart';

class MockBattery extends Mock implements Battery {}

void main() {
  late MockBattery mockBattery;
  late StreamController<BatteryState> stateController;

  setUp(() {
    mockBattery = MockBattery();
    stateController = StreamController<BatteryState>.broadcast();

    when(() => mockBattery.onBatteryStateChanged)
        .thenAnswer((_) => stateController.stream);
  });

  tearDown(() => stateController.close());

  BatteryMonitor buildMonitor() => BatteryMonitor(battery: mockBattery);

  group('BatteryMonitor', () {
    test('emits none when battery is fine', () async {
      when(() => mockBattery.isInBatterySaveMode).thenAnswer((_) async => false);
      when(() => mockBattery.batteryLevel).thenAnswer((_) async => 80);

      final monitor = buildMonitor();
      final first = await monitor.warningStream.first;

      expect(first, BatteryWarningState.none);
    });

    test('emits lowPowerMode when battery saver is on', () async {
      when(() => mockBattery.isInBatterySaveMode).thenAnswer((_) async => true);
      when(() => mockBattery.batteryLevel).thenAnswer((_) async => 80);

      final monitor = buildMonitor();
      final first = await monitor.warningStream.first;

      expect(first, BatteryWarningState.lowPowerMode);
    });

    test('emits lowBattery when level is exactly 15 and saver is off', () async {
      when(() => mockBattery.isInBatterySaveMode).thenAnswer((_) async => false);
      when(() => mockBattery.batteryLevel).thenAnswer((_) async => 15);

      final monitor = buildMonitor();
      final first = await monitor.warningStream.first;

      expect(first, BatteryWarningState.lowBattery);
    });

    test('emits lowBattery when level is below 15 and saver is off', () async {
      when(() => mockBattery.isInBatterySaveMode).thenAnswer((_) async => false);
      when(() => mockBattery.batteryLevel).thenAnswer((_) async => 5);

      final monitor = buildMonitor();
      final first = await monitor.warningStream.first;

      expect(first, BatteryWarningState.lowBattery);
    });

    test('emits none when level is 16 and saver is off', () async {
      when(() => mockBattery.isInBatterySaveMode).thenAnswer((_) async => false);
      when(() => mockBattery.batteryLevel).thenAnswer((_) async => 16);

      final monitor = buildMonitor();
      final first = await monitor.warningStream.first;

      expect(first, BatteryWarningState.none);
    });

    test('emits lowPowerMode over lowBattery when both conditions are true', () async {
      // Low power mode takes priority even when battery is also low
      when(() => mockBattery.isInBatterySaveMode).thenAnswer((_) async => true);
      when(() => mockBattery.batteryLevel).thenAnswer((_) async => 10);

      final monitor = buildMonitor();
      final first = await monitor.warningStream.first;

      expect(first, BatteryWarningState.lowPowerMode);
    });

    test('emits updated state when battery state changes', () async {
      // Start fine, then enter battery saver
      var saveMode = false;
      when(() => mockBattery.isInBatterySaveMode)
          .thenAnswer((_) async => saveMode);
      when(() => mockBattery.batteryLevel).thenAnswer((_) async => 80);

      final monitor = buildMonitor();
      final emitted = <BatteryWarningState>[];
      final sub = monitor.warningStream.listen(emitted.add);

      // Wait for initial evaluation
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Simulate entering battery saver
      saveMode = true;
      stateController.add(BatteryState.discharging);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(emitted, containsAllInOrder([
        BatteryWarningState.none,
        BatteryWarningState.lowPowerMode,
      ]));
    });
  });
}
