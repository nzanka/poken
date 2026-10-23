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
class HealthActivitySource implements ActivitySource {
  final Health _health = Health();
  static const _types = [HealthDataType.STEPS, HealthDataType.WORKOUT];
  static final _access = [HealthDataAccess.READ, HealthDataAccess.READ];

  @override
  Future<bool> requestPermissions() async {
    await _health.configure();
    return _health.requestAuthorization(_types, permissions: _access);
  }

  @override
  Future<ActivityDay> fetchDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final dayEnd = start.add(const Duration(days: 1));
    final now = DateTime.now();
    final end = now.isBefore(dayEnd) ? now : dayEnd; // 미래 시각은 넣지 않는다

    var steps = 0;
    try {
      steps = await _health.getTotalStepsInInterval(start, end) ?? 0;
    } catch (_) {}
    // 합계 조회가 0이면 원본 기록을 직접 더해 본다 (가장 많이 기록한 앱 기준, 중복 합산 방지)
    if (steps == 0) steps = await _rawSteps(start, end);

    var km = 0.0;
    var seconds = 0;
    try {
      final points = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT],
        startTime: start,
        endTime: end,
      );
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
    } catch (_) {}
    final pace = km > 0 ? seconds / km : 0.0;
    return ActivityDay(steps: steps, runKm: km, avgPaceSecPerKm: pace);
  }

  Future<int> _rawSteps(DateTime s, DateTime e) async {
    try {
      final pts = await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: s,
        endTime: e,
      );
      final m = <String, num>{};
      for (final p in pts) {
        if (p.recordingMethod == RecordingMethod.manual) continue;
        final v = p.value;
        if (v is NumericHealthValue) {
          m[p.sourceName] = (m[p.sourceName] ?? 0) + v.numericValue;
        }
      }
      if (m.isEmpty) return 0;
      return m.values.reduce((a, b) => a > b ? a : b).round();
    } catch (_) {
      return 0;
    }
  }

  /// 걸음 수가 0일 때 화면에 보여줄 진단 정보.
  Future<String> diagnose() async {
    final b = StringBuffer();
    try {
      final st = await _health.getHealthConnectSdkStatus();
      b.writeln('Health Connect 상태: $st');
    } catch (e) {
      b.writeln('Health Connect 상태 확인 실패: $e');
    }
    try {
      final has = await _health.hasPermissions(_types, permissions: _access);
      b.writeln('앱 권한: $has');
    } catch (e) {
      b.writeln('권한 확인 실패: $e');
    }
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    try {
      final agg = await _health.getTotalStepsInInterval(start, now);
      b.writeln('오늘 걸음 합계: $agg');
    } catch (e) {
      b.writeln('합계 조회 실패: $e');
    }
    try {
      final pts = await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: now.subtract(const Duration(days: 2)),
        endTime: now,
      );
      b.writeln('최근 2일 걸음 기록: ${pts.length}건');
      final m = <String, num>{};
      for (final p in pts) {
        final v = p.value;
        if (v is NumericHealthValue) {
          m[p.sourceName] = (m[p.sourceName] ?? 0) + v.numericValue;
        }
      }
      m.forEach((k, v) => b.writeln(' - $k: ${v.round()}보'));
    } catch (e) {
      b.writeln('원본 기록 조회 실패: $e');
    }
    return b.toString();
  }
}
