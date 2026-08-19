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
# starship und mise liegen in den meisten Distro-Repos nicht (oder veraltet).
# Beide bringen offizielle Installer mit, die nach ~/.local/bin schreiben —
# kein root nötig, und der Pfad steht in der .zshrc bereits im PATH.
linux_extras() {
  local bin="$HOME/.local/bin"

  if command -v starship >/dev/null 2>&1; then
    skip "starship bereits vorhanden"
  elif [ "${DRY_RUN:-0}" = 1 ]; then
    info "[dry-run] würde starship nach $bin installieren"
  else
    info "Installiere starship nach $bin"
    mkdir -p "$bin"
    if curl -fsSL https://starship.rs/install.sh \
         | sh -s -- --yes --bin-dir "$bin" >/dev/null 2>&1; then
      ok "starship installiert"
    else
      warn "starship-Installation fehlgeschlagen — Prompt bleibt schlicht"
    fi
  fi

  if command -v mise >/dev/null 2>&1; then
    skip "mise bereits vorhanden"
  elif [ "${DRY_RUN:-0}" = 1 ]; then
    info "[dry-run] würde mise nach $bin installieren"
  else
    info "Installiere mise nach $bin"
    mkdir -p "$bin"
    if curl -fsSL https://mise.run | MISE_QUIET=1 sh >/dev/null 2>&1; then
      ok "mise installiert"
    else
      warn "mise-Installation fehlgeschlagen"
    fi
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
