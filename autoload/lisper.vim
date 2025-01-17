"=============================================================================
" lisper.vim
" Author: Yasuhiro Matsumoto <mattn.jp@gmail.com>
" Last Change: 19-Nov-2011.
"
" Based On: http://norvig.com/lis.py

let s:env = { "bind": {}, "lambda": [] }

function! s:env.new(...)
  let params = a:0 > 0 ? a:000[0] : []
  let args   = a:0 > 1 ? a:000[1] : []
  let outer  = a:0 > 2 ? a:000[2] : 0
  let f = 0
  while f < len(params)
    let p = params[f]
    let m = s:deref(p)
    let self.bind[m] = args[f]
    let f += 1
  endwhile
  let self.outer = outer
  return deepcopy(self)
endfunction

function! s:env.find(...) dict
  let var = a:1
  let is_set = a:0 > 1 ? a:2 : 0
  if is_set || has_key(self.bind, var)
    return self.bind
  endif
  if !empty(self.outer)
    return self.outer.find(var)
  endif
  throw "Not found symbol `".var."`"
endfunction

function! s:env.update(var) dict
  for k in keys(a:var)
    let self.bind[k] = a:var[k]
  endfor
endfunction

function! s:env.make_op(f, ...) dict
  let s:op_n = get(s:, 'op_n', 0) + 1
  let s:op_f{s:op_n}_ = a:f
  let s:op_f{s:op_n}__ = a:000
  function! s:op_f{s:op_n}(...)
    let __ = eval(substitute(expand('<sfile>'), '^.*\zeop_f[0-9]\+$', 's:', '').'__')
    return eval(substitute(eval(substitute(expand('<sfile>'), '^.*\zeop_f[0-9]\+$', 's:', '').'_'), '\n', '', 'g'))
  endfunction
  call add(self.lambda, 's:op_f'.s:op_n)
  return function('s:op_f'.s:op_n)
endfunction

function! s:env.make_do(f, ...) dict
  let s:op_n = get(s:, 'op_n', 0) + 1
  let s:op_f{s:op_n}_ = a:f
  let s:op_f{s:op_n}__ = a:000
  function! s:op_f{s:op_n}(...)
    let __ = eval(substitute(expand('<sfile>'), '^.*\zeop_f[0-9]\+$', 's:', '').'__')
    exe eval(substitute(expand('<sfile>'), '^.*\zeop_f[0-9]\+$', 's:', '').'_')
  endfunction
  call add(self.lambda, 's:op_f'.s:op_n)
  return function('s:op_f'.s:op_n)
endfunction

function! s:echo(...)
  echo join(a:000, ' ')
  return a:000
endfunction

function! s:debug(...)
  echohl WarningMsg | echomsg string(a:000) | echohl None
  return a:000
endfunction

function! s:add_globals(env)
  "env.update(vars(math)) # sin, sqrt, ...
  let env = a:env
  call env.update({
\ '+':       env.make_op('eval(join(map(range(a:0), ''"s:deref(a:".(v:val+1).")"''), ''+''))'),
\ '-':       env.make_op('eval(join(map(range(a:0), ''"s:deref(a:".(v:val+1).")"''), ''-''))'),
\ '*':       env.make_op('eval(join(map(range(a:0), ''"s:deref(a:".(v:val+1).")"''), ''*''))'),
\ '/':       env.make_op('eval(join(map(range(a:0), ''"s:deref(a:".(v:val+1).")"''), ''/''))'),
\ 'not':     env.make_op('!s:deref(a:1)'),
\ '>':       env.make_op('(s:deref(a:1) > s:deref(a:2))'),
\ '<':       env.make_op('(s:deref(a:1) < s:deref(a:2))'),
\ '>=':      env.make_op('(s:deref(a:1) >= s:deref(a:2))'),
\ '<=':      env.make_op('(s:deref(a:1) <= s:deref(a:2))'),
\ '=':       env.make_op('(s:deref(a:1) == s:deref(a:2))'),
\ 'equal?':  env.make_op('(s:deref(a:1) ==# s:deref(a:2))'),
\ 'eq?':     env.make_op('(s:deref(a:1) is# s:deref(a:2))'),
\ 'length':  env.make_op('len(s:deref(a:1))'),
\ 'cons':    env.make_op('eval(join(map(range(a:0), ''"s:deref(a:".(v:val+1).")"''), ''.''))'),
\ 'car':     env.make_op('s:deref(a:1)[0]'),
\ 'cdr':     env.make_op('s:deref(a:1)[1:]'),
\ 'append':  env.make_op('eval(join(map(map(copy(a:000), ''type(v:val)==3?v:val :[v:val]''), ''s:deref(v:val)''), ''+''))'),
\ 'list':    env.make_op('map(copy(a:000), ''s:deref(v:val)'')'),
\ 'list?':   env.make_op('type(s:deref(a:1))==3'),
\ 'null?':   env.make_op('len(s:deref(a:1)) == 0'),
\ 'symbol?': env.make_op('type(a:1) == 4'),
\ 'abs':     env.make_op('abs(s:deref(a:1))'),
\ 'sin':     env.make_op('sin(s:deref(a:1))'),
\ 'cos':     env.make_op('cos(s:deref(a:1))'),
\ 'tan':     env.make_op('tan(s:deref(a:1))'),
\ 'asin':    env.make_op('asin(s:deref(a:1))'),
\ 'acos':    env.make_op('acos(s:deref(a:1))'),
\ 'atan':    env.make_op('atan(s:deref(a:1))'),
\ 'atan2':   env.make_op('atan2(s:deref(a:1), s:deref(a:2))'),
\ 'mod':     env.make_op('s:deref(a:1) % s:deref(a:2)'),
\ '#t':      !0,
\ '#f':      0,
\ 'nil':     0,
\})
  return env
endfunction

function! s:parse(s)
  let ctx = {"tokens": s:tokenize(a:s)}
  return s:read_from(ctx)
endfunction

function! s:can(r)
  let b = 0
  for s in a:r
    if s == '('
      let b += 1
    elseif s == ')'
      let b -= 1
    endif
  endfor
  return b
endfunction

function! s:tokenize(s)
  let ss = split(a:s, '\zs')
  let [n, l] = [0, len(ss)]
  let r = []
  let m = {"t": "\t", "n": "\n", "r": "\r"}
  while n < l
    let c = ss[n]
    if c =~ '[\r\n\t ]'
      let n += 1
    elseif c == '(' || c == ')'
      call add(r, c)
      let n += 1
    elseif c == '"'
      let b = c
      let n += 1
      while n < l
        let c = ss[n]
        if c == '"'
          let b .= c
          let n += 1
          break
        elseif c != '\'
          let b .= c
        elseif n < l - 1 && has_key(m, c)
          let b .= m[c]
        endif
        let n += 1
      endwhile
      call add(r, b)
    elseif c == ';'
      while n < l
        let c = ss[n]
        let n += 1
        if c == "\n"
          break
        endif
      endwhile
    else
      let b = ''
      while n < l
        let c = ss[n]
        if c =~ '[\r\n\t ()]'
          break
        endif
        let n += 1
        let b .= c
      endwhile
      call add(r, b)
    endif
  endwhile
  return r
endfunction

function! s:read_from(ctx)
  if len(a:ctx.tokens) == 0
    throw 'unexpected EOF while reading'
  endif
  let token = a:ctx.tokens[0]
  let a:ctx.tokens = a:ctx.tokens[1:]
  if '(' == token
    let l = []
    while len(a:ctx.tokens) > 0 && a:ctx.tokens[0] != ')'
      call add(l, s:read_from(a:ctx))
    endwhile
    if len(a:ctx.tokens) == 0
      throw 'unexpected EOF while reading'
    endif
    let a:ctx.tokens = a:ctx.tokens[1:]
    "if len(l) > 0 && len(a:ctx.tokens) > 0
    "  let l += s:read_from(a:ctx)
    "endif
    return l
  elseif ')' == token
    throw 'unexpected )'
  else
    return s:atom(token)
  endif
endfunction

function! s:atom(token)
  let t = type(a:token)
  if t == 0 || t == 5
    return a:token
  elseif t == 1
    if a:token =~ '^[+-]\?[0-9]\+$'
      return 0 + a:token
    endif
    if a:token =~ '^\([+-]\?\)\%([0-9]\|\.[0-9]\)[0-9]*\(\.[0-9]*\)\?\([Ee]\([+-]\?[0-9]+\)\)\?$'
      return str2float(a:token)
    endif
    if a:token =~ '^\".*"$'
      return eval(a:token)
    endif
  endif
  return {'_lisper_symbol_': a:token}
endfunction

function! lisper#stringer(v)
  let t = type(a:v)
  if t == 0 || t == 1 || t == 5
    return a:v
  elseif t == 4
    if has_key(a:v, '_lisper_symbol_')
      return lisper#stringer(a:v['_lisper_symbol_'])
    endif
    return string(a:v)
  elseif t == 3
    let s = '('
    for V in a:v
      if s != '('
        let s .= ' '
      endif
      let s .= lisper#stringer(V)
      unlet V
    endfor
    let s .= ')'
    return s
  else
    return string(a:v)
  endif
endfunction

function! s:deref(x)
  let X = a:x
  while type(X) == 4
    if !has_key(X, '_lisper_symbol_')
      return X
    endif
    let Y = X['_lisper_symbol_']
    unlet X
    let X = Y
  endwhile
  return X
endfunction

let s:lisp = {}

function! s:lisp.dispose() dict
  for X in self.global_env.lambda
    exe "delfunction" X
    unlet X
  endfor
  let self.global_env = {}
endfunction

function! s:lisp._eval(...) dict abort
  let x = a:1
  let env = a:0 > 1 ? a:2 : self.global_env
  if type(x) == 4 " symbol
    let s = s:deref(x)
    if type(s) == 4
      return s
    endif
    return env.find(s)[s]
  elseif type(x) != 3 " constant
    return x
  else
    if len(x) == 0
      return
    endif
    while type(x[0]) == 3 && len(x[0])
      let t = x[0]
      unlet x
      let x = t
      unlet t
    endwhile
    if len(x[0]) == 0
      return 0
    endif
    let m = s:deref(x[0])
    if m == 'quote' " (quote exp)
      let [_, exp; rest] = x
      return exp
    elseif m == 'if' " (if test conseq alt)
      let [_, test, conseq; rest] = x
      let alt = len(rest) > 0 ? rest[0] : 0
      if self._eval(test, env)
        return self._eval(conseq, env)
      else
        return self._eval(alt, env)
      endif
    elseif m == 'set!' " (set! var exp)
      let [_, var, exp; rest] = x
      let m = s:deref(var)
      let vars = env.find(m, 1)
      let vars[m] = self._eval(exp, env)
      return m
    elseif m == 'define' " (define var exp)
      let [_, var, exp; rest] = x
      unlet m
      let m = s:deref(var)
      let env.bind[m] = self._eval(exp, env)
      return env.bind[m]
    elseif m == 'return' " (return exp)
      let env['_lisper_loop_'] = 0
      return len(x) > 1 ? self._eval(x[1], env) : 0
    elseif m == 'loop' " (loop exp*)
      let oldloop = get(env, '_lisper_loop_', 0)
      while 1
        for exp in x[1:]
          silent! unlet V
          let env['_lisper_loop_'] = 1
          let V = self._eval(exp, env)
          if env['_lisper_loop_'] == 0
            let env['_lisper_loop_'] = oldloop
            return V
          endif
          unlet exp
        endfor
      endwhile
    elseif m == 'lambda' " (lambda (var*) exp)
      let [_, vars, exp; rest] = x
      return {'_lisper_symbol_': env.make_op('__[0]._eval(__[1], s:env.new(__[2], a:000, __[3]))', self, exp, vars, env)}
    elseif m == 'begin' " (begin exp*)
      let V = 0
      for exp in x[1:]
        silent! unlet VV
        let VV = self._eval(exp, env)
        silent! unlet V
        let V = VV
        unlet exp
      endfor
      return V
    elseif m == 'vim-echo'
      let exps = []
      for exp in x[1:]
        call add(exps, self._eval(exp, env))
        unlet exp
      endfor
      call call('s:echo', exps)
      return ''
    elseif m == 'vim-call'
      let exps = []
      for exp in x[2:]
        call add(exps, self._eval(exp, env))
        unlet exp
      endfor
      return call(s:deref(x[1]), exps)
    elseif m == 'vim-eval'
      let exps = []
      for exp in x[2:]
        call add(exps, self._eval(exp, env))
        unlet exp
      endfor
      return call(env.make_op(s:deref(x[1])), exps)
    elseif m == 'vim-do'
      let exps = []
      for exp in x[2:]
        call add(exps, self._eval(exp, env))
        unlet exp
      endfor
      return call(env.make_do(s:deref(x[1])), exps)
    else " (proc exp*)
      let exps = []
      for exp in x
        call add(exps, self._eval(exp, env))
        unlet exp
      endfor
      return call(s:deref(exps[0]), exps[1:])
    endif
  endif
endfunction

function! s:lisp.eval(exp) dict
  return lisper#stringer(self._eval(s:parse(a:exp)))
endfunction

function! s:lisp.evalv(exp) dict
  return self._eval(s:parse(a:exp))
endfunction

function! lisper#engine()
  let engine = deepcopy(s:lisp)
  let engine.global_env = s:add_globals(s:env.new())
  return engine
endfunction

function! s:cut_vimprefix(e)
  let e = a:e
  if e =~ '^Vim'
    let e = substitute(e, '^Vim[^:]*:', '', '')
  endif
  return e
endfunction

function! lisper#eval(exp)
  let engine = lisper#engine()
  try
    return engine.eval(a:exp)
  catch /.../
    throw s:cut_vimprefix(v:exception)
  finally
    call engine.dispose()
    unlet engine
  endtry
endfunction

function! lisper#repl()
  let repl = lisper#engine()
  let oldmore = &more
  set nomore
  let exp = ''
  let nest = 0
  try
    while 1
      let exp .= input("lisp".repeat(">", nest+1)." ")
      echo "\n"
      if len(exp) > 0
        let tokens = []
        try
          let tokens = s:tokenize(exp)
          let ret = lisper#stringer(repl._eval(s:read_from({"tokens": tokens})))
          echohl Constant | echo "=>" ret | echohl None
          let exp = ''
          let nest = 0
        catch /.../
          if v:exception != 'unexpected EOF while reading'
            let exp = ''
            echohl WarningMsg | echo s:cut_vimprefix(v:exception) | echohl None
          else
            let nest = s:can(tokens)
          endif
        endtry
      endif
    endwhile
  finally
    let &more = oldmore
    call repl.dispose()
    unlet repl
  endtry
endfunction

" vim:set et:
