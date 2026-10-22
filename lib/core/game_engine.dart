import 'dart:math';

/// 산책 모드 / 러닝 모드. 같은 엔진, 환산 비율만 다름.
enum PlayMode { walk, run }

const int kMaxStepsPerDay = 30000;
const double kMaxRunKmPerDay = 60;
const double kMinPaceSecPerKm = 150; // 2:30/km보다 빠르면 비정상 기록

class ActivityDay {
  final int steps;
  final double runKm;
  final double avgPaceSecPerKm; // 달리기 없으면 0
  const ActivityDay({this.steps = 0, this.runKm = 0, this.avgPaceSecPerKm = 0});
}

class MapData {
  final String name;
  final int length;
  final List<int> bossCells;
  final int bossBaseHp;
  const MapData(this.name, this.length, this.bossCells, this.bossBaseHp);
}

const List<MapData> kMaps = [
  MapData('포근 숲길', 30, [10, 20, 30], 120),
  MapData('벚꽃 둘레길', 40, [10, 20, 30, 40], 300),
];

class GameState {
  PlayMode mode;
  int level;
  int xp;
  int mapIndex;
  int pos;
  Set<int> wonBosses;
  int bossHp;
  int claimedUnits;
  double claimedRunKm;
  double speedStat;
  int streak;
  int companionBonusPct;
  bool subscribed;

  GameState({
    this.mode = PlayMode.walk,
    this.level = 1,
    this.xp = 0,
    this.mapIndex = 0,
    this.pos = 0,
    Set<int>? wonBosses,
    this.bossHp = 0,
    this.claimedUnits = 0,
    this.claimedRunKm = 0,
    this.speedStat = 0,
    this.streak = 0,
    this.companionBonusPct = 0,
    this.subscribed = false,
  }) : wonBosses = wonBosses ?? <int>{};

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'level': level,
        'xp': xp,
        'mapIndex': mapIndex,
        'pos': pos,
        'wonBosses': wonBosses.toList(),
        'bossHp': bossHp,
        'claimedUnits': claimedUnits,
        'claimedRunKm': claimedRunKm,
        'speedStat': speedStat,
        'streak': streak,
        'companionBonusPct': companionBonusPct,
        'subscribed': subscribed,
      };

  factory GameState.fromJson(Map<String, dynamic> j) => GameState(
        mode: PlayMode.values.byName(j['mode'] ?? 'walk'),
        level: j['level'] ?? 1,
        xp: j['xp'] ?? 0,
        mapIndex: j['mapIndex'] ?? 0,
        pos: j['pos'] ?? 0,
        wonBosses: Set<int>.from((j['wonBosses'] ?? <int>[]) as List),
        bossHp: j['bossHp'] ?? 0,
        claimedUnits: j['claimedUnits'] ?? 0,
        claimedRunKm: (j['claimedRunKm'] ?? 0).toDouble(),
        speedStat: (j['speedStat'] ?? 0).toDouble(),
        streak: j['streak'] ?? 0,
        companionBonusPct: j['companionBonusPct'] ?? 0,
        subscribed: j['subscribed'] ?? false,
      );
}

class ClaimResult {
  final int xpGained;
  final int levelsGained;
  final int cellsAdvanced;
  final List<String> events; // chest, random_event, boss_appeared, boss_defeated, map_unlocked
  const ClaimResult(this.xpGained, this.levelsGained, this.cellsAdvanced, this.events);
  static const empty = ClaimResult(0, 0, 0, []);
}

class GameEngine {
  static int needXp(int level) => 100 + 50 * (level - 1);

  /// 부정 기록 1차 방어: 상한 + 비정상 페이스 제거.
  static ActivityDay sanitize(ActivityDay d) {
    var km = min(d.runKm, kMaxRunKmPerDay);
    if (d.avgPaceSecPerKm > 0 && d.avgPaceSecPerKm < kMinPaceSecPerKm) km = 0;
    return ActivityDay(
      steps: min(d.steps, kMaxStepsPerDay),
      runKm: km,
      avgPaceSecPerKm: d.avgPaceSecPerKm,
    );
  }

  /// 걸음 + 달리기 환산 포인트. 러닝 모드는 달리기 가중치가 더 큼.
  static int units(ActivityDay d, PlayMode m) =>
      d.steps + (d.runKm * (m == PlayMode.run ? 900 : 600)).round();

  static double multiplier(GameState s, double weather) =>
      (1 + (s.companionBonusPct + min(s.streak, 10) + (s.subscribed ? 30 : 0)) / 100) * weather;

  static int bossMaxHp(GameState s, int cell) => kMaps[s.mapIndex].bossBaseHp + cell * 15;

  static bool bossAlive(GameState s) =>
      kMaps[s.mapIndex].bossCells.contains(s.pos) && !s.wonBosses.contains(s.pos);

  static double _paceFactor(double pace) {
    if (pace <= 0) return 1;
    if (pace <= 300) return 2;
    if (pace <= 360) return 1.5;
    return 1;
  }

  static ClaimResult claim(GameState s, ActivityDay raw, {double weather = 1}) {
    final d = sanitize(raw);
    final u = units(d, s.mode);
    final pending = u - s.claimedUnits;
    if (pending <= 0) return ClaimResult.empty;

    final gained = (pending / 10 * multiplier(s, weather)).floor();
    final events = <String>[];

    s.xp += gained;
    var levels = 0;
    while (s.xp >= needXp(s.level)) {
      s.xp -= needXp(s.level);
      s.level++;
      levels++;
    }

    final newKm = d.runKm - s.claimedRunKm;
    if (newKm > 0) {
      s.speedStat += newKm * _paceFactor(d.avgPaceSecPerKm);
      s.claimedRunKm = d.runKm;
    }

    final map = kMaps[s.mapIndex];
    final cells = u ~/ 1000 - s.claimedUnits ~/ 1000;
    final fightingBefore = bossAlive(s);
    var blocked = false;
    var advanced = 0;
    for (var i = 0; i < cells; i++) {
      if (s.pos >= map.length) break;
      if (bossAlive(s)) {
        blocked = true;
        break;
      }
      s.pos++;
      advanced++;
      if (map.bossCells.contains(s.pos)) {
        s.bossHp = bossMaxHp(s, s.pos);
        events.add('boss_appeared');
      } else if (s.pos % 5 == 0) {
        events.add('chest');
      } else {
        events.add('random_event'); // 발생 확률은 UI 계층에서 결정
      }
    }

    if (bossAlive(s) && (fightingBefore || blocked)) {
      s.bossHp -= gained;
      if (s.bossHp <= 0) {
        s.wonBosses.add(s.pos);
        s.bossHp = 0;
        events.add('boss_defeated');
        if (s.pos >= map.length && s.mapIndex < kMaps.length - 1) {
          s.mapIndex++;
          s.pos = 0;
          s.wonBosses = <int>{};
          events.add('map_unlocked');
        }
      }
    }

    s.claimedUnits = u;
    return ClaimResult(gained, levels, advanced, events);
  }

  /// 하루가 지났을 때 호출 (어제 기록 기준으로 연속일 갱신).
  static void rollDay(GameState s, ActivityDay yesterday) {
    final u = units(sanitize(yesterday), s.mode);
    s.streak = u >= 1000 ? s.streak + 1 : 0;
    s.claimedUnits = 0;
    s.claimedRunKm = 0;
  }
}
