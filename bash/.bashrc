#!/bin/bash

PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
PROMPT_DIRTRIM=3

# don't put duplicate lines or lines starting with space in the history.
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# nvim
if command -v nvim &> /dev/null
then
  alias vim=$(which nvim)
fi

# Env PATH
host=$(cat ~/.dotfiles_host 2>/dev/null)
[ -n "$host" ] && [ -f ~/.env_$host ] && . ~/.env_$host

# Python aliases
if command -v python3.13 &> /dev/null; then
  alias python=python3.13
  alias python3=python3.13
fi


# Open function
function open() {
  if [ -n "$(which xdg-open 2>/dev/null)" ]; then
    if [ -z "$1" -o "$1" == "-h" -o "$1" == "--help"  ];then
      echo "open function/script, as standin for NextSteps 'open'"
      echo "Using $(which xdg-open)"
      echo "To see full script type \'type open\'"
    fi
  elif [ -n "$(which cygstart 2>/dev/null)" ]; then
    cygstart $1
  else #no xdg-open nor cygstart Should be NextSteps(MacOSX)
    /usr/bin/open $1
  fi
}
export -f open

export TMUX_TMPDIR=~/.cache_$host/tmux
mkdir -p $TMUX_TMPDIR
export EDITOR='nvim'
export VISUAL='nvim'

# Clean old images
if command -v docker &> /dev/null; then
  alias docker-clean='docker rmi -f $(docker images -aq)'
fi

# Python venv
if [[ -z "$VIRTUAL_ENV" ]]; then source ~/.local/venv/nvim/bin/activate; fi
