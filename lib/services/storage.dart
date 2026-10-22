import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/game_engine.dart';

class Storage {
  static const _key = 'game_state_v1';

  static Future<GameState?> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return null;
    return GameState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<void> save(GameState s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(s.toJson()));
  }
}
