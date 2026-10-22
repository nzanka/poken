import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/game_engine.dart';
import 'services/activity_source.dart';
import 'services/storage.dart';

const _supaUrl = String.fromEnvironment('SUPABASE_URL');
const _supaKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const _useHealth = bool.fromEnvironment('USE_HEALTH'); // 실기기: --dart-define=USE_HEALTH=true

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_supaUrl.isNotEmpty) {
    await Supabase.initialize(url: _supaUrl, anonKey: _supaKey);
  }
  runApp(const PokeunGilApp());
}

class PokeunGilApp extends StatelessWidget {
  const PokeunGilApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '포근길',
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFFE8883A),
          scaffoldBackgroundColor: const Color(0xFFFBF6EC),
          useMaterial3: true,
        ),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ActivitySource _source = _useHealth ? HealthActivitySource() : MockActivitySource();
  GameState? _s;
  ActivityDay _today = const ActivityDay();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _s = await Storage.load();
    if (_s != null) await _refresh();
    setState(() {});
  }

  Future<void> _pickMode(PlayMode m) async {
    _s = GameState(mode: m);
    await _source.requestPermissions();
    await Storage.save(_s!);
    await _refresh();
  }

  Future<void> _refresh() async {
    _today = await _source.fetchDay(DateTime.now());
    if (mounted) setState(() {});
  }

  Future<void> _claim() async {
    final r = GameEngine.claim(_s!, _today);
    await Storage.save(_s!);
    if (!mounted) return;
    setState(() {});
    final msg = r.xpGained == 0 ? '받을 보상이 없어요' : '경험치 +${r.xpGained}'
        '${r.levelsGained > 0 ? ' · 레벨업!' : ''}'
        '${r.events.contains('boss_defeated') ? ' · 보스 격파!' : ''}';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // 개발용: 에뮬레이터에서 걸음 수를 올려본다.
  void _debugAdd(int steps) {
    final src = _source;
    if (src is MockActivitySource) {
      src.steps += steps;
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    if (s == null) return _ModeSelect(onPick: _pickMode);
    final map = kMaps[s.mapIndex];
    return Scaffold(
      appBar: AppBar(title: Text('${map.name} · ${s.pos}/${map.length}칸')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Center(child: Text(s.mode == PlayMode.run ? '🐰' : '🐶', style: const TextStyle(fontSize: 96))),
        Center(child: Text('Lv.${s.level}', style: Theme.of(context).textTheme.headlineSmall)),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: s.xp / GameEngine.needXp(s.level), minHeight: 14),
        const SizedBox(height: 16),
        Text('오늘 ${_today.steps}보 · 달리기 ${_today.runKm.toStringAsFixed(1)}km'),
        if (s.mode == PlayMode.run) Text('스피드 스탯 ${s.speedStat.toStringAsFixed(1)}'),
        if (GameEngine.bossAlive(s)) Text('👿 보스 남은 HP ${s.bossHp}'),
        const SizedBox(height: 16),
        FilledButton(onPressed: _claim, child: const Text('보상 받기')),
        OutlinedButton(onPressed: _refresh, child: const Text('걸음 새로고침')),
        if (!_useHealth) ...[
          const Divider(),
          Wrap(spacing: 8, children: [
            for (final n in [500, 1000, 3000])
              OutlinedButton(onPressed: () => _debugAdd(n), child: Text('+$n (테스트)')),
          ]),
        ],
      ]),
    );
  }
}

class _ModeSelect extends StatelessWidget {
  final ValueChanged<PlayMode> onPick;
  const _ModeSelect({required this.onPick});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('어떻게 모험할까요?', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(72)),
                onPressed: () => onPick(PlayMode.walk),
                child: const Text('🚶 산책 모드  (걸음 수 중심)'),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(72)),
                onPressed: () => onPick(PlayMode.run),
                child: const Text('🏃 러닝 모드  (거리, 페이스 중심)'),
              ),
            ]),
          ),
        ),
      );
}
