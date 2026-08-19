# ~/.zprofile — verwaltet in ~/developer/dotfiles (zsh/.zprofile)
# Läuft einmal pro Login-Shell, vor der .zshrc.

# OrbStack: Docker-CLI und Integration
[[ -r "$HOME/.orbstack/shell/init.zsh" ]] && source "$HOME/.orbstack/shell/init.zsh"

# JetBrains Toolbox: die 'idea', 'webstorm' etc. Starter
_jb="$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
[[ -d $_jb ]] && export PATH="$PATH:$_jb"
unset _jb
