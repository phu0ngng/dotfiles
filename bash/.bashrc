#!/bin/bash

PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

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
host=$(hostname  | cut -d . -f 1)
[ -f ~/.env_$host ] && . ~/.env_$host


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
