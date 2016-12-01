fu! s:update_iabbrev(line1, line2) abort
    let abbr_table    = execute('iab')
    let pattern       = '\vi\s+\zs\w+'
    let abbreviations = reverse(map(split(abbr_table, "\n"), 'matchstr(v:val, pattern)'))
    let assignment    = 'let s:iab_list = ' . string(abbreviations)
endfu

