# pica-select

> Webformular zur Abfrage von Daten aus PICA-Datenbanken

Siehe <https://deutsche-nationalbibliothek-dnblab-dnb-testabfrage-x7jfa9.streamlitapp.com/>

## Installation und Konfiguration

Es empfiehlt sich, Perl-Module vorab als Debian-Paket zu installieren (als root). Zumindest `starman` sollte als Systempaket installiert sein:

    sudo apt-get install libcatmandu-sru-perl libplack-perl starman

Der Dienst kann grundsätzlich als beliebiger Nutzer laufen, es empfiehlt sich aber ein spezieller Account:

    sudo adduser --home /srv/sru-select sru-select --disabled-password
    sudo -iu sru-select
    git clone --bare https://github.com/gbv/sru-select.git .git
    git config --unset core.bare
    git checkout

Die noch fehlenden Perl-Module werden in `./local` installiert:

    make deps

Der Dienst kann nun testweise auf Port :5000 gestartet werden:

    make run

Zur dauerhaften Installation als Service gibt es verschiedene Möglichkeiten, diesen Aufruf dauerhaft, d.h. beim Booten und nach Absturz des Dienst, einzurichten. Die Datei `sru-select.service` enthält ein Beispiel für Systemd. Die Datei setzt vorraus, dass der Coverdienst in `/srv/sru-select` als Benutzer `sru-select` installiert ist (muss je nach Installation angepasst werden):

    sudo cp sru-select.service /etc/systemd/system
    sudo systemctl enable sru-select
    sudo systemctl start sru-select

