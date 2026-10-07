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
