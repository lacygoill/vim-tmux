fu tmux#paste_last_shell_cmd(n) abort "{{{1
    sil let buffer = systemlist('tmux showb')
    " Why don't you delete the tmux buffer from the tmux key binding which runs this Vim function?{{{
    "
    " `copy-pipe` and  `if-shell` don't block,  so there's  no way to  know when
    " `deleteb` would be run.
    " In practice,  it seems to  be run before Vim  is invoked, which  means that
    " `$ tmux showb` wouldn't give the buffer you expect.
    "}}}
    sil call system('tmux deleteb')
    if &ft isnot# 'markdown'
        " run `redraw!` to clear the command-line
        redraw! | return
    endif
    call s:remove_first_prompt_line_with_cwd(buffer)
    call map(buffer, {_,v -> substitute(v, '^[^٪].*\zs', '~', '')})
    call map(buffer, {_,v -> substitute(v, '^٪', '$', '')})
    call map(buffer, {_,v -> '    '..v})
    if getline('.') =~# '\S'
        let buffer = [''] + buffer
    endif
    if getline(line('.')+1) =~# '\S'
        let buffer = buffer + ['']
    endif
    call append('.', buffer)
    update | redraw!
endfu

fu s:remove_first_prompt_line_with_cwd(buffer) abort
    " Why `copy()`?{{{
    "
    " Because we're going to filter the list `buffer` with a test which involves
    " the item *following* the one currently filtered.
    " And because `filter()` may alter the size of `buffer` during the filtering.
    "
    " If the test only involved the current item, there would be no need for `copy()`.
    "}}}
    let buffer_copy = copy(a:buffer)
    call filter(a:buffer, {i -> get(buffer_copy, i+1, '') !~# '^٪'})
endfu

fu tmux#undo_ftplugin() abort "{{{1
    setl cms<
    set efm< mp<
    nunmap <buffer> g"
    nunmap <buffer> g""
    xunmap <buffer> g"
endfu
"}}}1

" K {{{1
" keyword based jump dictionary maps {{{2

" Mapping short keywords to their longer version so they can be found
" in man page with 'K'
" '\[' at the end of the keyword ensures the match jumps to the correct
" place in tmux manpage where the option/command is described.
let s:keyword_mappings = {
\ 'attach':              'attach-session',
\ 'bind':                'bind-key \[',
\ 'bind-key':            'bind-key \[',
\ 'breakp':              'break-pane',
\ 'capturep':            'capture-pane',
\ 'clearhist':           'clear-history',
\ 'confirm':             'confirm-before',
\ 'copyb':               'copy-buffer',
\ 'deleteb':             'delete-buffer',
\ 'detach':              'detach-client',
\ 'display':             'display-message',
\ 'displayp':            'display-panes',
\ 'findw':               'find-window',
\ 'has':                 'has-session',
\ 'if':                  'if-shell',
\ 'joinp':               'join-pane',
\ 'killp':               'kill-pane',
\ 'killw':               'kill-window',
\ 'last':                'last-window',
\ 'lastp':               'last-pane',
\ 'linkw':               'link-window',
\ 'loadb':               'load-buffer',
\ 'lock':                'lock-server',
\ 'lockc':               'lock-client',
\ 'locks':               'lock-session',
\ 'ls':                  'list-sessions',
\ 'lsb':                 'list-buffers',
\ 'lsc':                 'list-clients',
\ 'lscm':                'list-commands',
\ 'lsk':                 'list-keys',
\ 'lsp':                 'list-panes',
\ 'lsw':                 'list-windows \[',
\ 'list-windows':        'list-windows \[',
\ 'movep':               'move-pane',
\ 'movew':               'move-window',
\ 'new':                 'new-session',
\ 'neww':                'new-window',
\ 'next':                'next-window',
\ 'nextl':               'next-layout',
\ 'pasteb':              'paste-buffer',
\ 'pipep':               'pipe-pane',
\ 'prev':                'previous-window',
\ 'prevl':               'previous-layout',
\ 'refresh':             'refresh-client',
\ 'rename':              'rename-session',
\ 'renamew':             'rename-window',
\ 'resizep':             'resize-pane',
\ 'respawnp':            'respawn-pane',
\ 'respawnw':            'respawn-window',
\ 'rotatew':             'rotate-window',
\ 'run':                 'run-shell',
\ 'saveb':               'save-buffer',
\ 'selectl':             'select-layout \[',
\ 'select-layout':       'select-layout \[',
\ 'selectp':             'select-pane',
\ 'selectw':             'select-window',
\ 'send':                'send-keys',
\ 'set':                 'set-option \[',
\ 'set-option':          'set-option \[',
\ 'setb':                'set-buffer \[',
\ 'set-buffer':          'set-buffer \[',
\ 'setenv':              'set-environment',
\ 'setw':                'set-window-option \[',
\ 'set-window-option':   'set-window-option \[',
\ 'show':                'show-options',
\ 'showb':               'show-buffer',
\ 'showenv':             'show-environment',
\ 'showmsgs':            'show-messages',
\ 'showw':               'show-window-options \[',
\ 'show-window-options': 'show-window-options \[',
\ 'source':              'source-file',
\ 'splitw':              'split-window \[',
\ 'split-window':        'split-window \[',
\ 'start':               'start-server',
\ 'suspendc':            'suspend-client',
\ 'swapp':               'swap-pane',
\ 'swapw':               'swap-window',
\ 'switchc':             'switch-client \[',
\ 'switch-client':       'switch-client \[',
\ 'unbind':              'unbind-key \[',
\ 'unbind-key':          'unbind-key \[',
\ 'unlinkw':             'unlink-window'
\ }

" Syntax highlighting group names are arranged by tmux manpage
" sections. That makes it easy to find a section in the manpage where the
" keyword is described.
" This dictionary provides a mapping between a syntax highlighting group and
" related manpage section.
let s:highlight_group_manpage_section = {
\ 'tmuxClientSessionCmds': 'CLIENTS AND SESSIONS',
\ 'tmuxWindowPaneCmds':    'WINDOWS AND PANES',
\ 'tmuxBindingCmds':       'KEY BINDINGS',
\ 'tmuxOptsSet':           'OPTIONS',
\ 'tmuxOptsSetw':          'OPTIONS',
\ 'tmuxEnvironmentCmds':   'ENVIRONMENT',
\ 'tmuxStatusLineCmds':    'STATUS LINE',
\ 'tmuxBufferCmds':        'BUFFERS',
\ 'tmuxMiscCmds':          'MISCELLANEOUS'
\ }

" keyword based jump {{{2

fu s:get_search_keyword(keyword) abort
    return has_key(s:keyword_mappings, a:keyword)
        \ ?     s:keyword_mappings[a:keyword]
        \ :     a:keyword
endfu

fu s:man_tmux_search(section, regex) abort
    try
        call search('^'.a:section)
        call search(a:regex)
        return 1
    catch
        return 0
    endtry
endfu

fu s:keyword_based_jump(highlight_group, keyword) abort
    let section = has_key(s:highlight_group_manpage_section, a:highlight_group)
        \ ?     s:highlight_group_manpage_section[a:highlight_group]
        \ :     ''
    let search_keyword = s:get_search_keyword(a:keyword)

    Man tmux

    if s:man_tmux_search(section, '^\s\+\zs'.search_keyword)
    \ || s:man_tmux_search(section, search_keyword)
    \ || s:man_tmux_search('', a:keyword)
        norm! zt
    else
        redraw
        echohl ErrorMsg | echo "Sorry, couldn't find ".a:keyword | echohl None
    end
endfu

" highlight group based jump {{{2

let s:highlight_group_to_match_mapping = {
\ 'tmuxKeyTable':            ['KEY BINDINGS', '^\s\+\zslist-keys', ''],
\ 'tmuxLayoutOptionValue':   ['WINDOWS AND PANES', '^\s\+\zs{}', '^\s\+\zsThe following layouts are supported'],
\ 'tmuxUserOptsSet':         ['.', '^OPTIONS', ''],
\ 'tmuxKeySymbol':           ['KEY BINDINGS', '^KEY BINDINGS', ''],
\ 'tmuxKey':                 ['KEY BINDINGS', '^KEY BINDINGS', ''],
\ 'tmuxAdditionalCommand':   ['COMMANDS', '^\s\+\zsMultiple commands may be specified together', ''],
\ 'tmuxColor':               ['OPTIONS', '^\s\+\zsmessage-command-style', '^\s\+\zsmessage-bg'],
\ 'tmuxStyle':               ['OPTIONS', '^\s\+\zsmessage-command-style', '^\s\+\zsmessage-attr'],
\ 'tmuxPromptInpol':         ['STATUS LINE', '^\s\+\zscommand-prompt', ''],
\ 'tmuxFmtInpol':            ['.', '^FORMATS', ''],
\ 'tmuxFmtInpolDelimiter':   ['.', '^FORMATS', ''],
\ 'tmuxFmtAlias':            ['.', '^FORMATS', ''],
\ 'tmuxFmtVariable':         ['FORMATS', '^\s\+\zs{}', 'The following variables are available'],
\ 'tmuxFmtConditional':      ['.', '^FORMATS', ''],
\ 'tmuxFmtLimit':            ['.', '^FORMATS', ''],
\ 'tmuxDateInpol':           ['OPTIONS', '^\s\+\zsstatus-left', ''],
\ 'tmuxAttrInpol':           ['OPTIONS', '^\s\+\zsstatus-left', ''],
\ 'tmuxAttrInpolDelimiter':  ['OPTIONS', '^\s\+\zsstatus-left', ''],
\ 'tmuxAttrBgFg':            ['OPTIONS', '^\s\+\zsmessage-command-style', '^\s\+\zsstatus-left'],
\ 'tmuxAttrEquals':          ['OPTIONS', '^\s\+\zsmessage-command-style', '^\s\+\zsstatus-left'],
\ 'tmuxAttrSeparator':       ['OPTIONS', '^\s\+\zsmessage-command-style', '^\s\+\zsstatus-left'],
\ 'tmuxShellInpol':          ['OPTIONS', '^\s\+\zsstatus-left', ''],
\ 'tmuxShellInpolDelimiter': ['OPTIONS', '^\s\+\zsstatus-left', '']
\ }

fu s:highlight_group_based_jump(highlight_group, keyword) abort
    Man tmux
    let section = s:highlight_group_to_match_mapping[a:highlight_group][0]
    let search_string = s:highlight_group_to_match_mapping[a:highlight_group][1]
    let fallback_string = s:highlight_group_to_match_mapping[a:highlight_group][2]

    let search_keyword = substitute(search_string, '{}', a:keyword, "")
    if s:man_tmux_search(section, search_keyword) ||
    \ s:man_tmux_search(section, fallback_string)
        norm! zt
    else
        redraw
        echohl ErrorMsg | echo 'Sorry, couldn't find the exact description' | echohl None
    end
endfu

" just open manpage {{{2

fu s:just_open_manpage(highlight_group) abort
    let char_under_cursor = matchstr(getline('.'), '\%'.col('.').'c.')
    let syn_groups =<< trim END

        tmuxStringDelimiter
        tmuxOptions
        tmuxAction
        tmuxBoolean
        tmuxOptionValue
        tmuxNumber
    END
    return index(syn_groups, a:highlight_group) >= 0 ||
        \ char_under_cursor =~# '\s'
endfu

" 'public' function {{{2

" From where do we call `tmux#man()`?{{{
"
" `doc#mapping#main()`.
"}}}
" Why don't you simply install a local `K` mapping calling `tmux#man()`?{{{
"
" We would  not be able to  press `K` on constructs  like codespans, codeblocks,
" `:h cmd`, `man cmd`, `info cmd`, `CSI ...` inside a tmux file.
"
" IOW, we want to integrate `tmux#man()` into `doc#mapping#main()`.
" To  do so,  the latter  must first  be  invoked to  try and  detect whether  a
" familiar construct exists around the cursor position.
" *Then*, if nothing is found, we can fall back on `tmux#man()`.
" The only way to achieve this is to invoke `tmux#man()` from `doc#mapping#main()`.
"}}}
fu tmux#man(...) abort
    let keyword = expand('<cWORD>')

    let highlight_group = synIDattr(synIDtrans(synID(line('.'), col('.'), 1)), 'name')
    if s:just_open_manpage(highlight_group)
        Man tmux
    elseif has_key(s:highlight_group_to_match_mapping, highlight_group)
        return s:highlight_group_based_jump(highlight_group, keyword)
    else
        return s:keyword_based_jump(highlight_group, keyword)
    endif
endfu
" }}}1
" g! {{{1

fu s:opfunc(type) abort
    let sel_save = &selection
    let cb_save = &clipboard
    let reg_save = @@
    try
        set selection=inclusive clipboard-=unnamed clipboard-=unnamedplus
        if a:type =~ '^\d\+$'
             sil exe 'norm! ^v'.a:type.'$hy'
        elseif a:type =~# '^.$'
             sil exe "norm! `<" . a:type . "`>y"
        elseif a:type is# 'line'
             norm! '[V']y
        elseif a:type is# 'block'
             sil exe "norm! `[\<c-V>`]y"
        else
             norm! `[v`]y
        endif
        redraw
        return @@
    finally
        let @@ = reg_save
        let &selection = sel_save
        let &clipboard = cb_save
    endtry
endfu

fu tmux#filterop(type) abort
    let reg_save = @@
    try
        let expr = s:opfunc(a:type)
        let lines = split(expr, "\n")
        let all_output = ""
        let index = 0
        while index < len(lines)
            let line = lines[index]

            " if line is a part of multi-line string (those have '\' at the end)
            " and not last line, perform " concatenation
            while line =~# '\\\s*$' && index != len(lines)-1
                let index += 1
                " remove '\' from line end
                let line = substitute(line, '\\\s*$', '', '')
                " append next line
                let line ..= lines[index]
            endwhile

            " skip empty line and comments
            if line =~# '^\s*\%(#\|$\)'
                continue
            endif

            let command = 'tmux '.line
            if all_output =~# '\S'
                let all_output ..= "\n".command
            else  " empty var, do not include newline first
                let all_output = command
            endif

            sil let output = system(command)
            if v:shell_error
                " reset `v:shell_error`
                call system('')
                throw output
            elseif output =~# '\S'
                let all_output ..= "\n> ".output[0:-2]
            endif

            let index += 1
        endwhile

        if all_output =~# '\S'
            redraw
            echo all_output
        endif
    catch /^.*/
        redraw
        echo all_output
        return lg#catch_error()
    finally
        let @@ = reg_save
    endtry
endfu

