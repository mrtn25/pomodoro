# Pomodoro für die macOS-Menüleiste

Eigenständige kleine Mac-App, unabhängig von der Web-App: Der Countdown steht in
der Menüleiste, ein Klick darauf öffnet die Steuerung. Wenn du willst, schwebt der
Timer zusätzlich als kleines Fenster über allen Apps und Spaces.

## Voraussetzung

macOS 13 oder neuer und die Xcode Command Line Tools (`xcode-select --install`).
Die volle Xcode-App ist optional.

## Bauen und starten

```bash
cd macos/PomodoroTimer
./build-app.sh --install     # baut, kopiert nach ~/Applications und startet
```

Für einen schnellen Probelauf ohne App-Bundle reicht `swift run`.
In Xcode: `Package.swift` öffnen und auf ▶ klicken.

## Bedienung

- **Menüleiste:** Timer-Symbol, solange er läuft die Restzeit (`24:57`).
- **Klick:** Fokus 25 min / Pause 5 min, Start/Pause (auch mit der Leertaste) und Zurücksetzen.
- **Schwebendes Fenster:** Schalter im Menü. Das Fenster bleibt über allen Apps,
  lässt sich verschieben und merkt sich seine Position.
- **Ablauf:** Ton „Glass“. Der Timer läuft über Ruhezustand und Neustart der App hinweg weiter.
- **Beim Login starten:** Systemeinstellungen → Allgemein → Anmeldeobjekte →
  `PomodoroTimer.app` hinzufügen.
