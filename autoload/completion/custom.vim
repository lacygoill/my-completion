fu completion#custom#easy_c_x_c_p() abort "{{{1
    if !exists('s:cot_save')
        let s:cot_save = &cot
        set cot-=noinsert
        call timer_start(0, {-> s:restore_cot()})
    endif
endfu

fu s:restore_cot() abort
    if exists('s:cot_save')
        let &cot = s:cot_save
        unlet! s:cot_save
    endif
endfu

fu completion#custom#signature(mode) abort "{{{1
    let [line, col] = a:mode is# 'i' ? [getline('.'), col('.')] : [getcmdline(), getcmdpos()]
    let func_name = matchstr(line, '\<\w\+\ze()\=\%' .. col .. 'c')
    if empty(func_name)
        return ''
    endif

    let file = readfile($VIMRUNTIME .. '/doc/eval.txt')
    let signature = filter(file, {_, v -> v =~ '^' .. func_name .. '('})->get(0, '')
    " needed, for example, for `deepcopy()`
    let signature = matchstr(signature, '.\{-})')
    if empty(signature) | return '' | endif

    let new_line = substitute(line, '\V' .. func_name .. '\%[()]', signature, '')
    if a:mode is# 'i'
        call setline('.', new_line)
    else
        return new_line
    endif
    return ''
endfu

