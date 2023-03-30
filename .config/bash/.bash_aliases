#!/bin/bash

# Program aliases
alias vim='nvim'
alias fm='thunar'

# Utility
alias ls='ls -ahlH --color=auto'
alias reload=". ~/.bashrc && echo 'Reloaded bash config from ~/.bashrc'"
alias dotfiles="cd ~/.dotfiles"

# Git aliases
# Use both "git branch clean" and "git clean branches"
alias gcb='git branch --merged | grep -v 'main$' | xargs git branch -d 2>/dev/null'
alias gbc='gcb'
alias gs='git switch'

# Heroku Local
alias hl='heroku local'
alias hlc='heroku local:run rails c'
alias hldbm='heroku local:run rails db:migrate'

# Tail dev logs in Rails project root
alias devlogs='tail -f log/development.log'

