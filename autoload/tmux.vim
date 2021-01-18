vim9 noclear

if exists('loaded') | finish | endif
var loaded = true

import Opfunc from 'lg.vim'
const SID: string = execute('fu Opfunc')->matchstr('\C\<def\s\+\zs<SNR>\d\+_')
const PROMPT_SIGIL: string = "\u066a"

def tmux#pasteLastShellCmd(n: number) #{{{1
    sil var buffer: list<string> = systemlist('tmux showb')

    # The last 2 lines are the prompt of the last yet-to-be-typed command.  Useless.
    buffer = buffer[: -3]

    # remove the top part of all the prompts
    # (i.e. any element after an element which starts with the prompt sigil)
    # Why `copy()`?{{{
    #
    # Because we're going to filter the list `buffer` with a test which involves
    # the item *following* the one currently filtered.
    # And because `filter()` may alter the size of `buffer` during the filtering.
    #
    # If the test only involved the current item, there would be no need for `copy()`.
    #}}}
    var copy_buffer: list<string> = copy(buffer)
    var len_buffer: number = len(buffer)
    filter(buffer, (i, v) =>
           i == 0
        || i == len_buffer - 1
        || copy_buffer[i + 1][0] != PROMPT_SIGIL)
    var idx: number = match(buffer, '^' .. PROMPT_SIGIL, 0, n + 1)
    if idx == -1
        idx = len_buffer
    endif
    buffer = buffer[: idx - 1]

    # Why don't you delete the tmux buffer from the tmux key binding which runs this Vim function?{{{
    #
    # `copy-pipe` and  `if-shell` don't block,  so there's  no way to  know when
    # `deleteb` would be run.
    # In practice,  it seems to  be run before Vim  is invoked, which  means that
    # `$ tmux showb` wouldn't give the buffer you expect.
    #}}}
    sil system('tmux deleteb')
    if &ft != 'markdown'
        # run `redraw!` to clear the command-line
        redraw!
        return
    endif
    buffer->map((_, v) => substitute(v, '^[^٪].*\zs', '~', ''))
          ->map((_, v) => substitute(v, '^٪', '$', ''))
          ->map((_, v) => '    ' .. v)
    if getline('.') =~ '\S'
        buffer = [''] + buffer
    endif
    if (line('.') + 1)->getline() =~ '\S'
        buffer = buffer + ['']
    endif
    append('.', buffer)
    update
    redraw!
enddef

def tmux#undoFtplugin() #{{{1
    set cms< efm< mp<
    nunmap <buffer> g"
    nunmap <buffer> g""
    xunmap <buffer> g"
enddef
#}}}1

# K {{{1
# keyword based jump dictionary maps {{{2

# Mapping short keywords to their longer version so they can be found
# in man page with 'K'
# '\[' at the end of the keyword ensures the match jumps to the correct
# place in tmux manpage where the option/command is described.
const KEYWORD_MAPPINGS: dict<string> = {
    attach:       'attach-session',
    bind:         'bind-key \[',
    bind-key:     'bind-key \[',
    breakp:       'break-pane',
    capturep:     'capture-pane',
    clearhist:    'clear-history',
    confirm:      'confirm-before',
    copyb:        'copy-buffer',
    deleteb:      'delete-buffer',
    detach:       'detach-client',
    display:      'display-message',
    displayp:     'display-panes',
    findw:        'find-window',
    has:          'has-session',
    if:           'if-shell',
    joinp:        'join-pane',
    killp:        'kill-pane',
    killw:        'kill-window',
    last:         'last-window',
    lastp:        'last-pane',
    linkw:        'link-window',
    loadb:        'load-buffer',
    lock:         'lock-server',
    lockc:        'lock-client',
    locks:        'lock-session',
    ls:           'list-sessions',
    lsb:          'list-buffers',
    lsc:          'list-clients',
    lscm:         'list-commands',
    lsk:          'list-keys',
    lsp:          'list-panes',
    lsw:          'list-windows \[',
    list-windows: 'list-windows \[',
    movep:    'move-pane',
    movew:    'move-window',
    new:      'new-session',
    neww:     'new-window',
    next:     'next-window',
    nextl:    'next-layout',
    pasteb:   'paste-buffer',
    pipep:    'pipe-pane',
    prev:     'previous-window',
    prevl:    'previous-layout',
    refresh:  'refresh-client',
    rename:   'rename-session',
    renamew:  'rename-window',
    resizep:  'resize-pane',
    respawnp: 'respawn-pane',
    respawnw: 'respawn-window',
    rotatew:  'rotate-window',
    run:      'run-shell',
    saveb:    'save-buffer',
    selectl:  'select-layout \[',
    select-layout: 'select-layout \[',
    selectp:    'select-pane',
    selectw:    'select-window',
    send:       'send-keys',
    set:        'set-option \[',
    set-option: 'set-option \[',
    setb:       'set-buffer \[',
    set-buffer: 'set-buffer \[',
    setenv:     'set-environment',
    setw:       'set-window-option \[',
    set-window-option: 'set-window-option \[',
    show:     'show-options',
    showb:    'show-buffer',
    showenv:  'show-environment',
    showmsgs: 'show-messages',
    showw:    'show-window-options \[',
    show-window-options: 'show-window-options \[',
    source:        'source-file',
    splitw:        'split-window \[',
    split-window:  'split-window \[',
    start:         'start-server',
    suspendc:      'suspend-client',
    swapp:         'swap-pane',
    swapw:         'swap-window',
    switchc:       'switch-client \[',
    switch-client: 'switch-client \[',
    unbind:        'unbind-key \[',
    unbind-key:    'unbind-key \[',
    unlinkw:       'unlink-window'
    }

# Syntax  highlight group  names are  arranged by  tmux manpage  sections.  That
# makes it easy to find a section in the manpage where the keyword is described.
# This  dictionary provides  a  mapping  between a  syntax  highlight group  and
# related manpage section.
const HIGHLIGHT_GROUP_MANPAGE_SECTION: dict<string> = {
    tmuxClientSessionCmds: 'CLIENTS AND SESSIONS',
    tmuxWindowPaneCmds:    'WINDOWS AND PANES',
    tmuxBindingCmds:       'KEY BINDINGS',
    tmuxOptsSet:           'OPTIONS',
    tmuxOptsSetw:          'OPTIONS',
    tmuxEnvironmentCmds:   'ENVIRONMENT',
    tmuxStatusLineCmds:    'STATUS LINE',
    tmuxBufferCmds:        'BUFFERS',
    tmuxMiscCmds:          'MISCELLANEOUS'
    }

# keyword based jump {{{2

def GetSearchKeyword(keyword: string): string
    return has_key(KEYWORD_MAPPINGS, keyword)
        ?     KEYWORD_MAPPINGS[keyword]
        :     keyword
enddef

def ManTmuxSearch(section: string, regex: string): bool
    if search('^' .. section, 'W') == 0
        return false
    endif
    if search(regex, 'W') == 0
        return false
    endif
    return true
enddef

def KeywordBasedJump(highlight_group: string, keyword: string)
    var section: string = has_key(HIGHLIGHT_GROUP_MANPAGE_SECTION, highlight_group)
        ?     HIGHLIGHT_GROUP_MANPAGE_SECTION[highlight_group]
        :     ''
    var search_keyword: string = GetSearchKeyword(keyword)

    Man tmux

    if ManTmuxSearch(section, '^\s\+\zs' .. search_keyword)
    || ManTmuxSearch(section, search_keyword)
    || ManTmuxSearch('', keyword)
        norm! zt
    else
        redraw
        echohl ErrorMsg
        echo "Sorry, couldn't find " .. keyword
        echohl None
    endif
enddef

# highlight group based jump {{{2

const HIGHLIGHT_GROUP_TO_MATCH_MAPPING: dict<list<string>> = {
    tmuxKeyTable:            ['KEY BINDINGS', '^\s\+\zslist-keys', ''],
    tmuxLayoutOptionValue:   ['WINDOWS AND PANES', '^\s\+\zs{}', '^\s\+\zsThe following layouts are supported'],
    tmuxUserOptsSet:         ['.', '^OPTIONS', ''],
    tmuxKeySymbol:           ['KEY BINDINGS', '^KEY BINDINGS', ''],
    tmuxKey:                 ['KEY BINDINGS', '^KEY BINDINGS', ''],
    tmuxAdditionalCommand:   ['COMMANDS', '^\s\+\zsMultiple commands may be specified together', ''],
    tmuxColor:               ['OPTIONS', '^\s\+\zsmessage-command-style', '^\s\+\zsmessage-bg'],
    tmuxStyle:               ['OPTIONS', '^\s\+\zsmessage-command-style', '^\s\+\zsmessage-attr'],
    tmuxPromptInpol:         ['STATUS LINE', '^\s\+\zscommand-prompt', ''],
    tmuxFmtInpol:            ['.', '^FORMATS', ''],
    tmuxFmtInpolDelimiter:   ['.', '^FORMATS', ''],
    tmuxFmtAlias:            ['.', '^FORMATS', ''],
    tmuxFmtVariable:         ['FORMATS', '^\s\+\zs{}', 'The following variables are available'],
    tmuxFmtConditional:      ['.', '^FORMATS', ''],
    tmuxFmtLimit:            ['.', '^FORMATS', ''],
    tmuxDateInpol:           ['OPTIONS', '^\s\+\zsstatus-left', ''],
    tmuxAttrInpol:           ['OPTIONS', '^\s\+\zsstatus-left', ''],
    tmuxAttrInpolDelimiter:  ['OPTIONS', '^\s\+\zsstatus-left', ''],
    tmuxAttrBgFg:            ['OPTIONS', '^\s\+\zsmessage-command-style', '^\s\+\zsstatus-left'],
    tmuxAttrEquals:          ['OPTIONS', '^\s\+\zsmessage-command-style', '^\s\+\zsstatus-left'],
    tmuxAttrSeparator:       ['OPTIONS', '^\s\+\zsmessage-command-style', '^\s\+\zsstatus-left'],
    tmuxShellInpol:          ['OPTIONS', '^\s\+\zsstatus-left', ''],
    tmuxShellInpolDelimiter: ['OPTIONS', '^\s\+\zsstatus-left', '']
    }

def HighlightGroupBasedJump(highlight_group: string, keyword: string)
    Man tmux
    var section: string = HIGHLIGHT_GROUP_TO_MATCH_MAPPING[highlight_group][0]
    var search_string: string = HIGHLIGHT_GROUP_TO_MATCH_MAPPING[highlight_group][1]
    var fallback_string: string = HIGHLIGHT_GROUP_TO_MATCH_MAPPING[highlight_group][2]

    var search_keyword: string = substitute(search_string, '{}', keyword, '')
    if ManTmuxSearch(section, search_keyword)
    || ManTmuxSearch(section, fallback_string)
        norm! zt
    else
        redraw
        echohl ErrorMsg
        echo 'Sorry, couldn''t find the exact description'
        echohl None
    end
enddef

# just open manpage {{{2

def s:JustOpenManpage(highlight_group: string): bool
    var char_under_cursor: string = getline('.')->strpart(col('.') - 1)[0]
    var syn_groups: list<string> =<< trim END

        tmuxStringDelimiter
        tmuxOptions
        tmuxAction
        tmuxBoolean
        tmuxOptionValue
        tmuxNumber
    END
    return index(syn_groups, highlight_group) >= 0 || char_under_cursor =~ '\s'
enddef

# 'public' function {{{2

# From where do we call `tmux#man()`?{{{
#
# `doc#mapping#main()`.
#}}}
# Why don't you simply install a local `K` mapping calling `tmux#man()`?{{{
#
# We would  not be able to  press `K` on constructs  like codespans, codeblocks,
# `:h cmd`, `man cmd`, `info cmd`, `CSI ...` inside a tmux file.
#
# IOW, we want to integrate `tmux#man()` into `doc#mapping#main()`.
# To  do so,  the latter  must first  be  invoked to  try and  detect whether  a
# familiar construct exists around the cursor position.
# *Then*, if nothing is found, we can fall back on `tmux#man()`.
# The only way to achieve this is to invoke `tmux#man()` from `doc#mapping#main()`.
#}}}
def tmux#man()
    var keyword: string = expand('<cWORD>')

    var highlight_group: string = synID('.', col('.'), 1)->synIDtrans()->synIDattr('name')
    if JustOpenManpage(highlight_group)
        Man tmux
    elseif has_key(HIGHLIGHT_GROUP_TO_MATCH_MAPPING, highlight_group)
        return HighlightGroupBasedJump(highlight_group, keyword)
    else
        return KeywordBasedJump(highlight_group, keyword)
    endif
enddef
# }}}1
# g" {{{1

def tmux#filterop(): string
    &opfunc = SID .. 'Opfunc'
    g:opfunc = {core: 'tmux#filteropCore'}
    return 'g@'
enddef

def tmux#filteropCore(_: any)
    redraw
    var lines: list<string> = getreg('"', true, true)

    var all_output: string = ''
    var index: number = 0
    while index < len(lines)
        var line: string = lines[index]

        # if line is a part of multi-line string (those have '\' at the end)
        # and not last line, perform " concatenation
        while line =~ '\\\s*$' && index != len(lines) - 1
            index += 1
            # remove '\' from line end
            line = substitute(line, '\\\s*$', '', '')
            # append next line
            line ..= lines[index]
        endwhile

        # skip empty line and comments
        if line =~ '^\s*\%(#\|$\)'
            continue
        endif

        var command: string = 'tmux ' .. line
        if all_output =~ '\S'
            all_output ..= "\n" .. command
        # empty var, do not include newline first
        else
            all_output = command
        endif

        sil var output: string = system(command)
        if v:shell_error
            # reset `v:shell_error`
            system('')
            throw output
        elseif output =~ '\S'
            all_output ..= "\n> " .. output[0 : -2]
        endif

        index += 1
    endwhile

    if all_output =~ '\S'
        redraw
        echo all_output
    endif
enddef

