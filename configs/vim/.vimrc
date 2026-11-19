" :options

" 24 multi-byte characters
set encoding=utf-8
scriptencoding utf-8

" 2 moving around, searching and patterns
set incsearch
set nowrapscan
set ignorecase

" 4 displaying text
set list
set listchars=tab:>-,trail:-,extends:»,precedes:«,nbsp:%
silent! set fillchars=vert:│
set number

" 5 syntax, highlighting and spelling
filetype plugin indent on
syntax enable
set background=dark
set hlsearch
set nocursorcolumn
set cursorline
silent! colorscheme quiet
highlight Normal ctermbg=NONE
highlight CursorLine term=underline cterm=underline ctermbg=NONE gui=underline guibg=NONE
highlight CursorLineNr ctermbg=NONE guibg=NONE

" 6 multiple windows
set laststatus=2
set statusline=\ %F\ %m%r%h%w%=%{&fileencoding.'\ '}
set hidden
set splitbelow
set splitright

" 9 using the mouse
set mouse=a
" vim cannot tell that tmux supports sgr and stays at xterm, which reports no drags
if &term =~# '^tmux'
  set ttymouse=sgr
endif

" 11 messages and info
set showcmd
set noruler
set belloff=all

" 12 selecting text
set clipboard=unnamed,unnamedplus

" 13 editing text
set backspace=indent,eol,start
set nrformats=bin,hex
silent! set completeopt=menu,menuone,noinsert,fuzzy,popup

" 14 tabs and indenting
set tabstop=4
set shiftwidth=2
set smarttab
set softtabstop=0
set expandtab
set autoindent

" 17 mapping
set ttimeout ttimeoutlen=50

" 20 command line editing
set wildmenu
silent! set wildmode=longest,full
silent! set wildoptions=pum,fuzzy
set cmdwinheight=15

" highlight the cursor only in the current window
" remember the :set values shared by all windows, since WinEnter would otherwise overwrite them
let s:cursor_options = #{cursorcolumn: &cursorcolumn, cursorline: &cursorline}
augroup vimrc_cursor
  autocmd!
  autocmd OptionSet cursorcolumn,cursorline
    \ if v:option_type ==# 'global' |
    \   let s:cursor_options[expand('<amatch>')] = v:option_new |
    \ endif
  autocmd WinLeave * setlocal nocursorline nocursorcolumn
  autocmd WinEnter *
    \ let &l:cursorcolumn = s:cursor_options.cursorcolumn |
    \ let &l:cursorline = s:cursor_options.cursorline
augroup END

" highlight trailing whitespace in normal file buffers
highlight default link ErrTrailingWhitespace Error
augroup vimrc_trailing_whitespace
  autocmd!
  autocmd BufEnter,BufWinEnter,WinEnter *
    \ execute &buftype == '' ? 'match ErrTrailingWhitespace /\s\+$/' : 'match none'
augroup END

" highlight matches of the visual selection
highlight default link VisualMatch SpellRare
function! s:update_hl_visual_match() abort
  if exists('w:hl_visual_match_id')
    silent! call matchdelete(w:hl_visual_match_id)
    unlet w:hl_visual_match_id
  endif

  " only a selection within a line, since a multiline one makes the pattern as large as itself
  let mode = mode()
  if mode !~# '^[vV]$' || line('v') != line('.')
    return
  endif

  let text = getregion(getpos('v'), getpos('.'), #{type: mode})[0]
  if text !~# '\S'
    return
  endif

  let w:hl_visual_match_id = matchadd('VisualMatch', '\V\c' .. escape(text, '\'))
endfunction
augroup vimrc_visual_match
  autocmd!
  autocmd CursorMoved,ModeChanged * call s:update_hl_visual_match()
augroup END

" keymaps
let mapleader = "\<space>"
let maplocalleader = "\\"

nnoremap c "_c
nnoremap C "_C
nnoremap s "_s
nnoremap S "_S
nnoremap x "_x
nnoremap X "_X
xnoremap c "_c
xnoremap C "_C
xnoremap s "_s
xnoremap S "_S
xnoremap x "_x
xnoremap X "_X
xnoremap p "_dP

nnoremap <silent> <leader>n :tabnext<cr>
nnoremap <silent> <leader>p :tabprevious<cr>
nnoremap <silent> <leader><leader> :buffers<cr>
nnoremap <silent> <leader>c :set cursorcolumn!<cr>
nnoremap <silent> <leader>m
  \ :exec &mouse!="" ? "set mouse=" : "set mouse=a"<cr>
  \ :echo 'mouse:'.(&mouse!='' ? 'enabled' : 'disabled')<cr>
nnoremap <silent> <esc><esc> :nohlsearch<cr>

" copy the mouse selection on release
for s:release in ['<LeftRelease>', '<2-LeftRelease>', '<3-LeftRelease>', '<4-LeftRelease>']
  execute 'xnoremap' s:release s:release
    \ .. 'ygv<cmd>call popup_notification(strchars(@") .. " chars copied",'
    \ .. ' #{line: 1, col: &columns, pos: "topright", border: [0, 0, 0, 0],'
    \ .. ' minwidth: 0, padding: [1, 2, 1, 2]})<cr>'
endfor

nnoremap <silent> <c-h> :wincmd h<cr>
nnoremap <silent> <c-j> :wincmd j<cr>
nnoremap <silent> <c-k> :wincmd k<cr>
nnoremap <silent> <c-l> :wincmd l<cr>

" flip the sign when there is no window to the right or below (the border of an edge window moves the other way)
function! s:resize_window_keys(direction) abort
  let vertical = a:direction ==# 'left' || a:direction ==# 'right'
  let step = a:direction ==# 'down' || a:direction ==# 'right' ? 2 : -2
  let has_next = winnr(vertical ? 'l' : 'j') != winnr()
  return printf("\<cmd>%sresize %+d\<cr>\<Plug>(resize-window)",
    \ vertical ? 'vertical ' : '', has_next ? step : -step)
endfunction
" keep resizing with <c-hjkl> within timeoutlen after <c-w>
" each resize leaves <Plug>(resize-window) to wait for the next key, and it ends with <Nop>
nnoremap <Plug>(resize-window) <Nop>
for [s:direction, s:key] in items(#{left: '<c-h>', down: '<c-j>', up: '<c-k>', right: '<c-l>'})
  for s:prefix in ['<c-w>', '<Plug>(resize-window)']
    execute printf('nmap <silent> <expr> %s%s <sid>resize_window_keys(%s)',
      \ s:prefix, s:key, string(s:direction))
  endfor
endfor

inoremap <expr> <esc> complete_info(['selected']).selected != -1 ? "\<c-e>" : "\<esc>"
inoremap <expr> <cr> complete_info(['selected']).selected != -1 ? "\<c-y>" : "\<cr>"
inoremap <tab> <c-n>
inoremap <s-tab> <c-p>

" <esc> sent from a mapping executes the command, so quit with <c-c>
cnoremap <expr> <esc> wildmenumode() ? "\<c-e>" : "\<c-c>"
cnoremap <expr> <cr> wildmenumode() ? "\<c-y>" : "\<cr>"

cnoremap <c-w> <c-f>
cnoremap <c-b> <left>
cnoremap <c-f> <right>
cnoremap <c-a> <home>
cnoremap <c-d> <del>
cnoremap <c-k> <c-\>estrpart(getcmdline(), 0, getcmdpos() - 1)<cr>
