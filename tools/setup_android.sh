#!/usr/bin/env bash
# يولّد مشروع أندرويد ويضيف إليه ملفات Kotlin والتعديلات. يعمل محلياً وفي GitHub Actions.
set -euo pipefail
cd "$(dirname "$0")/.."

KEEP=$(mktemp -d)
cp -r lib test "$KEEP"/ && cp pubspec.yaml "$KEEP"/

flutter create --org com.adel --project-name adel_tube_downloader --platforms android .

# أعد ملفاتنا (flutter create يولّد ملفات تجريبية)
rm -rf lib test
cp -r "$KEEP/lib" lib && cp -r "$KEEP/test" test && cp "$KEEP/pubspec.yaml" pubspec.yaml

KDIR=android/app/src/main/kotlin/com/adel/adel_tube_downloader
mkdir -p "$KDIR"
cp android_files/kotlin/com/adel/adel_tube_downloader/*.kt "$KDIR"/

python3 tools/patch_android.py
