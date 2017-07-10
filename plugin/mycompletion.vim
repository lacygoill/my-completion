imap <silent> <expr> <c-j>                    pumvisible() ? mycompletion#cycle(1) : '<plug>(MC_c-j)'
ino  <silent>        <plug>(MC_c-j)           <c-j>

imap <silent> <expr> <c-k>                    pumvisible() ? mycompletion#cycle(-1) : '<plug>(MC_c-k)'
ino  <silent>        <plug>(MC_c-k)           <c-k>

imap <silent> <expr> <plug>(MC_next_method)   mycompletion#verify_completion()
imap <silent> <expr> <plug>(MC_Auto)          mycompletion#complete(1)

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

nno <silent>         [om                      :<c-u>call mycompletion#enable_auto()<cr>
nno <silent>         ]om                      :<c-u>call mycompletion#disable_auto()<cr>
nno <silent>         com                      :<c-u>call mycompletion#toggle_auto()<cr>

com! -bar McAutoEnable  call mycompletion#enable_auto()
com! -bar McAutoDisable call mycompletion#disable_auto()
com! -bar McAutoToggle  call mycompletion#toggle_auto()
