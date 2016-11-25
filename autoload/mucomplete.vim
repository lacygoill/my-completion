" Chained completion that works as I want!
" Maintainer: Lifepillar <lifepillar@lifepillar.me>
" License: This file is placed in the public domain

" FIXME: BUG "{{{
"
" If I hit C-x C-p C-k at the end of this line:
"
"     License: This file
"
" There's the following error:
"
"         Error detected while processing function
"         mucomplete#cycle[2]..<SNR>66_next_method:
"         line    1:
"         E121: Undefined variable: s:N
"         Error detected while processing function
"         mucomplete#cycle[2]..<SNR>66_next_method:
"         line    1:
"         E15: Invalid expression: (s:cycle ? (s:i + s:dir + s:N) % s:N : s:i + s:dir)
"
" Note:
" C-k is use to cycle backward in the completion chain.
" By default, it was C-h. I changed the mapping.
"
"}}}
" The methods `c-n` and `c-p` are tricky to invoke."{{{
"
" Indeed, we don't know in advance WHEN they will be invoked.
" As the first ones? Or after other failing methods?
"
" For example, if `c-n` is the first method to be invoked after hitting Tab,
" then there's NO problem.
" But if it's invoked after another one, there MIGHT be a problem.
" Suppose the previous failing method left us in `C-x` submode (C-x C-…),
" then `C-n` will be interpreted, WRONGLY, as an attempt to cycle in the menu.
" So, we should prefix `C-n` with `C-e` to exit `C-x` submode, right?
" Nope.
" Because then, if the `C-n` method was the first one to be invoked, then
" `C-e` will be interpreted as ’copy the character below the current one’.
"
" MUcomplete.vim chooses the solution of prefixing the trigger keys with:
"
"         C-x C-b BS
"
" What does it do?
" `C-b` is not a valid key in C-x submode. Any invalid key makes us leave the
" submode, and is inserted. So, we leave the submode, C-b is inserted, and BS
" deletes it.
" And why did lifepillar choose SPECIFICALLY C-b?
" For 2 reasons.
"
"     1 - It's invalid in C-x submode, as we just saw it.
"     2 - It's unmapped in basic insert mode, see: :h i_CTRL-B-gone
"
" So, C-b is a good choice because it won't cause any side-effect.
"
" All in all, this trick works.
" BUT, there's a problem for me. I have remapped C-B to move the cursor back.
" Because of this, the trick won't work.
"
" We have to choose another key. I'm going to use `C-g C-g`.
" Why this key?
" Because by default, C-g is used as a prefix in insert mode for various kind
" of actions. To get a list of them, type: :h i_^g C-d
" Currently, behind this prefix, there is:
"
"         CTRL-J
"         CTRL-K
"         Down
"         Up
"         j
"         k
"         u
"         U
"
" Vim may map other actions in the future on other keys, but for the moment
" nothing is mapped on CTRL-G.
"
" FIXME:
" It seems to work, but are we sure it is as good as `C-x C-b`?
" Ask lifepillar what he thinks, here:
"
"     https://github.com/lifepillar/vim-mucomplete/issues/4
"
" But don't ask him to integrate the change. He doesn't want. He added the tag
" `wontfix` and closed the issue.
"
" "}}}
" Why do we need to prepend `s:exit_ctrl_x` in front of "\<c-x>\<c-l>"? "{{{
"
" Suppose we have the following buffer:
"
"     hello world
"
" On another line, we write:
"
"     hello C-x C-l
"
" The line completion suggests us `hello world`, but we refuse and go on typing:
"
"     hello people
"
" If we hit C-x C-l again, the line completion will insert a newline.
" Why?
" It's probably one of Vim's quirks / bugs.
" It shouldn't insert anything, because now the line is unique.
"
" According to lifepillar, this can cause a problem when autocompletion
" is enabled.
" I can see how. The user set up line completion in his completion chain.
" Line completion is invoked automatically but he refuses the suggestion,
" and goes on typing. Later, line completion is invoked a second time.
" This time, there will be no suggestion, because the current line is likely
" unique (the user typed something that was nowhere else), but line completion
" will still insert a newline.
"
" Here's what lifepillar commented on the patch that introduced it:
"
"     Fix 'line' completion method inserting a new line.

"     Line completion seems to work differently from other completion methods:
"     typing a character that does not belong to an entry does not exit
"     completion. Before this commit, with autocompletion on such behaviour
"     resulted in µcomplete inserting a new line while the user was typing,
"     because µcomplete would insert <c-x><c-l> while in ctrl-x submode.

"     To fix that, we use the same trick as with 'c-p': make sure that we are
"     out of ctrl-x submode before typing <c-x><c-l>.
"
" To find the commit:
"
"     $ gsearch 's:cnp."\<c-x>\<c-l>"'
"
" There's a case, though, where adding a newline can make sense for line
" completion. When we're at the END of a line existing in multiple places, and
" we hit `C-x C-l`. Invoking line completion twice inserts a newline to suggest
" us the next line:
"
"     We have 2 identical lines:    L1 and L1'
"     After L1, there's L2.
"     The cursor is at the end of L1'.
"     The first `C-x C-l` invocation only suggests L1.
"     The second one inserts a newline and suggests L2.
"
"}}}

let s:exit_ctrl_x = "\<c-g>\<c-g>"
let s:compl_mappings = {
                       \ 'c-n' : s:exit_ctrl_x."\<c-n>",
                       \ 'c-p' : s:exit_ctrl_x."\<c-p>",
                       \ 'defs': "\<c-x>\<c-d>",
                       \ 'file': "\<c-x>\<c-f>",
                       \ 'incl': "\<c-x>\<c-i>",
                       \ 'dict': "\<c-x>\<c-k>",
                       \ 'line': s:exit_ctrl_x."\<c-x>\<c-l>",
                       \ 'keyn': "\<c-x>\<c-n>",
                       \ 'omni': "\<c-x>\<c-o>",
                       \ 'keyp': "\<c-x>\<c-p>",
                       \ 'spel': "\<c-x>s",
                       \ 'thes': "\<c-x>\<c-t>",
                       \ 'user': "\<c-x>\<c-u>",
                       \ 'cmd' : "\<c-x>\<c-v>",
                       \ 'tags': "\<c-x>\<c-]>",
                       \ 'path': "\<c-r>=mucomplete#path#complete()\<cr>",
                       \ 'ulti': "\<c-r>=mucomplete#ultisnips#complete()\<cr>",
                       \ 'uspl': "\<c-o>:call mucomplete#spel#gather()\<cr>\<c-r>=mucomplete#spel#complete()\<cr>",
                       \ }
unlet s:exit_ctrl_x

let s:select_entry     = { 'c-p' : "\<c-p>\<down>", 'keyp': "\<c-p>\<down>" }
" Internal state
let s:methods_to_try   = []
let s:text_to_complete = ''
let s:auto             = 0
let s:dir              = 1
let s:cycle            = 0
let s:i                = 0
let s:pumvisible       = 0

fu! s:act_on_textchanged() abort
    if s:completedone
        let s:completedone = 0
        let g:mucomplete_with_key = 0
        if get(s:methods_to_try, s:i, '') ==# 'path' && getline('.')[col('.')-2] =~# '\m\f'
            sil call mucomplete#path#complete()
        elseif get(s:methods_to_try, s:i, '') ==# 'file' && getline('.')[col('.')-2] =~# '\m\f'
            sil call feedkeys("\<c-x>\<c-f>", 'i')
        endif
    elseif match(strpart(getline('.'), 0, col('.') - 1),
                \  get(g:mucomplete#trigger_auto_pattern, &ft,
                \      g:mucomplete#trigger_auto_pattern['default'])) > -1
        sil call feedkeys("\<plug>(MUcompleteAuto)", 'i')
    endif
endfu

fu! mucomplete#enable_auto() abort
    let s:completedone = 0
    let g:mucomplete_with_key = 0
    augroup MUcompleteAuto
        autocmd!
        autocmd TextChangedI * noautocmd call s:act_on_textchanged()
        autocmd CompleteDone * noautocmd let s:completedone = 1
    augroup END
    let s:auto = 1
endfu

fu! mucomplete#disable_auto() abort
    if exists('#MUcompleteAuto')
        autocmd! MUcompleteAuto
        augroup! MUcompleteAuto
    endif
    let s:auto = 0
endfu

fu! mucomplete#toggle_auto() abort
    if exists('#MUcompleteAuto')
        call mucomplete#disable_auto()
        echom '[MUcomplete] Auto off'
    else
        call mucomplete#enable_auto()
        echom '[MUcomplete] Auto on'
    endif
endfu

" Patterns to decide when automatic completion should be triggered.
let g:mucomplete#trigger_auto_pattern = extend({
            \ 'default' : '\k\k$'
            \ }, get(g:, 'mucomplete#trigger_auto_pattern', {}))

" Completion chains
let g:mu_chains = extend({
                         \ 'default' : ['file', 'omni', 'keyn', 'dict']
                         \ }, get(g:, 'mu_chains', {}))

" Conditions to be verified for a given method to be applied."{{{
"
" Explanation of the regex for the file completion method:
"
"     \v[/~]\f*$
"
" Before the cursor, there must a slash or a tilda, then zero or more characters
" in 'isfname'.
" By default the tilda is in 'isf', so why not simply:
"
"     \v/?\f*
"
" Because then, it would match anything. The condition would be useless.
" At the very least, we want a slash or a tilda before the cursor.
" The filename characters afterwards are optional, because we could try to
" complete `some_dir/` or just `~`.
"
"}}}

let s:yes_you_can = { _ -> 1 } " Try always
let g:mucomplete#can_complete = {
                                \ 'default' : {
                                \               'dict': { t -> strlen(&l:dictionary) > 0 },
                                \               'file': { t -> t =~# '\v[/~]\f*$' },
                                \               'path': { t -> t =~# '\v[/~]\f*$' },
                                \               'omni': { t -> strlen(&l:omnifunc) > 0 },
                                \               'tags': { t -> !empty(tagfiles()) },
                                \               'user': { t -> strlen(&l:completefunc) > 0 },
                                \               'uspl': { t -> &l:spell && !empty(&l:spelllang) },
                                \               'ulti': { t -> get(g:, 'did_plugin_ultisnips', 0) },
                                \             },
                                \ }

fu! s:act_on_pumvisible() abort
    let s:pumvisible = 0
    return s:auto || index(['spel','uspl'], get(s:methods_to_try, s:i, '')) > - 1
                \ ? ''
                \ : (stridx(&l:completeopt, 'noselect') == -1
                \     ? (stridx(&l:completeopt, 'noinsert') == - 1 ? '' : "\<up>\<c-n>")
                \     : get(s:select_entry, s:methods_to_try[s:i], "\<c-n>\<up>")
                \   )
endfu

fu! s:can_complete() abort
    return get(get(g:mucomplete#can_complete, &ft, {}),
                \          s:methods_to_try[s:i],
                \          get(g:mucomplete#can_complete['default'], s:methods_to_try[s:i], s:yes_you_can)
                \ )(s:text_to_complete)
endfu

fu! mucomplete#yup() abort
    let s:pumvisible = 1
    return ''
endfu

" Precondition: pumvisible() is false.
fu! s:next_method() abort
    let s:i = (s:cycle ? (s:i + s:dir + s:N) % s:N : s:i + s:dir)
    while (s:i+1) % (s:N+1) != 0  && !s:can_complete()
        let s:i = (s:cycle ? (s:i + s:dir + s:N) % s:N : s:i + s:dir)
    endwhile
    if (s:i+1) % (s:N+1) != 0
        return s:compl_mappings[s:methods_to_try[s:i]] .
                    \ "\<c-r>\<c-r>=pumvisible()?mucomplete#yup():''\<cr>\<plug>(MUcompleteNxt)"
    endif
    return ''
endfu

fu! mucomplete#verify_completion() abort
    return s:pumvisible ? s:act_on_pumvisible() : s:next_method()
endfu

" Precondition: pumvisible() is true.
fu! mucomplete#cycle(dir) abort
    let [s:dir, s:cycle] = [a:dir, 1]
    return "\<c-e>" . s:next_method()
endfu

" Precondition: pumvisible() is false.
fu! mucomplete#complete(dir) abort
    let s:text_to_complete = matchstr(strpart(getline('.'), 0, col('.') - 1), '\S\+$')

    if empty(s:text_to_complete)
        return (a:dir > 0 ? "\<plug>(MUcompleteTab)" : "\<plug>(MUcompleteCtd)")
    endif

    let [s:dir, s:cycle] = [a:dir, 0]
    let s:methods_to_try = get(b:, 'mucomplete_chain',
                                 \ get(g:mu_chains, &ft, g:mu_chains['default'])
                            \ )

    let s:N = len(s:methods_to_try)
    let s:i = s:dir > 0 ? -1 : s:N

    return s:next_method()
endfu

fu! mucomplete#tab_complete(dir) abort
    if pumvisible()
        return get(g:, 'mucomplete#cycle_with_trigger', 0)
                    \ ? mucomplete#cycle(a:dir)
                    \ : (a:dir > 0 ? "\<c-n>" : "\<c-p>")
    else
        let g:mucomplete_with_key = 1
        return mucomplete#complete(a:dir)
    endif
endfu
