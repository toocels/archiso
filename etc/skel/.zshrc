#
# ~/.zshrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias gui='dbus-run-session -- gnome-shell --wayland'
