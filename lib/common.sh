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

# ---------------------------------------------------------------- Rechte
# Leer, wenn wir ohnehin root sind — sonst sudo. So funktionieren die
# Paket-Aufrufe in beiden Fällen ohne Sonderbehandlung.
sudo_cmd() {
  if [ "$(id -u)" = 0 ]; then printf ''; else printf 'sudo'; fi
}

# ---------------------------------------------------------------- Login-Shell
# Liest die eingetragene Login-Shell — nicht $SHELL, das ist nur geerbt und
# lügt in genau dem Moment, in dem man es wissen will.
current_login_shell() {
  local s=''
  if command -v getent >/dev/null 2>&1; then
    s=$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7)
  fi
  if [ -z "$s" ] && [ "$(uname -s)" = Darwin ]; then
    s=$(dscl . -read "/Users/$(id -un)" UserShell 2>/dev/null | awk '{print $2}')
  fi
  [ -z "$s" ] && s="${SHELL:-}"
  printf '%s' "$s"
}

# Sorgt dafür, dass zsh die Login-Shell ist. Idempotent.
ensure_default_shell() {
  local target current sudo_
  sudo_=$(sudo_cmd)

  if ! target=$(command -v zsh); then
    warn "zsh ist nicht installiert — Login-Shell bleibt unverändert"
    return 0
  fi

  current=$(current_login_shell)
  if [ "$current" = "$target" ]; then
    skip "Login-Shell ist bereits $target"
    return 0
  fi

  info "Login-Shell: $current -> $target"
  if [ "${DRY_RUN:-0}" = 1 ]; then
    info "[dry-run] würde chsh ausführen"
    return 0
  fi

  # chsh akzeptiert nur Shells aus /etc/shells. Bei zsh aus Homebrew oder
  # /usr/local fehlt der Eintrag oft.
  if [ -r /etc/shells ] && ! grep -qxF "$target" /etc/shells; then
    info "$target fehlt in /etc/shells — trage nach (benötigt sudo)"
    printf '%s\n' "$target" | $sudo_ tee -a /etc/shells >/dev/null \
      || { warn "Eintrag in /etc/shells fehlgeschlagen — chsh übersprungen"; return 0; }
  fi

  # Kann nach dem Passwort fragen; deshalb hängt stdin im Bootstrap am Terminal.
  if chsh -s "$target" 2>/dev/null; then
    ok "Login-Shell gesetzt"
  elif $sudo_ chsh -s "$target" "$(id -un)" 2>/dev/null; then
    # Manche PAM-Konfigurationen lassen chsh nur mit erhöhten Rechten zu.
    ok "Login-Shell gesetzt (via sudo)"
  else
    warn "chsh fehlgeschlagen. Von Hand:  sudo chsh -s $target $(id -un)"
    return 0
  fi

  warn "Wirkt erst bei der nächsten Login-Session (bei SSH: neu verbinden)."
}
