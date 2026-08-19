#!/usr/bin/env bash
# macOS-spezifische Installation: Homebrew + Brewfiles.

install_packages_macos() {
  if ! have brew; then
    info "Homebrew nicht gefunden — installiere es"
    if [ "${DRY_RUN:-0}" = 1 ]; then
      info "[dry-run] würde Homebrew installieren"
    else
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
        || die "Homebrew-Installation fehlgeschlagen"
      # Frisch installiertes brew liegt je nach Architektur woanders.
      for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        [ -x "$b" ] && eval "$("$b" shellenv)" && break
      done
    fi
  fi
  have brew || { warn "brew weiterhin nicht im PATH — Pakete übersprungen"; return 0; }

  bundle_file "$DOTFILES/macos/Brewfile.core" "Kern-Pakete"

  if [ "${WITH_EXTRA:-0}" = 1 ]; then
    bundle_file "$DOTFILES/macos/Brewfile.extra" "Zusatz-Pakete (GUI-Apps, Spezialwerkzeug)"
  else
    skip "Brewfile.extra übersprungen (mit --extra aktivieren)"
  fi
}

# bundle_file <pfad> <beschreibung>
bundle_file() {
  local file=$1 label=$2
  [ -f "$file" ] || { warn "Brewfile fehlt: $file"; return 0; }

  info "$label aus $(basename "$file")"
  if [ "${DRY_RUN:-0}" = 1 ]; then
    # --no-upgrade hält den Check schnell; zeigt nur, was fehlen würde.
    brew bundle check --file "$file" --verbose || true
    return 0
  fi

  # --no-upgrade ist Absicht: install.sh soll Fehlendes nachinstallieren,
  # aber nicht ungefragt jedes veraltete Paket hochziehen. Das ist auf einer
  # eingerichteten Maschine schnell eine halbe Stunde und kann Toolchains
  # unter den Füßen wegziehen. Upgrades bewusst per --upgrade anfordern.
  local args=(--file "$file")
  [ "${WITH_UPGRADE:-0}" = 1 ] || args+=(--no-upgrade)

  brew bundle "${args[@]}" || die "brew bundle fehlgeschlagen für $file"
  ok "$label installiert"
}
