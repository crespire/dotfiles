#!/bin/bash

export PATH="$PATH:$HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/usr/local/go/bin"
if [ -f "$HOME/.cargo/env" ]; then
  source "$HOME/.cargo/env"
fi
