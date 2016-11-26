" I think lifepillar introduced a regression here: "{{{
"
"     https://github.com/lifepillar/vim-mucomplete/issues/28
"
" Because, he inverted the order of the arguments passed to `stridx()`, which
" seems to prevent the `ulti` method to function properly.
"
" By the way, I removed the global variable `g:mucomplete#ultisnips#match_at_start`.
" By default, mucomplete looked only for the snippets whose name began with
" the word before the cursor.
" If you wanted all the snippets which contained the word ANYWHERE in their
" names, you had to set the variable to 0.
" For the moment I want all the snippets, no matter where the word is in their
" name. But if we wanted to look for only those containing it at the
" beginning, we would simply have to replace `>=0` with `==0`.
"
" "}}}

fu! mucomplete#ultisnips#complete() abort
    " UltiSnips#SnippetsInCurrentScope() is a public function provided by the
    " UltiSnips plugin.
    " When we call it, it automatically creates the variable `g:cur`
    " curabc
    " cur
    if empty(UltiSnips#SnippetsInCurrentScope(1))
        return ''
    endif

    let word_to_complete = matchstr(strpart(getline('.'), 0, col('.') - 1), '\S\+$')
    let contain_word     = 'stridx(v:val, word_to_complete)>=0'
    let candidates       = map(filter(keys(g:current_ulti_dict_info), contain_word),
                        \  "{
                        \      'word': v:val,
                        \      'menu': '[snip] '. get(g:current_ulti_dict_info[v:val], 'description', ''),
                        \      'dup' : 1
                        \   }")
    if !empty(candidates)
        call complete(col('.') - len(word_to_complete), candidates)
    endif
    return ''
endfu
