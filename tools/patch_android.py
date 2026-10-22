"""flutter create 직후 실행: 건강 데이터(Health Connect) 연동에 필요한 안드로이드 설정을 자동 적용."""
import re, pathlib

man = pathlib.Path('android/app/src/main/AndroidManifest.xml')
t = man.read_text(encoding='utf-8')
perms = ''.join(
    f'    <uses-permission android:name="android.permission.health.{p}"/>\n'
    for p in ('READ_STEPS', 'READ_DISTANCE', 'READ_EXERCISE'))
if 'READ_STEPS' not in t:
    t = t.replace('<application', perms + '    <application', 1)
    t = t.replace('</activity>',
        '    <intent-filter>\n'
        '        <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE"/>\n'
        '    </intent-filter>\n    </activity>', 1)
    man.write_text(t, encoding='utf-8')

for f in ('android/app/build.gradle.kts', 'android/app/build.gradle'):
    p = pathlib.Path(f)
    if p.exists():
        s = p.read_text(encoding='utf-8')
        s = s.replace('flutter.minSdkVersion', '26')
        p.write_text(s, encoding='utf-8')

for kt in pathlib.Path('android/app/src/main').rglob('MainActivity.kt'):
    pkg = re.search(r'^package\s+(\S+)', kt.read_text(encoding='utf-8'), re.M).group(1)
    kt.write_text(
        f'package {pkg}\n\nimport io.flutter.embedding.android.FlutterFragmentActivity\n\n'
        'class MainActivity : FlutterFragmentActivity()\n', encoding='utf-8')
print('android patched')
