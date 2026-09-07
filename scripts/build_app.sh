#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
OUTPUT_DIR="$PROJECT_DIR/outputs"
APP_PATH="$OUTPUT_DIR/微信隐私守卫-1.4.0.app"
DMG_PATH="$OUTPUT_DIR/微信隐私守卫-1.4.0.dmg"
ZIP_PATH="$OUTPUT_DIR/微信隐私守卫-1.4.0.zip"
GUIDE_PATH="$OUTPUT_DIR/快速使用指南.pdf"
BACKGROUND_PATH="$PROJECT_DIR/Packaging/DMGBackground.png"
LAYOUT_PATH="$PROJECT_DIR/Packaging/DMGLayout.dsstore"
VOLUME_NAME="微信隐私守卫 1.4.0"
LAYOUT_VOLUME_TOKEN="${VOLUME_NAME##* }"

if [[ -e "$APP_PATH" || -e "$DMG_PATH" || -e "$ZIP_PATH" ]]; then
  print -u2 "输出文件已存在。请先移动旧版本，再重新构建。"
  exit 1
fi
if [[ ! -f "$GUIDE_PATH" ]]; then
  print -u2 "缺少快速使用指南：$GUIDE_PATH"
  exit 1
fi
if [[ ! -f "$BACKGROUND_PATH" ]]; then
  print -u2 "缺少 DMG 背景：$BACKGROUND_PATH"
  exit 1
fi
if [[ ! -f "$LAYOUT_PATH" ]] || \
  ! grep -a -q "DMGBackground.png" "$LAYOUT_PATH" || \
  ! grep -a -q "$LAYOUT_VOLUME_TOKEN" "$LAYOUT_PATH"; then
  print -u2 "缺少有效的 Finder 布局：$LAYOUT_PATH"
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
  -framework Security \
  -framework CoreGraphics \
  -framework CoreImage \
  -framework CoreML \
  -framework CoreVideo \
  -framework QuartzCore \
  "$PROJECT_DIR"/Sources/WeChatPrivacyGuard/*.m \
  -o "$PROJECT_DIR/work/WeChatPrivacyGuard"

mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$PROJECT_DIR/work/WeChatPrivacyGuard" "$APP_PATH/Contents/MacOS/WeChatPrivacyGuard"
cp "$PROJECT_DIR/Packaging/Info.plist" "$APP_PATH/Contents/Info.plist"
cp "$PROJECT_DIR/Packaging/AppIcon.icns" "$APP_PATH/Contents/Resources/AppIcon.icns"
cp -R "$PROJECT_DIR/Resources/Models/MobileFaceEmbedding.mlpackage" "$APP_PATH/Contents/Resources/"
cp "$PROJECT_DIR/THIRD_PARTY_NOTICES.md" "$APP_PATH/Contents/Resources/THIRD_PARTY_NOTICES.md"
cp "$PROJECT_DIR/ThirdPartyLicenses/Apache-2.0.txt" "$APP_PATH/Contents/Resources/Apache-2.0.txt"
chmod 755 "$APP_PATH/Contents/MacOS/WeChatPrivacyGuard"
codesign --force --deep --sign - "$APP_PATH"

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

STAGING_DIR="$(mktemp -d /tmp/wechat-privacy-guard-stage.XXXXXX)"
trap 'rm -rf "$STAGING_DIR"' EXIT

cp -R "$APP_PATH" "$STAGING_DIR/微信隐私守卫.app"
cp "$GUIDE_PATH" "$STAGING_DIR/快速使用指南.pdf"
ln -s /Applications "$STAGING_DIR/Applications"
mkdir -p "$STAGING_DIR/.background"
cp "$BACKGROUND_PATH" "$STAGING_DIR/.background/DMGBackground.png"
cp "$LAYOUT_PATH" "$STAGING_DIR/.DS_Store"

hdiutil create -quiet -volname "$VOLUME_NAME" -fs HFS+ -srcfolder "$STAGING_DIR" -ov -format UDZO -imagekey zlib-level=9 "$DMG_PATH"
hdiutil verify -quiet "$DMG_PATH"

print "构建完成："
print "$APP_PATH"
print "$DMG_PATH"
print "$ZIP_PATH"
