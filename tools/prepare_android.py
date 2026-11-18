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
for p in ('android.permission.INTERNET', 'android.permission.ACCESS_COARSE_LOCATION',
          'android.permission.ACCESS_FINE_LOCATION'):
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
            s='import java.util.Properties\\n'+s
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
# Use the included original Reach icon instead of Flutter's default launcher icon.
for density in ('mdpi','hdpi','xhdpi','xxhdpi','xxxhdpi'):
    src=root/'assets/launcher'/f'ic_launcher_{density}.png'
    target=android/'app/src/main/res'/f'mipmap-{density}'/'ic_launcher.png'
    if src.exists():
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(src,target)
print('Reach Android configuration applied: API 36, deep links, network, opt-in location, push='+str(os.environ.get('REACH_ENABLE_PUSH')=='1'))
