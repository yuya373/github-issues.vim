" File:        github-issues.vim
" Version:     3.1.0
" Description: Pulls github issues into Vim
" Maintainer:  Jonathan Warner <jaxbot@gmail.com> <http://github.com/jaxbot>
" Homepage:    http://jaxbot.me/
" Repository:  https://github.com/jaxbot/github-issues.vim
" License:     Copyright (C) 2014 Jonathan Warner
"              Released under the MIT license
"        ======================================================================

" do not load twice
if exists("g:github_issues_loaded") || &cp
  finish
endif

let g:github_issues_loaded = 1

" do not continue if Vim is not compiled with Python2.7 support
if !has("python")
  echo "github-issues.vim requires Python support, sorry :c"
  finish
endif

function! s:showGithubMilestones(...)
  call ghissues#init()

  if a:0 <1
    python showMilestoneList(0, "True")
  else
    python showMilestoneList(vim.eval("a:1"), "True")
  endif

  set buftype=nofile
  nnoremap <buffer> q :q<cr>
  nnoremap <buffer> <cr> :normal! 0<cr>:call <SID>setMilestone(getline("."))<cr>

endfunction

function! s:showGithubIssues(...)
  call ghissues#init()

  let github_failed = 0
  if a:0 < 1
    python showIssueList(0, "True")
  else
    python showIssueList(vim.eval("a:1"), "True")
  endif

  if github_failed == "1"
    return
  endif

  " its not a real file
  set buftype=nofile

  " map the enter key to show issue or click link
  nnoremap <buffer> <cr> :call <SID>showIssue(expand("<cword>"))<cr>
  nnoremap <buffer> i :Giadd<cr>
  nnoremap <buffer> q :q<cr>

endfunction

function! s:showIssue(...)
  call ghissues#init()

  if a:0 > 1
    python showIssueBuffer(vim.eval("a:1"), vim.eval("a:2"))
  else
    python showIssueBuffer(vim.eval("a:1"))
  endif


  call s:setupOmni()

  if a:1 == "new"
    normal 0llllllllll
    startinsert
  endif

  setlocal nomodified
endfunction

function! s:setIssueState(state)
  python setIssueData({ 'state': 'open' if vim.eval("a:state") == '1' else 'closed' })
endfunction

function! s:updateIssue()
  call ghissues#init()
  python showIssue()
  silent execute 'doautocmd BufReadPost '.expand('%:p')
endfunction

function! s:saveIssue()
  call ghissues#init()
  python saveGissue()
  silent execute 'doautocmd BufWritePost '.expand('%:p')
endfunction

" omnicomplete function, also used by neocomplete
function! githubissues#CompleteIssues(findstart, base)
  if g:gissues_lazy_load
    if !b:did_init_omnicomplete
      python populateOmniComplete()
      let b:did_init_omnicomplete = 1
    endif
  endif

  if g:gissues_async_omni && len(b:omni_options) < 1
    python doPopulateOmniComplete()
  endif

  if a:findstart
    " locate the start of the word
    let line = getline('.')
    let start = col('.') - 1

    while start > 0 && line[start - 1] =~ '\w'
      let start -= 1
    endwhile
    let b:compl_context = getline('.')[start - 1: col('.')]
    return start
  else
    let res = []
    if b:compl_context == '.'
      return res
    endif

    for m in b:omni_options
      if m['menu'] == '[Issue]'
        if '#' . m['word'] =~ '^' . b:compl_context
          call add(res, m)
        endif
      elseif m['menu'] == '[User]'
        if '@' . m['word'] =~ '^' . b:compl_context
          call add(res, m)
        endif
      else
        if m['word'] =~ '^' . b:compl_context || ' ' . m['word'] =~ '^' . b:compl_context
          call add(res, m)
        endif
      endif
    endfor
    return res
  endif
endfunction

" set omnifunc for the buffer
function! s:setupOmni()
  call ghissues#init()

  setlocal omnifunc=githubissues#CompleteIssues

  " empty array will store the menu items
  let b:omni_options = []

  if !g:gissues_lazy_load
    python populateOmniComplete()
    if !g:gissues_async_omni
      python doPopulateOmniComplete()
    endif
  else
    let b:did_init_omnicomplete = 0
  endif
endfunction

function! s:handleEnter()
  if len(expand("<cword>")) == 40
    echo expand("<cword>")
    execute ":Gedit " . expand("<cword>")
  endif
endfunction

function! s:setMilestone(title)
  let title = ""
  if a:title != "[None]"
    let title = a:title
    echo "Switched current milestone to " . title
  else
    echo "No longer filtering by milestone"
  endif

  let g:github_current_milestone = title

endfunction

" define the :Gissues command
command! -nargs=* Gissues call s:showGithubIssues(<f-args>)
command! -nargs=* Giadd call s:showIssue("new", <f-args>)
command! -nargs=* Giedit call s:showIssue(<f-args>)
command! -nargs=0 Giupdate call s:updateIssue()

command! -nargs=* Gmiles call s:showGithubMilestones(<f-args>)

autocmd BufReadCmd gissues/*/\([0-9]*\|new\) call s:updateIssue()
autocmd BufReadCmd gissues/*/\([0-9]*\|new\) nnoremap <buffer> cc :call <SID>setIssueState(0)<cr>
autocmd BufReadCmd gissues/*/\([0-9]*\|new\) nnoremap <buffer> co :call <SID>setIssueState(1)<cr>
autocmd BufReadCmd gissues/*/\([0-9]*\|new\) nnoremap <buffer> <cr> :call <SID>handleEnter()<cr>
autocmd BufWriteCmd gissues/*/[0-9a-z]* call s:saveIssue()

if !exists("g:github_issues_no_omni")
  " Neocomplete support
  if !exists('g:neocomplete#sources#omni#input_patterns')
    let g:neocomplete#sources#omni#input_patterns = {}
  endif
  let g:neocomplete#sources#omni#input_patterns.gitcommit = '.'
  let g:neocomplete#sources#omni#input_patterns.gfimarkdown = '.'

  " Install omnifunc on gitcommit files
  autocmd FileType gitcommit call s:setupOmni()
endif

if !exists("g:github_access_token")
  let g:github_access_token = ""
endif

if !exists("g:github_upstream_issues")
  let g:github_upstream_issues = 0
endif

if !exists("g:github_issues_urls")
  let g:github_issues_urls = ["github.com:", "github.com/"]
endif

if !exists("g:github_api_url")
  let g:github_api_url = "https://api.github.com/"
endif

if !exists("g:github_issues_max_pages")
  let g:github_issues_max_pages = 1
endif

" force issues and what not to stay in the same window
if !exists("g:github_same_window")
  let g:github_same_window = 0
endif

" allow milestone filtering
if !exists("g:github_current_milestone")
  let g:github_current_milestone = ""
endif

" lazy load issues
if !exists("g:gissues_lazy_load")
  let g:gissues_lazy_load = 0
endif

" asynchronously load autocomplete
if !exists("g:gissues_async_omni")
  let g:gissues_async_omni = 0
endif

if !exists("g:gissues_default_remote")
  let g:gissues_default_remote = "origin"
endif

if !exists("g:gissues_show_errors")
  let g:gissues_show_errors = 0
endif

