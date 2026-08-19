#!/usr/bin/env bash
# Linux-spezifische Installation.

# Liest eine Paketliste: Kommentare und Leerzeilen raus, Inline-Kommentare ab.
read_pkglist() {
  local file=$1
  [ -r "$file" ] || return 1
  sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$file" | grep -v '^$'
}

install_packages_linux() {
  info "Linux: distro=${DISTRO:-unbekannt} paketmanager=${PKG_MANAGER:-keiner}"

  if [ -z "$PKG_MANAGER" ]; then
    warn "Kein unterstützter Paketmanager gefunden — Pakete übersprungen"
    return 0
  fi

  case "$PKG_MANAGER" in
    apt-get) linux_pkgs_apt ;;
    pacman)  linux_pkgs_pacman ;;
    *)       warn "Paketmanager '$PKG_MANAGER' noch nicht angebunden — übersprungen" ;;
  esac

  linux_extras
  linux_desktop
}

# ---------------------------------------------------------------- apt
linux_pkgs_apt() {
  local list="$DOTFILES/linux/pkglist.apt" sudo_
  sudo_=$(sudo_cmd)
  local wanted; wanted=$(read_pkglist "$list") || { warn "Liste fehlt: $list"; return 0; }

  info "Aktualisiere Paketindex"
  if [ "${DRY_RUN:-0}" = 1 ]; then
    info "[dry-run] würde 'apt-get update' ausführen"
  else
    $sudo_ apt-get update -qq || warn "apt-get update fehlgeschlagen — fahre fort"
  fi

  # Vorher aussortieren, was diese Release gar nicht kennt. Sonst bricht
  # apt-get beim ersten unbekannten Paket ab und installiert gar nichts.
  local available=() missing=() p
  for p in $wanted; do
    if apt-cache show "$p" >/dev/null 2>&1; then available+=("$p"); else missing+=("$p"); fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    warn "In dieser Release nicht verfügbar: ${missing[*]}"
  fi
  [ ${#available[@]} -eq 0 ] && { warn "Nichts zu installieren"; return 0; }

  info "Installiere ${#available[@]} Pakete"
  if [ "${DRY_RUN:-0}" = 1 ]; then
    info "[dry-run] würde installieren: ${available[*]}"
  else
    $sudo_ apt-get install -y "${available[@]}" || die "apt-get install fehlgeschlagen"
    ok "Pakete installiert"
  fi
}

# ---------------------------------------------------------------- pacman
linux_pkgs_pacman() {
  local list="$DOTFILES/linux/pkglist.pacman" sudo_
  sudo_=$(sudo_cmd)
  local wanted; wanted=$(read_pkglist "$list") || { warn "Liste fehlt: $list"; return 0; }

  local available=() missing=() p
  for p in $wanted; do
    if pacman -Si "$p" >/dev/null 2>&1; then available+=("$p"); else missing+=("$p"); fi
  done

  [ ${#missing[@]} -gt 0 ] && warn "Nicht in den Repos: ${missing[*]}"
  [ ${#available[@]} -eq 0 ] && { warn "Nichts zu installieren"; return 0; }

  info "Installiere ${#available[@]} Pakete"
  if [ "${DRY_RUN:-0}" = 1 ]; then
    info "[dry-run] würde installieren: ${available[*]}"
  else
    $sudo_ pacman -S --needed --noconfirm "${available[@]}" || die "pacman fehlgeschlagen"
    ok "Pakete installiert"
  fi
}

# ---------------------------------------------------------------- Extras
# starship, mise und eza liegen in den meisten Distro-Repos nicht oder sind
# veraltet (eza fehlt in Debian vor 13 ganz). Alle drei bringen statische
# Builds mit, die ohne root nach ~/.local/bin gehen — dieser Pfad steht in der
# .zshrc bereits im PATH.
#
# WICHTIG: kein 'curl ... | sh'. Der Exit-Status einer Pipeline ist der ihres
# LETZTEN Glieds — bei einem 404 bekommt sh leere Eingabe und beendet sich mit
# 0. Der Fehlschlag saehe dann wie ein Erfolg aus. Deshalb wird erst geladen,
# geprueft, und dann ausgefuehrt.

# _fetch <label> <url> <ziel> -> laedt herunter und prueft auf nicht-leer
_fetch() {
  local label=$1 url=$2 out=$3 log
  log=$(mktemp) || return 1
  if ! curl -fsSL "$url" -o "$out" 2>"$log"; then
    warn "$label: Download fehlgeschlagen — $url"
    tail -4 "$log" | sed 's/^/      /' >&2
    rm -f "$log"; return 1
  fi
  rm -f "$log"
  if [ ! -s "$out" ]; then
    warn "$label: Download war leer — $url"
    return 1
  fi
  return 0
}

# install_script <label> <url> [argumente fuer das Skript...]
install_script() {
  local label=$1 url=$2; shift 2
  local tmp log rc=0
  tmp=$(mktemp) || return 1
  if ! _fetch "$label" "$url" "$tmp"; then rm -f "$tmp"; return 1; fi

  log=$(mktemp)
  if sh "$tmp" "$@" >"$log" 2>&1; then
    ok "$label installiert"
  else
    warn "$label fehlgeschlagen — letzte Zeilen:"
    tail -8 "$log" | sed 's/^/      /' >&2
    rc=1
  fi
  rm -f "$tmp" "$log"
  return $rc
}

# install_tarball <label> <url> <zielverzeichnis> <element im archiv>
install_tarball() {
  local label=$1 url=$2 dest=$3 member=$4
  local tmp log rc=0
  tmp=$(mktemp) || return 1
  if ! _fetch "$label" "$url" "$tmp"; then rm -f "$tmp"; return 1; fi

  log=$(mktemp)
  if tar xzf "$tmp" -C "$dest" "$member" >"$log" 2>&1; then
    ok "$label installiert"
  else
    warn "$label: Entpacken fehlgeschlagen"
    tail -6 "$log" | sed 's/^/      /' >&2
    rc=1
  fi
  rm -f "$tmp" "$log"
  return $rc
}

linux_extras() {
  local bin="$HOME/.local/bin"
  mkdir -p "$bin"

  if command -v starship >/dev/null 2>&1; then
    skip "starship bereits vorhanden"
  elif [ "${DRY_RUN:-0}" = 1 ]; then
    info "[dry-run] wuerde starship nach $bin installieren"
  else
    info "Installiere starship nach $bin"
    install_script starship https://starship.rs/install.sh --yes --bin-dir "$bin" || true
  fi

  if command -v eza >/dev/null 2>&1; then
    skip "eza bereits vorhanden"
  else
    local arch target
    arch=$(uname -m)
    case "$arch" in
      aarch64|arm64) target=aarch64-unknown-linux-gnu ;;
      x86_64|amd64)  target=x86_64-unknown-linux-gnu ;;
      armv7l|armv6l) target=arm-unknown-linux-gnueabihf ;;
      *)             target='' ;;
    esac

    if [ -z "$target" ]; then
      warn "eza: keine passende Binary fuer $arch — uebersprungen"
    elif [ "${DRY_RUN:-0}" = 1 ]; then
      info "[dry-run] wuerde eza ($target) nach $bin installieren"
    else
      info "Installiere eza ($target) nach $bin"
      if install_tarball eza \
           "https://github.com/eza-community/eza/releases/latest/download/eza_${target}.tar.gz" \
           "$bin" ./eza; then
        chmod +x "$bin/eza"
      else
        warn "ls/ll fallen auf coreutils zurueck"
      fi
    fi
  fi

  if command -v mise >/dev/null 2>&1; then
    skip "mise bereits vorhanden"
  elif [ "${DRY_RUN:-0}" = 1 ]; then
    info "[dry-run] wuerde mise nach $bin installieren"
  else
    info "Installiere mise nach $bin"
    MISE_QUIET=1 install_script mise https://mise.run || true
  fi
}

# ---------------------------------------------------------------- Desktop
# Hook für Hyprland & Co. Noch leer: erfundene Configs wären nur Ballast.
# Wenn du das füllst, gehören die Configs nach linux/config/ und die Symlinks
# in link_dotfiles() in install.sh — die Stelle ist dort kommentiert.
linux_desktop() {
  if [ "${WITH_DESKTOP:-0}" != 1 ]; then
    skip "Desktop/Hyprland übersprungen (mit --desktop aktivieren)"
    return 0
  fi
  skip "Desktop/Hyprland: Hook in lib/linux.sh noch nicht befüllt"
}
