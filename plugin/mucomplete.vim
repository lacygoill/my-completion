imap <silent> <expr> <c-j>             pumvisible() ? mucomplete#cycle(1) : '<plug>(MC_c-j)'
ino  <silent>        <plug>(MC_c-j)    <c-j>

imap <silent> <expr> <c-k>             pumvisible() ? mucomplete#cycle(-1) : '<plug>(MC_c-k)'
ino  <silent>        <plug>(MC_c-k)    <c-k>

imap <silent> <expr> <plug>(MC_next_method)   mucomplete#verify_completion()
imap <silent> <expr> <plug>(MC_Auto)          mucomplete#complete(1)

" Expand snippet or complete, when hitting Tab or S-Tab
ino  <silent>        <Tab>                    <c-r>=mucomplete#snippet_or_complete(1)<cr>
ino  <silent>        <S-Tab>                  <c-r>=mucomplete#snippet_or_complete(-1)<cr>
imap <silent> <expr> <plug>(MC_tab_complete)  mucomplete#tab_complete(1)
imap <silent> <expr> <plug>(MC_stab_complete) mucomplete#tab_complete(-1)

snor <silent>        <Tab>                    <esc>:call UltiSnips#JumpForwards()<cr>
snor <silent>        <S-Tab>                  <esc>:call UltiSnips#JumpBackwards()<cr>

" Typed/returned by mucomplete#complete()
ino <silent>         <plug>(MC_Tab)           <Tab>
ino <silent>         <plug>(MC_C-d)           <c-d>

com! -bar McAutoEnable  call mucomplete#enable_auto()
com! -bar McAutoDisable call mucomplete#disable_auto()
com! -bar McAutoToggle  call mucomplete#toggle_auto()
