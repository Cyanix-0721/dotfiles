# =============================================================================
# Fish Abbreviations for Common Tools
# =============================================================================

# -----------------------------------------------------------------------------
# Git abbreviations
# -----------------------------------------------------------------------------
abbr -a gs   'git status'
abbr -a gd   'git diff'
abbr -a gdc  'git diff --cached'
abbr -a ga   'git add'
abbr -a gaa  'git add --all'
abbr -a gc   'git commit'
abbr -a gcm  'git commit -m'
abbr -a gca  'git commit --amend'
abbr -a gco  'git checkout'
abbr -a gcb  'git checkout -b'
abbr -a gp   'git push'
abbr -a gpl  'git pull'
abbr -a gf   'git fetch'
abbr -a gl   'git log --oneline --graph'
abbr -a gll  'git log --graph --pretty=format:"%C(yellow)%h%Creset %s %Cgreen(%cr)%Creset %C(blue)<%an>%Creset"'
abbr -a gr   'git restore'
abbr -a gb   'git branch'
abbr -a gbd  'git branch -d'

# -----------------------------------------------------------------------------
# Directory navigation
# -----------------------------------------------------------------------------
abbr -a ..   'cd ..'
abbr -a ...  'cd ../..'
abbr -a .... 'cd ../../..'

# -----------------------------------------------------------------------------
# File listing (eza)
# -----------------------------------------------------------------------------
abbr -a ls   'eza --icons'
abbr -a ll   'eza -l --icons'
abbr -a la   'eza -la --icons'
abbr -a lt   'eza --tree --icons'
abbr -a llt  'eza -l --tree --icons'
abbr -a lr   'eza -R --icons'
abbr -a lsd  'eza -D --icons'

# -----------------------------------------------------------------------------
# Search tools (ripgrep, fd)
# -----------------------------------------------------------------------------
abbr -a grep 'rg'          # ripgrep
abbr -a find 'fd'          # fd-find
abbr -a rgi  'rg -i'       # case-insensitive ripgrep
abbr -a fdi  'fd -i'       # case-insensitive fd

# -----------------------------------------------------------------------------
# File viewing (bat)
# -----------------------------------------------------------------------------
abbr -a cat  'bat'
abbr -a less 'bat'
abbr -a b    'bat'

# -----------------------------------------------------------------------------
# Fuzzy finder (fzf)
# -----------------------------------------------------------------------------
abbr -a ff   'fzf'
abbr -a fh   'history | fzf'
abbr -a fcd  'cd (find . -type d | fzf)'
abbr -a fcat 'bat (fzf)'

# -----------------------------------------------------------------------------
# System utilities
# -----------------------------------------------------------------------------
abbr -a c    'clear'
abbr -a x    'chmod +x'
abbr -a t    'tmux'
abbr -a tn   'tmux new -s'
abbr -a ta   'tmux attach -t'

# -----------------------------------------------------------------------------
# Development shortcuts
# -----------------------------------------------------------------------------
abbr -a p    'python'
abbr -a p3   'python3'
abbr -a ipy  'ipython'
abbr -a n    'node'
abbr -a nr   'npm run'

# -----------------------------------------------------------------------------
# Fish shell management
# -----------------------------------------------------------------------------
abbr -a abedit 'vim ~/.config/fish/conf.d/02-abbr.fish'
