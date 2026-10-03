#!/bin/bash
# Builds PomodoroTimer.app into ./build and, with --install, copies it to ~/Applications.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="build/PomodoroTimer.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp ".build/release/PomodoroTimer" "$APP/Contents/MacOS/PomodoroTimer"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Pomodoro</string>
  <key>CFBundleDisplayName</key><string>Pomodoro</string>
  <key>CFBundleIdentifier</key><string>app.lifeassociate.pomodoro</string>
  <key>CFBundleExecutable</key><string>PomodoroTimer</string>
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
  rm -rf "$HOME/Applications/PomodoroTimer.app"
  cp -R "$APP" "$HOME/Applications/"
  echo "Installiert: ~/Applications/PomodoroTimer.app"
  open "$HOME/Applications/PomodoroTimer.app"
fi
