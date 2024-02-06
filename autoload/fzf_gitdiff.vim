" Copyright (c) 2024 Yinzuo Jiang
" License: MIT

function fzf_gitdiff#FzfSink(line)
	let l:line = split(a:line, '\t')

	if len(l:line) == 1
		" git diff --name-only
		let l:filename = l:line[0]
		call fzf_gitdiff#OpenDiff(l:filename, l:filename)
		return
	endif

	if l:line[0][0] == 'R' || l:line[0][0] == 'C'
		" 'R097' 'C062'
		call fzf_gitdiff#OpenDiff(l:line[1], l:line[2])
	elseif l:line[0] == 'M' || l:line[0] == 'A' || l:line[0] == 'D'
		let l:filename = l:line[1]
		call fzf_gitdiff#OpenDiff(l:filename, l:filename)
	else
		echom 'Unimplemented status: ' . l:line[0]
	endif
endfunction

function fzf_gitdiff#FillFZF(...)
	let toplevel = system('git -C ' . shellescape(getcwd()) . ' rev-parse --show-toplevel')->trim()
	if v:shell_error
		echom 'Not a git repo'
		return
	endif
	let l:cmd = get(g:, 'fzf_gitdiff_cmd', 'git diff --name-status -C')

	if a:0 > 2
		echoerr 'too many arguments'
		return
	endif
	if a:0 == 1 && (a:000[0] == '--staged' || a:000[0] == '--cached')
		" HEAD, staged area
		let t:git_diff_args = ['HEAD', '']
		let l:prompt = 'HEAD | staged area | '
	elseif a:0 == 2 && (a:000[0] == '--staged' || a:000[0] == '--cached')
		" a:000[1], staged area
		let t:git_diff_args = [a:000[1], '']
		let l:prompt = a:000[1] . ' | staged area | '
	elseif a:0 == 2 && (a:000[1] == '--staged' || a:000[1] == '--cached')
		" a:000[0], staged area
		let t:git_diff_args = [a:000[0], '']
		let l:prompt = a:000[0] . ' | staged area | '
	else
		let t:git_diff_args = a:000
		if len(a:000) == 0
			let l:prompt = 'staged area | working directory | '
		elseif len(a:000) == 1
			let l:prompt = a:000[0] . ' | working directory | '
		else
			let l:prompt = a:000[0] . ' | ' . a:000[1] .' | '
		endif
	endif
	if a:0 > 0
		let l:cmd .= ' ' . join(a:000, ' ')
	endif

	call fzf#run(fzf#wrap(l:cmd, {
				\ 'source': l:cmd, 'options': '--prompt "' . l:prompt . '"',
				\ 'sink': function('fzf_gitdiff#FzfSink'),
				\ 'window': get(g:, 'fzf_gitdiff_window', { 'width': 0.5, 'height': 0.7 }),
				\ }))
endfunction

function fzf_gitdiff#OpenDiff(left_filename, right_filename)
	if !exists('t:git_diff_args')
		echoerr 'Fill FZF with git diff first.'
		return
	endif
	if len(t:git_diff_args) == 0
		" staged area, working directory
		let left_commit = ':'
		let right_commit = ''
	elseif len(t:git_diff_args) == 1
		" t:git_diff_args[0], working directory
		let left_commit = t:git_diff_args[0] . ':'
		let right_commit = ''
	elseif len(t:git_diff_args) == 2
		let left_commit = t:git_diff_args[0] . ':'
		let right_commit = t:git_diff_args[1] . ':'
	else
		echoerr 't:git_diff_args too long!'
	endif
	let l:prefix = system('git rev-parse --show-prefix')->trim()

	windo diffoff
	" Create 2 windows, load 2 commit versions and enable diff mode

	" left
	let left_filename = left_commit . l:prefix . a:left_filename
	let l:left_bufname = (left_commit == ':' ? 'gitdiff://(staged)' : 'gitdiff://') . left_filename
	if bufexists(l:left_bufname)
		exe 'b ' . l:left_bufname
	else
		enew
		silent! execute '0read !git show "' . left_filename  . '"'
		exe 'file ' . l:left_bufname
		setlocal bufhidden=hide
		setlocal nomodifiable
		setlocal nomodified
		setlocal readonly
	endif

	only

	" right
	let right_filename = right_commit . l:prefix . a:right_filename
	let l:right_bufname = (right_commit == ':' ? 'gitdiff://(staged)' : 'gitdiff://') . right_filename
	if bufexists(l:right_bufname)
		exe 'vertical sb ' . l:right_bufname
	else
		vnew
		if right_commit == ''
			try
				exe '0r ' . a:right_filename
			catch /./
				call append(0, v:exception)
			endtry
		else
			silent! execute '0read !git show "' . right_filename . '"'
		endif
		setlocal bufhidden=hide
		setlocal nomodifiable
		setlocal nomodified
		setlocal readonly
		exe 'file ' . l:right_bufname
	endif
	windo diffthis
endfunction
