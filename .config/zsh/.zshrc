if [ -d /opt/homebrew/ ]; then
  source /opt/homebrew/opt/asdf/libexec/asdf.sh
  export PATH=/opt/homebrew/bin:$PATH
else
  source $HOME/.asdf/asdf.sh
fi

export ASDF_GOLANG_MOD_VERSION_ENABLED=true

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

# Aliases and things
source ~/.zsh_aliases
source ~/.zsh_funcs
source ~/.zprofile

# Golang via ASDF
source ~/.asdf/plugins/golang/set-env.zsh
export ASDF_GOLANG_MOD_VERSION_ENABLED=true

# Kill port
kill_port() {
  port_num=$1
  lsof -ti :$port_num | xargs kill -9
}

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/simmonli/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/simmonli/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/simmonli/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/simmonli/google-cloud-sdk/completion.zsh.inc'; fi
