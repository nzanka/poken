import 'package:supabase_flutter/supabase_flutter.dart';

/// 크루 기능 (러닝크루 / 가족 모험단 공용). 스키마는 supabase/schema.sql 참고.
class CrewRepository {
  final SupabaseClient _db = Supabase.instance.client;

  Future<String> createCrew(String name) async {
    final uid = _db.auth.currentUser!.id;
    final row = await _db
        .from('crews')
        .insert({'name': name, 'owner': uid})
        .select('id, invite_code')
        .single();
    await _db.from('crew_members').insert({'crew_id': row['id'], 'user_id': uid});
    return row['invite_code'] as String;
  }

  Future<void> joinByCode(String code) async {
    await _db.rpc('join_crew', params: {'p_code': code});
  }

  /// 오늘 기록 업로드 (서버에서 상한 검증)
  Future<void> uploadDay(DateTime day, int steps, double runKm) async {
    final uid = _db.auth.currentUser!.id;
    await _db.from('daily_activity').upsert({
      'user_id': uid,
      'day': day.toIso8601String().substring(0, 10),
      'steps': steps,
      'run_km': runKm,
    });
  }

  Future<List<Map<String, dynamic>>> weeklyTotals(String crewId) async {
    final res = await _db.rpc('crew_weekly_totals', params: {'p_crew': crewId});
    return List<Map<String, dynamic>>.from(res as List);
  }
}
