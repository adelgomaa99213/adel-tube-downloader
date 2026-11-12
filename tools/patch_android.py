#!/usr/bin/env python3
"""يعدّل مشروع أندرويد المولَّد (flutter create) ليناسب adel_tube_downloader.
آمن للتشغيل أكثر من مرة. يفشل بوضوح إن لم يجد أحد المواضع المتوقعة."""
import os, re, sys

def read(p):
    with open(p, encoding="utf-8") as f: return f.read()
def write(p, s):
    with open(p, "w", encoding="utf-8") as f: f.write(s)
def die(msg):
    print("خطأ:", msg); sys.exit(1)

# ---------- Gradle ----------
kts = os.path.exists("android/app/build.gradle.kts")
gp = "android/app/build.gradle.kts" if kts else "android/app/build.gradle"
if not os.path.exists(gp): die("لم أجد ملف gradle للتطبيق")
g = read(gp)

if "youtubedl-android" not in g:
    g, n = re.subn(r"minSdk(Version)?\s*=?\s*flutter\.minSdkVersion",
                   "minSdk = 29" if kts else "minSdkVersion 29", g)
    if n == 0: die("لم أجد minSdk")

    ndk = ('\n            ndk { abiFilters += listOf("arm64-v8a", "armeabi-v7a") }\n' if kts
           else '\n            ndk { abiFilters "arm64-v8a", "armeabi-v7a" }\n')
    g, n = re.subn(r"(versionName[^\n]*\n)", lambda m: m.group(1) + ndk, g, count=1)
    if n == 0: die("لم أجد versionName")

    pack = ("packaging { jniLibs { useLegacyPackaging = true } }" if kts
            else "packagingOptions { jniLibs { useLegacyPackaging = true } }")
    g, n = re.subn(r"android\s*\{", lambda m: m.group(0) + "\n    " + pack, g, count=1)
    if n == 0: die("لم أجد كتلة android")

    prog = ('proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")'
            if kts else
            "proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'")
    g, n = re.subn(r"release\s*\{", lambda m: m.group(0) + "\n            " + prog, g, count=1)
    if n == 0: die("لم أجد buildTypes.release")

    if kts:
        deps = '''
dependencies {
    implementation("io.github.junkfood02.youtubedl-android:library:0.17.2")
    implementation("io.github.junkfood02.youtubedl-android:ffmpeg:0.17.2")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
}
'''
    else:
        deps = '''
dependencies {
    implementation "io.github.junkfood02.youtubedl-android:library:0.17.2"
    implementation "io.github.junkfood02.youtubedl-android:ffmpeg:0.17.2"
    implementation "org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1"
}
'''
    g += deps
    write(gp, g)

write("android/app/proguard-rules.pro",
      "-keep class com.yausername.** { *; }\n-keep class com.adel.** { *; }\n-dontwarn com.yausername.**\n")

# ---------- Manifest ----------
mp = "android/app/src/main/AndroidManifest.xml"
m = read(mp)
if "DownloadService" not in m:
    perms = '''    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    '''
    m, n = re.subn(r"<application", lambda x: perms + "<application", m, count=1)
    if n == 0: die("لم أجد <application>")

    m, n = re.subn(r'android:launchMode="[^"]*"', 'android:launchMode="singleTask"', m, count=1)
    if n == 0: die("لم أجد launchMode")

    share = '''<intent-filter>
                <action android:name="android.intent.action.SEND"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <data android:mimeType="text/plain"/>
            </intent-filter>
        '''
    m, n = re.subn(r"</activity>", lambda x: share + "</activity>", m, count=1)
    if n == 0: die("لم أجد </activity>")

    svc = '''<service android:name=".DownloadService" android:exported="false"
            android:foregroundServiceType="dataSync"/>
    '''
    m, n = re.subn(r"</application>", lambda x: svc + "</application>", m, count=1)
    if n == 0: die("لم أجد </application>")
    write(mp, m)

print("تم تعديل مشروع أندرويد")
