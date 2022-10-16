HISTFILE="${XDG_STATE_HOME}/bash/history"

[ -d "${XDG_CONFIG_HOME}"/bash/completion ] && for c in "${XDG_CONFIG_HOME}"/bash/completion/*; do
  [ -f "$c" ] && source "$c"
done
unset c

alias vc='python -m venv venv'
alias va='source venv/Scripts/activate'
alias ve='python -m venv venv && source .venv/Scripts/activate && python -m pip install -U pip setuptools wheels'

source "${XDG_CONFIG_HOME}/dotfiles-config.bash"
__git_complete conf git
