fu! completion#util#custom_isk(chars) abort "{{{1
    let [s:isk_save, s:bufnr] = [&l:isk, bufnr('%')]

    try
        for char in split(a:chars, '\zs')
            exe 'setl isk+='..char2nr(char)
        endfor
        " Why `CursorMoved` and `TextChanged`?{{{
        "
        " If you press  `C-c` while the completion menu  is open, `CompleteDone`
        " is not fired; but `CursorMoved` and `TextChanged` are fired.
        "}}}
        unlet! s:did_shoot
        au CursorMoved,TextChanged,CompleteDone * ++once
            \ if !get(s:, 'did_shoot', 0)
            \ |     let s:did_shoot = 1
            \ |     sil! call setbufvar(s:bufnr, '&isk', s:isk_save)
            \ |     unlet! s:bufnr s:isk_save
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

