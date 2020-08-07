import Catch from 'lg.vim'

fu completion#util#custom_isk(chars) abort "{{{1
    " Why this check?{{{
    "
    " If for  some reason  the function  is invoked  twice without  a completion
    " in between, I don't want to save/restore a modified value of `'isk'`.
    "}}}
    if exists('s:isk_save') | return 1 | endif
    let [s:isk_save, s:bufnr] = [&l:isk, bufnr('%')]
    try
        for char in split(a:chars, '\zs')
            exe 'setl isk+=' .. char2nr(char)
        endfor
        augroup completion_util_restore_isk | au!
            au TextChangedP,TextChangedI,TextChanged,CompleteDone *
                \   exe 'au! completion_util_restore_isk'
                \ | call setbufvar(s:bufnr, '&isk', s:isk_save)
                \ | unlet! s:isk_save s:bufnr
        augroup END
    catch
        call s:Catch()
        " Do *not* add a finally clause to restore `'isk'`.
        " It would be too soon.  The completion hasn't been done yet.
    endtry
    return 1
endfu

fu completion#util#setup_dict() abort "{{{1
    if exists('s:ic_save') | return 1 | endif
    " There should be at least 2 characters in front of the cursor,{{{
    " otherwise, `C-x C-k` could try to complete a text like:
    "
    "     #!
    "
    " ... which  would take a  long time,  because it's not  a word so,  all the
    " words of the dictionary could match.
    "}}}
    let complete_more_than_2chars = getline('.')
        \ ->matchstr('\k\+\%' .. col('.') .. 'c')
        \ ->strchars(1) >= 2
    if index(['en', 'fr'], &l:spelllang) == -1 || !complete_more_than_2chars
        return 0
    endif
    let s:ic_save = &ic
    set noic
    let &l:dictionary = &l:spelllang is# 'en' ? '/usr/share/dict/words' : '/usr/share/dict/french'
    augroup completion_dict_restore_ic | au!
        au CompleteDone,TextChanged,TextChangedI,TextChangedP * exe 'au! completion_dict_restore_ic'
            \ | let &ic = s:ic_save
            \ | unlet! s:ic_save
    augroup END
    return 1
endfu

