fu! mucomplete#ultisnips#complete() abort

    " UltiSnips#SnippetsInCurrentScope() is a public function provided by the"{{{
    " UltiSnips plugin.

    " By default, it returns a Vim dictionary with the snippets whose trigger
    " matches the current word.
    " We pass it the argument `1`, because we want ALL snippets information of
    " current buffer. Indeed, the current word will probably be incomplete.
    " That's why we call this function in the first place.

    " When we call it like this, it automatically creates the variable
    " `g:current_ulti_dict_info` where the info will be stored.
    " The contents of the dictionary is as follows:
    "
    "       - keys      triggers
    "       - values    dictionaries, each with 2 keys:
    "
    "                           - file location where the snippet is defined
    "                           - optional description included in the snippet
    "
    " By testing if the output of `UltiSnips#SnippetsInCurrentScope()` is an
    " empty dictionary, we also create the variable `g:current_ulti_dict_info`.
"}}}

    if empty(UltiSnips#SnippetsInCurrentScope(1))
        return ''
    endif

    let word_to_complete = matchstr(strpart(getline('.'), 0, col('.') - 1), '\S\+$')

    " Condition for a candidate (trigger inside `g:current_ulti_dict_info`) to
    " be valid.
    " For the moment I want all the snippets, no matter where the word is in
    " their name. But if we wanted to look for only those containing it at the
    " beginning, we would simply have to replace `>=0` with `==0`.

    let contain_word = 'stridx(v:val, word_to_complete)>=0'

    " keys(g:current_ulti_dict_info)    →    all valid triggers in the buffer"{{{
    "
    " filter(keys(…), contain_word)     →    all triggers containing the word
    "                                        before the cursor

    " `complete()` waits for 2 arguments: {startcol} and {matches}
    " {matches} MUST be a list.
    " Here, the result of `filter(…)`is a list, so we're good.
    "
    " The items of the list can be simple strings, OR dictionaries.
    " The OR is not exlusive: some item may be strings, while others are
    " dictionaries.
    " The dictionaries can only contain special items.
    " They are all optional, except 'word' which is mandatory:
    "
    "         - word     the text that will be inserted (MANDATORY)
    "         - abbr     abbr; short form of the word to be displayed in the menu
    "         - menu     extra text for the popup menu, displayed after "word"/"abbr"
    "         - info     more info for the preview window
    "         - kind     single letter indicating the type of completion
    "
    "                            v	variable
    "                            f	function or method
    "                            m	member of a struct or class
    "                            t	typedef
    "                            d	#define or macro
    "
    "         - icase    flag; when non-zero, case is to be ignored when
    "                          comparing items to be equal; w
    "
    "         - dup      flag; when non-zero the item will be added even when
    "                    another one with the same word is already present in
    "                    the list
    "
    "         - empty    flag; when non-zero this item will be added even when
    "                    it is an empty string

    " map(filter(…),…)                  →    convert the triggers into
    "                                        dictionaries with additional
    "                                        info (description)
    "
    " The output of `map(…)` is a valid list to pass to `complete()`, because
    " its dictionaries contain only valid keys:
    "
    "         - word
    "         - menu
    "         - dup
    "
    " Why do we add the flag `dup` to each dictionary?
    " Because, we could have 2 snippets with the same trigger but different
    " descriptions.
    " It would probably be an error on our part, but now we would be aware of
    " the error.
    " IOW, `dup` = duplicate detector.
    ""}}}

    let candidates = map(filter(keys(g:current_ulti_dict_info), contain_word),
                   \  "{
                   \      'word': v:val,
                   \      'menu': '[snip] '. g:current_ulti_dict_info[v:val]['description'],
                   \      'dup' : 1,
                   \   }")

    if !empty(candidates)
        call complete(col('.') - len(word_to_complete), candidates)
    endif
    return ''
endfu
