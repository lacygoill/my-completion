let s:pathsep = exists('+shellslash') && !&shellslash ? '\\' : '/'

fu! mucomplete#compat#yes_you_can(t) abort
    return 1
endfu

fu! mucomplete#compat#dict(t) abort
    return strlen(&l:dictionary) > 0
endfu

fu! mucomplete#compat#file(t) abort
    return a:t =~# '\m\%('.s:pathsep.'\|\~\)\f*$'
endfu

fu! mucomplete#compat#omni(t) abort
    return strlen(&l:omnifunc) > 0
endfu

fu! mucomplete#compat#spel(t) abort
    return &l:spell && !empty(&l:spelllang)
endfu

fu! mucomplete#compat#tags(t) abort
    return !empty(tagfiles())
endfu

fu! mucomplete#compat#thes(t) abort
    return strlen(&l:thesaurus) > 0
endfu

fu! mucomplete#compat#user(t) abort
    return strlen(&l:completefunc) > 0
endfu

fu! mucomplete#compat#path(t) abort
    return a:t =~# '\m\%('.s:pathsep.'\|\~\)\f*$'
endfu

fu! mucomplete#compat#ulti(t) abort
    return get(g:, 'did_plugin_ultisnips', 0)
endfu

fu! mucomplete#compat#uspl(t) abort
    return &l:spell && !empty(&l:spelllang)
endfu

fu! mucomplete#compat#can_complete() abort
    return extend({
                \ 'default' : extend({
                \     'dict':  function('mucomplete#compat#dict'),
                \     'file':  function('mucomplete#compat#file'),
                \     'omni':  function('mucomplete#compat#omni'),
                \     'spel':  function('mucomplete#compat#spel'),
                \     'tags':  function('mucomplete#compat#tags'),
                \     'thes':  function('mucomplete#compat#thes'),
                \     'user':  function('mucomplete#compat#user'),
                \     'path':  function('mucomplete#compat#path'),
                \     'uspl':  function('mucomplete#compat#uspl'),
                \     'ulti':  function('mucomplete#compat#ulti')
                \   }, get(get(g:, 'mucomplete#can_complete', {}), 'default', {}))
                \ }, get(g:, 'mucomplete#can_complete', {}), 'keep')
endfu
