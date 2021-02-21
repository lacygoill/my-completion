vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

def completion#custom#easyCXCP() #{{{1
    if cot_save == ''
        cot_save = &cot
        set cot-=noinsert
        timer_start(0, () => RestoreCot())
    endif
enddef
var cot_save: string

def RestoreCot()
    if cot_save != ''
        &cot = cot_save
        cot_save = ''
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

    var func_name: string = matchstr(line, '\<\w\+\ze()\=\%' .. col .. 'c')
    if empty(func_name)
        return ''
    endif

    var file: list<string> = readfile($VIMRUNTIME .. '/doc/eval.txt')
    var signature: string = file
        ->filter((_, v: string): bool => v =~ '^' .. func_name .. '(')
        ->get(0, '')
    # needed, for example, for `deepcopy()`
    signature = matchstr(signature, '.\{-})')
    if empty(signature)
        return ''
    endif

    var new_line: string = substitute(line, '\V' .. func_name .. '\%[()]', signature, '')
    if mode == 'i'
        setline('.', new_line)
    else
        return new_line
    endif
    return ''
enddef

