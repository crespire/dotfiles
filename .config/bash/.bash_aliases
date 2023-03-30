#!/bin/bash

alias vim='nvim'
alias fm='thunar'

# Git Clean Branches
alias gcb='git branch --merged | grep -v 'main$' | xargs git branch -d 2>/dev/null'

# Heroku Local
alias hl='heroku local'
alias hlc='heroku local:run rails c'
alias hldbm='heroku local:run rails db:migrate'

# Tail dev logs in Rails project root
alias devlogs='tail -f log/development.log'

