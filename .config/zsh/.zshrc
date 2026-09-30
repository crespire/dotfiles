# Interactive setup only. Environment variables live in .zshenv.

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

# Golang via ASDF (source set-env if it exists)
if [ -f ~/.asdf/plugins/golang/set-env.zsh ]; then
  source ~/.asdf/plugins/golang/set-env.zsh
fi

# Google Cloud SDK completions
if [ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]; then . "$HOME/google-cloud-sdk/completion.zsh.inc"; fi

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
