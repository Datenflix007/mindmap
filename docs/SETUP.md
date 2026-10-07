# Einrichtung und Nutzung – Referentenleitfaden

## 1. Was du brauchst

- GitHub-Konto
- kostenloses Supabase-Projekt
- Internetzugang für die Workshopgeräte
- keinen lokalen Server und keine freigegebene IPv4-Adresse

Das Frontend liegt auf GitHub Pages. Die gemeinsam genutzten Sessiondaten liegen in Supabase.

---

## 2. Supabase einmalig einrichten

### 2.1 Projekt anlegen

1. Supabase öffnen und ein neues Projekt erstellen.
2. Projektname z. B. `jenacraft-mindmap`.
3. Ein starkes Datenbankpasswort vergeben und sicher speichern.
4. Warten, bis das Projekt bereit ist.

### 2.2 Datenbankstruktur installieren

1. Im Supabase Dashboard **SQL Editor** öffnen.
2. Den kompletten Inhalt von `sql/schema.sql` kopieren.
3. Als neues SQL-Skript einfügen.
4. **Run** ausführen.

Das Skript legt Tabellen und die sicheren RPC-Funktionen an. Browsernutzer bekommen keinen direkten Tabellenzugriff.

### 2.3 Project URL und Publishable Key eintragen

Im Supabase Dashboard den **Connect**-Dialog bzw. die API-Key-Einstellungen öffnen.

Benötigt werden:

- Project URL, z. B. `https://abcxyz.supabase.co`
- **Publishable Key**, beginnend etwa mit `sb_publishable_...`

Dann `assets/js/config.js` bearbeiten:

```js
window.APP_CONFIG = {
  SUPABASE_URL: "https://abcxyz.supabase.co",
  SUPABASE_PUBLISHABLE_KEY: "sb_publishable_..."
};
```

**Keinen Secret Key eintragen.**

---

## 3. GitHub Pages veröffentlichen

1. Neues GitHub-Repository anlegen, z. B. `jenacraft-mindmap`.
2. Den gesamten Inhalt dieses Ordners in das Repository hochladen.
3. In GitHub: **Settings → Pages**.
4. Unter **Build and deployment** als Source **GitHub Actions** auswählen.
5. Der enthaltene Workflow `.github/workflows/pages.yml` veröffentlicht die Seite bei jedem Push auf `main`.
6. Unter **Actions** warten, bis `Deploy GitHub Pages` grün ist.

Danach erhältst du eine URL wie:

```text
https://DEIN-NAME.github.io/jenacraft-mindmap/
```

---

# Vorbereitung vor dem Workshop

## 4. Referentenansicht öffnen

Auf der veröffentlichten Page:

```text
/moderator.html
```

öffnen.

Standardmäßig ist vorbereitet:

**Mindmap-Name:**

> Must haves und No Gos JenaCraft

**Äste:**

1. Must Haves
2. No Gos
3. Anmerkung
4. Gern besuchte Orte

Du kannst Titel und Äste vor dem Sessionstart beliebig ändern oder weitere Äste hinzufügen.

## 5. Session starten

Auf **„Session starten“** klicken.

Danach werden angezeigt:

- Session-Code
- Teilnehmerlink
- QR-Code
- Moderator-Schlüssel

### Moderator-Schlüssel sichern

Der Schlüssel wird lokal im Browser gespeichert. Kopiere ihn trotzdem zusätzlich in deine Notizen. Wenn du später einen anderen Rechner oder Browser verwendest, brauchst du:

- Session-Code
- Moderator-Schlüssel

um die Referentenansicht wieder zu öffnen.

---

# Nutzung mit Teilnehmenden

## 6. Beitritt

Zeige QR-Code oder Teilnehmerlink am Smartboard/Beamer.

Der Teilnehmerlink enthält bereits den Session-Code. Alternativ kann der Code manuell auf `participant.html` eingegeben werden.

## 7. Gruppennummer wählen

Vor der Bearbeitung erscheint ein Tastenfeld mit Gruppen 1–12.

Die ausgewählte Gruppennummer wird auf dem jeweiligen Gerät lokal gespeichert. Es werden keine Namen benötigt.

## 8. Beiträge erstellen

Links stehen die vom Referenten vorbereiteten Äste.

Ablauf:

1. Ast anklicken.
2. Text eingeben.
3. **„+ Hinzufügen“** drücken.
4. Einen vorhandenen Knoten anklicken, um darunter einen Unterpunkt zu ergänzen.
5. Eigene Knoten können bearbeitet oder gelöscht werden.

Andere Gruppen sind in dieser Arbeitsphase nicht sichtbar.

---

# #Collect und Plenum

## 9. Gesamtmindmap erzeugen

In der Referentenansicht auf:

> **#Collect · Gesamtmindmap**

klicken.

Alle Beiträge werden anhand der vorbereiteten Äste in einer gemeinsamen Mindmap dargestellt. Jeder Beitrag behält sein Gruppenlabel:

```text
Mehr Bäume auf dem Platz   G3
```

Mehrfach genannte Ideen bleiben zunächst getrennt. Dadurch ist sichtbar, welche Gruppen unabhängig zu ähnlichen Ergebnissen gekommen sind.

## 10. Einzelgruppen ansehen

Unter **Ansicht → Einzelne Gruppe** kann eine Gruppe separat eingeblendet werden.

## 11. Bearbeitung stoppen

Mit **„Session sperren“** können keine neuen Gruppenbeiträge mehr erstellt, verändert oder gelöscht werden.

Zum Weiterarbeiten erneut **„Session öffnen“** wählen.

---

# Auswertung

Unterhalb der Gesamtmindmap befindet sich eine Tabelle:

| Gruppe | Must Haves | No Gos | Anmerkung | Gern besuchte Orte | Gesamt |
|---|---:|---:|---:|---:|---:|
| Gruppe 1 | 4 | 2 | 1 | 3 | 10 |

Damit lässt sich schnell erkennen:

- welche Gruppen besonders viele Beiträge hatten,
- welche Äste stark oder schwach bearbeitet wurden,
- wo im Plenum noch Nachfragen sinnvoll sind.

Für eine Rohdatensicherung steht zusätzlich **JSON** zur Verfügung.

---

# Export

Die aktuell angezeigte Mindmap kann exportiert werden als:

- **SVG** – ideal für verlustfreie Weiterbearbeitung und große Ausdrucke
- **JPG** – praktisch für Präsentationen, LMS und einfache Bildablage
- **PDF** – gut für Dokumentation und Ausdruck
- **JSON** – vollständige Sessiondaten für spätere technische Auswertung

Der Export erfolgt vollständig im Browser.

---

# Empfohlener Workshopablauf

## Vorher

1. GitHub Page testen.
2. Supabase-Verbindung testen.
3. Template anpassen.
4. Session erstellen.
5. Moderator-Schlüssel sichern.
6. QR-Code auf Präsentationsfolie oder Smartboard bereithalten.

## Einstieg

1. Ziel der Mindmap erklären.
2. QR-Code zeigen.
3. Gruppen legen ihre Gruppennummer fest.
4. Kurzen Testeintrag durchführen lassen.

## Arbeitsphase

1. Gruppen arbeiten getrennt.
2. Referentenansicht offenlassen.
3. Statistik beobachten, ohne Inhalte vorzeitig im Plenum zu zeigen.

## Plenum

1. Session optional sperren.
2. `#Collect` drücken.
3. Äste gemeinsam durchgehen.
4. ähnliche oder gegensätzliche Beiträge diskutieren.

## Abschluss

1. Gesamtmindmap exportieren.
2. PDF/JPG für Dokumentation speichern.
3. JSON sichern, wenn die Daten später erneut ausgewertet werden sollen.

---

# Datenschutz / Praxishinweis

Das Modul verlangt standardmäßig keine personenbezogenen Angaben. Es speichert lediglich:

- Session
- Gruppennummer
- Mindmap-Ast
- Beitragstext
- technische Zeitstempel

Die Teilnehmenden sollten deshalb angewiesen werden, keine Namen oder andere personenbezogene Informationen in die Textfelder einzutragen.

---

# Fehlerdiagnose

## „Supabase ist noch nicht konfiguriert“

`assets/js/config.js` prüfen.

## Session wird nicht gefunden

- Code korrekt?
- SQL-Schema vollständig ausgeführt?
- richtige Supabase Project URL?

## Beiträge können nicht gespeichert werden

- Session gesperrt?
- Internetverbindung vorhanden?
- Browser-Konsole auf Fehler prüfen.

## GitHub Page ist noch nicht erreichbar

Unter **Actions** prüfen, ob `Deploy GitHub Pages` erfolgreich abgeschlossen wurde.
