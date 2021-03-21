vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

def completion#file#complete(): string
    var filepath: string = getline('.')
        ->strpart(0, col('.') - 1)
        # remove curly brackets around possible environment variables
        ->substitute('${\(\w\+\)}', '$\1', 'g')
        # expand possible environment variables
        ->substitute('$\w\+', (m: list<string>): string => getenv(m[0][1 :]) ?? m[0], 'g')
        ->matchstr('\f\%(\f\|\s\)*$')

    var dir: string
    # Why a loop? {{{
    #
    # Consider this:
    #
    #     Some text a dir/
    #
    # We want to complete the path `a dir/`.
    # The current algo doesn't know where the path begins, it grabs as many `\f`
    # and `\s` characters.  So, initially, the value of `filepath` is:
    #
    #     Some text a dir/
    #
    # That's not a directory which `readdir()` can read.
    # We need the algo to retry another, shorter, path:
    #
    #     matchstr(filepath, '\s\zs\f.*$')
    #
    # This new value removes the text from the beginning of the string up to the
    # first sequence of whitespace (whitespace excluded).
    # For example, if the value of `filepath`'s was initially:
    #
    #     Some text a dir/
    #
    # ... its next values will be:
    #
    #     text a dir/
    #     a dir/
    #     dir/
    # }}}
    while !empty(filepath)
        dir = (fnamemodify(filepath, ':h') .. '/')
            ->substitute('^\~/', $HOME .. '/', '')
        if isdirectory(dir)
            break
        endif
        # If `dir` is not  a directory, try a shorter path  by removing the text
        # from the beginning of the path  up to the first sequence of whitespace
        # (whitespace excluded), or up to the first equal sign.
        filepath = matchstr(filepath, '[ \t=]\zs\f.*$')
        #                                  │
        #                                  └ try to also complete a path
        #                                    after an equal sign
    endwhile
    if !isdirectory(dir)
        return ''
    endif

    # Simpler alternative:{{{
    #
    #     var entries: list<string> = glob(filepath .. '*'), false, true, true)
    #     if filepath[-1] == '/'
    #         entries += glob(filepath .. '.*', false, true, true)
    #             ->filter((_, v: string): bool => v[-2 : -1] != '/.' && v[-3 : -1] != '/..')
    #     endif
    #}}}
    #   Why don't you use it?{{{
    #
    # It's a bit faster when `filepath`  contains a filename to complete, but it
    # can be much slower otherwise (i.e. when `filepath` is a directory).
    #}}}
    var entries: list<string>
    var filestart: string = fnamemodify(filepath, ':t')
    if filestart == ''
        entries = readdir(dir)
    else
        var flen: number = filestart->strcharlen()
        entries = dir
            ->readdir((n: string): bool => n[: flen - 1]  == filestart)
    endif

    # Why not simply `col('.') - strlen(filepath)`? {{{

    # Because, we don't  complete the whole path.  The matches  in the menu will
    # only match the last component of a path.
    # So we need to  tell `complete()` that the selected entry  in the menu will
    # replace only the last component of the current path.
    #}}}
    var from_where: number = col('.') - strlen(filestart)
    entries
        ->mapnew((_, v: string): dict<string> => ({
            # Setting 'menu' here can be leveraged in our custom `<CR>` mapping in insert mode.{{{
            #
            # To automatically re-perform a file completion.
            # The  idea is  to  be  able to  chain  file  completions simply  by
            # pressing `Enter`.
            #}}}
            menu: '[f]',
            word: fnamemodify(v, ':t') .. (isdirectory(dir .. v) ? '/' : '')
        }))->complete(from_where)
    return ''
enddef

