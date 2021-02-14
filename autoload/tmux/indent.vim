vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

def tmux#indent#expr(): number
    # If the  string is not  closed and was  previously indented, then  keep the
    # indentation.
    return PrevLineEndsWithOpenString(v:lnum)
        ?     indent('.')
        :     0
enddef

def HighlightGroup(line: number, col: number): string
    return synID(line, col, true)->synIDattr('name')
enddef

def PrevLineEndsWithOpenString(lnum: number): bool
    if lnum > 1
        var prev_line_len: number = getline(lnum - 1)->strlen()
        if HighlightGroup(lnum - 1, prev_line_len) == 'tmuxString'
            return true
        endif
    endif
    return false
enddef

