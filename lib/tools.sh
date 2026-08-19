#!/usr/bin/env bash
# Werkzeuge, die aus dem Quelltext gebaut werden — plattformunabhaengig.
# Wird von install.sh nach dem OS-Paketschritt aufgerufen.

# Liefert 0, wenn das gefundene go neu genug ist.
# Ab Go 1.21 laedt die Toolchain-Direktive in go.mod fehlende Versionen selbst
# nach; aeltere Go-Versionen kennen den Mechanismus nicht und scheitern hart.
_go_recent_enough() {
  local v major minor rest
  command -v go >/dev/null 2>&1 || return 1
  v=$(go env GOVERSION 2>/dev/null) || return 1
  v=${v#go}
  major=${v%%.*}; rest=${v#*.}; minor=${rest%%.*}
  case "$major$minor" in *[!0-9]*|'') return 1 ;; esac
  [ "$major" -gt 1 ] && return 0
  [ "$major" -eq 1 ] && [ "$minor" -ge 21 ]
}

# Gibt den Go-Aufruf aus, mit dem gebaut werden kann — oder nichts.
_go_command() {
  if _go_recent_enough; then
    printf 'go'
  elif command -v mise >/dev/null 2>&1; then
    # Debian Bookworm liefert Go 1.19, zu alt fuer go.mod. mise haelt aktuelle
    # Toolchains bereit und ist auf beiden Maschinen ohnehin installiert.
    printf 'mise exec go@latest -- go'
  fi
}

# lazyports: TUI zum Anzeigen und Beenden von Prozessen auf Netzwerkports.
#
# Gebaut wird aus Daves Fork, nicht aus upstream: der Fork traegt den Commit
# "Adding macos compatibility and improve multi-socket visualization".
#
# 'go install github.com/RedEagle-dh/LazyPorts@main' funktioniert NICHT — die
# go.mod des Forks deklariert weiterhin den Upstream-Pfad
# (github.com/v9mirza/lazyports), und Go besteht darauf, dass Modulpfad und
# Bezugspfad uebereinstimmen. Deshalb klonen und lokal bauen.
#
# Das mitgelieferte install.sh des Projekts wird bewusst nicht benutzt: es
# installiert upstream statt des Forks, kopiert per sudo nach /usr/local/bin
# und haengt eine PATH-Zeile an ~/.zshrc — das ist hier ein Symlink ins Repo.
install_lazyports() {
  local bin="$HOME/.local/bin"
  local src="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/LazyPorts"
  local url="https://github.com/RedEagle-dh/LazyPorts.git"
  local go_cmd

  if command -v lazyports >/dev/null 2>&1 && [ "${WITH_UPGRADE:-0}" != 1 ]; then
    skip "lazyports bereits vorhanden (--upgrade baut neu)"
    return 0
  fi

  go_cmd=$(_go_command)
  if [ -z "$go_cmd" ]; then
    warn "lazyports: weder aktuelles go noch mise gefunden — uebersprungen"
    return 0
  fi

  if [ "${DRY_RUN:-0}" = 1 ]; then
    info "[dry-run] wuerde lazyports aus $url bauen (via: $go_cmd)"
    return 0
  fi

  info "Baue lazyports aus dem Fork (via: $go_cmd)"
  mkdir -p "$bin" "$(dirname "$src")"

  if [ -d "$src/.git" ]; then
    if ! (git -C "$src" fetch -q --depth 1 origin main \
          && git -C "$src" reset -q --hard FETCH_HEAD); then
      warn "lazyports: Aktualisieren fehlgeschlagen, nutze vorhandenen Stand"
    fi
  elif ! { rm -rf "$src" && git clone -q --depth 1 "$url" "$src"; }; then
    warn "lazyports: Klonen fehlgeschlagen"
    return 0
  fi

  local log; log=$(mktemp)
  # Bei mise laedt der erste Lauf eine komplette Go-Toolchain — das dauert.
  if (cd "$src" && $go_cmd build -o "$bin/lazyports" .) >"$log" 2>&1; then
    chmod +x "$bin/lazyports"
    ok "lazyports gebaut -> $bin/lazyports"

    # Verdeckt eine aeltere Installation unseren Build? Passiert leicht, wenn
    # frueher einmal 'go install' lief: dessen Binary landet in GOPATH/bin,
    # und mise stellt dieses Verzeichnis weit vorn in den PATH.
    local found
    found=$(command -v lazyports 2>/dev/null)
    if [ -n "$found" ] && [ "$found" != "$bin/lazyports" ]; then
      warn "Achtung: im PATH gewinnt weiterhin $found"
      warn "  Das ist vermutlich ein alter 'go install'-Build aus upstream,"
      warn "  ohne deinen macOS-Commit. Entfernen mit:  rm $found"
    fi
  else
    warn "lazyports: Build fehlgeschlagen — letzte Zeilen:"
    tail -8 "$log" | sed 's/^/      /' >&2
  fi
  rm -f "$log"
}

install_source_tools() {
  install_lazyports
}
