#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
OUTPUT_DIR="$PROJECT_DIR/outputs"
APP_PATH="$OUTPUT_DIR/微信隐私守卫.app"
DMG_PATH="$OUTPUT_DIR/微信隐私守卫-1.3.1.dmg"
ZIP_PATH="$OUTPUT_DIR/微信隐私守卫-1.3.1.zip"
GUIDE_PATH="$OUTPUT_DIR/快速使用指南.pdf"

if [[ -e "$APP_PATH" || -e "$DMG_PATH" || -e "$ZIP_PATH" ]]; then
  print -u2 "输出文件已存在。请先移动旧版本，再重新构建。"
  exit 1
fi
if [[ ! -f "$GUIDE_PATH" ]]; then
  print -u2 "缺少快速使用指南：$GUIDE_PATH"
  exit 1
fi

cd "$PROJECT_DIR"
mkdir -p "$PROJECT_DIR/work/module-cache"
export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/work/module-cache"

xcrun clang -fobjc-arc -fmodules -O2 -mmacosx-version-min=13.0 \
  -framework AppKit \
  -framework AVFoundation \
  -framework Vision \
  -framework ServiceManagement \
  -framework CoreGraphics \
  -framework QuartzCore \
  "$PROJECT_DIR"/Sources/WeChatPrivacyGuard/*.m \
  -o "$PROJECT_DIR/work/WeChatPrivacyGuard"

mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$PROJECT_DIR/work/WeChatPrivacyGuard" "$APP_PATH/Contents/MacOS/WeChatPrivacyGuard"
cp "$PROJECT_DIR/Packaging/Info.plist" "$APP_PATH/Contents/Info.plist"
cp "$PROJECT_DIR/Packaging/AppIcon.icns" "$APP_PATH/Contents/Resources/AppIcon.icns"
chmod 755 "$APP_PATH/Contents/MacOS/WeChatPrivacyGuard"
codesign --force --deep --sign - "$APP_PATH"

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

STAGING_DIR="$(mktemp -d /tmp/wechat-privacy-guard.XXXXXX)"
trap 'rm -rf "$STAGING_DIR"' EXIT
cp -R "$APP_PATH" "$STAGING_DIR/微信隐私守卫.app"
cp "$GUIDE_PATH" "$STAGING_DIR/快速使用指南.pdf"
ln -s /Applications "$STAGING_DIR/Applications"
hdiutil create -quiet -volname "微信隐私守卫" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH"

print "构建完成："
print "$APP_PATH"
print "$DMG_PATH"
print "$ZIP_PATH"
