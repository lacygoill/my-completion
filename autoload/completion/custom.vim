vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

def completion#custom#easyCXCP() #{{{1
    if completeopt_save == ''
        completeopt_save = &completeopt
        set completeopt-=noinsert
        timer_start(0, (_) => RestoreCot())
    endif
enddef
var completeopt_save: string

def RestoreCot()
    if completeopt_save != ''
        &completeopt = completeopt_save
        completeopt_save = ''
    endif
enddef

def completion#custom#signature(mode: string): string #{{{1
    var line: string
    var col: number
    if mode == 'i'
        line = getline('.')
        col = col('.')
    else
        line = getcmdline()
        col = getcmdpos()
    endif

    var func_name: string = line->matchstr('\<\w\+\ze()\=\%' .. col .. 'c')
    if empty(func_name)
        return ''
    endif

    var file: list<string> = readfile($VIMRUNTIME .. '/doc/eval.txt')
    var signature: string = file
        ->filter((_, v: string): bool => v =~ '^' .. func_name .. '(')
        ->get(0, '')
    # needed, for example, for `deepcopy()`
    signature = signature->matchstr('.\{-})')
    if empty(signature)
        return ''
    endif

    var new_line: string = line
        ->substitute('\V' .. func_name .. '\%[()]', signature, '')
    if mode == 'i'
        setline('.', new_line)
    else
        return new_line
    endif
    return ''
enddef

