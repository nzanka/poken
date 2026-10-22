import 'package:health/health.dart';
import '../core/game_engine.dart';

/// 걸음, 달리기 데이터를 가져오는 추상 인터페이스.
/// 에뮬레이터에서는 Mock, 실기기에서는 건강 데이터(HealthKit / Health Connect).
abstract class ActivitySource {
  Future<bool> requestPermissions();
  Future<ActivityDay> fetchDay(DateTime day);
}

class MockActivitySource implements ActivitySource {
  int steps;
  double runKm;
  double pace;
  MockActivitySource({this.steps = 0, this.runKm = 0, this.pace = 0});

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<ActivityDay> fetchDay(DateTime day) async =>
      ActivityDay(steps: steps, runKm: runKm, avgPaceSecPerKm: pace);
}

/// 주의: health 패키지는 버전별로 API가 조금씩 다릅니다.
/// 설치된 버전의 문서를 보고 아래 호출을 맞춰주세요.
class HealthActivitySource implements ActivitySource {
  final Health _health = Health();
  static const _types = [HealthDataType.STEPS, HealthDataType.WORKOUT];

  @override
  Future<bool> requestPermissions() async {
    await _health.configure();
    return _health.requestAuthorization(
      _types,
      permissions: [HealthDataAccess.READ, HealthDataAccess.READ],
    );
  }

  @override
  Future<ActivityDay> fetchDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    final steps = await _health.getTotalStepsInInterval(start, end) ?? 0;

    final points = await _health.getHealthDataFromTypes(
      types: [HealthDataType.WORKOUT],
      startTime: start,
      endTime: end,
    );

    var km = 0.0;
    var seconds = 0;
    for (final p in points) {
      // 수동 입력 기록은 제외 (랭킹 부정 방지)
      if (p.recordingMethod == RecordingMethod.manual) continue;
      final v = p.value;
      if (v is WorkoutHealthValue &&
          v.workoutActivityType == HealthWorkoutActivityType.RUNNING) {
        final meters = (v.totalDistance ?? 0).toDouble();
        km += meters / 1000;
        seconds += p.dateTo.difference(p.dateFrom).inSeconds;
      }
    }
    final pace = km > 0 ? seconds / km : 0.0;
    return ActivityDay(steps: steps, runKm: km, avgPaceSecPerKm: pace);
  }
}
