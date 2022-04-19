"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" local.vim config for python
" https://realpython.com/vim-and-python-a-match-made-in-heaven/

set nocompatible              " required
filetype off                  " required
filetype plugin indent on    " required
set expandtab
set smarttab
set autoindent
set tabstop=4
set softtabstop=2
set shiftwidth=2

"autocmd FileType fortran setlocal smarttab expandtab smartindent autoindent tabstop=2 shiftwidth=2 bs=2
"autocmd FileType python setlocal tabstop=8 expandtab shiftwidth=4 softtabstop=4

let mapleader=","
set mouse=a
set hlsearch
" Return to last edit position when opening files
au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
"remap F5 to delete trailing whitespace
:nnoremap <silent> <F5> :let _s=@/<Bar>:%s/\s\+$//e<Bar>:let @/=_s<Bar>:nohl<CR>

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" alternatively, pass a path where Vundle should install plugins
"call vundle#begin('~/some/path/here')

" let Vundle manage Vundle, required
Plugin 'gmarik/Vundle.vim'

" add all your plugins here (note older versions of Vundle
" used Bundle instead of Plugin)

" Color Schemes
Plugin 'rakr/vim-togglebg'
Plugin 'jnurmine/Zenburn'
Plugin 'altercation/vim-colors-solarized'
"" define which scheme to use based upon the VIM mode
if has('gui_running')
  set background=dark
  colorscheme solarized
else
  "  colorscheme zenburn
endif
" switching between schemes
"call togglebg#map("<F4>")


" Enable folding
set foldmethod=indent
set foldlevel=99

" Enable folding with the spacebar
nnoremap <space> za

"Plugin 'tmhedberg/SimpylFold'
"let g:SimpylFold_docstring_preview=1

" Flagging Unnecessary Whitespace
au BufRead,BufNewFile *.py,*.pyw,*.c,*.h,*.cpp,*.f90 match BadWhitespace /\s\+$/

:highlight BadWhitespace ctermfg=16 ctermbg=253 guifg=#000000 guibg=#F8F8F0

" UTF-8 Support
set encoding=utf-8

" Auto-Complete
Bundle 'Valloric/YouCompleteMe'
let g:ycm_autoclose_preview_window_after_completion=1
map <leader>c  :YcmCompleter GoToDefinitionElseDeclaration<CR>

map <Leader>e :call Spellchk_en()<cr>
:set spellfile=~/.vim/spell/empty.add

let g:spellchk_on = 0

function! Spellchk_en()
  if g:spellchk_on == 0
    :setlocal spell spelllang=en_us
    :set spellfile=~/.vim/spell/en.utf-8.add
    let g:spellchk_on = 1
  else
    :setlocal spell spelllang=
    :set spellfile=/.vim/spell/empty.add
    let g:spellchk_on = 0
  endif
endfunction




" Grammar check
map <Leader>g :call Grammarchk_en()<cr>

Bundle 'rhysd/vim-grammarous'
let g:grammarchk_on = 0
function! Grammarchk_en()
  if g:grammarchk_on == 0
    GrammarousCheck
    let g:grammarchk_on =1
  else
    GrammarousReset
    let g:grammarchk_on = 0
  endif
endfunction

let g:grammarous#hooks = {}
function! g:grammarous#hooks.on_check(errs) abort
    nmap <buffer><C-n> <Plug>(grammarous-move-to-next-error)
    nmap <buffer><C-p> <Plug>(grammarous-move-to-previous-error)
endfunction

function! g:grammarous#hooks.on_reset(errs) abort
    nunmap <buffer><C-n>
    nunmap <buffer><C-p>
endfunction



" Virtualenv Support
"py << EOF
"import os
"import sys
"if 'VIRTUAL_ENV' in os.environ:
"  project_base_dir = os.environ['VIRTUAL_ENV']
"  activate_this = os.path.join(project_base_dir, 'bin/activate_this.py')
"  execfile(activate_this, dict(__file__=activate_this))
"EOF

"Syntax Checking/Highlighting
Plugin 'vim-syntastic/syntastic'
Plugin 'nvie/vim-flake8'
let python_highlight_all=1
syntax on

" File Browsing
Plugin 'jistr/vim-nerdtree-tabs'
let NERDTreeIgnore=['\.pyc$', '\~$'] "ignore files in NERDTree

" Super Searching
Plugin 'kien/ctrlp.vim'

" Line Numbering
set nu
"set ruler

" Git Integration
Plugin 'tpope/vim-fugitive'

" Powerline
Plugin 'Lokaltog/powerline', {'rtp': 'powerline/bindings/vim/'}

" System Clipboard
"set clipboard=unnamed

""" PYTHON
" PEP 8 indentation
au FileType python setlocal tabstop=4 softtabstop=4 shiftwidth=4 textwidth=79 expandtab fileformat=unix
au FileType python Plugin 'vim-scripts/indentpython.vim'  " Auto-Indentation

""" C/C++
au FileType c,cpp,cc setlocal tabstop=4 softtabstop=4 shiftwidth=4 enc=utf-8 fenc=utf-8 termencoding=utf-8 t_Co=256 showmatch comments=sl:/*,mb:\ *,elx:\ */
au FileType c,cpp,cc let g:tagbar_autoclose=1
au FileType c,cpp,cc nnoremap <silent><F8> :TagbarToggle<CR>
au FileType c,cpp,cc Plugin 'preservim/tagbar'

""" Fortran
"autocmd FileType fortran setlocal smarttab expandtab smartindent autoindent tabstop=2 shiftwidth=2 bs=2
au FileType fortran setlocal tabstop=2 shiftwidth=2 bs=2 incsearch	ignorecase smartcase
au FileType fortran let fotran_free_source=1
au FileType fortran let fortran_do_enddo=1
au FileType fortran let fortran_more_precise=1
au FileType fortran Plugin 'rudrab/vimf90'

""" Latex
""au FileType tex Plugin 'lervag/vimtex'
Plugin 'lervag/vimtex'

" All of your Plugins must be added before the following line
call vundle#end()            " required
