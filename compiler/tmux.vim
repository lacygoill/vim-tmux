if exists('current_compiler')
    finish
endif
let current_compiler = 'tmux'

if exists(':CompilerSet') != 2
    com -nargs=* CompilerSet setl <args>
endif

CompilerSet makeprg=tmux\ source-file\ %:p

CompilerSet errorformat=
    \%f:%l:%m,
    \%+Gunknown\ command:\ %s

