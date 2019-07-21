let current_compiler = 'tmux'

if exists(':CompilerSet') != 2
    com -nargs=* CompilerSet setl <args>
endif

CompilerSet makeprg=tmux\ source-file\ %:p:S

CompilerSet errorformat=
    \%f:%l:%m,
    \%+Gunknown\ command:\ %s

