#!/usr/bin/env bash
# Linux-spezifische Installation.
#
# STATUS: Gerüst. Bewusst noch ohne Paketlisten — die kommen, wenn die
# Maschine existiert und feststeht, welche Distro es wird. Die Hooks unten
# werden von install.sh bereits aufgerufen; du füllst nur die Rümpfe.

install_packages_linux() {
  info "Linux erkannt: distro=${DISTRO:-unbekannt} paketmanager=${PKG_MANAGER:-keiner}"

  if [ -z "$PKG_MANAGER" ]; then
    warn "Kein unterstützter Paketmanager gefunden — Pakete übersprungen"
    return 0
  fi

  # ---------------------------------------------------------------- Hook 1
  # Basis-Pakete (die Linux-Entsprechungen der Mac-CLI-Tools).
  #
  # Wenn du das füllst: Paketlisten pro Manager anlegen, z.B.
  #   linux/pkglist.pacman  /  linux/pkglist.apt
  # und hier einlesen. Namen unterscheiden sich je Distro
  # (fd-find vs fd, bat vs batcat, ...) — deshalb getrennte Listen.
  case "$PKG_MANAGER" in
    pacman)   skip "Basis-Pakete: pacman-Zweig noch nicht befüllt" ;;
    apt-get)  skip "Basis-Pakete: apt-Zweig noch nicht befüllt" ;;
    dnf|zypper|apk)
              skip "Basis-Pakete: ${PKG_MANAGER}-Zweig noch nicht befüllt" ;;
  esac

  # ---------------------------------------------------------------- Hook 2
  # Desktop / Hyprland.
  #
  # Gedacht für: hyprland, waybar, wofi/rofi, hyprpaper, xdg-desktop-portal-hlr.
  # Die zugehörigen Configs gehören nach linux/config/ und werden dann in
  # install.sh unter link_dotfiles() nach ~/.config/ verlinkt.
  # Absichtlich leer: erfundene Hyprland-Configs wären nur Ballast.
  if [ "${WITH_DESKTOP:-0}" = 1 ]; then
    skip "Desktop/Hyprland: noch nicht befüllt (Hook in lib/linux.sh)"
  else
    skip "Desktop/Hyprland übersprungen (mit --desktop aktivieren)"
  fi
}
