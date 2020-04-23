fu completion#file#complete() abort
    let line = getline('.')
    let text_before_cursor = strpart(line, 0, col('.') - 1)
    " Remove curly brackets around possible environment variables.
    let text_before_cursor = substitute(text_before_cursor, '${\(\w\+\)}', '$\1', 'g')
    let cur_path = matchstr(text_before_cursor, '\f\%(\f\|\s\)*$')
    " Why a while loop? {{{
    "
    " Consider this:
    "
    "     Some text a dir/
    "
    " We want to complete the path `a dir/`.
    " The current algo doesn't know where the path begins, it grabs as many `\f`
    " and `\s` characters.
    " So, initially, the value of `cur_path` is `Some text a dir/`.
    " When the algo will try to expand `Some text a dir/*`:
    "
    "     let entries = glob(cur_path.'*', 0, 1, 1)
    "
    " It won't find anything. `entries` will be an empty list.
    " We need the algo to retry another, shorter, path.
    " To achieve this, we do 2 things:
    "
    "    - call `complete()` and return (`return ''`) on the condition that
    "      `entries` is not empty
    "
    "    - if `entries` is empty, we:
    "
    "        1. reset `cur_path`, giving it the value:
    "
    "             matchstr(cur_path, '\s\zs\f.*$')
    "
    "        This new value removes the text from the beginning of the
    "        string up to the first sequence of whitespace (whitespace
    "        excluded).
    "        For example, if the value of `cur_path`'s was initially:
    "
    "             Some text a dir/
    "
    "        ... its next value will be:
    "
    "             text a dir/
    "
    "        2. loop as long as `cur_path` is not empty.
    "        The loop will try to expand, consecutively:
    "
    "             Some text a dir/
    "             text a dir/
    "             a dir/
    "
    "        If `a dir` and `dir` are not an existing directory, their expansion
    "        will also  fail, and at the  end of the last  iteration, `cur_path`
    "        will be empty, because:
    "
    "             matchstr('dir', '\s\zs\f.*$') is# ''
    " "}}}
    while !empty(cur_path)
        " Why: `cur_path isnot# '~' ? '*' : ''`?{{{
        "
        " If `cur_path` is different from `~`, for example if it's:
        "
        "     /home/user/Do
        "
        " ... we add a wildcard, so that `glob()` gives us any existing entry in
        " the filesystem whose name begins like `cur_path`.
        " But if `cur_path` is `~`, we don't add a wildcard, because:
        "
        "     glob('~*', 0, 1, 1)
        "
        " ...  would return  an  empty  list. Indeed, there's  no  entry in  the
        " filesystem whose name  begins with `~`. We need to  expand `~` itself,
        " into `/home/user`."}}}
        let entries = glob(cur_path..(cur_path isnot# '~' ? '*' : ''), 0, 1, 1)
        if !empty(entries)
            " Why: `col('.') - strlen(fnamemodify(cur_path, ':t'))`{{{
            "
            " ... instead of:
            "
            "     col('.') - strlen(cur_path)
            "
            " ...?
            " Because, we don't complete the whole path. The matches in the menu
            " will only match the last component of a path.
            " So we  need to tell  `complete()` that  the selected entry  in the
            " menu will replace only the last component of the current path.
            "}}}
            let from_where = col('.') - strlen(fnamemodify(cur_path, ':t'))
            " Why: `cur_path isnot# '~' ? fnamemodify(v, ':t') : v`?{{{
            "
            " Because, if `cur_path` is `~`, then `entries` is:
            "
            "     ['/home/user']
            "
            " and `v` will take the (single) value `'/home/user'`.
            " Usually, we want to complete only the last component of a path.
            " But here, we don't want to complete only the last component of
            " `/home/user`, which is `user`, we want the whole path `/home/user`.
            "}}}
            " Why `[f]` in the menu?{{{
            "
            " We inspect  this `menu` key in  our `CR` custom mapping  in insert
            " mode, to automatically re-perform a file completion.
            " The  idea is  to  be  able to  chain  file  completions simply  by
            " pressing `Enter`.
            "}}}
            call complete(from_where,
                \ map(entries, {_,v ->
                \     {
                \       'menu': '[f]',
                \       'word': (cur_path isnot# '~' ? fnamemodify(v, ':t') : v)..(isdirectory(v) ? '/' : '')
                \     }}))
            return ''
        else
            " If the expansion failed, try a shorter path by removing the text
            " from the beginning of the path up to the first sequence of
            " whitespace (whitespace excluded), or up to the first equal sign.
            let cur_path = matchstr(cur_path, '[ \t=]\zs\f.*$')
            "                                      │
            "                                      └ try to also complete a path
            "                                        after an equal sign
        endif
    endwhile
    " If `cur_path` is empty, return nothing.
    return ''
endfu

