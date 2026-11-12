# adel_tube_downloader - خطوات التشغيل

1) أنشئ مشروع Flutter ثم انسخ الملفات فوقه:
   flutter create --org com.adel --project-name adel_tube_downloader --platforms android .
   (استبدل lib/ و pubspec.yaml بالموجودة هنا)
   انسخ android_files/kotlin/com/adel/adel_tube_downloader/*.kt إلى
   android/app/src/main/kotlin/com/adel/adel_tube_downloader/  (استبدل MainActivity.kt)

2) android/app/build.gradle(.kts):
   - minSdk = 29      (مطلوب لحفظ الملفات في المعرض عبر MediaStore بدون صلاحيات تخزين)
   - ndk { abiFilters += listOf("arm64-v8a", "armeabi-v7a") }
   - packaging { jniLibs { useLegacyPackaging = true } }
   - dependencies (تحقق من أحدث إصدار):
       implementation("io.github.junkfood02.youtubedl-android:library:0.17.2")
       implementation("io.github.junkfood02.youtubedl-android:ffmpeg:0.17.2")
       implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")

3) AndroidManifest.xml:
   <uses-permission android:name="android.permission.INTERNET"/>
   <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
   <uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC"/>
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

   على <activity> الرئيسي: android:launchMode="singleTask" وأضف بداخله (لاستقبال المشاركة):
   <intent-filter>
     <action android:name="android.intent.action.SEND"/>
     <category android:name="android.intent.category.DEFAULT"/>
     <data android:mimeType="text/plain"/>
   </intent-filter>

   داخل <application>:
   <service android:name=".DownloadService" android:exported="false"
            android:foregroundServiceType="dataSync"/>

4) شغّل: flutter pub get && flutter run

## كيف يعمل الاستئناف
- كل تحميل يُكتب في مجلد مؤقت باسم ثابت = معرّف المهمة، فيجد yt-dlp الملف الجزئي (.part) ويكمل منه (--continue).
- إيقاف مؤقت / انقطاع / قتل التطبيق: الملفات الجزئية تبقى. زر «استئناف» يكمل من نفس النقطة.
- عند فتح التطبيق، أي تحميل كان جارياً يُستأنف تلقائياً.
- «إلغاء» وحده يحذف الملفات الجزئية.
- لا توجد قيود على الشبكة أو البطارية.

## الحفظ في المعرض
- عند الاكتمال يُنسخ الملف إلى Movies/adel_tube_downloader (فيديو) أو Music/adel_tube_downloader (صوت) عبر MediaStore، ثم يُحذف المؤقت.

## الطريق السريع (بدلاً من الخطوات اليدوية 1–3)
    bash tools/setup_android.sh      # يولّد android/ ويضيف Kotlin والتعديلات تلقائياً
    flutter pub get
    flutter build apk                # نسخة تجريبية جاهزة للتثبيت (موقّعة بمفتاح debug)
الناتج: build/app/outputs/flutter-apk/app-release.apk
لتثبيته: فعّل «التثبيت من مصادر غير معروفة» على الهاتف أو `adb install app-release.apk`.
هذه النسخة للتجربة فقط؛ للنشر العام استخدم مفتاح توقيع خاصاً (انظر الخطوات السابقة).

## GitHub Actions
كل push إلى main (أو تشغيل يدوي من تبويب Actions) يبني الـAPK ويرفعه:
Actions > آخر تشغيل > Artifacts > adel_tube_downloader-apk
