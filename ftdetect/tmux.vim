au BufRead,BufNewFile {.,}tmux*.conf setf tmux
au BufRead,BufNewFile $HOME/.config/tmux/{*.conf,plugins_config/*,plugins/run} setf tmux
