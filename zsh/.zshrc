# ~/.zshrc — verwaltet in ~/developer/dotfiles (zsh/.zshrc)
# Konfiguration für interaktive Shells.

# ---------------------------------------------------------------- PATH-Hygiene
# -U (unique) verhindert doppelte Einträge, wenn diese Datei mehrfach
# gesourcet wird. Muss vor allen PATH-Änderungen stehen.
typeset -U path PATH fpath FPATH

# Kleiner Helfer: existiert das Kommando überhaupt?
_have() { (( $+commands[$1] )) }

# ---------------------------------------------------------------- Homebrew
# Apple Silicon, Intel-Mac und Linuxbrew liegen an verschiedenen Orten.
# shellenv erweitert unter anderem FPATH — muss deshalb vor compinit laufen.
for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
  if [[ -x $_brew ]]; then
    eval "$("$_brew" shellenv)"
    BREW_PREFIX=${_brew%/bin/brew}
    break
  fi
done
unset _brew

# ---------------------------------------------------------------- PATH
# Jeder Eintrag prüft selbst, ob er existiert — fehlt das Verzeichnis,
# landet kein Müll im PATH.
[[ -d $HOME/.local/bin ]]        && path=("$HOME/.local/bin" $path)
[[ -d $HOME/.lmstudio/bin ]]     && path=($path "$HOME/.lmstudio/bin")
[[ -d $HOME/.kimi-code/bin ]]    && path=("$HOME/.kimi-code/bin" $path)
[[ -d /Library/TeX/texbin ]]     && path=(/Library/TeX/texbin $path)
# rustup ist bei Homebrew keg-only: erst dieser Pfad bringt cargo-miri o.ä. mit.
[[ -d ${BREW_PREFIX:-/opt/homebrew}/opt/rustup/bin ]] && \
  path=("${BREW_PREFIX:-/opt/homebrew}/opt/rustup/bin" $path)

# ---------------------------------------------------------------- History
HISTFILE="$HOME/.zsh_history"
HISTSIZE=60000            # im Speicher — bewusst größer als SAVEHIST, damit
SAVEHIST=50000            # vor dem Schreiben noch dedupliziert werden kann

setopt hist_ignore_all_dups   # ältere Duplikate entfernen
setopt hist_ignore_space      # führendes Leerzeichen -> nicht in die History
setopt hist_reduce_blanks     # überflüssige Leerzeichen normalisieren
setopt extended_history       # mit Zeitstempel und Laufzeit
setopt share_history          # History zwischen offenen Shells teilen
setopt autocd                 # "src/" statt "cd src/"
setopt interactivecomments    # '#' auch interaktiv als Kommentar

# ---------------------------------------------------------------- Completion
autoload -Uz compinit
compinit

# ---------------------------------------------------------------- Werkzeuge
# Jeder Aufruf ist abgesichert: fehlt ein Werkzeug, startet die Shell trotzdem
# sauber, statt bei jedem Öffnen einen Fehler zu werfen.
_have starship && eval "$(starship init zsh)"
_have zoxide   && eval "$(zoxide init zsh)"
_have mise     && eval "$(mise activate zsh)"
_have direnv   && eval "$(direnv hook zsh)"
_have fzf      && source <(fzf --zsh)

# ---------------------------------------------------------------- Aliase
if _have eza; then
  alias ls="eza --icons=auto --group-directories-first"
  alias ll="eza -l  --icons=auto --group-directories-first"          # lang
  alias la="eza -la --icons=auto --group-directories-first"          # lang + versteckt
  alias lt="eza --tree --level=2 --icons=auto"                       # Baum
fi

# Absichtlich KEIN 'alias grep=rg': rg ist nicht flag-kompatibel mit grep
# (-r heißt Replace statt Recursive, BRE fehlt, .gitignore wird respektiert).
# rg direkt aufrufen, grep bleibt grep.
_have bat && alias cat="bat"

alias k="kubectl"
alias ..="cd .."
alias ...="cd ../.."

# ---------------------------------------------------------------- Funktionen
# Beendet Prozesse, die auf einem Port LAUSCHEN. Usage: killport 3000 3001
killport() {
  if (( $# == 0 )); then
    print -u2 "Usage: killport <port> [port...]"
    return 1
  fi

  local port out
  for port in "$@"; do
    # -sTCP:LISTEN ist entscheidend: ohne diesen Filter trifft lsof auch
    # ausgehende Verbindungen auf den Port — 'killport 443' würde dann
    # Browser, Mail und Editor mit abräumen.
    out=$(lsof -ti tcp:"$port" -sTCP:LISTEN 2>/dev/null)
    if [[ -z $out ]]; then
      print "Port $port: kein lauschender Prozess"
      continue
    fi

    local pids=(${=out})
    print "Port $port: ${(j:, :)pids} ($(ps -o comm= -p ${pids[1]} 2>/dev/null | xargs basename 2>/dev/null))"

    # Erst höflich fragen — Dev-Server dürfen Sockets und Lockfiles aufräumen.
    kill ${pids} 2>/dev/null

    local waited=0
    while (( waited < 20 )); do
      sleep 0.1
      (( waited++ ))
      [[ -z $(lsof -ti tcp:"$port" -sTCP:LISTEN 2>/dev/null) ]] && break
    done

    local alive=$(lsof -ti tcp:"$port" -sTCP:LISTEN 2>/dev/null)
    if [[ -n $alive ]]; then
      kill -9 ${=alive} 2>/dev/null
      print "  SIGTERM ignoriert -> SIGKILL"
    else
      print "  beendet"
    fi
  done
}

# ---------------------------------------------------------------- Eigene Skripte
# 'source datei1 datei2' würde NUR die erste Datei laden und den Rest still
# als Positionsparameter verschlucken — deshalb die Schleife.
# (N) = Null-Glob: kein Fehler, wenn das Verzeichnis leer ist oder fehlt.
for _f in "$HOME"/.scripts/*.zsh(N); do
  source "$_f"
done
unset _f

# ---------------------------------------------------------------- Ergänzungen
[[ -s "$HOME/.bun/_bun" ]] && source "$HOME/.bun/_bun"

# ---------------------------------------------------------------- Plugins
# Müssen ganz zum Schluss stehen; syntax-highlighting zwingend als Letztes,
# sonst erfasst es die vorher definierten Widgets nicht.
_zsh_plugin() {
  local p
  for p in "${BREW_PREFIX:-/opt/homebrew}/share/$1/$1.zsh" \
           "/usr/share/zsh/plugins/$1/$1.zsh" \
           "/usr/share/$1/$1.zsh"; do
    [[ -r $p ]] && { source "$p"; return 0 }
  done
  return 1
}

_zsh_plugin zsh-autosuggestions
_zsh_plugin zsh-syntax-highlighting
