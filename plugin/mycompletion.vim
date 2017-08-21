" completion mappings {{{1

" Expand snippet or complete, when hitting Tab or S-Tab
ino  <silent>        <Tab>                    <c-r>=mycompletion#snippet_or_complete(1)<cr>
ino  <silent>        <S-Tab>                  <c-r>=mycompletion#snippet_or_complete(-1)<cr>
imap <silent> <expr> <plug>(MC_tab_complete)  mycompletion#tab_complete(1)
imap <silent> <expr> <plug>(MC_stab_complete) mycompletion#tab_complete(-1)

snor <silent>        <Tab>                    <esc>:call UltiSnips#JumpForwards()<cr>
snor <silent>        <S-Tab>                  <esc>:call UltiSnips#JumpBackwards()<cr>

" Typed/returned by mycompletion#complete()
ino <silent>         <plug>(MC_Tab)           <Tab>
ino <silent>         <plug>(MC_C-d)           <c-d>

" cycling mappings {{{1

imap <silent> <expr> <c-j>                    pumvisible() ? mycompletion#cycle(1) : '<plug>(MC_c-j)'
ino  <silent>        <plug>(MC_c-j)           <c-j>

" To cycle back, we can't use `c-k` because it would be shadowed by `c-k c-k`
" (vimrc) which deletes from cursor till end of line.
" It's hard to find a key for this mapping (can't use `c-h`, `c-l`, `c-k`, …).
" We'll try `c-o` with the mnemonics: Old (cycle back).
imap <silent> <expr> <c-o>                    pumvisible() ? mycompletion#cycle(-1) : '<plug>(MC_c-o)'
ino  <silent>        <plug>(MC_c-o)           <c-o>

imap <silent> <expr> <plug>(MC_next_method)   mycompletion#verify_completion()
imap <silent> <expr> <plug>(MC_Auto)          mycompletion#complete(1)

" autocompletion {{{1

nno <silent>         [om                      :<c-u>call mycompletion#enable_auto()<cr>
nno <silent>         ]om                      :<c-u>call mycompletion#disable_auto()<cr>
nno <silent>         com                      :<c-u>call mycompletion#toggle_auto()<cr>

com! -bar McAutoEnable  call mycompletion#enable_auto()
com! -bar McAutoDisable call mycompletion#disable_auto()
com! -bar McAutoToggle  call mycompletion#toggle_auto()