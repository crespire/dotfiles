if [ -d /opt/homebrew/ ]; then
  source /opt/homebrew/opt/asdf/libexec/asdf.sh
  export PATH=/opt/homebrew/bin:$PATH
  export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"
else
  source $HOME/.asdf/asdf.sh
fi

# autoload
autoload -Uz compinit && compinit
autoload -Uz vcs_info
precmd() { vcs_info }

# History file
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000

# zstyle
zstyle ':completion:*' completer _complete _ignored _approximate
zstyle :compinstall filename '/home/crespire/.zshrc'
zstyle ':vcs_info:git:*' formats '%b'

# Options
unsetopt autocd
setopt PROMPT_SUBST
bindkey -v

# Prompt
PROMPT='(%T) %F{34}%n%f:%F{32}%4~%f (${vcs_info_msg_0_}) $ '

# Aliases
source ~/.zsh_aliases
source ~/.zprofile

# Kill port
kill_port() {
  port_num=$1
  lsof -ti :$port_num | xargs kill -9
}
