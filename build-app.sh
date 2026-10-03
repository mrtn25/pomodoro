#!/bin/bash
# Builds PomodoroTimer.app into ./build and, with --install, copies it to ~/Applications.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="build/PomodoroTimer.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/PomodoroTimer" "$APP/Contents/MacOS/PomodoroTimer"
cp -R "Resources/Tomatoes" "$APP/Contents/Resources/Tomatoes"

# App icon from the happy tomato (Finder, Spotlight, Login Items).
ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
for size in 16 32 128 256; do
  sips -z $size $size "Resources/Tomatoes/happy.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  if [[ $double -le 256 ]]; then
    sips -z $double $double "Resources/Tomatoes/happy.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
  fi
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns" || echo "Hinweis: App-Icon übersprungen"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Pomodoro</string>
  <key>CFBundleDisplayName</key><string>Pomodoro</string>
  <key>CFBundleIdentifier</key><string>app.lifeassociate.pomodoro</string>
  <key>CFBundleExecutable</key><string>PomodoroTimer</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc signature: enough for a locally built app to launch.
codesign --force --sign - "$APP"
echo "Gebaut: $APP"

if [[ "${1:-}" == "--install" ]]; then
  mkdir -p "$HOME/Applications"
  # A running old version would otherwise keep running: quit it first.
  pkill -x PomodoroTimer && sleep 1 || true
  rm -rf "$HOME/Applications/PomodoroTimer.app"
  cp -R "$APP" "$HOME/Applications/"
  echo "Installiert: ~/Applications/PomodoroTimer.app"
  open "$HOME/Applications/PomodoroTimer.app"
fi
