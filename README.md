# dotfiles

Shell-Konfiguration und Paketlisten für meine Maschinen. Ein Script erkennt das
Betriebssystem und installiert, was dort relevant ist.

## Installation

**Direkt aus dem Netz** — das Script holt sich das Repo selbst:

```bash
curl -fsSL https://raw.githubusercontent.com/RedEagle-dh/dotfiles/main/install.sh | bash
```

Optionen werden nach `-s --` durchgereicht:

```bash
curl -fsSL https://raw.githubusercontent.com/RedEagle-dh/dotfiles/main/install.sh | bash -s -- --extra
```

**Oder manuell klonen** — identisches Ergebnis:

```bash
git clone https://github.com/RedEagle-dh/dotfiles.git ~/developer/dotfiles
~/developer/dotfiles/install.sh
```

Beide Wege sind idempotent; mehrfaches Ausführen ist unschädlich. Liegt das Repo
schon da, wird es aktualisiert statt neu geklont. Vorhandene Dateien werden nie
überschrieben, sondern nach `~/.dotfiles-backup/<zeitstempel>/` verschoben.

## Optionen

| Flag | Wirkung |
|---|---|
| `--extra` | Zusatz-Pakete mitinstallieren (GUI-Apps, schwere Toolchains) |
| `--desktop` | Desktop-Umgebung mitinstallieren (nur Linux/Hyprland) |
| `--upgrade` | vorhandene Pakete aktualisieren — sonst wird nur Fehlendes nachinstalliert |
| `--dry-run` | nichts verändern, nur anzeigen |
| `--no-link` | Symlinks überspringen |
| `--no-packages` | Paketinstallation überspringen |
| `--no-shell` | Login-Shell nicht auf zsh umstellen und nicht hineinwechseln |

`--upgrade` ist bewusst **nicht** der Standard: auf einer eingerichteten Maschine
zieht ein vollständiges Brew-Upgrade schnell dutzende Pakete hoch und kann
Toolchains unter den Füßen wegziehen.

### Umgebungsvariablen

| Variable | Standard | Zweck |
|---|---|---|
| `DOTFILES_DIR` | `~/developer/dotfiles` | Zielverzeichnis |
| `DOTFILES_REPO` | `RedEagle-dh/dotfiles` | Repo als `owner/name` |
| `DOTFILES_BRANCH` | `main` | Branch |
| `DOTFILES_REMOTE` | `https://github.com/<repo>.git` | vollständige Clone-URL (Fork, SSH, Test) |

```bash
DOTFILES_DIR=~/dev/dotfiles ./install.sh          # anderes Zielverzeichnis
DOTFILES_REMOTE=git@github.com:me/dotfiles.git ./install.sh   # via SSH
```

## Login-Shell

Zum Schluss stellt `install.sh` zsh als Login-Shell ein und **wechselt direkt
hinein** — kein Aus- und Wiedereinloggen nötig. `exit` bringt dich zurück in die
vorherige Shell.

Das ist vor allem auf Linux relevant: macOS nutzt zsh seit Catalina ohnehin,
Debian und Raspberry Pi OS starten dagegen mit bash. Ohne diesen Schritt liegen
die Symlinks zwar richtig, werden aber von niemandem gelesen.

Im Einzelnen:

- `chsh` auf das gefundene `zsh`, aber nur wenn es nicht ohnehin schon gesetzt ist
- fehlt der Pfad in `/etc/shells`, wird er vorher ergänzt — `chsh` akzeptiert
  sonst nichts, was dort nicht steht (betrifft zsh aus Homebrew)
- scheitert `chsh` an der PAM-Konfiguration, folgt ein Versuch über `sudo`;
  klappt auch das nicht, gibt es den fertigen Befehl zum Selbstausführen
- der abschließende Wechsel unterbleibt ohne echtes Terminal (CI, Docker-Build)
  und wenn der Aufruf ohnehin schon aus einer zsh kommt

Mit `--no-shell` bleibt beides aus.

## Aufbau

```
install.sh              Einstiegspunkt: Bootstrap, OS-Erkennung, Symlinks, Pakete
lib/common.sh           Logging, Symlink-Helfer mit Backup, OS-Erkennung
lib/macos.sh            Homebrew + Brewfiles
lib/linux.sh            apt- und pacman-Zweig, Extras, Desktop-Hook
linux/pkglist.apt       Paketliste Debian/Ubuntu/Raspberry Pi OS
linux/pkglist.pacman    Paketliste Arch
macos/Brewfile.core     CLI-Basis — immer
macos/Brewfile.extra    GUI-Apps, schwere Toolchains — nur mit --extra
zsh/.zshrc              interaktive Shell
zsh/.zprofile           Login-Shell
zsh/scripts/*.zsh       eigene Funktionen, werden automatisch geladen
```

## Wie der Bootstrap funktioniert

`install.sh` prüft, ob es neben einem `lib/common.sh` und einem `zsh/` liegt.

- **Ja** → es läuft aus einem Clone und legt direkt los.
- **Nein** → es wurde gepiped oder einzeln kopiert, klont das Repo nach
  `$DOTFILES_DIR` und übergibt per `exec` an die geklonte Fassung.

Fehlt `git` — frischer Mac ohne Command Line Tools —, lädt es stattdessen einen
Tarball. Das funktioniert, kostet aber die Historie; das Script weist darauf hin.

Beim Pipen hängt `stdin` an der Pipe. Vor dem `exec` wird deshalb auf `/dev/tty`
umgelenkt, damit Rückfragen (Homebrew-Installer, `sudo`) noch Eingaben bekommen.
Wo sich kein Terminal öffnen lässt — CI, Docker-Build — unterbleibt das.

## Symlinks statt Kopien

```
~/.zshrc     -> zsh/.zshrc
~/.zprofile  -> zsh/.zprofile
~/.scripts   -> zsh/scripts
```

Bearbeiten lässt sich beides — Repo und `~` sind dieselbe Datei, `git status`
zeigt Änderungen sofort. `~/.scripts` ist als *Verzeichnis* verlinkt: ein neues
Skript im Repo ist ohne erneutes `install.sh` aktiv.

## Was die zsh-Konfiguration mitbringt

Prompt über [starship](https://starship.rs), Verzeichnissprünge über `zoxide`,
`Ctrl-R` über `fzf`, Laufzeitversionen über `mise`, projektweise Umgebungen über
`direnv`. Dazu `zsh-autosuggestions` (History-Vorschläge inline) und
`zsh-syntax-highlighting` (Tippfehler vor dem Enter sichtbar).

Bewusste Entscheidungen:

- **Kein `alias grep=rg`.** `rg` ist nicht flag-kompatibel: `-r` heißt Replace
  statt Recursive, BRE fehlt, `.gitignore` wird respektiert — `grep` fände dann
  Dateien nicht mehr, die eindeutig da sind. `rg` wird direkt aufgerufen.
- **Jeder Tool-Hook ist abgesichert.** Fehlt ein Werkzeug, startet die Shell
  trotzdem sauber, statt bei jedem Öffnen einen Fehler zu werfen.
- **`typeset -U path`** verhindert doppelte PATH-Einträge beim Neu-Sourcen.
- **`killport` trifft nur lauschende Prozesse** (`lsof -sTCP:LISTEN`). Ohne
  diesen Filter würde `killport 443` auch Browser, Mail und Editor abräumen,
  weil die ausgehende Verbindungen auf den Port halten. Beendet wird erst mit
  `SIGTERM`, `SIGKILL` folgt nur, wenn nach zwei Sekunden noch etwas lebt.
- **`hist_ignore_space`** ist aktiv: ein führendes Leerzeichen hält den Befehl
  aus der History. Praktisch für `ghtest <PAT>` und Ähnliches.

## Neue Pakete aufnehmen

`Brewfile.core` bleibt klein — CLI-Grundausstattung und alles, was die `.zshrc`
tatsächlich benutzt. Alles andere nach `Brewfile.extra`.

Abweichungen vom Ist-Zustand finden:

```bash
brew bundle check --file macos/Brewfile.core --verbose
```

## Linux

Paketinstallation über `apt-get` und `pacman`, Listen unter `linux/pkglist.*`.
Weil nicht jede Release alles anbietet, werden die Pakete **vor** der
Installation gegen die Repos geprüft; was fehlt, wird gemeldet statt den Lauf
abzubrechen. `eza` etwa gibt es erst ab Debian 13.

`starship` und `mise` fehlen in den meisten Distro-Repos oder sind dort veraltet.
Beide werden über ihre offiziellen Installer nach `~/.local/bin` gelegt — ohne
root, und der Pfad steht in der `.zshrc` bereits im `PATH`.

Debian benennt zwei Binaries um, weil die Namen dort belegt sind: `bat` liegt als
`batcat`, `fd` als `fdfind`. Die `.zshrc` fängt beides über Aliase ab.

Offen ist der Desktop-Teil: der `--desktop`-Hook in `lib/linux.sh` ist
dokumentiert, aber leer. Configs gehören nach `linux/config/`, die Symlinks in
`link_dotfiles()` in `install.sh` — die Stelle ist dort kommentiert.
