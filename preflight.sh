#!/usr/bin/env bash
# فحص ما قبل الإصدار. يعمل من جذر المشروع:  bash tools/preflight.sh
cd "$(dirname "$0")/.." || exit 1
fail=0
ok(){ echo "  [OK]   $1"; }
bad(){ echo "  [FAIL] $1"; fail=1; }
skip(){ echo "  [SKIP] $1"; }

echo "1) نظافة الأسماء"
if grep -rniE "snap[ _-]?tube|vidmate|tubemate|mobile ?tube|com\.snap" lib test android_files pubspec.yaml >/dev/null 2>&1; then bad "وُجد اسم تطبيق آخر"; else ok "لا أسماء تطبيقات أخرى"; fi

echo "2) أسرار وملفات توقيع"
if find . -name "*.jks" -o -name "*.keystore" -o -name "key.properties" | grep -q .; then bad "ملف توقيع/أسرار داخل المشروع (لا ترفعه إلى GitHub)"; else ok "لا مفاتيح داخل المشروع"; fi

echo "3) بقايا تطوير"
if grep -rnE "\bprint\(|debugPrint\(|TODO|FIXME" lib android_files >/dev/null 2>&1; then bad "print/TODO في الكود"; else ok "لا print ولا TODO"; fi

echo "4) ملفات لازمة"
for f in pubspec.yaml README_SETUP.md TEST_PLAN.md lib/main.dart android_files/kotlin/com/adel/adel_tube_downloader/YtDlpPlugin.kt; do
  [ -f "$f" ] && ok "$f" || bad "ناقص: $f"
done

echo "5) أدوات فلاتر"
if command -v flutter >/dev/null 2>&1; then
  flutter pub get && flutter analyze && flutter test && ok "analyze + test" || bad "analyze/test فشل"
else
  skip "flutter غير مثبت هنا: شغّل flutter analyze و flutter test على جهازك"
fi

echo; [ $fail -eq 0 ] && echo "النتيجة: جاهز (مع مراعاة ما تم تخطيه)" || echo "النتيجة: غير جاهز"
exit $fail
