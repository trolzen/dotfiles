HISTFILE="${XDG_STATE_HOME}/bash/history"

[ -d "${XDG_CONFIG_HOME}"/bash/completion ] && for c in "${XDG_CONFIG_HOME}"/bash/completion/*; do
  [ -f "$c" ] && source "$c"
done
unset c

source "${XDG_CONFIG_HOME}/dotfiles-config.bash"
