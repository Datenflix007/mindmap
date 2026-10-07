# JenaCraft Collaborative Mindmap

Browserbasierte Gruppen-Mindmap für Workshops. Das Frontend läuft vollständig über **GitHub Pages**; für die gemeinsamen Daten wird ein **Supabase-Projekt** genutzt. Es ist keine lokale IPv4-Adresse, kein eigener Server und keine Installation auf Teilnehmergeräten nötig.

## Enthalten

- Referentenansicht zur Vorbereitung und Session-Erstellung
- Standardtemplate **„Must haves und No Gos JenaCraft“**
  - Must Haves
  - No Gos
  - Anmerkung
  - Gern besuchte Orte
- frei bearbeitbare Äste vor Sessionstart
- Session-Code + Teilnehmerlink + QR-Code
- Gruppenauswahl über Tastenfeld
- getrennte Gruppen-Mindmaps
- verschachtelte Knoten / Unterpunkte
- `#Collect` für die zusammengeführte Gesamtmindmap
- Gruppenlabels `G1`, `G2`, … in der Gesamtansicht
- Live-Aktualisierung durch Polling
- Session sperren/öffnen
- Auswertung pro Gruppe und Ast
- Export als SVG, JPG, PDF und JSON
- responsives Klima-Labor-Farbset
- keine Namen, E-Mails oder Teilnehmerkonten erforderlich

## Schnellstart

Die ausführliche Anleitung steht in [`docs/SETUP.md`](docs/SETUP.md).

Kurzfassung:

1. kostenloses Supabase-Projekt anlegen
2. `sql/schema.sql` im Supabase SQL Editor ausführen
3. Project URL + **Publishable Key** in `assets/js/config.js` eintragen
4. dieses Verzeichnis in ein GitHub-Repository pushen
5. GitHub → Settings → Pages → Source: **GitHub Actions**
6. Workflow abwarten und Page öffnen
7. `moderator.html` öffnen und Session starten

## Sicherheit

Im Frontend steht **nur** der Supabase Publishable Key. Das ist für Browseranwendungen vorgesehen. Der Supabase Secret Key gehört **niemals** in dieses Repository oder in JavaScript. Tabellen sind für `anon` und `authenticated` direkt gesperrt; die Web-App arbeitet nur mit den in `schema.sql` definierten RPC-Funktionen.

Die Gruppennummer ist bewusst eine niederschwellige Workshop-Identität, kein sicheres Benutzerkonto. Wer Session-Code und Gruppennummer kennt und die API manuell anspricht, könnte theoretisch innerhalb dieser Gruppe schreiben. Für ein schulisches Workshopsetting ohne personenbezogene Daten ist das meist angemessen. Für prüfungsrelevante oder sensible Daten sollte echte Authentifizierung ergänzt werden.

## Projektstruktur

```text
.
├── index.html
├── participant.html
├── moderator.html
├── assets/
│   ├── css/style.css
│   └── js/
│       ├── config.js
│       ├── supabase-client.js
│       ├── common.js
│       ├── participant.js
│       └── moderator.js
├── sql/schema.sql
├── docs/SETUP.md
└── .github/workflows/pages.yml
```

## Hinweis zu externen Bibliotheken

Die Page lädt `@supabase/supabase-js`, `qrcodejs` und `jsPDF` über jsDelivr. Damit müssen die Workshopgeräte lediglich Internetzugriff auf die GitHub Page und diese CDN-Ressourcen haben.


## Session zurücksetzen

Die Referentenansicht enthält **„Auf Vorlage zurücksetzen“**. Beim JenaCraft-Template werden alle Beiträge gelöscht und Titel sowie Standardäste wiederhergestellt; bei eigenen Templates werden die Beiträge gelöscht und die Aststruktur bleibt erhalten.

## Session-Lifecycle und temporäre Datenhaltung

Supabase ist ausschließlich ein temporärer Kollaborationsspeicher. Beim Start einer Session merkt sich die Referentenansicht Session-Code und Moderator-Token ausschließlich im `localStorage` des verwendeten Browsers. Ein Reload, das Schließen des Browsers oder ein späteres Wiederöffnen erzeugt deshalb keine neue Session: Die Ansicht bietet an, die vorhandene Session fortzusetzen.

Eine Session wird nur durch **„Session beenden“** unmittelbar aus Supabase entfernt. Der Dialog bietet vorher einen JSON-Export an. Die Löschung ist über den Moderator-Token abgesichert; durch die vorhandenen `ON DELETE CASCADE`-Beziehungen werden zugehörige Äste und Knoten mit entfernt. Ist ein lokaler Verweis nach einer manuellen Löschung oder Bereinigung nicht mehr gültig, kann er ohne technischen Fehler entfernt oder ein JSON-Backup importiert werden.

## JSON-Backup und Wiederherstellung

**JSON sichern** erzeugt ein vollständiges, wiederherstellbares Backup mit Titel, Vorlage, Layout, Exportrecht, Astfarben, Ästen, Knoten, Gruppen und Eltern-Kind-Beziehungen. Es enthält ausdrücklich **keinen** Moderator-Token, keinen Secret Hash, keine API-Schlüssel und keine anderen Zugangsdaten.

Über **„JSON-Arbeitsstand importieren“** wird die Datei zunächst geprüft und mit Titel, Anzahl der Äste, Gruppen und Beiträge vorgeschaut. Beim Wiederherstellen entsteht immer eine neue Session mit neuem Code, neuem Moderator-Token und neuen Datenbank-IDs. Das verhindert, dass eine gelöschte Session technisch reaktiviert werden kann.

## Automatische Bereinigung nach 30 Tagen

Die Standard-Aufbewahrungsdauer beträgt **30 Tage**. `sql/schema.sql` definiert die nicht öffentlich erreichbare Funktion `cleanup_old_mindmap_sessions()`. Das ergänzende, separat auszuführende Skript [`sql/cron.sql`](sql/cron.sql) aktiviert Supabase Cron und plant die Bereinigung täglich um 03:30 UTC.

Für eine andere Frist wird in `sql/schema.sql` der zentrale Ausdruck `interval '30 days'` angepasst, zum Beispiel zu `interval '7 days'`, `interval '14 days'` oder `interval '90 days'`, und anschließend das Schema erneut ausgeführt. Die reguläre, bewusste Session-Löschung ist unabhängig davon sofort wirksam. GitHub Actions ist höchstens ein Fallback: Es bräuchte einen privilegierten Supabase-Schlüssel als GitHub Secret und ist daher nicht der Standardweg.
