#!/usr/bin/env python3
"""Read-only release audit of the ACTUAL compiled Android App Bundle.

Checks exactly the permissions intentionally enabled in the selected QA
build: media calling is optional and must never be advertised as fully tested.
The AAB base manifest is a protobuf binary; embedded permission strings are
sufficient to verify absence/presence of named uses-permission entries because
those names are encoded verbatim in the binary manifest.
"""
import json
import os
import sys
import zipfile
from pathlib import Path

bundle=Path(sys.argv[1] if len(sys.argv)>1 else 'build/app/outputs/bundle/release/app-release.aab')
output=Path(sys.argv[2] if len(sys.argv)>2 else 'dist/PLAY-PERMISSION-AUDIT.json')
calling_enabled=os.environ.get('REACH_ENABLE_CALLS')=='1'
push_enabled=os.environ.get('REACH_ENABLE_PUSH')=='1'
required=[
    'android.permission.INTERNET',
    'android.permission.ACCESS_COARSE_LOCATION',
]
forbidden=[
    'android.permission.ACCESS_FINE_LOCATION',
    'android.permission.READ_MEDIA_IMAGES',
    'android.permission.READ_MEDIA_VIDEO',
    'android.permission.READ_MEDIA_AUDIO',
    'android.permission.READ_MEDIA_VISUAL_USER_SELECTED',
    'android.permission.MANAGE_EXTERNAL_STORAGE',
    'android.permission.READ_EXTERNAL_STORAGE',
    'android.permission.WRITE_EXTERNAL_STORAGE',
]
if calling_enabled:
    required+=['android.permission.RECORD_AUDIO','android.permission.CAMERA']
else:
    forbidden+=['android.permission.RECORD_AUDIO','android.permission.CAMERA',
        'android.permission.BLUETOOTH','android.permission.MODIFY_AUDIO_SETTINGS']
if push_enabled:
    required+=['android.permission.POST_NOTIFICATIONS']
else:
    forbidden+=['android.permission.POST_NOTIFICATIONS',
        'android.permission.WAKE_LOCK','com.google.android.c2dm.permission.RECEIVE']
with zipfile.ZipFile(bundle) as z:
    manifest=z.read('base/manifest/AndroidManifest.xml')
    icons=[n for n in z.namelist() if n.endswith('/ic_launcher.png') and '/mipmap-' in n]
    required_present=[v for v in required if v.encode() in manifest]
    unexpected=[v for v in forbidden if v.encode() in manifest]
    has_app_id=b'app.reachnetwork.reach_network' in manifest
    has_launcher=len(icons)>=5
report={
    'app':'Reach',
    'voice_video_enabled_for_device_qa':calling_enabled,
    'firebase_push_enabled':push_enabled,
    'bundle':bundle.name,
    'compiled_android_manifest_verified':True,
    'required_permissions':required_present,
    'unexpected_sensitive_or_disabled_feature_permissions':unexpected,
    'expected_application_id':has_app_id,
    'launcher_density_count':len(icons),
    'result':'PASS' if len(required_present)==len(required) and not unexpected
                   and has_app_id and has_launcher else 'FAIL',
}
output.parent.mkdir(parents=True,exist_ok=True)
output.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
if report['result']!='PASS':
    raise SystemExit('Bundled Play manifest permission policy failed. Do not upload.')
