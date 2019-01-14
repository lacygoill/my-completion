fu! completion#util#custom_isk(chars) abort "{{{1
    let b:isk_save = &l:isk

    try
        for char in split(a:chars, '\zs')
            exe 'setl isk+='.char2nr(char)
        endfor
        augroup my_custom_isk
            au! * <buffer>
            " Why `CursorMoved` and `TextChanged`?{{{
            "
            " If  you   press  `C-c`   while  the   completion  menu   is  open,
            " `CompleteDone` is not fired.
            " But `CursorMoved` and `TextChanged` are fired.
            "}}}
            au CursorMoved,TextChanged,CompleteDone <buffer> let &l:isk = get(b:, 'isk_save', &l:isk)
                \ | unlet! b:isk_save
                \ | exe 'au! my_custom_isk'
                \ | aug! my_custom_isk
        augroup END
    catch
        return lg#catch_error()
    " Do NOT add a finally clause to restore 'isk'.
    " It would be too soon. The completion hasn't been done yet.
    endtry
    return ''
endfu

fu! completion#util#hyphen_is_already_in_isk() abort "{{{1
    return ['clojure', 'lisp', 'scheme']
endfu

fu! completion#util#setup_dict() abort "{{{1
    exe 'setl dict='.(&l:spelllang is# 'en' ? '/usr/share/dict/words' : '/usr/share/dict/french')
    return ''
endfu

