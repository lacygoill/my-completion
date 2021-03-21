vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

import Catch from 'lg.vim'

def completion#util#customIsk(chars: string): bool #{{{1
    # Why this check?{{{
    #
    # If for  some reason  the function  is invoked  twice without  a completion
    # in between, I don't want to save/restore a modified value of `'isk'`.
    #}}}
    if isk_save != ''
        return true
    endif
    isk_save = &l:isk
    bufnr = bufnr('%')
    try
        for char in split(chars, '\zs')
            exe 'setl isk+=' .. char2nr(char)
        endfor
        augroup CompletionUtilRestoreIsk | au!
            au TextChangedP,TextChangedI,TextChanged,CompleteDone *
                \   exe 'au! CompletionUtilRestoreIsk'
                | setbufvar(bufnr, '&isk', isk_save)
                | isk_save = ''
                | bufnr = 0
        augroup END
    catch
        Catch()
        return false
        # Do *not* add a finally clause to restore `'isk'`.
        # It would be too soon.  The completion hasn't been done yet.
    endtry
    return true
enddef
var isk_save: string
var bufnr: number

def completion#util#setupDict(): bool #{{{1
    if ic_was_reset
        return true
    endif
    # There should be at least 2 characters in front of the cursor,{{{
    # otherwise, `C-x C-k` could try to complete a text like:
    #
    #     #!
    #
    # ... which  would take a  long time,  because it's not  a word so,  all the
    # words of the dictionary could match.
    #}}}
    var complete_more_than_2chars: bool = getline('.')
        ->strpart(0, col('.') - 1)
        ->matchstr('\k\+$')
        ->strcharlen() >= 2
    if index(['en', 'fr'], &l:spelllang) == -1
        || !complete_more_than_2chars
        return false
    endif
    ic_save = &ic
    set noic
    ic_was_reset = true
    &l:dictionary = &l:spelllang == 'en' ? '/usr/share/dict/words' : '/usr/share/dict/french'
    augroup CompletionDictRestoreIc | au!
        au CompleteDone,TextChanged,TextChangedI,TextChangedP * exe 'au! CompletionDictRestoreIc'
            | &ic = ic_save
            | ic_was_reset = false
    augroup END
    return true
enddef
var ic_save: bool
var ic_was_reset: bool

