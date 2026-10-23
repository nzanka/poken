"""flutter create 직후 실행: 안드로이드 설정을 한 번에 적용.
 1) 건강 데이터(Health Connect) 권한, 권한 안내 화면, 안드로이드 14+ 대응
 2) minSdk 26, MainActivity 교체
 3) 앱 이름 '포근길'
 4) 고정 서명 키 (새 버전을 기존 앱 위에 덮어쓰기 설치 가능)
"""
import re, pathlib

man = pathlib.Path('android/app/src/main/AndroidManifest.xml')
t = man.read_text(encoding='utf-8')

if 'READ_STEPS' not in t:
    perms = ''.join(
        f'    <uses-permission android:name="android.permission.health.{p}"/>\n'
        for p in ('READ_STEPS', 'READ_DISTANCE', 'READ_EXERCISE'))
    t = t.replace('<application', perms + '    <application', 1)
    t = t.replace('</activity>',
        '    <intent-filter>\n'
        '        <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE"/>\n'
        '    </intent-filter>\n    </activity>', 1)

if 'ViewPermissionUsageActivity' not in t:
    alias = (
        '    <activity-alias\n'
        '        android:name="ViewPermissionUsageActivity"\n'
        '        android:exported="true"\n'
        '        android:targetActivity=".MainActivity"\n'
        '        android:permission="android.permission.START_VIEW_PERMISSION_USAGE">\n'
        '        <intent-filter>\n'
        '            <action android:name="android.intent.action.VIEW_PERMISSION_USAGE"/>\n'
        '            <category android:name="android.intent.category.HEALTH_PERMISSIONS"/>\n'
        '        </intent-filter>\n'
        '    </activity-alias>\n')
    t = t.replace('</application>', alias + '    </application>', 1)

if '<queries>' in t:
    if 'com.google.android.apps.healthdata' not in t:
        t = t.replace('<queries>', '<queries>\n        <package android:name="com.google.android.apps.healthdata"/>', 1)
else:
    t = t.replace('<application',
        '    <queries>\n        <package android:name="com.google.android.apps.healthdata"/>\n    </queries>\n    <application', 1)

t = t.replace('android:label="pokeun_gil"', 'android:label="포근길"')
man.write_text(t, encoding='utf-8')

kts = pathlib.Path('android/app/build.gradle.kts')
if kts.exists():
    s = kts.read_text(encoding='utf-8')
    s = s.replace('flutter.minSdkVersion', '26')
    if 'create("pg")' not in s and 'signingConfigs.getByName("debug")' in s and 'buildTypes {' in s:
        block = (
            '    signingConfigs {\n'
            '        create("pg") {\n'
            '            storeFile = file("../../tools/debug.keystore")\n'
            '            storePassword = "android"\n'
            '            keyAlias = "androiddebugkey"\n'
            '            keyPassword = "android"\n'
            '        }\n'
            '    }\n\n')
        s = s.replace('buildTypes {', block + '    buildTypes {', 1)
        s = s.replace('signingConfigs.getByName("debug")', 'signingConfigs.getByName("pg")')
    kts.write_text(s, encoding='utf-8')

old = pathlib.Path('android/app/build.gradle')
if old.exists():
    old.write_text(old.read_text(encoding='utf-8').replace('flutter.minSdkVersion', '26'), encoding='utf-8')

for kt in pathlib.Path('android/app/src/main').rglob('MainActivity.kt'):
    pkg = re.search(r'^package\s+(\S+)', kt.read_text(encoding='utf-8'), re.M).group(1)
    kt.write_text(
        f'package {pkg}\n\nimport io.flutter.embedding.android.FlutterFragmentActivity\n\n'
        'class MainActivity : FlutterFragmentActivity()\n', encoding='utf-8')
print('android patched')
