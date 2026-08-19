#!/usr/bin/env bash
#
# Dotfiles-Installer.
#
# Direkt aus dem Netz (holt sich das Repo selbst):
#   curl -fsSL https://raw.githubusercontent.com/RedEagle-dh/dotfiles/main/install.sh | bash
#
# Oder aus einem Clone:
#   git clone https://github.com/RedEagle-dh/dotfiles.git ~/developer/dotfiles
#   ~/developer/dotfiles/install.sh
#
# Idempotent: mehrfaches Ausführen ist unschädlich.

set -euo pipefail

# ---------------------------------------------------------------- Konfiguration
# Alle per Umgebungsvariable überschreibbar, z.B. für einen Fork:
#   DOTFILES_REPO=meinuser/dotfiles curl -fsSL ... | bash
REPO_SLUG="${DOTFILES_REPO:-RedEagle-dh/dotfiles}"
REPO_BRANCH="${DOTFILES_BRANCH:-main}"
TARGET_DIR="${DOTFILES_DIR:-$HOME/developer/dotfiles}"
# Vollständige Clone-URL. Nur nötig für Forks, SSH statt HTTPS oder Tests.
REPO_URL="${DOTFILES_REMOTE:-https://github.com/$REPO_SLUG.git}"

# ---------------------------------------------------------------- Bootstrap
# Dieser Block läuft, bevor lib/common.sh verfügbar ist — beim Aufruf über
# 'curl | bash' liegt das Repo noch gar nicht auf der Platte. Deshalb hier
# bewusst eigene, minimale Ausgabe-Helfer.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  _b=$'\033[34m'; _y=$'\033[33m'; _r=$'\033[31m'; _n=$'\033[0m'
else
  _b=''; _y=''; _r=''; _n=''
fi
_info() { printf '%s==>%s %s\n' "$_b" "$_n" "$*"; }
_warn() { printf '%s  !!%s %s\n' "$_y" "$_n" "$*" >&2; }
_die()  { printf '%s ERR%s %s\n' "$_r" "$_n" "$*" >&2; exit 1; }
_short() { printf '%s' "${1/#$HOME/\~}"; }

# Liegt dieses Script in einem vollständigen Repo? Beim Pipen durch bash ist
# BASH_SOURCE leer bzw. kein echter Pfad — genau daran hängt die Erkennung.
_repo_root() {
  local self="${BASH_SOURCE[0]:-}" dir
  [ -n "$self" ] && [ -f "$self" ] || return 1
  dir=$(cd "$(dirname "$self")" 2>/dev/null && pwd) || return 1
  [ -f "$dir/lib/common.sh" ] && [ -d "$dir/zsh" ] || return 1
  printf '%s' "$dir"
}

bootstrap() {
  # Schutz gegen Endlosschleife, falls das geholte Repo unvollständig ist.
  [ "${DOTFILES_BOOTSTRAPPED:-0}" = 1 ] && \
    _die "Bootstrap-Schleife: $(_short "$TARGET_DIR") enthält kein vollständiges Repo."

  _info "Bootstrap: hole $REPO_URL nach $(_short "$TARGET_DIR")"

  if [ -d "$TARGET_DIR/.git" ]; then
    _info "Repo liegt bereits vor — aktualisiere"
    git -C "$TARGET_DIR" pull --ff-only \
      || _warn "pull fehlgeschlagen, nutze vorhandenen Stand"
  elif [ -e "$TARGET_DIR" ] && [ -n "$(ls -A "$TARGET_DIR" 2>/dev/null)" ]; then
    _die "$(_short "$TARGET_DIR") ist nicht leer, aber kein git-Repo. Bitte manuell aufräumen."
  elif command -v git >/dev/null 2>&1; then
    mkdir -p "$(dirname "$TARGET_DIR")"
    git clone --branch "$REPO_BRANCH" "$REPO_URL" "$TARGET_DIR" \
      || _die "git clone fehlgeschlagen"
  else
    # Ohne git geht es auch: Tarball entpacken. Rettet den Fall 'frischer Mac
    # ohne Command Line Tools', kostet aber die git-Historie.
    _warn "git nicht gefunden — lade Tarball statt Clone"
    mkdir -p "$TARGET_DIR"
    curl -fsSL "https://codeload.github.com/$REPO_SLUG/tar.gz/$REPO_BRANCH" \
      | tar xz -C "$TARGET_DIR" --strip-components=1 \
      || _die "Download fehlgeschlagen"
    _warn "Kein git-Checkout. Später nachholen:"
    _warn "  rm -rf $(_short "$TARGET_DIR") && git clone https://github.com/$REPO_SLUG.git $(_short "$TARGET_DIR")"
  fi

  [ -f "$TARGET_DIR/install.sh" ] || _die "install.sh fehlt im geholten Repo"
  chmod +x "$TARGET_DIR/install.sh" 2>/dev/null || true

  _info "Übergebe an $(_short "$TARGET_DIR")/install.sh"
  export DOTFILES_BOOTSTRAPPED=1

  # stdin ans Terminal hängen: bei 'curl | bash' hängt stdin an der Pipe, und
  # Rückfragen (Homebrew-Installer, sudo-Passwort) bekämen keine Eingabe.
  #
  # '[ -e /dev/tty ]' genügt hier NICHT: in CI-Runnern und Docker-Builds
  # existiert der Geräteknoten, lässt sich aber nicht öffnen. Wir probieren
  # das Öffnen deshalb in einer Subshell aus, bevor wir darauf umleiten.
  if (exec 3< /dev/tty) 2>/dev/null; then
    exec "$TARGET_DIR/install.sh" "$@" < /dev/tty
  else
    exec "$TARGET_DIR/install.sh" "$@"
  fi
}

if ! DOTFILES=$(_repo_root); then
  bootstrap "$@"   # kehrt nicht zurück (exec)
fi
export DOTFILES

# ---------------------------------------------------------------- Ab hier: Clone
# shellcheck source=lib/common.sh
. "$DOTFILES/lib/common.sh"

BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
DRY_RUN=0
WITH_EXTRA=0
WITH_DESKTOP=0
WITH_UPGRADE=0
DO_LINK=1
DO_PACKAGES=1
DO_SHELL=1

usage() {
  cat <<'USAGE'
Verwendung: install.sh [Optionen]

  --extra        Zusatz-Pakete mitinstallieren (GUI-Apps, Spezialwerkzeug)
  --desktop      Desktop-Umgebung mitinstallieren (nur Linux/Hyprland)
  --upgrade      vorhandene Pakete zusätzlich aktualisieren (sonst nur Fehlendes)
  --dry-run      nichts verändern, nur anzeigen
  --no-link      Symlinks überspringen
  --no-packages  Paketinstallation überspringen
  --no-shell     Login-Shell nicht auf zsh umstellen und nicht hineinwechseln
  -h, --help     diese Hilfe

Umgebungsvariablen:
  DOTFILES_DIR     Zielverzeichnis        (Standard: ~/developer/dotfiles)
  DOTFILES_REPO    Repo als owner/name    (Standard: RedEagle-dh/dotfiles)
  DOTFILES_BRANCH  Branch                 (Standard: main)
  DOTFILES_REMOTE  vollständige Clone-URL (Standard: https://github.com/<repo>.git)

Vorhandene Dateien werden nie überschrieben, sondern nach
~/.dotfiles-backup/<zeitstempel>/ verschoben.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --extra)       WITH_EXTRA=1 ;;
    --desktop)     WITH_DESKTOP=1 ;;
    --upgrade)     WITH_UPGRADE=1 ;;
    --dry-run)     DRY_RUN=1 ;;
    --no-link)     DO_LINK=0 ;;
    --no-packages) DO_PACKAGES=0 ;;
    --no-shell)    DO_SHELL=0 ;;
    -h|--help)     usage; exit 0 ;;
    *)             err "Unbekannte Option: $1"; echo; usage; exit 1 ;;
  esac
  shift
done
export BACKUP_DIR DRY_RUN WITH_EXTRA WITH_DESKTOP WITH_UPGRADE DO_SHELL

# ---------------------------------------------------------------- Symlinks
# Alles, was auf jedem Betriebssystem gleich ist.
link_dotfiles() {
  info "Verlinke Shell-Konfiguration"
  link_file "$DOTFILES/zsh/.zshrc"    "$HOME/.zshrc"
  link_file "$DOTFILES/zsh/.zprofile" "$HOME/.zprofile"

  # ~/.scripts wird als Verzeichnis verlinkt: ein neues Skript im Repo ist
  # dadurch sofort aktiv, ohne install.sh erneut auszuführen.
  link_file "$DOTFILES/zsh/scripts"   "$HOME/.scripts"

  # Hier später OS-spezifische Configs ergänzen, z.B.
  #   [ "$OS" = linux ] && link_file "$DOTFILES/linux/config/hypr" "$HOME/.config/hypr"
}

# ---------------------------------------------------------------- Shellwechsel
# Wechselt zum Schluss direkt in die neue Shell, damit man nicht erst
# aus- und wieder einloggen muss. Ersetzt per exec den Installer-Prozess.
launch_zsh() {
  local target parent
  target=$(command -v zsh) || return 0

  # Läuft der Aufruf schon aus einer zsh? Dann wäre ein weiteres Login
  # nur eine überflüssige Verschachtelung.
  parent=$(ps -o comm= -p "$PPID" 2>/dev/null | sed 's|^-||; s|.*/||')
  if [ "$parent" = zsh ]; then
    skip "läuft bereits unter zsh"
    return 0
  fi

  # Ohne echtes Terminal (CI, Docker-Build) darf hier nichts Interaktives starten.
  if [ ! -t 0 ] || [ ! -t 1 ]; then
    info "Neue Shell starten oder 'exec zsh -l' ausführen."
    return 0
  fi

  info "Wechsle in zsh — 'exit' bringt dich zurück nach $parent"
  exec "$target" -l
}

# ---------------------------------------------------------------- Ablauf
main() {
  detect_os
  info "System: $OS${DISTRO:+ ($DISTRO)} · Repo: $(shorten "$DOTFILES")"
  [ "$DRY_RUN" = 1 ] && warn "dry-run: es wird nichts verändert"

  if [ "$DO_LINK" = 1 ]; then
    link_dotfiles
  else
    skip "Symlinks übersprungen (--no-link)"
  fi

  if [ "$DO_PACKAGES" = 1 ]; then
    case "$OS" in
      macos) . "$DOTFILES/lib/macos.sh"; install_packages_macos ;;
      linux) . "$DOTFILES/lib/linux.sh"; install_packages_linux ;;
    esac
  else
    skip "Pakete übersprungen (--no-packages)"
  fi

  if [ "$DO_SHELL" = 1 ]; then
    ensure_default_shell
  else
    skip "Login-Shell unverändert (--no-shell)"
  fi

  echo
  ok "Fertig."
  [ -d "$BACKUP_DIR" ] && info "Ersetzte Dateien liegen in $(shorten "$BACKUP_DIR")"

  if [ "$DO_SHELL" = 1 ] && [ "$DRY_RUN" != 1 ]; then
    launch_zsh
  fi
}

main "$@"
