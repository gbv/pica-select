# pica-select

> API und Webformular zur Abfrage von Daten aus PICA-Datenbanken

Inspiriert von <https://deutsche-nationalbibliothek-dnblab-dnb-testabfrage-x7jfa9.streamlitapp.com/> und dem Excel-Export Plugin von WinIBW3 (siehe <https://wiki.k10plus.de/display/K10PLUS/Excel-Tabelle+erstellen>).

## Installation und Konfiguration

### Backend

Es empfiehlt sich, Perl-Module vorab als Debian-Paket zu installieren (als root). Zumindest `starman` sollte als Systempaket installiert sein:

    sudo apt-get install libcatmandu-sru-perl libplack-perl starman

Der Dienst kann grundsätzlich als beliebiger Nutzer laufen, es empfiehlt sich aber ein spezieller Account:

    sudo adduser --home /srv/pica-select pica-select --disabled-password
    sudo -iu pica-select
    git clone --bare https://github.com/gbv/pica-select.git .git
    git config --unset core.bare
    git checkout

Die noch fehlenden Perl-Module werden in `./local` installiert:

    make deps

Der Dienst kann nun testweise auf Port :5000 gestartet werden:

    make run

Zur Entwicklung sollten stattdessen Frontend und Backend zusammen dynamisch gestartet werden:

    make dev

Zur dauerhaften Installation als Service gibt es verschiedene Möglichkeiten, diesen Aufruf dauerhaft, d.h. beim Booten und nach Absturz des Dienst, einzurichten. Die Datei `pica-select.service` enthält ein Beispiel für Systemd. Die Datei setzt vorraus, dass der Coverdienst in `/srv/pica-select` als Benutzer `pica-select` installiert ist (muss je nach Installation angepasst werden):

    sudo cp pica-select.service /etc/systemd/system
    sudo systemctl enable pica-select
    sudo systemctl start pica-select

## Benutzung

### API

#### GET /

An der Basis-URL des Webservice wird der Client in Form von statischen HTML, CSS und JavaScript-Dateien ausgeliefert.

#### GET /status

Liefert die Konfiguration des Webservice in JSON.

#### GET /select

Abfrage von Daten aus einem PICA-Katalog mit folgenden Abfrage-Parametern:

- `db` (optional) Datenbankkürzel (siehe <http://uri.gbv.de/database/>)
- `query` (notwendig) Abfrage in CQL-Syntax
- `format` (optional) Gewünschtes Rückgabeformat
- `reduce` (optional) Liste von auszuwählenden PICA-Feldern als [PICA Path]-Ausdrücke
- `select` (optional)
- `levels` (optional)
- `separator` (optional)

[PICA Path]: https://format.gbv.de/query/picapath

## Entwicklung

Der Webservice ist in Perl und JavaScript entwickelt.

## Client

## Project Setup

```sh
npm install
```

### Compile and Hot-Reload for Development

```sh
npm run dev
```

### Compile and Minify for Production

```sh
npm run build
```

### Lint with [ESLint](https://eslint.org/)

```sh
npm run lint
```
