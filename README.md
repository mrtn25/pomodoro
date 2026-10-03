# Pomodoro 🍅 – Fokus-Timer für die macOS-Menüleiste

Eine kleine, eigenständige Mac-App: eine Tomate in der Menüleiste, ein Klick öffnet
den Timer. Für jede Fokus-Session sammelst du eine Tomate, je länger, desto seltener.

## Voraussetzung

macOS 13 oder neuer und die Xcode Command Line Tools (`xcode-select --install`).

## Bauen und starten

```bash
cd macos/PomodoroTimer
./build-app.sh --install
```

Das Skript baut die App, beendet die alte Version, installiert die neue nach
`~/Applications` und startet sie. Für einen schnellen Probelauf ohne App-Bundle
reicht `swift run`.

## Bedienung

- **Menüleiste:** eine Tomate, während einer Session zusätzlich die Restzeit.
- **Unten drei Knöpfe:** ✓ Aufgaben · ▶︎/❚❚ Start/Pause · 🍅 Sammlung.
  Ein zweiter Klick auf Aufgaben oder Sammlung führt zurück zum Timer.
- **Dauer:** Slider von 1 bis 60 min. Er ist nur zwischen zwei Sessions sichtbar.
  In einer pausierten Session steht dort stattdessen „Session beenden“.
- **Aufgaben:** Plane, was du in der nächsten Session machst. Die erste offene Aufgabe
  steht unter dem Timer.
- **Sounds:** „Pop“ beim Start, „Glass“ am Ende.
- **Schwebendes Fenster:** die Nadel oben rechts im Menü. Das Fenster liegt über allen
  Apps, lässt sich frei größer ziehen und mit ⌃ auf eine Zeile einklappen.
  Schließen geht über das •••-Menü.
- **Beim Login starten:** Systemeinstellungen → Allgemein → Anmeldeobjekte →
  `PomodoroTimer.app` hinzufügen.

## Tomaten

| Tomate | So bekommst du sie |
|---|---|
| Verwirrt | Session unter 5 min beenden |
| Schläfrig | 5–9 min |
| Zen | 10–14 min |
| Fröhlich | 15–19 min |
| Verliebt | 20–24 min |
| Fokus | 25–29 min |
| Cool | 30–39 min |
| Ninja | 40–49 min |
| Aufsteiger | 50–59 min |
| König | volle 60 min |
| Wütend | Session nach mindestens 5 min abbrechen |
| Erschöpft | an einem Tag 4 h Fokus erreichen (zusätzlich) |

Maßgeblich ist die eingestellte Dauer einer **fertig gelaufenen** Session.

## Daten

- Sessions: `~/Library/Application Support/PomodoroTimer/sessions.json`
  (Start, Ende, Dauer, Fokuszeit, App-Wechsel, Tomaten, Aufgabe)
- Aufgaben, Timer-Stand und Fensterposition: in den UserDefaults der App

## App-Wechsel und Ausblick

Während der Timer läuft, zählt die App, wie oft eine andere App nach vorne kommt.
Dafür braucht sie keine Berechtigung, denn sie hört nur auf die App-Wechsel-Ereignisse
von macOS und schaut nie auf den Bildschirm. Die Zahl steht nach jeder Session unter
der Tomate.

Der nächste Schritt wäre eine Auswertung, *welche* Apps und Fenster das waren. Für die
Fenstertitel braucht die App die Bedienungshilfen-Berechtigung, fürs Erkennen des
Bildschirminhalts die Bildschirmaufnahme-Berechtigung.
