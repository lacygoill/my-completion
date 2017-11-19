" guard {{{1

if exists('g:loaded_mycompletion')
    finish
endif
let g:loaded_mycompletion = 1

" Commands {{{1

com! -bar McAutoEnable  call mycompletion#enable_auto()
com! -bar McAutoDisable call mycompletion#disable_auto()
com! -bar McAutoToggle  call mycompletion#toggle_auto()

" Mappings {{{1
" completion {{{2

" Expand snippet or complete, when hitting Tab or S-Tab
ino  <silent>        <Tab>                    <c-r>=mycompletion#snippet_or_complete(1)<cr>
ino  <silent>        <S-Tab>                  <c-r>=mycompletion#snippet_or_complete(-1)<cr>
imap <silent> <expr> <plug>(MC_tab_complete)  mycompletion#tab_complete(1)
imap <silent> <expr> <plug>(MC_stab_complete) mycompletion#tab_complete(-1)

snor <silent>        <Tab>                    <esc>:call UltiSnips#JumpForwards()<cr>
snor <silent>        <S-Tab>                  <esc>:call UltiSnips#JumpBackwards()<cr>

" The next mappings are necessary to prevent custom mappings from interfering.

" Typed/returned by mycompletion#complete()
ino <silent>         <plug>(MC_tab)           <Tab>
ino <silent>         <plug>(MC_c-d)           <c-d>

" Typed/returned by mycompletion#cycle()
ino <silent>         <plug>(MC_c-e)           <c-e>
ino <silent>         <plug>(MC_c-n)           <c-n>
ino <silent>         <plug>(MC_c-p)           <c-p>
ino <silent>         <plug>(MC_c-r)           <c-r>
ino <silent>         <plug>(MC_down)          <down>
ino <silent>         <plug>(MC_up)            <up>

" We don't want recursiveness for those keys when we're in regular insert mode.
" In C-x submode, custom mappings should not interfere.

" cycling {{{2

"                     ┌─ if we override `c-j` in our vimrc, warn us
"                     │
imap <silent> <expr> <unique> <c-j>             pumvisible() ? mycompletion#cycle(1) : '<plug>(MC_c-j)'
ino  <silent>                 <plug>(MC_c-j)    <c-j>

" To cycle back, we can't use `c-k` because it would be shadowed by `c-k c-k`
" (vimrc) which deletes from cursor till end of line.
" It's hard to find a key for this mapping (can't use `c-h`, `c-l`, `c-k`, …).
" We'll try `c-o` with the mnemonics: Old (cycle back).
imap <silent> <expr> <unique> <c-o>             pumvisible() ? mycompletion#cycle(-1) : '<plug>(MC_c-o)'
ino  <silent>                 <plug>(MC_c-o)    <c-o>

imap <silent> <expr> <plug>(MC_next_method)   mycompletion#verify_completion()
imap <silent> <expr> <plug>(MC_Auto)          mycompletion#complete(1)

nno <silent>         [om                      :<c-u>call mycompletion#enable_auto()<cr>
nno <silent>         ]om                      :<c-u>call mycompletion#disable_auto()<cr>
nno <silent>         com                      :<c-u>call mycompletion#toggle_auto()<cr>

" Options {{{1

" 'complete'
"
" where should Vim look when using C-n/C-p
set complete=.,w,b
"            │ │ │
"            │ │ └─ buffers in buffer list
"            │ └─ other windows
"            └─ current buffer


" 'cot'  +menuone
"
" We add 'menuone' for 2 reasons:
"
"     • the menu allows us to cancel  a completion if the inserted text is not
"       the one we wanted
"
"     • when  there's   only  1  candidate,  the  menu  will   not  open  and
"       vim-completion will  think that the  current method has failed,  then will
"       immediately try the  next one; because of  this we could end up  with 2 or
"       more completed texts
set cot+=menuone

" Issue1:
" When we press C-d / C-u while the  popup menu is visible, and there are only a
" few entries, we don't want to move in the menu, we want to delete text.
" This issue is particularly annoying when there's only one entry in the menu.

" Issue2:
" If there's only 1 candidate to complete  a word and 'noinsert' is in 'cot', we
" won't be able to complete the  latter. This is an issue for default completion
" mechanisms (C-x  C-p, …),  but also  for our  completion plugin  which will,
" wrongly, think that the method has failed, and try the next one.
"
" Warning:
" So, make sure that you don't have 'noinsert' without 'menuone' in 'cot':
"
"     • +noinsert -menuone    ✘ ALL completion mechanisms broken when there's only 1 candidate
"     • -noinsert -menuone    ✘ vim-completion broken            "
"     • +noinsert +menuone    ✔
"     • -noinsert +menuone    ✔


" 'cot'  -noinsert
"
" We remove 'noinsert' for 3 reasons:
"
"     • it breaks the repetition of C-x C-p
"
"       The  first invocation  works, but  the  consecutive ones  don't work  as
"       expected.  Indeed, we  have to hit enter to insert  a candidate from the
"       menu.  This CR breaks the chaining of C-x C-p.
"
"     • if we remove 'menuone', it  would break all completion mechanisms when
"       there's only 1 candidate
"
"     • it's annoying while in auto-completion mode
"
"       vim-completion already makes sure that  'noinsert' is not in 'cot' while
"       in auto mode, but still …
set cot-=noinsert


" 'cot'  -noselect
"
" Do NOT  add 'noselect', because we  use a completion system  which would break
" the undo sequence when 'noselect' is in  'cot'.  It means that some text would
" be lost when we use the dot command to repeat a completion.
set cot-=noselect


" 'cot'  -preview
"
" When we  hit `C-x C-g` by  accident, the unicode.vim plugin  opens the preview
" window (digraph completion), and we have to close it manually.  It's annoying.
"
" If one day, we  need to add 'preview' in 'cot' again, we  could get around the
" unicode.vim  plugin issue  with an  autocmd  which closes  the preview  window
" automatically each time we complete a text:
"
"         au CompleteDone * if pumvisible() == 0 | pclose | endif
set cot-=preview


" 'infercase'
"
" Add some intelligence regarding the case of a text which is completed.
"
" For example, suppose we have the word 'WeirdCaseWord' in a buffer.
" We type:    weirdc    … and press Tab to complete,
"                         with `noinfercase`, we get `WeirdCaseWord`;
"                         with `infercase`  , we get `weirdcaseword`.
"
" Commented because I find it annoying at the moment.
" Besides,  it's a  buffer-local option,  so it  should be  set from  a filetype
" plugin.
"
"         set infercase
