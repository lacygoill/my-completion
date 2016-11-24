" Chained completion that works as I want!
" Maintainer: Lifepillar <lifepillar@lifepillar.me>
" License: This file is placed in the public domain

" FIXME: BUG "{{{
"
" If I hit C-x C-p C-h at the end of this line:
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
" FIXME: QUESTION "{{{
"
" Why do we need to prepend `s:exit_ctrl_x` in front of "\<c-x>\<c-l>"?
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

let s:select_entry  = { 'c-p' : "\<c-p>\<down>", 'keyp': "\<c-p>\<down>" }
let s:pathsep       = exists('+shellslash') && !&shellslash ? '\\' : '/'
" Internal state
let s:compl_methods = []
let s:compl_text    = ''
let s:auto          = 0
let s:dir           = 1
let s:cycle         = 0
let s:i             = 0
let s:pumvisible    = 0

fu! s:act_on_textchanged() abort
    if s:completedone
        let s:completedone = 0
        let g:mucomplete_with_key = 0
        if get(s:compl_methods, s:i, '') ==# 'path' && getline('.')[col('.')-2] =~# '\m\f'
            sil call mucomplete#path#complete()
        elseif get(s:compl_methods, s:i, '') ==# 'file' && getline('.')[col('.')-2] =~# '\m\f'
            sil call feedkeys("\<c-x>\<c-f>", 'i')
        endif
    elseif !&g:paste && match(strpart(getline('.'), 0, col('.') - 1),
                \  get(g:mucomplete#trigger_auto_pattern, getbufvar('%', '&ft'),
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
let g:mucomplete#chains = extend({
            \ 'default' : ['file', 'omni', 'keyn', 'dict']
            \ }, get(g:, 'mucomplete#chains', {}))

" Conditions to be verified for a given method to be applied.
if has('lambda')
    let s:yes_you_can = { _ -> 1 } " Try always
    let g:mucomplete#can_complete = extend({
                \ 'default' : extend({
                \     'dict':  { t -> strlen(&l:dictionary) > 0 },
                \     'file':  { t -> t =~# '\m\%('.s:pathsep.'\|\~\)\f*$' },
                \     'omni':  { t -> strlen(&l:omnifunc) > 0 },
                \     'spel':  { t -> &l:spell && !empty(&l:spelllang) },
                \     'tags':  { t -> !empty(tagfiles()) },
                \     'thes':  { t -> strlen(&l:thesaurus) > 0 },
                \     'user':  { t -> strlen(&l:completefunc) > 0 },
                \     'path':  { t -> t =~# '\m\%('.s:pathsep.'\|\~\)\f*$' },
                \     'uspl':  { t -> &l:spell && !empty(&l:spelllang) },
                \     'ulti':  { t -> get(g:, 'did_plugin_ultisnips', 0) }
                \   }, get(get(g:, 'mucomplete#can_complete', {}), 'default', {}))
                \ }, get(g:, 'mucomplete#can_complete', {}), 'keep')
else
    let s:yes_you_can = function('mucomplete#compat#yes_you_can')
    let g:mucomplete#can_complete = mucomplete#compat#can_complete()
endif

fu! s:act_on_pumvisible() abort
    let s:pumvisible = 0
    return s:auto || index(['spel','uspl'], get(s:compl_methods, s:i, '')) > - 1
                \ ? ''
                \ : (stridx(&l:completeopt, 'noselect') == -1
                \     ? (stridx(&l:completeopt, 'noinsert') == - 1 ? '' : "\<up>\<c-n>")
                \     : get(s:select_entry, s:compl_methods[s:i], "\<c-n>\<up>")
                \   )
endfu

fu! s:can_complete() abort
    return get(get(g:mucomplete#can_complete, getbufvar('%','&ft'), {}),
                \          s:compl_methods[s:i],
                \          get(g:mucomplete#can_complete['default'], s:compl_methods[s:i], s:yes_you_can)
                \ )(s:compl_text)
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
        return s:compl_mappings[s:compl_methods[s:i]] .
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

" Precondition: pumvisible() is true.
fu! mucomplete#cycle_or_select(dir) abort
    return get(g:, 'mucomplete#cycle_with_trigger', 0)
                \ ? mucomplete#cycle(a:dir)
                \ : (a:dir > 0 ? "\<c-n>" : "\<c-p>")
endfu

" Precondition: pumvisible() is false.
fu! mucomplete#complete(dir) abort
    let s:compl_text = matchstr(strpart(getline('.'), 0, col('.') - 1), '\S\+$')
    if strlen(s:compl_text) == 0
        return (a:dir > 0 ? "\<plug>(MUcompleteTab)" : "\<plug>(MUcompleteCtd)")
    endif
    let [s:dir, s:cycle] = [a:dir, 0]
    let s:compl_methods = get(b:, 'mucomplete_chain',
                \ get(g:mucomplete#chains, getbufvar('%', '&ft'), g:mucomplete#chains['default']))
    let s:N = len(s:compl_methods)
    let s:i = s:dir > 0 ? -1 : s:N
    return s:next_method()
endfu

fu! mucomplete#tab_complete(dir) abort
    if pumvisible()
        return mucomplete#cycle_or_select(a:dir)
    else
        let g:mucomplete_with_key = 1
        return mucomplete#complete(a:dir)
    endif
endfu
