#!/bin/bash

conf() {
  local GIT_DIR="$HOME/.dotfiles.git"
  local WORKTREE="$HOME"
  local REPO=${REPO:-git@github.com:trolzen/dotfiles.git}

  case "$1" in
    init)
      git init --bare $GIT_DIR
      conf config --local status.showUntrackedFiles no
      echo "/.dotfiles.git" >> "$GIT_DIR/info/exclude"
      ;;
    clone)
      git clone --bare --config status.showUntrackedFiles=no "$REPO" "$GIT_DIR"
      echo "/.dotfiles.git" >> "$GIT_DIR/info/exclude"
      ;;
    *)
      git --git-dir="$GIT_DIR" --work-tree="$WORKTREE" "$@"
  esac
}

alias dotf=conf
