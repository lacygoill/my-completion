fu! completion#custom#easy_c_x_c_p() abort "{{{1
    let s:cot_save = &cot
    set cot-=noinsert
    augroup restore_cot
        au!
        " Why not CompleteDone?{{{
        "
        " The first  time we  press `C-z`,  Vim displays  a completion  menu and
        " inserts its last candidate. But that doesn't fire `CompleteDone`.
        " The latter will be fired when the candidate has been accepted.
        " This could happen if we press Enter, or Space, or C-z again.
        "
        " I prefer an  event which will be fired for  all completions, including
        " the very first one, and immediately (not after pressing another key).
        "}}}
        au TextChangedP * let &cot = string(s:cot_save)
            \ | unlet! s:cot_save
            \ | au! restore_cot
            \ | aug! restore_cot
    augroup END
    return "\<c-x>\<c-p>"
endfu

fu! completion#custom#signature() abort "{{{1
    let func_name = matchstr(getline('.'), '\<\w\+\ze()\?\%'.col('.').'c')
    if empty(func_name)
        return ''
    endif

    let signature = get(filter(readfile($VIMRUNTIME.'/doc/eval.txt'),
    \                          {i,v -> v =~ '^'.func_name.'('}),
    \                   0, '')
    " needed, for example, for `deepcopy()`
    let signature = matchstr(signature, '.\{-})')
    if empty(signature)
        return ''
    endif

    let new_line = substitute(getline('.'), func_name.'\%[()]', signature, '')
    call timer_start(0, {-> setline('.', new_line)})
    return ''
endfu

