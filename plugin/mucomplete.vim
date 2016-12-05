imap <silent> <expr> <c-j>                    pumvisible() ? mucomplete#cycle(1) : "\<plug>(MC_cycle_back)"
ino  <silent>        <plug>(MC_cycle_back)    <c-j>

imap <silent> <expr> <c-k>                    pumvisible() ? mucomplete#cycle(-1) : "\<plug>(MC_cycle_fwd)"
ino  <silent>        <plug>(MC_cycle_fwd)     <c-k>

imap <silent> <expr> <plug>(MC_next_method)   mucomplete#verify_completion()
imap <silent> <expr> <plug>(MC_Auto)          mucomplete#complete(1)

" Initiate manual completion, when hitting Tab or S-Tab
imap <silent> <expr> <Tab>                    mucomplete#tab_complete(1)
imap <silent> <expr> <S-Tab>                  mucomplete#tab_complete(-1)

" Typed/returned by mucomplete#complete()
ino <silent>         <plug>(MC_Tab)           <Tab>
ino <silent>         <plug>(MC_C-d)           <c-d>
