#!/usr/bin/env bash
#
# build-rro-overlay-apk.sh —— 构建一个运行时 RRO overlay APK（实验用，不保证可安装）。
#
# 用途：验证"能不能在不改 ROM 的情况下，用运行时 RRO 覆盖 framework 资源"，
# 例如 config_showNavigationBar=false。若系统拒绝安装（缺少 overlayable 声明），
# 说明导航栏隐藏必须走 ROM 静态 overlay（见 docs/08）。
#
# 用法：
#   bash .github/scripts/build-rro-overlay-apk.sh <overlay_dir> <apk_name>
#   overlay_dir 需包含 AndroidManifest.xml 与 res/
set -euo pipefail

OVERLAY_DIR="${1:?用法: build-rro-overlay-apk.sh <overlay_dir> <apk_name>}"
APK_NAME="${2:?缺少 apk 名称}"
OUT_DIR="${3:-out/apks}"

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
    echo "ERROR: build-tools 未找到" >&2
    exit 1
fi

WORK="$OUT_DIR/build-$APK_NAME"
rm -rf "$WORK"
mkdir -p "$WORK" "$OUT_DIR"

echo "[1/4] aapt2 compile"
"$BT/aapt2" compile --dir "$OVERLAY_DIR/res" -o "$WORK/res.zip"

echo "[2/4] aapt2 link"
"$BT/aapt2" link \
    -o "$WORK/base.apk" \
    -I "$PLATFORM" \
    --manifest "$OVERLAY_DIR/AndroidManifest.xml" \
    --min-sdk-version 28 \
    --target-sdk-version 35 \
    --auto-add-overlay \
    -R "$WORK/res.zip"

echo "[3/4] zipalign"
"$BT/zipalign" -f 4 "$WORK/base.apk" "$WORK/aligned.apk"

echo "[4/4] apksigner"
keytool -genkeypair \
    -keystore "$WORK/debug.keystore" \
    -storepass android -keypass android \
    -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
"$BT/apksigner" sign \
    --ks "$WORK/debug.keystore" \
    --ks-pass pass:android --key-pass pass:android \
    --out "$OUT_DIR/${APK_NAME}.apk" \
    "$WORK/aligned.apk"
"$BT/apksigner" verify --verbose "$OUT_DIR/${APK_NAME}.apk" | head -n 5
sha256sum "$OUT_DIR/${APK_NAME}.apk"
echo "OK: $OUT_DIR/${APK_NAME}.apk"
