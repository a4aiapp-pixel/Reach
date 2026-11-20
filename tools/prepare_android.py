#!/usr/bin/env python3
"""Post-flutter-create Android hardening and optional Firebase wiring.
Run after: flutter create --platforms=android --project-name reach_network --org app.reachnetwork .
"""
import os
import shutil
from pathlib import Path
from xml.etree import ElementTree as ET

root = Path(__file__).resolve().parent.parent
android = root / 'android'
manifest = android / 'app/src/main/AndroidManifest.xml'
if not manifest.exists():
    raise SystemExit('First run flutter create --platforms=android --project-name reach_network --org app.reachnetwork .')
ET.register_namespace('android', 'http://schemas.android.com/apk/res/android')
A='{http://schemas.android.com/apk/res/android}'
tree=ET.parse(manifest)
doc=tree.getroot()
for p in ('android.permission.INTERNET', 'android.permission.ACCESS_COARSE_LOCATION'):
    if not any(x.get(A+'name') == p for x in doc.findall('uses-permission')):
        el=ET.Element('uses-permission')
        el.set(A+'name',p)
        doc.insert(0,el)
app=doc.find('application')
assert app is not None
app.set(A+'label','Reach')
activity=app.find('activity')
assert activity is not None
# Supabase PKCE, OAuth, confirmation emails and password recovery callbacks.
if not any(any((d.get(A+'scheme')=='reachnetwork') for d in f.findall('data'))
           for f in activity.findall('intent-filter')):
    f=ET.SubElement(activity,'intent-filter')
    a=ET.SubElement(f,'action');a.set(A+'name','android.intent.action.VIEW')
    for name in ('android.intent.category.DEFAULT','android.intent.category.BROWSABLE'):
        c=ET.SubElement(f,'category');c.set(A+'name',name)
    d=ET.SubElement(f,'data');d.set(A+'scheme','reachnetwork');d.set(A+'host','auth-callback')
if os.environ.get('REACH_ENABLE_PUSH') == '1':
    if not (android/'app/google-services.json').exists():
        raise SystemExit('REACH_ENABLE_PUSH=1 requires android/app/google-services.json')
    if not any(x.get(A+'name')=='android.permission.POST_NOTIFICATIONS' for x in doc.findall('uses-permission')):
        el=ET.Element('uses-permission');el.set(A+'name','android.permission.POST_NOTIFICATIONS');doc.insert(0,el)
    app.set(A+'label','Reach')
    if not any(x.tag=='meta-data' and x.get(A+'name')=='com.google.firebase.messaging.default_notification_channel_id'
               for x in app.findall('meta-data')):
        meta=ET.SubElement(app,'meta-data')
        meta.set(A+'name','com.google.firebase.messaging.default_notification_channel_id')
        meta.set(A+'value','reach_updates')
    settings=android/'settings.gradle.kts'
    build=android/'app/build.gradle.kts'
    s=settings.read_text()
    if 'com.google.gms.google-services' not in s:
        s=s.replace('plugins {','plugins {\n    id("com.google.gms.google-services") version "4.4.4" apply false',1)
        settings.write_text(s)
    s=build.read_text()
    if 'com.google.gms.google-services' not in s:
        s=s.replace('plugins {','plugins {\n    id("com.google.gms.google-services")',1)
        build.write_text(s)
# Voice/video calls are foreground-only and hidden until real QA approval.
# Avoid runtime mic/camera permission requests when the call flag is disabled.
if os.environ.get('REACH_ENABLE_CALLS') == '1':
    for permission in ('android.permission.RECORD_AUDIO', 'android.permission.CAMERA',
                       'android.permission.MODIFY_AUDIO_SETTINGS',
                       'android.permission.ACCESS_NETWORK_STATE'):
        if not any(x.get(A+'name') == permission for x in doc.findall('uses-permission')):
            el = ET.Element('uses-permission')
            el.set(A+'name', permission)
            doc.insert(0,el)
    for feature in ('android.hardware.camera', 'android.hardware.microphone'):
        if not any(x.get(A+'name')==feature for x in doc.findall('uses-feature')):
            el=ET.Element('uses-feature')
            el.set(A+'name',feature)
            el.set(A+'required','false')
            doc.insert(0,el)
# Strip library-added permissions for product features intentionally disabled
# in the default Play build. Keep only foreground COARSE location for optional
# approximate discovery. Android's high-priority manifest merge markers suppress
# permissions declared by Firebase Messaging, WebRTC and related libraries.
# If push/calling is explicitly enabled later, regenerate and re-audit the AAB.
ET.register_namespace('tools', 'http://schemas.android.com/tools')
T='{http://schemas.android.com/tools}'
remove_permissions={
    'android.permission.ACCESS_FINE_LOCATION',
    # Android document picker grants scoped URI access: never require broad
    # media/storage access even in calling-enabled internal QA builds.
    'android.permission.READ_EXTERNAL_STORAGE',
    'android.permission.WRITE_EXTERNAL_STORAGE',
    'android.permission.MANAGE_EXTERNAL_STORAGE',
    'android.permission.READ_MEDIA_IMAGES',
    'android.permission.READ_MEDIA_VIDEO',
    'android.permission.READ_MEDIA_AUDIO',
    'android.permission.READ_MEDIA_VISUAL_USER_SELECTED',
}
if os.environ.get('REACH_ENABLE_PUSH') != '1':
    remove_permissions.update({
        'android.permission.POST_NOTIFICATIONS',
        'android.permission.WAKE_LOCK',
        'com.google.android.c2dm.permission.RECEIVE',
    })
    for name in ('firebase_messaging_auto_init_enabled',
                 'firebase_data_collection_default_enabled'):
        if not any(e.tag == 'meta-data' and e.get(A+'name') == name
                   for e in app.findall('meta-data')):
            meta=ET.SubElement(app,'meta-data')
            meta.set(A+'name',name)
            meta.set(A+'value','false')
if os.environ.get('REACH_ENABLE_CALLS') != '1':
    remove_permissions.update({
        'android.permission.BLUETOOTH',
        'android.permission.MODIFY_AUDIO_SETTINGS',
    })
for name in sorted(remove_permissions):
    for existing in list(doc.findall('uses-permission')):
        if existing.get(A+'name') == name:
            doc.remove(existing)
    rule=ET.SubElement(doc,'uses-permission')
    rule.set(A+'name',name)
    rule.set(T+'node','remove')

tree.write(manifest,encoding='utf-8',xml_declaration=True)
if os.environ.get('REACH_SIGNING_ENABLED') == '1':
    props_file=android/'key.properties'
    if not props_file.exists():
        raise SystemExit('Signing enabled but android/key.properties missing')
    build=android/'app/build.gradle.kts'
    s=build.read_text()
    if 'reachSigningProperties' not in s:
        # Kotlin Gradle DSL can resolve `java` to a Project extension rather
        # than the Java package. Import the type explicitly before plugins{}.
        if 'import java.util.Properties' not in s:
            s='import java.util.Properties\n'+s
        block='''
val reachSigningProperties = Properties().apply {
    rootProject.file("key.properties").inputStream().use { load(it) }
}

'''
        s=s.replace('android {',block+'android {',1)
        signing='''
    signingConfigs {
        create("reachRelease") {
            storeFile = file(reachSigningProperties.getProperty("storeFile"))
            storePassword = reachSigningProperties.getProperty("storePassword")
            keyAlias = reachSigningProperties.getProperty("keyAlias")
            keyPassword = reachSigningProperties.getProperty("keyPassword")
        }
    }
'''
        s=s.replace('android {','android {'+signing,1)
        s=s.replace('signingConfigs.getByName("debug")','signingConfigs.getByName("reachRelease")')
        build.write_text(s)

# Mandatory 2026 Play API requirements: Android 16, API 36.
for candidate in (android/'app/build.gradle.kts', android/'app/build.gradle'):
    if candidate.exists():
        s=candidate.read_text()
        import re
        s=re.sub(r'compileSdk\s*=\s*flutter\.compileSdkVersion','compileSdk = 36',s)
        s=re.sub(r'targetSdk\s*=\s*flutter\.targetSdkVersion','targetSdk = 36',s)
        s=re.sub(r'compileSdkVersion\s+flutter\.compileSdkVersion','compileSdkVersion 36',s)
        s=re.sub(r'targetSdkVersion\s+flutter\.targetSdkVersion','targetSdkVersion 36',s)
        candidate.write_text(s)
# Reproduce the owner-selected three-person location pin across every
# Android density from a single versioned binary asset. The app name,
# applicationId and persistent upload signing key intentionally remain unchanged.
try:
    from PIL import Image
except ImportError as exc:
    raise SystemExit("Pillow required: run the branded CI Python venv") from exc

brand_source = root / 'assets/branding/reach_selected_icon.webp'
if not brand_source.is_file():
    raise SystemExit('Missing approved Reach branding artwork')
with Image.open(brand_source) as original:
    if original.size[0] < 160 or original.size[1] < 160:
        raise SystemExit('Approved Reach icon source is below required size')
    brand = original.convert('RGB')
    for density, size in (
        ('mdpi', 48), ('hdpi', 72), ('xhdpi', 96),
        ('xxhdpi', 144), ('xxxhdpi', 192)
    ):
        target = android/'app/src/main/res'/f'mipmap-{density}'/'ic_launcher.png'
        target.parent.mkdir(parents=True, exist_ok=True)
        brand.resize((size, size), Image.Resampling.LANCZOS).save(
            target, 'PNG', optimize=True
        )
    play_icon = root/'assets/branding/reach_play_store_icon_512.png'
    brand.resize((512, 512), Image.Resampling.LANCZOS).save(
        play_icon, 'PNG', optimize=True
    )
# A minimal Android-specific bridge distinguishes international roaming from
# normal cellular data. Unknown status fails closed in Dart (no auto-download).
activity_kotlin = android/'app/src/main/kotlin/app/reachnetwork/reach_network/MainActivity.kt'
activity_kotlin.parent.mkdir(parents=True, exist_ok=True)
activity_kotlin.write_text("""package app.reachnetwork.reach_network

import android.content.Context
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "reach/network")
            .setMethodCallHandler { call, result ->
                if (call.method == "isRoaming") {
                    try {
                        val manager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
                        result.success(manager.isNetworkRoaming)
                    } catch (exception: Exception) {
                        result.error("UNKNOWN_ROAMING", "Could not check network roaming", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
""", encoding='utf-8')
print('Reach Android configured: API 36, selected 3-person location-pin icon,'
      ' deep links, opt-in location, push='+str(os.environ.get('REACH_ENABLE_PUSH')=='1'))
