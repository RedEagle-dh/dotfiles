#!/usr/bin/env bash
# Gemeinsame Helfer für install.sh und die OS-Module.
# Wird gesourcet, nicht direkt ausgeführt.

# ---------------------------------------------------------------- Ausgabe
# Farben nur, wenn wir wirklich auf einem Terminal schreiben.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\033[0m'; C_BLUE=$'\033[34m'; C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_DIM=$'\033[2m'
else
  C_RESET=''; C_BLUE=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_DIM=''
fi

info() { printf '%s==>%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok()   { printf '%s  ok%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
skip() { printf '%s  --%s %s\n' "$C_DIM" "$C_RESET" "$*"; }
warn() { printf '%s  !!%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()  { printf '%s ERR%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
die()  { err "$*"; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------- OS-Erkennung
# Setzt OS (macos|linux) und bei Linux zusätzlich DISTRO / PKG_MANAGER.
detect_os() {
  case "$(uname -s)" in
    Darwin) OS=macos ;;
    Linux)  OS=linux ;;
    *)      die "Nicht unterstütztes Betriebssystem: $(uname -s)" ;;
  esac

  DISTRO=''
  PKG_MANAGER=''
  if [ "$OS" = linux ]; then
    # /etc/os-release ist auf jeder halbwegs modernen Distro vorhanden.
    if [ -r /etc/os-release ]; then
      # shellcheck disable=SC1091
      DISTRO=$(. /etc/os-release && printf '%s' "${ID:-unknown}")
    else
      DISTRO=unknown
    fi
    for pm in pacman apt-get dnf zypper apk; do
      if have "$pm"; then PKG_MANAGER=$pm; break; fi
    done
  fi

  export OS DISTRO PKG_MANAGER
}

# ---------------------------------------------------------------- Symlinks
# link_file <quelle-im-repo> <ziel-im-home>
#
# Legt einen Symlink an. Existiert am Ziel bereits eine echte Datei, wandert
# sie vorher nach $BACKUP_DIR — es wird nie etwas kommentarlos überschrieben.
link_file() {
  local src=$1 dest=$2

  [ -e "$src" ] || { warn "Quelle fehlt, übersprungen: $src"; return 0; }

  # Zeigt der Link schon aufs Ziel? Dann ist nichts zu tun.
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    skip "$(shorten "$dest") -> bereits verlinkt"
    return 0
  fi

  if [ "${DRY_RUN:-0}" = 1 ]; then
    info "[dry-run] würde verlinken: $(shorten "$dest") -> $(shorten "$src")"
    return 0
  fi

  # Vorhandenes Ziel sichern (echte Datei ebenso wie ein falscher Symlink).
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    mkdir -p "$BACKUP_DIR"
    mv "$dest" "$BACKUP_DIR/$(basename "$dest")" \
      || die "Backup von $dest fehlgeschlagen"
    warn "$(shorten "$dest") gesichert nach $(shorten "$BACKUP_DIR")"
  fi

  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest" || die "Symlink $dest fehlgeschlagen"
  ok "$(shorten "$dest") -> $(shorten "$src")"
}

# Kürzt $HOME zu ~, damit die Ausgabe lesbar bleibt.
shorten() { printf '%s' "${1/#$HOME/\~}"; }
