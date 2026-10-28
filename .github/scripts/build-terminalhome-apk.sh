#!/usr/bin/env bash
#
# build-terminalhome-apk.sh —— 用 Android SDK 命令行工具构建 TerminalHome 的
# 可安装 debug 签名 APK（不需要 Soong/整包源码树，免费 GitHub runner 即可）。
#
# 用法（工作目录 = 项目仓库根）：
#   bash .github/scripts/build-terminalhome-apk.sh [SRC_DIR] [OUT_DIR]
#   默认 SRC_DIR=packages/apps/TerminalHome（如用源码树，可指向该路径）
#   默认 OUT_DIR=out/apks
#
# 环境要求：ANDROID_HOME 或 ANDROID_SDK_ROOT 指向 SDK；
#           platforms/android-35/android.jar 与 build-tools/<ver> 已安装；JDK 17。
set -euo pipefail

SRC_DIR="${1:-packages/apps/TerminalHome}"
OUT_DIR="${2:-out/apks}"

SDK_ROOT="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [[ -z "$SDK_ROOT" ]]; then
    echo "ERROR: ANDROID_HOME / ANDROID_SDK_ROOT 未设置" >&2
    exit 1
fi
PLATFORM="$SDK_ROOT/platforms/android-35/android.jar"
BT=""
for candidate in "$SDK_ROOT"/build-tools/*; do
    [[ -d "$candidate" ]] && BT="$candidate"
done
if [[ -z "$BT" || ! -x "$BT/aapt2" ]]; then
    echo "ERROR: build-tools 未找到（$SDK_ROOT/build-tools）" >&2
    exit 1
fi
if [[ ! -f "$PLATFORM" ]]; then
    echo "ERROR: android.jar 未找到：$PLATFORM" >&2
    exit 1
fi

WORK="$OUT_DIR/build-terminalhome"
rm -rf "$WORK"
mkdir -p "$WORK/res" "$WORK/gen" "$WORK/classes" "$WORK/dex" "$OUT_DIR"

echo "[1/7] aapt2 compile"
"$BT/aapt2" compile --dir "$SRC_DIR/res" -o "$WORK/res.zip"

echo "[2/7] aapt2 link"
"$BT/aapt2" link \
    -o "$WORK/base.apk" \
    -I "$PLATFORM" \
    --manifest "$SRC_DIR/AndroidManifest.xml" \
    --java "$WORK/gen" \
    --min-sdk-version 28 \
    --target-sdk-version 35 \
    --version-code 1 \
    --version-name 0.1.0 \
    "$WORK/res.zip"

echo "[3/7] collect java sources"
find "$SRC_DIR/src" "$WORK/gen" -name '*.java' | sort > "$WORK/sources.txt"
wc -l < "$WORK/sources.txt"

echo "[4/7] javac"
javac -source 11 -target 11 \
    -classpath "$PLATFORM" \
    -d "$WORK/classes" \
    @"$WORK/sources.txt"

echo "[5/7] d8"
find "$WORK/classes" -name '*.class' | sort > "$WORK/classes.txt"
"$BT/d8" --lib "$PLATFORM" --min-api 28 --output "$WORK/dex" @"$WORK/classes.txt"

echo "[6/7] package + zipalign"
cp "$WORK/dex/classes.dex" "$WORK/classes.dex"
(
    cd "$WORK"
    zip -q base.apk classes.dex
)
"$BT/zipalign" -f 4 "$WORK/base.apk" "$WORK/aligned.apk"

echo "[7/7] apksigner"
keytool -genkeypair \
    -keystore "$WORK/debug.keystore" \
    -storepass android -keypass android \
    -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
"$BT/apksigner" sign \
    --ks "$WORK/debug.keystore" \
    --ks-pass pass:android --key-pass pass:android \
    --out "$OUT_DIR/TerminalHome.apk" \
    "$WORK/aligned.apk"
"$BT/apksigner" verify --verbose "$OUT_DIR/TerminalHome.apk" | head -n 5
sha256sum "$OUT_DIR/TerminalHome.apk"
echo "OK: $OUT_DIR/TerminalHome.apk"
