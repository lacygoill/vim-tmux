if exists('did_load_filetypes')
    finish
endif

augroup filetypedetect
    au! BufRead,BufNewFile {.,}tmux*.conf setf tmux
    au! BufRead,BufNewFile $HOME/.tmux/{*.conf,plugins_config/*,plugins/run} setf tmux
augroup END

