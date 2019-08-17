if exists('b:current_syntax')
    finish
endif

" Make sure a hyphen is a keyword character.
syn iskeyword -,@,48-57,_,192-255
syn case match

syn keyword tmuxHookCmds set-hook show-hooks

syn keyword tmuxAction  any current none
syn keyword tmuxBoolean off on
syn keyword tmuxOptionValue top bottom left right top-left top-right
syn keyword tmuxOptionValue bottom-left bottom-right centre
syn keyword tmuxOptionValue vi emacs copy
syn keyword tmuxOptionValue bash zsh fish
syn keyword tmuxLayoutOptionValue even-horizontal even-vertical main-horizontal
syn keyword tmuxLayoutOptionValue main-vertical tiled

syn keyword tmuxClientSessionCmds attach[-session] detach[-client] has[-session]
syn keyword tmuxClientSessionCmds kill-server kill-session lsc list-clients lscm
syn keyword tmuxClientSessionCmds list-commands ls list-sessions lockc lock-client
syn keyword tmuxClientSessionCmds locks lock-session new[-session] refresh[-client]
syn keyword tmuxClientSessionCmds rename[-session] showmsgs show-messages
syn keyword tmuxClientSessionCmds source[-file] start[-server] suspendc
syn keyword tmuxClientSessionCmds suspend-client switchc switch-client

syn keyword tmuxWindowPaneCmds copy-mode breakp break-pane capturep capture-pane
syn keyword tmuxWindowPaneCmds choose-client choose-session choose-tree
syn keyword tmuxWindowPaneCmds choose-window displayp display-panes findw
syn keyword tmuxWindowPaneCmds find-window joinp join-pane killp kill-pane
syn keyword tmuxWindowPaneCmds killw kill-window lastp last-pane last[-window]
syn keyword tmuxWindowPaneCmds linkw link-window lsp list-panes lsw list-windows
syn keyword tmuxWindowPaneCmds movep move-pane movew move-window neww new-window
syn keyword tmuxWindowPaneCmds nextl next-layout next[-window] pipep pipe-pane
syn keyword tmuxWindowPaneCmds prevl previous-layout prev[ious-window] renamew
syn keyword tmuxWindowPaneCmds rename-window resizep resize-pane respawnp
syn keyword tmuxWindowPaneCmds respawn-pane respawnw respawn-window rotatew
syn keyword tmuxWindowPaneCmds rotate-window selectl select-layout selectp
syn keyword tmuxWindowPaneCmds select-pane selectw select-window splitw
syn keyword tmuxWindowPaneCmds split-window swapp swap-pane swapw swap-window
syn keyword tmuxWindowPaneCmds unlinkw unlink-window

syn keyword tmuxBindingCmds lsk list-keys send[-keys] send-prefix

syn keyword tmuxEnvironmentCmds setenv set-environment showenv show-environment

syn keyword tmuxStatusLineCmds command-prompt confirm[-before] display[-message] display-menu menu

syn keyword tmuxBufferCmds choose-buffer clearhist clear-history deleteb
syn keyword tmuxBufferCmds delete-buffer lsb list-buffers loadb load-buffer
syn keyword tmuxBufferCmds pasteb paste-buffer saveb save-buffer setb set-buffer
syn keyword tmuxBufferCmds showb show-buffer

syn keyword tmuxMiscCmds clock-mode if[-shell] lock[-server] wait[-for]
" obsolete (not in manpage anymore)
syn keyword tmuxMiscCmds info server-info

syn keyword tmuxOptsSet prefix prefix2 status status-fg status-bg bell-action
syn keyword tmuxOptsSet default-command history-file history-limit status-left status-right
syn keyword tmuxOptsSet status-interval set-titles display-time buffer-limit
syn keyword tmuxOptsSet status-left-length status-right-length status-position
syn keyword tmuxOptsSet message-command-bg message-bg lock-after-time default-path
syn keyword tmuxOptsSet message-command-attr message-attr status-attr set-remain-on-exit
syn keyword tmuxOptsSet status-utf8 default-terminal visual-activity repeat-time
syn keyword tmuxOptsSet visual-bell visual-content status-justify status-keys
syn keyword tmuxOptsSet terminal-overrides status-left-attr status-left-bg
syn keyword tmuxOptsSet status-left-fg status-right-attr status-right-bg
syn keyword tmuxOptsSet status-right-fg status-style update-environment base-index
syn keyword tmuxOptsSet display-panes-colour display-panes-time default-shell
syn keyword tmuxOptsSet set-titles-string lock-command lock-server
syn keyword tmuxOptsSet mouse-select-pane message-limit quiet escape-time
syn keyword tmuxOptsSet pane-active-border-bg pane-active-border-fg
syn keyword tmuxOptsSet pane-border-bg pane-border-fg message-command-fg message-fg
syn keyword tmuxOptsSet pane-border-status pane-border-format
syn keyword tmuxOptsSet display-panes-active-colour alternate-screen
syn keyword tmuxOptsSet detach-on-destroy word-separators
syn keyword tmuxOptsSet destroy-unattached exit-unattached focus-events set-clipboard
syn keyword tmuxOptsSet bell-on-alert mouse-select-window mouse-utf8
syn keyword tmuxOptsSet mouse-resize-pane mouse
syn keyword tmuxOptsSet renumber-windows visual-silence
syn keyword tmuxOptsSet show[-options] showw show-window-options

syn match tmuxUserOptsSet /@[[:alnum:]_-]\+/ display

syn keyword tmuxOptsSetw monitor-activity aggressive-resize force-width
syn keyword tmuxOptsSetw force-height remain-on-exit mode-fg mode-bg
syn keyword tmuxOptsSetw mode-keys clock-mode-colour clock-mode-style
syn keyword tmuxOptsSetw xterm-keys mode-attr window-status-attr
syn keyword tmuxOptsSetw window-status-bg window-status-fg automatic-rename
syn keyword tmuxOptsSetw main-pane-width main-pane-height monitor-content
syn keyword tmuxOptsSetw window-status-current-attr window-status-current-bg
syn keyword tmuxOptsSetw window-status-current-fg mode-mouse synchronize-panes
syn keyword tmuxOptsSetw window-status-format window-status-current-format
syn keyword tmuxOptsSetw window-status-activity-attr
syn keyword tmuxOptsSetw window-status-activity-bg window-status-activity-fg
syn keyword tmuxOptsSetw window-status-bell-attr
syn keyword tmuxOptsSetw window-status-bell-bg window-status-bell-fg
syn keyword tmuxOptsSetw window-status-content-attr
syn keyword tmuxOptsSetw window-status-content-bg window-status-content-fg
syn keyword tmuxOptsSetw window-status-separator window-status-last-attr
syn keyword tmuxOptsSetw window-status-last-fg window-status-last-bg
syn keyword tmuxOptsSetw window-status-activity-style window-status-bell-style
syn keyword tmuxOptsSetw pane-base-index other-pane-height other-pane-width
syn keyword tmuxOptsSetw allow-rename c0-change-interval c0-change-trigger
syn keyword tmuxOptsSetw layout-history-limit monitor-silence utf8 wrap-search
syn keyword tmuxOptsSetw window-active-style window-style
syn keyword tmuxOptsSetw pane-active-border-style pane-border-style

" keywords for vi/emacs edit, choice and copy modes
syn keyword tmuxModeCmds append-selection back-to-indentation backspace
syn keyword tmuxModeCmds begin-selection bottom-line cancel choose clear-selection
syn keyword tmuxModeCmds complete copy-end-of-line copy-pipe copy-pipe-and-cancel
syn keyword tmuxModeCmds copy-selection copy-selection-and-cancel copy-line
syn keyword tmuxModeCmds cursor-down cursor-left cursor-right cursor-up
syn keyword tmuxModeCmds delete delete-end-of-line delete-line delete-word down
syn keyword tmuxModeCmds end-of-line end-of-list enter goto-line halfpage-down
syn keyword tmuxModeCmds halfpage-up history-bottom history-down history-top
syn keyword tmuxModeCmds history-up jump-again jump-backward jump-forward
syn keyword tmuxModeCmds jump-reverse jump-to-backward jump-to-forward middle-line
syn keyword tmuxModeCmds next-matching-bracket next-space next-space-end next-word next-word-end
syn keyword tmuxModeCmds other-end page-down page-up paste previous-space previous-word
syn keyword tmuxModeCmds rectangle-toggle scroll-down scroll-up search-again
syn keyword tmuxModeCmds search-backward search-forward search-reverse select-line select-word
syn keyword tmuxModeCmds start-named-buffer start-number-prefix start-of-line
syn keyword tmuxModeCmds start-of-list switch-mode switch-mode-append
syn keyword tmuxModeCmds switch-mode-append-line switch-mode-begin-line
syn keyword tmuxModeCmds switch-mode-change-line switch-mode-substitute
syn keyword tmuxModeCmds switch-mode-substitute-line top-line transpose-chars
syn keyword tmuxModeCmds tree-collapse tree-collapse-all tree-expand
syn keyword tmuxModeCmds tree-expand-all tree-toggle up

" These keys can be used for the 'bind' command
syn keyword tmuxKeySymbol Enter Escape Space BSpace Home End Tab BTab DC IC
syn keyword tmuxKeySymbol F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 F11 F12
syn keyword tmuxKeySymbol NPage PageDown PgDn PPage PageUp PgUp
syn keyword tmuxKeySymbol Up Down Left Right

" these commands are special when at the beginning of the line
syn match tmuxMiscCmds        /run\(-shell\)\?/ display
syn match tmuxSpecialCmds /^\s*\zsrun\(-shell\)\?/ display

syn match tmuxBindingCmds     /bind\(-key\)\?/ display
syn match tmuxSpecialCmds /^\s*\zsbind\(-key\)\?/ display

syn match tmuxBindingCmds     /unbind\(-key\)\?/ display
syn match tmuxSpecialCmds /^\s*\zsunbind\(-key\)\?/ display

syn match tmuxOptsSet         /set\(-option\)\?/ display
syn match tmuxSpecialCmds /^\s*\zsset\(-option\)\?/ display

syn match tmuxOptsSetw        /\(setw\|set-window-option\)/ display
syn match tmuxSpecialCmds /^\s*\zs\(setw\|set-window-option\)/ display

" Why the `skip` argument?{{{
"
" Because of this undocumented syntax:
"
"                         v
"     # some tmux comment \
"     this second line is still considered commented by tmux!!!
"
" This  is because  tmux joins  continuation  lines, *then*  checks whether  the
" resulting line is commented:
" https://github.com/tmux/tmux/issues/75#issuecomment-130452290
"
" I don't want to wrongly think that a  line of code is sourced, while in effect
" it is *not*.
"}}}
" Why the `keepend` argument?{{{
"
" To  prevent  a  commented  codeblock  from continuing  on  the  next  line  of
" uncommented code:
"
"     #     x
"     set -s default-terminal tmux-256color
"
" In this example, without `keepend`, the `set` line would be wrongly commented.
"}}}
"   Does it cause an issue?{{{
"
" Yes.
"
" Because of it, a commented list item stops after the first line:
"
"     + the start of this list item is correctly highlighted
"       but the next line is not (it's highlighted as a commented code block)
"
" It's  an  acceptable issue:  don't  use  a list  in  a  tmux comment,  or  use
" single-line items only.
"
" ---
"
" If you think you can fix this issue, test your solution against this text:
"
"     #    - list item
"     #      continuation of list item
"
"     #     codeblock
"     command
"
"     # comment \
"     continuation of comment
"}}}
"   Why other similar syntax groups like `shComment` don't need `keepend`?{{{
"
" `shComment` is a match, so no issue.
" But `tmuxComment` *must* be a region, because we need `skip`.
"}}}
syn region tmuxComment start=/#/ skip=/\\\@<!\\$/ end=/$/ contains=tmuxTodo,tmuxURL,@Spell keepend

syn keyword tmuxTodo FIXME NOTE TODO XXX todo contained

syn match tmuxKey               /\(C-\|M-\|\^\)\+\S\+/  display
syn match tmuxKey               /\%(^\s*\%(un\)\=bind\%(-key\)\=\s\+\%(\%(-T\s\+\%(copy-mode-vi\|copy-mode\|root\)\|-r\)\s\+\)\=\)\@<=\S\+/ display
syn match tmuxNumber            /\<[+-]\?\d\+/          display
syn match tmuxSelWindowOption   /:[!+-]\?/              display
syn match tmuxOptions           /\s-\a\+/               display
syn match tmuxVariable          /\w\+=/                 display
syn match tmuxVariableExpansion /\${\=\w\+}\=/          display
syn match tmuxAdditionalCommand /\\;/ display

syn match tmuxKeyTable /\s\%(-T\)\=\(copy-mode-vi\|copy-mode\|root\)/ display

syn match tmuxColor /\(bright\)\?\(black\|red\|green\|yellow\|blue\|magenta\|cyan\|white\)/ display
syn match tmuxColor /default/        display
syn match tmuxColor /colour\d\{1,3}/ display
syn match tmuxColor /#\x\{6}/        display

syn match tmuxStyle /\(no\)\?\(bright\|bold\|dim\|underscore\|blink\|reverse\|hidden\|italics\)/ display

syn match tmuxPromptInpol /%\d\|%%%\=/ contained

" Matching `man 3 strftime` formats
syn match tmuxDateInpol /%[0_^#-]\?[A-DF-IMR-Z+]/     contained
syn match tmuxDateInpol /%[0_^#-]\?[a-eghj-npr-z]/    contained
syn match tmuxDateInpol /%[0_^#-]\?E[cCxXyY]/         contained
syn match tmuxDateInpol /%[0_^#-]\?O[BdeHImMSuUVwWy]/ contained

" Format aliases
syn match tmuxFmtAlias /#[HhDPTSFIW#]/ contained

" Format interpolation
syn region tmuxFmtInpol matchgroup=tmuxFmtInpolDelimiter start=/#{/ skip=/#{.\{-}}/ end=/}/ contained keepend contains=tmuxFmtVariable,tmuxFmtConditional,tmuxFmtLimit
syn match  tmuxFmtVariable    /[[:alnum:]_-]\+/ contained display
syn match  tmuxFmtConditional /[?,]/            contained display
syn match  tmuxFmtLimit       /=.\{-}:/         contained display contains=tmuxNumber

" Attribute interpolation
syn region tmuxAttrInpol matchgroup=tmuxAttrInpolDelimiter start=/#\[/ skip=/#\[.\{-}]/ end=/]/ contained keepend contains=tmuxColor,tmuxAttrBgFg,tmuxAttrEquals,tmuxAttrSeparator,tmuxStyle
syn match  tmuxAttrBgFg      /[fb]g/ contained display
syn match  tmuxAttrEquals    /=/     contained display
syn match  tmuxAttrSeparator /,/     contained display

" Shell command interpolation
syn region tmuxShellInpol matchgroup=tmuxShellInpolDelimiter start=/#(/ skip=/#(.\{-})/ end=/)/ contained keepend

syn region tmuxString matchgroup=tmuxStringDelimiter start=/"/ skip=/\\./ end=/"/ contains=tmuxFmtInpol,tmuxFmtAlias,tmuxAttrInpol,tmuxShellInpol,tmuxPromptInpol,tmuxDateInpol,@Spell display keepend
syn region tmuxString matchgroup=tmuxStringDelimiter start=/'/ end=/'/            contains=tmuxFmtInpol,tmuxFmtAlias,tmuxAttrInpol,tmuxShellInpol,tmuxPromptInpol,tmuxDateInpol,@Spell display keepend

hi link tmuxHookCmds            Keyword

hi link tmuxAction              Boolean
hi link tmuxBoolean             Boolean
hi link tmuxOptionValue         Constant
hi link tmuxLayoutOptionValue   Constant

hi link tmuxClientSessionCmds   Keyword
hi link tmuxWindowPaneCmds      Keyword
hi link tmuxBindingCmds         Keyword
hi link tmuxEnvironmentCmds     Keyword
hi link tmuxStatusLineCmds      Keyword
hi link tmuxBufferCmds          Keyword
hi link tmuxMiscCmds            Keyword

hi link tmuxSpecialCmds         Type
hi link tmuxComment             Comment
hi link tmuxKey                 Special
hi link tmuxKeySymbol           Special
hi link tmuxNumber              Number
hi link tmuxSelWindowOption     Number
hi link tmuxOptions             Operator
hi link tmuxOptsSet             PreProc
hi link tmuxUserOptsSet         Identifier
hi link tmuxOptsSetw            PreProc
hi link tmuxKeyTable            PreProc
hi link tmuxModeCmds            Keyword
hi link tmuxString              String
hi link tmuxStringDelimiter     Delimiter
hi link tmuxColor               Constant
hi link tmuxStyle               Constant

hi link tmuxPromptInpol         Special
hi link tmuxDateInpol           Special
hi link tmuxFmtAlias            Special
hi link tmuxFmtVariable         Constant
hi link tmuxFmtConditional      Conditional
hi link tmuxFmtLimit            Operator
hi link tmuxAttrBgFg            Constant
hi link tmuxAttrEquals          Operator
hi link tmuxAttrSeparator       Operator
hi link tmuxShellInpol          String
hi link tmuxFmtInpolDelimiter   Delimiter
hi link tmuxAttrInpolDelimiter  Delimiter
hi link tmuxShellInpolDelimiter Delimiter

hi link tmuxTodo                Todo
hi link tmuxVariable            Constant
hi link tmuxVariableExpansion   Constant
hi link tmuxAdditionalCommand   Special

let b:current_syntax = 'tmux'

