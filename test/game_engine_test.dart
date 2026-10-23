import 'package:flutter_test/flutter_test.dart';
import 'package:pokeun_gil/core/game_engine.dart';

void main() {
  test('1,000보면 레벨 2가 되고 1칸 전진', () {
    final s = GameState();
    final r = GameEngine.claim(s, const ActivityDay(steps: 1000));
    expect(r.xpGained, 100);
    expect(s.level, 2);
    expect(s.pos, 1);
  });

  test('같은 기록으로 두 번 받아도 중복 보상이 없다', () {
    final s = GameState();
    GameEngine.claim(s, const ActivityDay(steps: 1000));
    final r = GameEngine.claim(s, const ActivityDay(steps: 1000));
    expect(r.xpGained, 0);
  });

  test('비정상적으로 빠른 페이스의 달리기는 무시', () {
    const d = ActivityDay(steps: 0, runKm: 10, avgPaceSecPerKm: 100);
    expect(GameEngine.sanitize(d).runKm, 0);
  });

  test('걸음 수와 달리기 거리에 일일 상한이 적용', () {
    const d = ActivityDay(steps: 99999, runKm: 500, avgPaceSecPerKm: 300);
    final c = GameEngine.sanitize(d);
    expect(c.steps, kMaxStepsPerDay);
    expect(c.runKm, kMaxRunKmPerDay);
  });

  test('러닝 모드는 같은 거리에서 더 많은 포인트', () {
    const d = ActivityDay(runKm: 5, avgPaceSecPerKm: 330);
    expect(GameEngine.units(d, PlayMode.run), greaterThan(GameEngine.units(d, PlayMode.walk)));
  });

  test('보스를 쓰러뜨리면 진행이 풀린다', () {
    final s = GameState(pos: 10, bossHp: 270);
    final r = GameEngine.claim(s, const ActivityDay(steps: 5000));
    expect(r.events, contains('boss_defeated'));
    expect(s.wonBosses, contains(10));
  });

  test('마지막 보스를 이기면 다음 지도가 열린다', () {
    final s = GameState(pos: 30, bossHp: 570, wonBosses: {10, 20});
    final r = GameEngine.claim(s, const ActivityDay(steps: 10000));
    expect(r.events, contains('map_unlocked'));
    expect(s.mapIndex, 1);
    expect(s.pos, 0);
  });

  test('새 날이 되면 어제 못 받은 보상을 정산하고 연속일이 늘어난다', () {
    final s = GameState(lastDay: '2026-10-22');
    final r = GameEngine.settleAndRoll(s, DateTime(2026, 10, 23), const ActivityDay(steps: 2000));
    expect(r.xpGained, 200);
    expect(s.streak, 1);
    expect(s.claimedUnits, 0);
    expect(s.lastDay, '2026-10-23');
  });

  test('이틀 이상 비면 연속일이 끊긴다', () {
    final s = GameState(lastDay: '2026-10-20', streak: 5);
    GameEngine.settleAndRoll(s, DateTime(2026, 10, 23), const ActivityDay(steps: 2000));
    expect(s.streak, 0);
  });

  test('같은 날이면 새 날로 보지 않는다', () {
    final s = GameState(lastDay: '2026-10-23');
    expect(GameEngine.isNewDay(s, DateTime(2026, 10, 23, 18)), false);
  });
}
