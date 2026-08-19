# Linux

Noch Gerüst — bewusst leer, bis die Maschine existiert.

`lib/linux.sh` wird von `install.sh` bereits aufgerufen und erkennt Distro und
Paketmanager (pacman / apt-get / dnf / zypper / apk). Es fehlen nur die Inhalte.

## Was hier hin gehört

    linux/
    ├── pkglist.pacman        Paketnamen für Arch
    ├── pkglist.apt           Paketnamen für Debian/Ubuntu
    └── config/
        ├── hypr/             hyprland.conf, hyprpaper.conf
        ├── waybar/
        └── wofi/

Getrennte Paketlisten, weil die Namen je Distro abweichen: `fd` heißt auf
Debian `fd-find`, `bat` dort `batcat`.

## Zwei Stellen zum Ausfüllen

1. **`lib/linux.sh`, Hook 1** — Basis-Pakete. Paketliste einlesen und an den
   Paketmanager übergeben.
2. **`lib/linux.sh`, Hook 2** — Desktop/Hyprland, aktiv nur mit `--desktop`.

Kommen Configs nach `linux/config/`, gehören die Symlinks in `link_dotfiles()`
in `install.sh` — die Stelle ist dort kommentiert.

## Zu beachten

Die `.zshrc` ist bereits plattformübergreifend: Homebrew wird auch unter
`/home/linuxbrew/.linuxbrew` gefunden, jeder PATH-Eintrag prüft sich selbst,
und die zsh-Plugins werden zusätzlich unter `/usr/share/zsh/plugins/` gesucht —
dem üblichen Ort auf Arch und Debian. Sie sollte also ohne Änderung laufen.

Ungetestet: Es stand bisher keine Linux-Maschine zur Verfügung.
