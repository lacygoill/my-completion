fu! completion#util#custom_isk(chars) abort "{{{1
    if exists('s:isk_save') | return '' | endif
    let [s:isk_save, s:bufnr] = [&l:isk, bufnr('%')]
    try
        for char in split(a:chars, '\zs')
            exe 'setl isk+='..char2nr(char)
        endfor
        au TextChangedP,TextChangedI,TextChanged,CompleteDone * ++once
        \   if exists('s:isk_save')
        \ |     sil! call setbufvar(s:bufnr, '&isk', s:isk_save)
        \ |     unlet! s:isk_save s:bufnr
        \ | endif
    catch
        return lg#catch_error()
    " Do *not* add a finally clause to restore 'isk'.
    " It would be too soon. The completion hasn't been done yet.
    endtry
    return ''
endfu

fu! completion#util#setup_dict() abort "{{{1
    exe 'setl dict='..(&l:spelllang is# 'en' ? '/usr/share/dict/words' : '/usr/share/dict/french')
    return ''
endfu

