# Pomodoro 🍅 – Fokus-Timer für die macOS-Menüleiste

Eine kleine, eigenständige Mac-App: eine Tomate in der Menüleiste, ein Klick öffnet
den Timer. Für jede fertige Fokus-Session sammelst du eine Tomate und Punkte, je länger,
desto wertvoller. Danach startet automatisch eine 5-Minuten-Pause.

## Voraussetzung

macOS 13 oder neuer und die Xcode Command Line Tools (`xcode-select --install`).

## Bauen und starten

```bash
./build-app.sh --install
```

Das Skript baut die App, beendet die alte Version, installiert die neue nach
`~/Applications` und startet sie. Für einen schnellen Probelauf ohne App-Bundle
reicht `swift run`.

## Bedienung

- **Menüleiste:** eine Tomate, während einer Session zusätzlich die Restzeit.
- **Unten drei Knöpfe:** ✓ Aufgaben · ▶︎/❚❚ Start/Pause · 🍅 Sammlung.
  Ein zweiter Klick auf Aufgaben oder Sammlung führt zurück zum Timer.
- **Dauer:** Slider von 1 bis 60 min, darunter steht, welche Tomate diese Länge bringt.
  Er ist nur zwischen zwei Sessions sichtbar. In einer pausierten Session steht dort
  stattdessen „Session beenden“.
- **Ablauf:** Fokus → Ende-Sound → automatisch 5 min Pause (grün) → Sound →
  „Nächste Session starten“. Die Pause lässt sich überspringen.
- **Aufgaben:** Plane, was du in der nächsten Session machst. Die erste offene Aufgabe
  steht unter dem Timer.
- **Aufgaben-Check:** Nach einer fertigen Session fragt die App, welche der beim Start
  offenen Aufgaben erledigt sind. Pro bestätigter Aufgabe gibt es +10 Pkt, höchstens 3
  pro Session. Abhaken in der Liste selbst bringt nichts, und Aufgaben, die erst während
  der Session dazukommen, zählen nicht. So lohnt es sich nicht, Kleinkram abzuhaken.
- **Sounds:** „Pop“ beim Start, „Glass“ am Ende der Session, „Ping“ am Ende der Pause.
- **Schwebendes Fenster:** die Nadel oben rechts im Menü. Das Fenster liegt über allen
  Apps, lässt sich frei größer ziehen und mit ⌃ auf eine Zeile einklappen.
  Schließen geht über das •••-Menü.
- **Beim Login starten:** Systemeinstellungen → Allgemein → Anmeldeobjekte →
  `PomodoroTimer.app` hinzufügen.

## Sammlung und Kalender

Der 🍅-Knopf zeigt den Tag: Punkte, Fokuszeit und die heute gesammelten Tomaten. Die
Tomaten fangen jeden Tag wieder bei null an. Daneben stehen die Gesamtwerte über alle
Tage. Darunter liegt ein Monatskalender: Tage mit Punkten sind rot eingefärbt, je mehr
Punkte, desto kräftiger. Ein Klick auf einen Tag zeigt dessen Werte.

## Tomaten

| Tomate | Session ab | Punkte |
|---|---|---|
| Zen | 5 min | 5 |
| Fröhlich | 10 min | 10 |
| Verliebt | 15 min | 20 |
| Fokus | 25 min | 35 |
| Cool | 30 min | 50 |
| Ninja | 40 min | 75 |
| Aufsteiger | 50 min | 100 |
| König | 60 min | 150 |

Maßgeblich ist die eingestellte Dauer einer **fertig gelaufenen** Session. Du bekommst
die wertvollste Tomate, deren Mindestdauer du erreichst. Abgebrochene Sessions werden
protokolliert, bringen aber nichts.

## Daten

- Sessions: `~/Library/Application Support/PomodoroTimer/sessions.json`
  (Start, Ende, Dauer, Fokuszeit, App-Wechsel, Tomate, geplante und erledigte Aufgaben)
- Aufgaben, Timer-Stand und Fensterposition: in den UserDefaults der App

## App-Wechsel und Ausblick

Während der Timer läuft, zählt die App, wie oft eine andere App nach vorne kommt.
Dafür braucht sie keine Berechtigung, denn sie hört nur auf die App-Wechsel-Ereignisse
von macOS und schaut nie auf den Bildschirm. Die Zahl steht nach jeder Session unter
der Tomate.

Der nächste Schritt wäre eine Auswertung, *welche* Apps und Fenster das waren. Für die
Fenstertitel braucht die App die Bedienungshilfen-Berechtigung, fürs Erkennen des
Bildschirminhalts die Bildschirmaufnahme-Berechtigung.
