# JenaCraft MindMap – Erweiterung

## Session-Lifecycle, Backup und Datenbereinigung

- [x] Bestehenden Session-Lifecycle und Kaskaden prüfen
- [x] Reload-Wiederherstellung und aktive Session-Hinweis umsetzen
- [x] Bewusstes Session-Ende mit sicherer Löschung umsetzen
- [x] JSON-Backupformat vollständig machen
- [x] JSON-Validierung und Vorschau umsetzen
- [x] JSON-Restore mit neuen IDs und Parent-Mapping umsetzen
- [x] Cleanup-RPC und idempotentes Supabase-Cron-Skript ergänzen
- [x] Ablaufdatum und Fehlerfall gelöschter Session darstellen
- [x] README und Setup-Dokumentation ergänzen
- [x] Sicherheits- und Regressionstests durchführen

- [x] Header umbenennen
- [x] Session-Schema erweitern
- [x] Moderator-RPC erweitern
- [x] Exportberechtigung Teilnehmer
- [x] UI-Einstellungen Referent
- [x] Root links
- [x] Root rechts
- [x] Root oben
- [x] Root unten
- [x] Root Mitte / radial
- [x] vertikale Titelorientierung
- [x] dynamische Knotenhöhen
- [x] lange Texte und URLs
- [x] Vollbildmodus
- [x] Zoom/Fit
- [x] Export aktualisieren
- [x] Teilnehmeransicht aktualisieren
- [ ] Responsive Tests (Browserinstanz nicht verfügbar)
- [x] Regressionstest (Syntax, Diff und SVG-Layoutfälle)

## Abschlussbericht

## Geänderte Dateien

- `moderator.html`, `participant.html`, `assets/css/style.css`
- `assets/js/common.js`, `assets/js/moderator.js`, `assets/js/participant.js`
- `sql/schema.sql`

## Datenbankänderungen

Neue Sessionfelder für Exportrecht, Root-Position und Titelorientierung sowie die gesicherte RPC `update_session_settings`.

## Neue Funktionen

Fünf Root-Layouts, radialer Mittelmodus, gedrehter Root-Titel, automatische Textumbruch- und Kartenhöhen, Teilnehmer-Exportrecht, Vollbild sowie Zoom-Steuerung.

## Getestete Layouts

Automatischer SVG-Test für links, rechts, oben, unten und Mitte mit sieben Ästen, langem Text und langer URL. JavaScript-Syntax und Git-Diff-Check sind fehlerfrei.

## Bekannte Einschränkungen

Eine visuelle Prüfung auf Desktop, Tablet und Smartphone konnte in dieser Umgebung nicht laufen, weil keine Browserinstanz verfügbar war.

## Manuell in Supabase auszuführen

`sql/schema.sql` einmal vollständig im Supabase SQL Editor ausführen. Das Skript ist additiv und löscht keine bestehenden Sessions oder Beiträge.
