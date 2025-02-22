# JavaScript binding generator. Horrifying, I know. But it works!
# Warning: Function overloading is currently not implemented. Though there is a
# block dielabel:
#   ...
# around each bound function call, so it shouldn't be too difficult to get it
# working. (This would involve generating JS functions in registerType.)
# Now for the pragmas:
# {.jsctor.} for constructors. These need no `this' value, and are bound as
#   regular constructors in JS. They must return a ref object, which will have
#   a JS counterpart too. (Other functions can return ref objects too, which
#   will either use the existing JS counterpart, if exists, or create a new
#   one. In other words: cross-language reference semantics work seamlessly.)
# {.jsfunc.} is used for binding normal functions. Needs a `this' value, as all
#   following pragmas. As mentioned before, overloading doesn't work but OR
#   generics do. By default, the Nim function name is bound; if this is not
#   desired, you can rename the function like this: {.jsfunc: "preferredName".}
#   This also works for all other pragmas that define named functions in JS.
# {.jsstfunc.} binds static functions. Unlike .jsfunc, it does not have a
#   `this' value. A class name must be specified, e.g. {.jsstfunc: "URL".} to
#   define on the URL class. To rename a static function, use the syntax
#   "ClassName:funcName", e.g. "Response:error".
# {.jsget.}, {.jsfget.} must be specified on object fields; these generate
#   regular getter & setter functions.
# {.jsufget, jsuffget, jsuffunc.} For fields with the [LegacyUnforgeable]
#   WebIDL property.
#   This makes it so a non-configurable/writable, but enumerable property
#   is defined on the object when the *constructor* is called (i.e. NOT on
#   the prototype.)
# {.jsfget.} and {.jsfset.} for getters/setters. Note the `f'; bare jsget/jsset
#   can only be used on object fields. (I initially wanted to use the same
#   keyword, unfortunately that didn't work out.)
# {.jsgetprop.} for property getters. Called when GetOwnProperty would return
#   nothing. The key must be either a string or an integer (preferably uint32),
#   since it is converted from a JSAtom.
# {.jssetprop.} for property setters. Called on SetProperty - in fact this
#   is the set() method of Proxy, except it always returns true. Same rules as
#   jsgetprop for keys.
# {.jsdelprop.} for property deletion. It is like the deleteProperty method
#   of Proxy. Must return true if deleted, false if not deleted.
# {.jshasprop.} for overriding has_property. Must return a boolean.
# {.jspropnames.} overrides get_own_property_names. Must return a
#   JSPropertyEnumList object.

import std/macros
import std/options
import std/sets
import std/strutils
import std/tables
import std/unicode

import io/dynstream
import js/error
import js/fromjs
import js/opaque
import js/tojs
import js/typeptr
import types/opt
import utils/twtstr

import bindings/quickjs

export opt
export options
export tables

export
  JS_NULL, JS_UNDEFINED, JS_FALSE, JS_TRUE, JS_EXCEPTION, JS_UNINITIALIZED

export
  JS_EVAL_TYPE_GLOBAL,
  JS_EVAL_TYPE_MODULE,
  JS_EVAL_TYPE_DIRECT,
  JS_EVAL_TYPE_INDIRECT,
  JS_EVAL_TYPE_MASK,
  JS_EVAL_FLAG_SHEBANG,
  JS_EVAL_FLAG_STRICT,
  JS_EVAL_FLAG_STRIP,
  JS_EVAL_FLAG_COMPILE_ONLY

export JSRuntime, JSContext, JSValue, JSClassID

export
  JS_GetGlobalObject, JS_FreeValue, JS_IsException, JS_GetPropertyStr,
  JS_IsFunction, JS_NewCFunctionData, JS_Call, JS_DupValue

when sizeof(int) < sizeof(int64):
  export quickjs.`==`

type
  JSFunctionList = openArray[JSCFunctionListEntry]

  BoundFunction = object
    t: BoundFunctionType
    name: string
    id: NimNode
    magic: uint16
    unforgeable: bool
    isstatic: bool
    ctorBody: NimNode

  BoundFunctionType = enum
    FUNCTION = "js_func"
    CONSTRUCTOR = "js_ctor"
    GETTER = "js_get"
    SETTER = "js_set"
    PROPERTY_GET = "js_prop_get"
    PROPERTY_SET = "js_prop_set"
    PROPERTY_DEL = "js_prop_del"
    PROPERTY_HAS = "js_prop_has"
    PROPERTY_NAMES = "js_prop_names"
    FINALIZER = "js_fin"

var runtimes {.threadvar.}: seq[JSRuntime]

proc bindMalloc(s: ptr JSMallocState, size: csize_t): pointer {.cdecl.} =
  return alloc(size)

proc bindFree(s: ptr JSMallocState, p: pointer) {.cdecl.} =
  if p == nil:
    return
  dealloc(p)

proc bindRealloc(s: ptr JSMallocState, p: pointer, size: csize_t): pointer
    {.cdecl.} =
  return realloc(p, size)

proc newJSRuntime*(): JSRuntime =
  var mf {.global.} = JSMallocFunctions(
    js_malloc: bindMalloc,
    js_free: bindFree,
    js_realloc: bindRealloc,
    js_malloc_usable_size: nil
  )
  let rt = JS_NewRuntime2(addr mf, nil)
  let opaque = JSRuntimeOpaque()
  GC_ref(opaque)
  JS_SetRuntimeOpaque(rt, cast[pointer](opaque))
  # Must be added after opaque is set, or there is a chance of
  # nim_finalize_for_js dereferencing it (at the new call).
  runtimes.add(rt)
  return rt

proc newJSContext*(rt: JSRuntime): JSContext =
  let ctx = JS_NewContext(rt)
  let opaque = newJSContextOpaque(ctx)
  GC_ref(opaque)
  JS_SetContextOpaque(ctx, cast[pointer](opaque))
  return ctx

func getClass*(ctx: JSContext, class: string): JSClassID =
  # This function *should* never fail.
  ctx.getOpaque().creg[class]

func hasClass*(ctx: JSContext, class: type): bool =
  return $class in ctx.getOpaque().creg

func newJSCFunction*(ctx: JSContext, name: string, fun: JSCFunction,
    argc: int = 0, proto = JS_CFUNC_generic, magic = 0): JSValue =
  return JS_NewCFunction2(ctx, fun, cstring(name), cint(argc), proto, cint(magic))

proc free*(ctx: var JSContext) =
  var opaque = ctx.getOpaque()
  if opaque != nil:
    for a in opaque.sym_refs:
      JS_FreeAtom(ctx, a)
    for a in opaque.str_refs:
      JS_FreeAtom(ctx, a)
    for classid, v in opaque.ctors:
      JS_FreeValue(ctx, v)
    JS_FreeValue(ctx, opaque.Array_prototype_values)
    JS_FreeValue(ctx, opaque.Object_prototype_valueOf)
    JS_FreeValue(ctx, opaque.Uint8Array_ctor)
    JS_FreeValue(ctx, opaque.Set_ctor)
    JS_FreeValue(ctx, opaque.Function_ctor)
    for v in opaque.err_ctors:
      JS_FreeValue(ctx, v)
    GC_unref(opaque)
  JS_FreeContext(ctx)
  ctx = nil

proc free*(rt: var JSRuntime) =
  let opaque = rt.getOpaque()
  GC_unref(opaque)
  JS_FreeRuntime(rt)
  runtimes.del(runtimes.find(rt))
  rt = nil

proc setGlobal*[T](ctx: JSContext, global: JSValue, obj: T) =
  # Add JSValue reference.
  let p = JS_VALUE_GET_PTR(global)
  let header = cast[ptr JSRefCountHeader](p)
  inc header.ref_count
  ctx.setOpaque(global, cast[pointer](obj))
  GC_ref(obj)

proc setInterruptHandler*(rt: JSRuntime, cb: JSInterruptHandler, opaque: pointer = nil) =
  JS_SetInterruptHandler(rt, cb, opaque)

proc getExceptionStr*(ctx: JSContext): string =
  result = ""
  let ex = JS_GetException(ctx)
  let str = fromJS[string](ctx, ex)
  if str.isSome:
    result &= str.get & '\n'
  let stack = JS_GetPropertyStr(ctx, ex, cstring("stack"));
  if not JS_IsUndefined(stack):
    result &= fromJS[string](ctx, stack).get("")
  JS_FreeValue(ctx, stack)
  JS_FreeValue(ctx, ex)

proc writeException*(ctx: JSContext, s: DynStream) =
  s.write(ctx.getExceptionStr())
  s.sflush()

proc runJSJobs*(rt: JSRuntime, err: DynStream) =
  while JS_IsJobPending(rt):
    var ctx: JSContext
    let r = JS_ExecutePendingJob(rt, addr ctx)
    if r == -1:
      ctx.writeException(err)

# Add all LegacyUnforgeable functions defined on the prototype chain to
# the opaque.
# Since every prototype has a list of all its ancestor's LegacyUnforgeable
# functions, it is sufficient to simply merge the new list of new classes
# with their parent's list to achieve this.
proc addClassUnforgeable(ctx: JSContext, proto: JSValue,
    classid, parent: JSClassID, ourUnforgeable: JSFunctionList) =
  let ctxOpaque = ctx.getOpaque()
  var merged = @ourUnforgeable
  ctxOpaque.unforgeable.withValue(parent, uf):
    merged.add(uf[])
  if merged.len > 0:
    ctxOpaque.unforgeable[classid] = merged
    let ufp = addr ctxOpaque.unforgeable[classid][0]
    JS_SetPropertyFunctionList(ctx, proto, ufp, cint(merged.len))

func newJSClass*(ctx: JSContext, cdef: JSClassDefConst, tname: string,
    nimt: pointer, ctor: JSCFunction, funcs: JSFunctionList, parent: JSClassID,
    asglobal: bool, nointerface: bool, finalizer: JSFinalizerFunction,
    namespace: JSValue, errid: Opt[JSErrorEnum],
    unforgeable, staticfuns: JSFunctionList,
    ishtmldda: bool): JSClassID {.discardable.} =
  let rt = JS_GetRuntime(ctx)
  discard JS_NewClassID(addr result)
  var ctxOpaque = ctx.getOpaque()
  var rtOpaque = rt.getOpaque()
  if JS_NewClass(rt, result, cdef) != 0:
    raise newException(Defect, "Failed to allocate JS class: " & $cdef.class_name)
  ctxOpaque.typemap[nimt] = result
  ctxOpaque.creg[tname] = result
  ctxOpaque.parents[result] = parent
  if ishtmldda:
    ctxOpaque.htmldda = result
  if finalizer != nil:
    rtOpaque.fins[result] = finalizer
  var proto: JSValue
  if parent != 0:
    let parentProto = JS_GetClassProto(ctx, parent)
    proto = JS_NewObjectProtoClass(ctx, parentProto, parent)
    JS_FreeValue(ctx, parentProto)
  else:
    proto = JS_NewObject(ctx)
  if funcs.len > 0:
    # We avoid funcs being GC'ed by putting the list in rtOpaque.
    # (QuickJS uses the pointer later.)
    #TODO maybe put them in ctxOpaque instead?
    rtOpaque.flist.add(@funcs)
    JS_SetPropertyFunctionList(ctx, proto, addr rtOpaque.flist[^1][0], cint(funcs.len))
  #TODO check if this is an indexed property getter
  if cdef.exotic != nil and cdef.exotic.get_own_property != nil:
    let val = JS_DupValue(ctx, ctxOpaque.Array_prototype_values)
    doAssert JS_SetProperty(ctx, proto, ctxOpaque.sym_refs[ITERATOR], val) == 1
  let news = JS_NewAtomString(ctx, cdef.class_name)
  doAssert not JS_IsException(news)
  ctx.definePropertyC(proto, ctxOpaque.sym_refs[TO_STRING_TAG], news)
  JS_SetClassProto(ctx, result, proto)
  ctx.addClassUnforgeable(proto, result, parent, unforgeable)
  if asglobal:
    let global = JS_GetGlobalObject(ctx)
    assert ctxOpaque.gclaz == ""
    ctxOpaque.gclaz = tname
    ctxOpaque.gparent = parent
    if JS_SetPrototype(ctx, global, proto) != 1:
      raise newException(Defect, "Failed to set global prototype: " &
        $cdef.class_name)
    # Global already exists, so set unforgeable functions here
    ctxOpaque.unforgeable.withValue(result, uf):
      JS_SetPropertyFunctionList(ctx, global, addr uf[][0], cint(uf[].len))
    JS_FreeValue(ctx, global)
  let jctor = ctx.newJSCFunction($cdef.class_name, ctor, 0, JS_CFUNC_constructor)
  if staticfuns.len > 0:
    rtOpaque.flist.add(@staticfuns)
    JS_SetPropertyFunctionList(ctx, jctor, addr rtOpaque.flist[^1][0],
      cint(staticfuns.len))
  JS_SetConstructor(ctx, jctor, proto)
  if errid.isSome:
    ctx.getOpaque().err_ctors[errid.get] = JS_DupValue(ctx, jctor)
  ctxOpaque.ctors[result] = JS_DupValue(ctx, jctor)
  if not nointerface:
    if JS_IsNull(namespace):
      let global = JS_GetGlobalObject(ctx)
      ctx.definePropertyCW(global, $cdef.class_name, jctor)
      JS_FreeValue(ctx, global)
    else:
      ctx.definePropertyCW(namespace, $cdef.class_name, jctor)

type FuncParam = tuple[name: string, t: NimNode, val: Option[NimNode], generic: Option[NimNode]]

func getMinArgs(params: seq[FuncParam]): int =
  for i in 0..<params.len:
    let it = params[i]
    if it[2].isSome:
      return i
    let t = it.t
    if t.kind == nnkBracketExpr:
      if t.typeKind == varargs.getType().typeKind:
        assert i == params.high, "Not even nim can properly handle this..."
        return i
  return params.len

func fromJSP[T: string|uint32](ctx: JSContext, atom: JSAtom): Opt[T] =
  return fromJS[T](ctx, atom)

proc getJSFunction*[T, U](ctx: JSContext, val: JSValue):
    (proc(x: T): JSResult[U]) =
  return fromJSFunction1[T, U](ctx, val)

proc defineConsts*[T](ctx: JSContext, classid: JSClassID,
    consts: static openArray[(string, T)]) =
  let proto = ctx.getOpaque().ctors[classid]
  for (k, v) in consts:
    ctx.definePropertyE(proto, k, v)

proc defineConsts*(ctx: JSContext, classid: JSClassID,
    consts: typedesc[enum], astype: typedesc) =
  let proto = ctx.getOpaque().ctors[classid]
  for e in consts:
    ctx.definePropertyE(proto, $e, astype(e))

type
  JSFuncGenerator = ref object
    t: BoundFunctionType
    thisname: Option[string]
    funcName: string
    generics: Table[string, seq[NimNode]]
    funcParams: seq[FuncParam]
    passCtx: bool
    thisType: string
    thisTypeNode: NimNode
    returnType: Option[NimNode]
    newName: NimNode
    newBranchList: seq[NimNode]
    errval: NimNode # JS_EXCEPTION or -1
    dielabel: NimNode # die: didn't match parameters, but could still match other ones
    jsFunCallLists: seq[NimNode]
    jsFunCallList: NimNode
    jsFunCall: NimNode
    jsCallAndRet: NimNode
    minArgs: int
    actualMinArgs: int # minArgs without JSContext
    i: int # nim parameters accounted for
    j: int # js parameters accounted for (not including fix ones, e.g. `this')
    unforgeable: bool
    isstatic: bool

var BoundFunctions {.compileTime.}: Table[string, seq[BoundFunction]]

proc getGenerics(fun: NimNode): Table[string, seq[NimNode]] =
  var node = fun.findChild(it.kind == nnkBracket)
  if node.kind == nnkNilLit:
    return # no bracket
  node = node.findChild(it.kind == nnkGenericParams)
  if node.kind == nnkNilLit:
    return # no generics
  node = node.findChild(it.kind == nnkIdentDefs)
  var stack: seq[NimNode]
  for i in countdown(node.len - 1, 0): stack.add(node[i])
  var gen_name: NimNode
  var gen_types: seq[NimNode]
  template add_gen =
    if gen_name != nil:
      assert gen_types.len != 0
      result[gen_name.strVal] = gen_types
      gen_types.setLen(0)

  while stack.len > 0:
    let node = stack.pop()
    case node.kind
    of nnkIdent:
      add_gen
      gen_name = node
    of nnkSym:
      assert gen_name != nil
      gen_types.add(node)
    of nnkInfix:
      assert node[0].eqIdent(ident("|")) or node[0].eqIdent(ident("or")), "Only OR generics are supported."
      for i in countdown(node.len - 1, 1): stack.add(node[i]) # except infix ident
    of nnkBracketExpr:
      gen_types.add(node)
    else:
      discard
  add_gen

proc getParams(fun: NimNode): seq[FuncParam] =
  let formalParams = fun.findChild(it.kind == nnkFormalParams)
  var funcParams: seq[FuncParam]
  var returnType = none(NimNode)
  if formalParams[0].kind != nnkEmpty:
    returnType = some(formalParams[0])
  for i in 1..<fun.params.len:
    let it = formalParams[i]
    let tt = it[^2]
    var t: NimNode
    if it[^2].kind != nnkEmpty:
      t = `tt`
    elif it[^1].kind != nnkEmpty:
      let x = it[^1]
      t = quote do:
        typeof(`x`)
    else:
      error("?? " & treeRepr(it))
    if t.kind in {nnkRefTy, nnkPtrTy}:
      t = t[0]
    let val = if it[^1].kind != nnkEmpty:
      let x = it[^1]
      some(newPar(x))
    else:
      none(NimNode)
    var g = none(NimNode)
    for i in 0 ..< it.len - 2:
      let name = $it[i]
      funcParams.add((name, t, val, g))
  funcParams

proc getReturn(fun: NimNode): Option[NimNode] =
  let formalParams = fun.findChild(it.kind == nnkFormalParams)
  if formalParams[0].kind != nnkEmpty:
    some(formalParams[0])
  else:
    none(NimNode)

template getJSParams(): untyped =
  [
    (quote do: JSValue),
    newIdentDefs(ident("ctx"), quote do: JSContext),
    newIdentDefs(ident("this"), quote do: JSValue),
    newIdentDefs(ident("argc"), quote do: cint),
    newIdentDefs(ident("argv"), quote do: ptr UncheckedArray[JSValue])
  ]

template getJSGetterParams(): untyped =
  [
    (quote do: JSValue),
    newIdentDefs(ident("ctx"), quote do: JSContext),
    newIdentDefs(ident("this"), quote do: JSValue),
  ]

template getJSGetPropParams(): untyped =
  [
    (quote do: cint),
    newIdentDefs(ident("ctx"), quote do: JSContext),
    newIdentDefs(ident("desc"), quote do: ptr JSPropertyDescriptor),
    newIdentDefs(ident("obj"), quote do: JSValue),
    newIdentDefs(ident("prop"), quote do: JSAtom),
  ]

template getJSSetPropParams(): untyped =
  [
    (quote do: cint),
    newIdentDefs(ident("ctx"), quote do: JSContext),
    newIdentDefs(ident("obj"), quote do: JSValue),
    newIdentDefs(ident("atom"), quote do: JSAtom),
    newIdentDefs(ident("value"), quote do: JSValue),
    newIdentDefs(ident("receiver"), quote do: JSValue),
    newIdentDefs(ident("flags"), quote do: cint),
  ]

template getJSDelPropParams(): untyped =
  [
    (quote do: cint),
    newIdentDefs(ident("ctx"), quote do: JSContext),
    newIdentDefs(ident("obj"), quote do: JSValue),
    newIdentDefs(ident("prop"), quote do: JSAtom),
  ]

template getJSHasPropParams(): untyped =
  [
    (quote do: cint),
    newIdentDefs(ident("ctx"), quote do: JSContext),
    newIdentDefs(ident("obj"), quote do: JSValue),
    newIdentDefs(ident("atom"), quote do: JSAtom),
  ]


template getJSSetterParams(): untyped =
  [
    (quote do: JSValue),
    newIdentDefs(ident("ctx"), quote do: JSContext),
    newIdentDefs(ident("this"), quote do: JSValue),
    newIdentDefs(ident("val"), quote do: JSValue),
  ]

template getJSPropNamesParams(): untyped =
  [
    (quote do: cint),
    newIdentDefs(ident("ctx"), quote do: JSContext),
    newIdentDefs(ident("ptab"), quote do: ptr JSPropertyEnumArray),
    newIdentDefs(ident("plen"), quote do: ptr uint32),
    newIdentDefs(ident("obj"), quote do: JSValue)
  ]

template fromJS_or_return*(t, ctx, val: untyped): untyped =
  (
    let x = fromJS[t](ctx, val)
    if x.isErr:
      if x.error == nil:
        return JS_EXCEPTION
      return toJS(ctx, x.error)
    x.get
  )

template fromJSP_or_return*(t, ctx, val: untyped): untyped =
  (
    let x = fromJSP[t](ctx, val)
    if x.isErr:
      if x.error == nil:
        return JS_EXCEPTION
      return toJS(ctx, x.error)
    x.get
  )

template fromJS_or_die*(t, ctx, val, ev, dl: untyped): untyped =
  let x = fromJSP[t](ctx, val)
  if x.isNone:
    break dl
  x.get

proc addParam2(gen: var JSFuncGenerator, s, t, val: NimNode, fallback: NimNode = nil) =
  let ev = gen.errval
  let dl = gen.dielabel
  let stmt = quote do:
    fromJS_or_die(`t`, ctx, `val`, `ev`, `dl`)
  for i in 0..gen.jsFunCallLists.high:
    if fallback == nil:
      gen.jsFunCallLists[i].add(newLetStmt(s, stmt))
    else:
      let j = gen.j
      gen.jsFunCallLists[i].add(newLetStmt(s, quote do:
        if `j` < argc and not JS_IsUndefined(argv[`j`]):
          `stmt`
        else:
          `fallback`))

proc addValueParam(gen: var JSFuncGenerator, s, t: NimNode, fallback: NimNode = nil) =
  let j = gen.j
  gen.addParam2(s, t, quote do: argv[`j`], fallback)

proc addUnionParamBranch(gen: var JSFuncGenerator, query, newBranch: NimNode, fallback: NimNode = nil) =
  let i = gen.i
  let query = if fallback == nil: query else:
    quote do: (`i` < argc and `query`)
  let newBranch = newStmtList(newBranch)
  for i in 0..gen.jsFunCallLists.high:
    var ifstmt = newIfStmt((query, newBranch))
    let oldBranch = newStmtList()
    ifstmt.add(newTree(nnkElse, oldBranch))
    gen.jsFunCallLists[i].add(ifstmt)
    gen.jsFunCallLists[i] = oldBranch
  gen.newBranchList.add(newBranch)

func isSequence*(ctx: JSContext, o: JSValue): bool =
  if not JS_IsObject(o):
    return false
  let prop = JS_GetProperty(ctx, o, ctx.getOpaque().sym_refs[ITERATOR])
  # prop can't be exception (throws_ref_error is 0 and tag is object)
  result = not JS_IsUndefined(prop)
  JS_FreeValue(ctx, prop)

proc addUnionParam0(gen: var JSFuncGenerator, tt, s, val: NimNode,
    fallback: NimNode = nil) =
  # Union types.
  #TODO quite a few types are still missing.
  let flattened = gen.generics[tt.strVal] # flattened member types
  var tableg = none(NimNode)
  var seqg = none(NimNode)
  var numg = none(NimNode)
  var objg = none(NimNode)
  var hasString = false
  var hasJSValue = false
  var hasBoolean = false
  let ev = gen.errval
  let dl = gen.dielabel
  for g in flattened:
    if g.len > 0 and g[0] == Table.getType():
      tableg = some(g)
    elif g.typekind == ntySequence:
      seqg = some(g)
    elif g == string.getTypeInst():
      hasString = true
    elif g == JSValue.getTypeInst():
      hasJSValue = true
    elif g == bool.getTypeInst():
      hasBoolean = true
    elif g == int.getTypeInst(): #TODO should be SomeNumber
      assert numg.isNone
      numg = some(g)
    elif g == uint32.getTypeInst(): #TODO should be SomeNumber
      assert numg.isNone
      numg = some(g)
    elif g.getTypeInst().getTypeImpl().kind == nnkRefTy:
      # Assume it's ref object.
      objg = some(g)
    else:
      error("Type not supported yet")

  # 5. If V is a platform object, then:
  if objg.isSome:
    let t = objg.get
    let x = ident("x")
    let query = quote do:
      let `x` = fromJS[`t`](ctx, `val`)
      `x`.isOk
    gen.addUnionParamBranch(query, quote do:
      let `s` = `x`.get,
      fallback)
  # 10. If Type(V) is Object, then:
  # Sequence:
  if seqg.isSome:
    let query = quote do:
      isSequence(ctx, `val`)
    let a = seqg.get[1]
    gen.addUnionParamBranch(query, quote do:
      let `s` = fromJS_or_die(seq[`a`], ctx, `val`, `ev`, `dl`),
      fallback)
  # Record:
  if tableg.isSome:
    let a = tableg.get[1]
    let b = tableg.get[2]
    let query = quote do:
      JS_IsObject(`val`)
    gen.addUnionParamBranch(query, quote do:
      let `s` = fromJS_or_die(Table[`a`, `b`], ctx, `val`, `ev`, `dl`),
      fallback)
  # Object (JSObject variant):
  #TODO non-JS objects (i.e. ref object)
  if hasJSValue:
    let query = quote do:
      JS_IsObject(`val`)
    gen.addUnionParamBranch(query, quote do:
      let `s` = fromJS_or_die(JSValue, ctx, `val`, `ev`, `dl`),
      fallback)
  # 11. If Type(V) is Boolean, then:
  if hasBoolean:
    let query = quote do:
      JS_IsBool(`val`)
    gen.addUnionParamBranch(query, quote do:
      let `s` = fromJS_or_die(bool, ctx, `val`, `ev`, `dl`),
      fallback)
  # 12. If Type(V) is Number, then:
  if numg.isSome:
    let ng = numg.get
    let query = quote do:
      JS_IsNumber(`val`)
    gen.addUnionParamBranch(query, quote do:
      let `s` = fromJS_or_die(`ng`, ctx, `val`, `ev`, `dl`),
      fallback)
  # 14. If types includes a string type, then return the result of converting V
  # to that type.
  if hasString:
    gen.addParam2(s, string.getType(), quote do: `val`, fallback)
  # 16. If types includes a numeric type, then return the result of converting
  # V to that numeric type.
  elif numg.isSome:
    gen.addParam2(s, numg.get.getType(), quote do: `val`, fallback)
  # 17. If types includes boolean, then return the result of converting V to
  # boolean.
  elif hasBoolean:
    gen.addParam2(s, bool.getType(), quote do: `val`, fallback)
  # 19. Throw a TypeError.
  else:
    gen.addParam2(s, string.getType(), quote do:
      if true:
        discard JS_ThrowTypeError(ctx, "No match for union type")
        return `ev`
      JS_NULL, fallback)

  for branch in gen.newBranchList:
    gen.jsFunCallLists.add(branch)
  gen.newBranchList.setLen(0)

proc addUnionParam(gen: var JSFuncGenerator, tt: NimNode, s: NimNode,
    fallback: NimNode = nil) =
  let j = gen.j
  gen.addUnionParam0(tt, s, quote do: argv[`j`], fallback)

proc addFixParam(gen: var JSFuncGenerator, name: string) =
  let s = ident("arg_" & $gen.i)
  let t = gen.funcParams[gen.i][1]
  let id = ident(name)
  if t.typeKind == ntyGenericParam:
    gen.addUnionParam0(t, s, id)
  else:
    gen.addParam2(s, t, id)
  if gen.jsFunCall != nil:
    gen.jsFunCall.add(s)
  inc gen.i

proc addRequiredParams(gen: var JSFuncGenerator) =
  while gen.i < gen.minArgs:
    let s = ident("arg_" & $gen.i)
    let tt = gen.funcParams[gen.i][1]
    if tt.typeKind == ntyGenericParam:
      gen.addUnionParam(tt, s)
    else:
      gen.addValueParam(s, tt)
    if gen.jsFunCall != nil:
      gen.jsFunCall.add(s)
    inc gen.j
    inc gen.i

proc addOptionalParams(gen: var JSFuncGenerator) =
  while gen.i < gen.funcParams.len:
    let j = gen.j
    let s = ident("arg_" & $gen.i)
    let tt = gen.funcParams[gen.i][1]
    if tt.typeKind == varargs.getType().typeKind: # pray it's not a generic...
      let vt = tt[1].getType()
      for i in 0..gen.jsFunCallLists.high:
        gen.jsFunCallLists[i].add(newLetStmt(s, quote do:
          (
            var valist: seq[`vt`]
            for i in `j`..<argc:
              let it = fromJS_or_return(`vt`, ctx, argv[i])
              valist.add(it)
            valist
          )
        ))
    else:
      if gen.funcParams[gen.i][2].isNone:
        error("No fallback value. Maybe a non-optional parameter follows an " &
          "optional parameter?")
      let fallback = gen.funcParams[gen.i][2].get
      if tt.typeKind == ntyGenericParam:
        gen.addUnionParam(tt, s, fallback)
      else:
        gen.addValueParam(s, tt, fallback)
    if gen.jsFunCall != nil:
      gen.jsFunCall.add(s)
    inc gen.j
    inc gen.i

proc finishFunCallList(gen: var JSFuncGenerator) =
  for branch in gen.jsFunCallLists:
    branch.add(gen.jsFunCall)

var existingFuncs {.compileTime.}: HashSet[string]
var jsDtors {.compileTime.}: HashSet[string]

proc registerFunction(typ: string, nf: BoundFunction) =
  BoundFunctions.withValue(typ, val):
    val[].add(nf)
  do:
    BoundFunctions[typ] = @[nf]
  existingFuncs.incl(nf.id.strVal)

proc registerFunction(typ: string, t: BoundFunctionType, name: string,
    id: NimNode, magic: uint16 = 0, uf = false, isstatic = false,
    ctorBody: NimNode = nil) =
  registerFunction(typ, BoundFunction(
    t: t,
    name: name,
    id: id,
    magic: magic,
    unforgeable: uf,
    isstatic: isstatic,
    ctorBody: ctorBody
  ))

proc registerConstructor(gen: JSFuncGenerator, jsProc: NimNode) =
  registerFunction(gen.thisType, gen.t, gen.funcName, gen.newName,
    uf = gen.unforgeable, isstatic = gen.isstatic, ctorBody = jsProc)

proc registerFunction(gen: JSFuncGenerator) =
  registerFunction(gen.thisType, gen.t, gen.funcName, gen.newName,
    uf = gen.unforgeable, isstatic = gen.isstatic)

export JS_ThrowTypeError, JS_ThrowRangeError, JS_ThrowSyntaxError,
       JS_ThrowInternalError, JS_ThrowReferenceError

proc newJSProcBody(gen: var JSFuncGenerator, isva: bool): NimNode =
  let tt = gen.thisType
  let fn = gen.funcName
  let ma = gen.actualMinArgs
  result = newStmtList()
  if isva:
    result.add(quote do:
      if argc < `ma`:
        return JS_ThrowTypeError(ctx,
          "At least %d arguments required, but only %d passed", cint(`ma`),
          cint(argc))
    )
  if gen.thisname.isSome and not gen.isstatic:
    let tn = ident(gen.thisname.get)
    let ev = gen.errval
    result.add(quote do:
      if not ctx.isInstanceOf(`tn`, `tt`):
        discard JS_ThrowTypeError(ctx,
          "'%s' called on an object that is not an instance of %s", `fn`, `tt`)
        return `ev`
    )
  result.add(gen.jsCallAndRet)

proc newJSProc(gen: var JSFuncGenerator, params: openArray[NimNode],
    isva = true): NimNode =
  let jsBody = gen.newJSProcBody(isva)
  let jsPragmas = newNimNode(nnkPragma).add(ident("cdecl"))
  return newProc(gen.newName, params, jsBody, pragmas = jsPragmas)

func getFuncName(fun: NimNode, jsname, staticName: string): string =
  if jsname != "":
    return jsname
  if staticName != "":
    let name = staticName.after(':')
    if name != "":
      return name
  let x = $fun[0]
  if x == "$":
    # stringifier
    return "toString"
  return x

func getErrVal(t: BoundFunctionType): NimNode =
  if t in {PROPERTY_GET, PROPERTY_SET, PROPERTY_DEL, PROPERTY_HAS,
      PROPERTY_NAMES}:
    return quote do: cint(-1)
  return quote do: JS_EXCEPTION

proc addJSContext(gen: var JSFuncGenerator) =
  if gen.funcParams.len > gen.i:
    if gen.funcParams[gen.i].t.eqIdent(ident("JSContext")):
      gen.passCtx = true
      gen.jsFunCall.add(ident("ctx"))
      inc gen.i
    elif gen.funcParams[gen.i].t.eqIdent(ident("JSRuntime")):
      inc gen.i # special case for finalizers that have a JSRuntime param

proc addThisName(gen: var JSFuncGenerator, thisname: Option[string]) =
  if thisname.isSome:
    gen.thisTypeNode = gen.funcParams[gen.i][1]
    gen.thisType = $gen.funcParams[gen.i][1]
    gen.newName = ident($gen.t & "_" & gen.thisType & "_" & gen.funcName)
  else:
    let rt = gen.returnType.get
    if rt.kind in {nnkRefTy, nnkPtrTy}:
      gen.thisTypeNode = rt[0]
      gen.thisType = rt[0].strVal
    else:
      if rt.kind == nnkBracketExpr:
        gen.thisTypeNode = rt[1]
        gen.thisType = rt[1].strVal
      else:
        gen.thisTypeNode = rt
        gen.thisType = rt.strVal
    gen.newName = ident($gen.t & "_" & gen.funcName)

func getActualMinArgs(gen: var JSFuncGenerator): int =
  var ma = gen.minArgs
  if gen.thisname.isSome and not gen.isstatic:
    dec ma
  if gen.passCtx:
    dec ma
  assert ma >= 0
  return ma

proc initGenerator(fun: NimNode, t: BoundFunctionType,
    thisname = some("this"), jsname: string = "", unforgeable = false,
    staticName = ""): JSFuncGenerator =
  let jsFunCallList = newStmtList()
  let funcParams = getParams(fun)
  var gen = JSFuncGenerator(
    t: t,
    funcName: getFuncName(fun, jsname, staticName),
    generics: getGenerics(fun),
    funcParams: funcParams,
    returnType: getReturn(fun),
    minArgs: funcParams.getMinArgs(),
    thisname: thisname,
    errval: getErrVal(t),
    dielabel: ident("ondie"),
    jsFunCallList: jsFunCallList,
    jsFunCallLists: @[jsFunCallList],
    jsFunCall: newCall(fun[0]),
    unforgeable: unforgeable,
    isstatic: staticName != ""
  )
  gen.addJSContext()
  gen.actualMinArgs = gen.getActualMinArgs() # must come after passctx is set
  if staticName == "":
    gen.addThisName(thisname)
  else:
    gen.thisType = staticName.until(':')
    gen.newName = ident($gen.t & "_" & gen.funcName)
  return gen

proc makeJSCallAndRet(gen: var JSFuncGenerator, okstmt, errstmt: NimNode) =
  let jfcl = gen.jsFunCallList
  let dl = gen.dielabel
  gen.jsCallAndRet = if gen.returnType.isSome:
    quote do:
      block `dl`:
        return ctx.toJS(`jfcl`)
      `errstmt`
  else:
    quote do:
      block `dl`:
        `jfcl`
        `okstmt`
      `errstmt`

proc makeCtorJSCallAndRet(gen: var JSFuncGenerator, errstmt: NimNode) =
  let jfcl = gen.jsFunCallList
  let dl = gen.dielabel
  gen.jsCallAndRet = quote do:
    block `dl`:
      return ctx.toJSNew(`jfcl`, this)
    `errstmt`

macro jsctor*(fun: typed) =
  var gen = initGenerator(fun, CONSTRUCTOR, thisname = none(string))
  if gen.newName.strVal in existingFuncs:
    #TODO TODO TODO implement function overloading
    error("Function overloading hasn't been implemented yet...")
  gen.addRequiredParams()
  gen.addOptionalParams()
  gen.finishFunCallList()
  let errstmt = quote do:
    return JS_ThrowTypeError(ctx, "Invalid parameters passed to constructor")
  gen.makeCtorJSCallAndRet(errstmt)
  let jsProc = gen.newJSProc(getJSParams())
  gen.registerConstructor(jsProc)
  return newStmtList(fun)

macro jshasprop*(fun: typed) =
  var gen = initGenerator(fun, PROPERTY_HAS, thisname = some("obj"))
  if gen.newName.strVal in existingFuncs:
    #TODO TODO TODO ditto
    error("Function overloading hasn't been implemented yet...")
  gen.addFixParam("obj")
  gen.addFixParam("atom")
  gen.finishFunCallList()
  let jfcl = gen.jsFunCallList
  let dl = gen.dielabel
  gen.jsCallAndRet = quote do:
    block `dl`:
      let retv = `jfcl`
      return cint(retv)
    doAssert false # TODO?
  let jsProc = gen.newJSProc(getJSHasPropParams(), false)
  gen.registerFunction()
  return newStmtList(fun, jsProc)

macro jsgetprop*(fun: typed) =
  var gen = initGenerator(fun, PROPERTY_GET, thisname = some("obj"))
  if gen.newName.strVal in existingFuncs:
    #TODO TODO TODO ditto
    error("Function overloading hasn't been implemented yet...")
  gen.addFixParam("obj")
  gen.addFixParam("prop")
  gen.finishFunCallList()
  let jfcl = gen.jsFunCallList
  let dl = gen.dielabel
  gen.jsCallAndRet = quote do:
    block `dl`:
      let retv = ctx.toJS(`jfcl`)
      if retv != JS_NULL:
        if desc != nil:
          # From quickjs.h:
          # > If 1 is returned, the property descriptor 'desc' is filled
          # > if != NULL.
          # So desc may be nil.
          desc[].setter = JS_UNDEFINED
          desc[].getter = JS_UNDEFINED
          desc[].value = retv
          desc[].flags = 0
        return cint(1)
    return cint(0)
  let jsProc = gen.newJSProc(getJSGetPropParams(), false)
  gen.registerFunction()
  return newStmtList(fun, jsProc)

macro jssetprop*(fun: typed) =
  var gen = initGenerator(fun, PROPERTY_SET, thisname = some("obj"))
  if gen.newName.strVal in existingFuncs:
    #TODO TODO TODO ditto
    error("Function overloading hasn't been implemented yet...")
  gen.addFixParam("receiver")
  gen.addFixParam("atom")
  gen.addFixParam("value")
  gen.finishFunCallList()
  let jfcl = gen.jsFunCallList
  let dl = gen.dielabel
  gen.jsCallAndRet = if gen.returnType.isSome:
    quote do:
      block `dl`:
        let v = toJS(ctx, `jfcl`)
        if not JS_IsException(v):
          return cint(1)
      return cint(-1)
  else:
    quote do:
      block `dl`:
        `jfcl`
        return cint(1)
      return cint(-1)
  let jsProc = gen.newJSProc(getJSSetPropParams(), false)
  gen.registerFunction()
  return newStmtList(fun, jsProc)

macro jsdelprop*(fun: typed) =
  var gen = initGenerator(fun, PROPERTY_DEL, thisname = some("obj"))
  if gen.newName.strVal in existingFuncs:
    #TODO TODO TODO ditto
    error("Function overloading hasn't been implemented yet...")
  gen.addFixParam("obj")
  gen.addFixParam("prop")
  gen.finishFunCallList()
  let jfcl = gen.jsFunCallList
  let dl = gen.dielabel
  gen.jsCallAndRet = quote do:
    block `dl`:
      let retv = `jfcl`
      return cint(retv)
    return cint(-1)
  let jsProc = gen.newJSProc(getJSDelPropParams(), false)
  gen.registerFunction()
  return newStmtList(fun, jsProc)

macro jspropnames*(fun: typed) =
  var gen = initGenerator(fun, PROPERTY_NAMES, thisname = some("obj"))
  if gen.newName.strVal in existingFuncs:
    #TODO TODO TODO ditto
    error("Function overloading hasn't been implemented yet...")
  gen.addFixParam("obj")
  gen.finishFunCallList()
  let jfcl = gen.jsFunCallList
  let dl = gen.dielabel
  gen.jsCallAndRet = quote do:
    block `dl`:
      let retv = `jfcl`
      ptab[] = retv.buffer
      plen[] = retv.len
      return cint(0)
    return cint(-1)
  let jsProc = gen.newJSProc(getJSPropNamesParams(), false)
  gen.registerFunction()
  return newStmtList(fun, jsProc)

macro jsfgetn(jsname: static string, uf: static bool, fun: typed) =
  var gen = initGenerator(fun, GETTER, jsname = jsname, unforgeable = uf)
  if gen.actualMinArgs != 0 or gen.funcParams.len != gen.minArgs:
    error("jsfget functions must only accept one parameter.")
  if gen.returnType.isNone:
    error("jsfget functions must have a return type.")
  if gen.newName.strVal in existingFuncs:
    #TODO TODO TODO ditto
    error("Function overloading hasn't been implemented yet...")
  gen.addFixParam("this")
  gen.finishFunCallList()
  gen.makeJSCallAndRet(nil, quote do: discard)
  let jsProc = gen.newJSProc(getJSGetterParams(), false)
  gen.registerFunction()
  return newStmtList(fun, jsProc)

# "Why?" So the compiler doesn't cry.
template jsfget*(fun: typed) =
  jsfgetn("", false, fun)

template jsuffget*(fun: typed) =
  jsfgetn("", true, fun)

template jsfget*(jsname: static string, fun: typed) =
  jsfgetn(jsname, false, fun)

template jsuffget*(jsname: static string, fun: typed) =
  jsfgetn(jsname, true, fun)

# Ideally we could simulate JS setters using nim setters, but nim setters
# won't accept types that don't match their reflected field's type.
macro jsfsetn(jsname: static string, fun: typed) =
  var gen = initGenerator(fun, SETTER, jsname = jsname)
  if gen.actualMinArgs != 1 or gen.funcParams.len != gen.minArgs:
    error("jsfset functions must accept two parameters")
  if gen.returnType.isSome:
    let rt = gen.returnType.get
    #TODO ??
    let rtType = rt[0]
    let errType = getTypeInst(Err)
    if not errType.sameType(rtType) and not rtType.sameType(errType):
      error("jsfset functions must not have a return type")
  gen.addFixParam("this")
  gen.addFixParam("val")
  gen.finishFunCallList()
  # return param anyway
  let okstmt = quote do: discard
  let errstmt = quote do: return JS_DupValue(ctx, val)
  gen.makeJSCallAndRet(okstmt, errstmt)
  let jsProc = gen.newJSProc(getJSSetterParams(), false)
  gen.registerFunction()
  return newStmtList(fun, jsProc)

template jsfset*(fun: typed) =
  jsfsetn("", fun)

template jsfset*(jsname: static string, fun: typed) =
  jsfsetn(jsname, fun)

macro jsfuncn*(jsname: static string, uf: static bool,
    staticName: static string, fun: typed) =
  var gen = initGenerator(fun, FUNCTION, jsname = jsname, unforgeable = uf,
    staticName = staticName)
  if gen.minArgs == 0 and not gen.isstatic:
    error("Zero-parameter functions are not supported. (Maybe pass Window or Client?)")
  if not gen.isstatic:
    gen.addFixParam("this")
  gen.addRequiredParams()
  gen.addOptionalParams()
  gen.finishFunCallList()
  let okstmt = quote do:
    return JS_UNDEFINED
  let errstmt = quote do:
    return JS_ThrowTypeError(ctx, "Invalid parameters passed to function")
  gen.makeJSCallAndRet(okstmt, errstmt)
  let jsProc = gen.newJSProc(getJSParams())
  gen.registerFunction()
  return newStmtList(fun, jsProc)

template jsfunc*(fun: typed) =
  jsfuncn("", false, "", fun)

template jsuffunc*(fun: typed) =
  jsfuncn("", true, "", fun)

template jsfunc*(jsname: static string, fun: typed) =
  jsfuncn(jsname, false, "", fun)

template jsuffunc*(jsname: static string, fun: typed) =
  jsfuncn(jsname, true, "", fun)

template jsstfunc*(name: static string, fun: typed) =
  jsfuncn("", false, name, fun)

macro jsfin*(fun: typed) =
  var gen = initGenerator(fun, FINALIZER, thisname = some("fin"))
  let finName = gen.newName
  let finFun = ident(gen.funcName)
  let t = gen.thisTypeNode
  if gen.minArgs == 1:
    let jsProc = quote do:
      proc `finName`(rt: JSRuntime, val: JSValue) =
        let opaque = JS_GetOpaque(val, JS_GetClassID(val))
        if opaque != nil:
          `finFun`(cast[`t`](opaque))
    gen.registerFunction()
    result = newStmtList(fun, jsProc)
  elif gen.minArgs == 2:
    let jsProc = quote do:
      proc `finName`(rt: JSRuntime, val: JSValue) =
        let opaque = JS_GetOpaque(val, JS_GetClassID(val))
        if opaque != nil:
          `finFun`(rt, cast[`t`](opaque))
    gen.registerFunction()
    result = newStmtList(fun, jsProc)
  else:
    error("Expected one or two parameters")

# Having the same names for these and the macros leads to weird bugs, so the
# macros get an additional f.
template jsget*() {.pragma.}
template jsget*(name: string) {.pragma.}
template jsset*() {.pragma.}
template jsset*(name: string) {.pragma.}
template jsgetset*() {.pragma.}
template jsgetset*(name: string) {.pragma.}
template jsufget*() {.pragma.}
template jsufget*(name: string) {.pragma.}

proc js_illegal_ctor*(ctx: JSContext, this: JSValue, argc: cint,
    argv: ptr UncheckedArray[JSValue]): JSValue {.cdecl.} =
  return JS_ThrowTypeError(ctx, "Illegal constructor")

type
  JSObjectPragma = object
    name: string
    varsym: NimNode
    unforgeable: bool

  JSObjectPragmas = object
    jsget: seq[JSObjectPragma]
    jsset: seq[JSObjectPragma]
    jsinclude: seq[JSObjectPragma]

func getPragmaName(varPragma: NimNode): string =
  if varPragma.kind == nnkExprColonExpr:
    return $varPragma[0]
  return $varPragma

func getStringFromPragma(varPragma: NimNode): Option[string] =
  if varPragma.kind == nnkExprColonExpr:
    if not varPragma.len == 1 and varPragma[1].kind == nnkStrLit:
      error("Expected string as pragma argument")
    return some($varPragma[1])

proc findPragmas(t: NimNode): JSObjectPragmas =
  let typ = t.getTypeInst()[1] # The type, as declared.
  var impl = typ.getTypeImpl() # ref t
  if impl.kind in {nnkRefTy, nnkPtrTy}:
    impl = impl[0].getImpl()
  else:
    impl = typ.getImpl()
  # stolen from std's macros.customPragmaNode
  var identDefsStack = newSeq[NimNode](impl[2].len)
  for i in 0 ..< identDefsStack.len:
    identDefsStack[i] = impl[2][i]
  var pragmas: JSObjectPragmas
  while identDefsStack.len > 0:
    var identDefs = identDefsStack.pop()
    case identDefs.kind
    of nnkRecList:
      for child in identDefs.children:
        identDefsStack.add(child)
    of nnkRecCase:
      # Add condition definition
      identDefsStack.add(identDefs[0])
      # Add branches
      for i in 1 ..< identDefs.len:
        identDefsStack.add(identDefs[i].last)
    else:
      for i in 0 .. identDefs.len - 3:
        let varNode = identDefs[i]
        if varNode.kind == nnkPragmaExpr:
          var varName = varNode[0]
          if varName.kind == nnkPostfix:
            # This is a public field. We are skipping the postfix *
            varName = varName[1]
          var varPragmas = varNode[1]
          for varPragma in varPragmas:
            let pragmaName = getPragmaName(varPragma)
            var op = JSObjectPragma(
              name: getStringFromPragma(varPragma).get($varName),
              varsym: varName
            )
            case pragmaName
            of "jsget": pragmas.jsget.add(op)
            of "jsset": pragmas.jsset.add(op)
            of "jsufget": # LegacyUnforgeable
              op.unforgeable = true
              pragmas.jsget.add(op)
            of "jsgetset":
              pragmas.jsget.add(op)
              pragmas.jsset.add(op)
            of "jsinclude": pragmas.jsinclude.add(op)
  return pragmas

proc nim_finalize_for_js*(obj: pointer) =
  for rt in runtimes:
    let rtOpaque = rt.getOpaque()
    rtOpaque.plist.withValue(obj, v):
      let p = v[]
      let val = JS_MKPTR(JS_TAG_OBJECT, p)
      let classid = JS_GetClassID(val)
      rtOpaque.fins.withValue(classid, fin):
        fin[](rt, val)
      JS_SetOpaque(val, nil)
      rtOpaque.plist.del(obj)
      if rtOpaque.destroying == obj:
        # Allow QJS to collect the JSValue through checkDestroy.
        rtOpaque.destroying = nil
      else:
        JS_FreeValueRT(rt, val)

type
  TabGetSet* = object
    name*: string
    get*: JSGetterMagicFunction
    set*: JSSetterMagicFunction
    magic*: int16

  TabFunc* = object
    name*: string
    fun*: JSCFunction

template jsDestructor*[U](T: typedesc[ref U]) =
  static:
    jsDtors.incl($T)
  {.warning[Deprecated]:off.}:
    proc `=destroy`(obj: var U) =
      nim_finalize_for_js(addr obj)

template jsDestructor*(T: typedesc[object]) =
  static:
    jsDtors.incl($T)
  {.warning[Deprecated]:off.}:
    proc `=destroy`(obj: var T) =
      nim_finalize_for_js(addr obj)

type RegistryInfo = object
  t: NimNode # NimNode of type
  name: string # JS name, if this is the empty string then it equals tname
  tabList: NimNode # array of function table
  ctorImpl: NimNode # definition & body of constructor
  ctorFun: NimNode # constructor ident
  getset: Table[string, (NimNode, NimNode, bool)] # name -> get, set, uf
  propGetFun: NimNode # custom get function ident
  propSetFun: NimNode # custom set function ident
  propDelFun: NimNode # custom del function ident
  propHasFun: NimNode # custom has function ident
  propNamesFun: NimNode # custom property names function ident
  finFun: NimNode # finalizer ident
  finName: NimNode # finalizer wrapper ident
  dfin: NimNode # CheckDestroy finalizer ident
  classDef: NimNode # ClassDef ident
  tabUnforgeable: NimNode # array of unforgeable function table
  tabStatic: NimNode # array of static function table

func tname(info: RegistryInfo): string =
  return info.t.strVal

# Differs from tname if the Nim object's name differs from the JS object's
# name.
func jsname(info: RegistryInfo): string =
  if info.name != "":
    return info.name
  return info.tname

proc newRegistryInfo(t: NimNode, name: string): RegistryInfo =
  let info = RegistryInfo(
    t: t,
    name: name,
    dfin: ident("js_" & t.strVal & "ClassCheckDestroy"),
    classDef: ident("classDef"),
    tabList: newNimNode(nnkBracket),
    tabUnforgeable: newNimNode(nnkBracket),
    tabStatic: newNimNode(nnkBracket),
    finName: newNilLit(),
    finFun: newNilLit(),
    propGetFun: newNilLit(),
    propSetFun: newNilLit(),
    propDelFun: newNilLit(),
    propHasFun: newNilLit(),
    propNamesFun: newNilLit()
  )
  if info.tname notin jsDtors:
    warning("No destructor has been defined for type " & info.tname)
  return info

proc bindConstructor(stmts: NimNode, info: var RegistryInfo): NimNode =
  if info.ctorFun != nil:
    stmts.add(info.ctorImpl)
    return info.ctorFun
  return ident("js_illegal_ctor")

proc registerGetters(stmts: NimNode, info: RegistryInfo,
    jsget: seq[JSObjectPragma]) =
  let t = info.t
  let tname = info.tname
  let jsname = info.jsname
  for op in jsget:
    let node = op.varsym
    let fn = op.name
    let id = ident($GETTER & "_" & tname & "_" & fn)
    stmts.add(quote do:
      proc `id`(ctx: JSContext, this: JSValue): JSValue {.cdecl.} =
        if not ctx.isInstanceOf(this, `tname`):
          return JS_ThrowTypeError(ctx,
            "'%s' called on an object that is not an instance of %s", `fn`,
            `jsname`)
        let arg_0 = fromJSP_or_return(`t`, ctx, this)
        when typeof(arg_0.`node`) is object:
          return toJSP(ctx, arg_0, arg_0.`node`)
        else:
          return toJS(ctx, arg_0.`node`)
    )
    registerFunction(tname, BoundFunction(
      t: GETTER,
      name: fn,
      id: id,
      unforgeable: op.unforgeable
    ))

proc registerSetters(stmts: NimNode, info: RegistryInfo,
    jsset: seq[JSObjectPragma]) =
  let t = info.t
  let tname = info.tname
  let jsname = info.jsname
  for op in jsset:
    let node = op.varsym
    let fn = op.name
    let id = ident($SETTER & "_" & tname & "_" & fn)
    stmts.add(quote do:
      proc `id`(ctx: JSContext, this: JSValue, val: JSValue): JSValue
          {.cdecl.} =
        if not ctx.isInstanceOf(this, `tname`):
          return JS_ThrowTypeError(ctx,
            "'%s' called on an object that is not an instance of %s", `fn`,
            `jsname`)
        let arg_0 = fromJSP_or_return(`t`, ctx, this)
        let arg_1 = val
        # Note: if you get a compiler error that leads back to here, that
        # might be because you added jsset to a non-ref object type.
        arg_0.`node` = fromJS_or_return(typeof(arg_0.`node`), ctx, arg_1)
        return JS_DupValue(ctx, arg_1)
    )
    registerFunction(tname, SETTER, fn, id)

proc bindFunctions(stmts: NimNode, info: var RegistryInfo) =
  BoundFunctions.withValue(info.tname, funs):
    for fun in funs[].mitems:
      var f0 = fun.name
      let f1 = fun.id
      if fun.name.endsWith("_exceptions"):
        fun.name = fun.name.substr(0, fun.name.high - "_exceptions".len)
      case fun.t
      of FUNCTION:
        f0 = fun.name
        if fun.unforgeable:
          info.tabUnforgeable.add(quote do:
            JS_CFUNC_DEF_NOCONF(`f0`, 0, cast[JSCFunction](`f1`)))
        elif fun.isstatic:
          info.tabStatic.add(quote do:
            JS_CFUNC_DEF(`f0`, 0, cast[JSCFunction](`f1`)))
        else:
          info.tabList.add(quote do:
            JS_CFUNC_DEF(`f0`, 0, cast[JSCFunction](`f1`)))
      of CONSTRUCTOR:
        info.ctorImpl = fun.ctorBody
        if info.ctorFun != nil:
          error("Class " & info.tname & " has 2+ constructors.")
        info.ctorFun = f1
      of GETTER:
        info.getset.withValue(f0, exv):
          exv[0] = f1
          exv[2] = fun.unforgeable
        do:
          info.getset[f0] = (f1, newNilLit(), fun.unforgeable)
      of SETTER:
        info.getset.withValue(f0, exv):
          exv[1] = f1
        do:
          info.getset[f0] = (newNilLit(), f1, false)
      of PROPERTY_GET:
        if info.propGetFun.kind != nnkNilLit:
          error("Class " & info.tname & " has 2+ property getters.")
        info.propGetFun = f1
      of PROPERTY_SET:
        if info.propSetFun.kind != nnkNilLit:
          error("Class " & info.tname & " has 2+ property setters.")
        info.propSetFun = f1
      of PROPERTY_DEL:
        if info.propDelFun.kind != nnkNilLit:
          error("Class " & info.tname & " has 2+ property setters.")
        info.propDelFun = f1
      of PROPERTY_HAS:
        if info.propHasFun.kind != nnkNilLit:
          error("Class " & info.tname & " has 2+ hasprop getters.")
        info.propHasFun = f1
      of PROPERTY_NAMES:
        if info.propNamesFun.kind != nnkNilLit:
          error("Class " & info.tname & " has 2+ propnames getters.")
        info.propNamesFun = f1
      of FINALIZER:
        f0 = fun.name
        info.finFun = ident(f0)
        info.finName = f1

proc bindGetSet(stmts: NimNode, info: RegistryInfo) =
  for k, (get, set, unforgeable) in info.getset:
    if not unforgeable:
      info.tabList.add(quote do: JS_CGETSET_DEF(`k`, `get`, `set`))
    else:
      info.tabUnforgeable.add(quote do:
        JS_CGETSET_DEF_NOCONF(`k`, `get`, `set`))

proc bindExtraGetSet(stmts: NimNode, info: var RegistryInfo,
    extra_getset: openArray[TabGetSet]) =
  for x in extra_getset:
    let k = x.name
    let g = x.get
    let s = x.set
    let m = x.magic
    info.tabList.add(quote do: JS_CGETSET_MAGIC_DEF(`k`, `g`, `s`, `m`))

proc bindCheckDestroy(stmts: NimNode, info: RegistryInfo) =
  let t = info.t
  let dfin = info.dfin
  stmts.add(quote do:
    proc `dfin`(rt: JSRuntime, val: JSValue): JS_BOOL {.cdecl.} =
      let opaque = JS_GetOpaque(val, JS_GetClassID(val))
      if opaque != nil:
        when `t` is ref object:
          # Before this function is called, the ownership model is
          # JSObject -> Nim object.
          # Here we change it to Nim object -> JSObject.
          # As a result, Nim object's reference count can now reach zero (it is
          # no longer "referenced" by the JS object).
          # nim_finalize_for_js will be invoked by the Nim GC when the Nim
          # refcount reaches zero. Then, the JS object's opaque will be set
          # to nil, and its refcount decreased again, so next time this
          # function will return true.
          #
          # Actually, we need another hack to ensure correct
          # operation. GC_unref may call the destructor of this object, and
          # in this case we cannot ask QJS to keep the JSValue alive. So we set
          # the "destroying" pointer to the current opaque, and return true if
          # the opaque was collected.
          rt.getOpaque().destroying = opaque
          GC_unref(cast[`t`](opaque))
          if rt.getOpaque().destroying == nil:
            # Looks like GC_unref called nim_finalize_for_js for this pointer.
            # This means we can allow QJS to collect this JSValue.
            return true
          else:
            rt.getOpaque().destroying = nil
            # Returning false from this function signals to the QJS GC that it
            # should not be collected yet. Accordingly, the JSObject's refcount
            # will be set to one again.
            return false
        else:
          # This is not a reference, just a pointer with a reference to the
          # root ancestor object.
          # Remove the reference, allowing destruction of the root object once
          # again.
          let rtOpaque = rt.getOpaque()
          var crefunref: tuple[cref, cunref: (proc())]
          discard rtOpaque.refmap.pop(opaque, crefunref)
          crefunref.cunref()
          # Of course, nim_finalize_for_js might only be called later for
          # this object, because the parent can still have references to it.
          # (And for the same reason, a reference to the same object might
          # still be necessary.)
          # Accordingly, we return false here as well.
          return false
      return true
  )

proc bindEndStmts(endstmts: NimNode, info: RegistryInfo) =
  let jsname = info.jsname
  let dfin = info.dfin
  let classDef = info.classDef
  if info.propGetFun.kind != nnkNilLit or
      info.propSetFun.kind != nnkNilLit or
      info.propDelFun.kind != nnkNilLit or
      info.propHasFun.kind != nnkNilLit or
      info.propNamesFun.kind != nnkNilLit:
    let propGetFun = info.propGetFun
    let propSetFun = info.propSetFun
    let propDelFun = info.propDelFun
    let propHasFun = info.propHasFun
    let propNamesFun = info.propNamesFun
    endstmts.add(quote do:
      var exotic {.global.} = JSClassExoticMethods(
        get_own_property: `propGetFun`,
        get_own_property_names: `propNamesFun`,
        has_property: `propHasFun`,
        set_property: `propSetFun`,
        delete_property: `propDelFun`
      )
      var cd {.global.} = JSClassDef(
        class_name: `jsname`,
        can_destroy: `dfin`,
        exotic: addr exotic
      )
      let `classDef` = JSClassDefConst(addr cd)
    )
  else:
    endstmts.add(quote do:
      var cd {.global.} = JSClassDef(
        class_name: `jsname`,
        can_destroy: `dfin`
      )
      let `classDef` = JSClassDefConst(addr cd))

macro registerType*(ctx: typed, t: typed, parent: JSClassID = 0,
    asglobal = false, nointerface = false, name: static string = "",
    has_extra_getset: static bool = false,
    extra_getset: static openArray[TabGetSet] = [],
    namespace: JSValue = JS_NULL, errid = opt(JSErrorEnum),
    ishtmldda = false): JSClassID =
  var stmts = newStmtList()
  var info = newRegistryInfo(t, name)
  let pragmas = findPragmas(t)
  stmts.registerGetters(info, pragmas.jsget)
  stmts.registerSetters(info, pragmas.jsset)
  stmts.bindFunctions(info)
  stmts.bindGetSet(info)
  if has_extra_getset:
    #HACK: for some reason, extra_getset gets weird contents when nothing is
    # passed to it. So we need an extra flag to signal if anything has
    # been passed to it at all.
    stmts.bindExtraGetSet(info, extra_getset)
  let sctr = stmts.bindConstructor(info)
  stmts.bindCheckDestroy(info)
  let endstmts = newStmtList()
  endstmts.bindEndStmts(info)
  let tabList = info.tabList
  let finName = info.finName
  let classDef = info.classDef
  let tname = info.tname
  let unforgeable = info.tabUnforgeable
  let staticfuns = info.tabStatic
  endstmts.add(quote do:
    `ctx`.newJSClass(`classDef`, `tname`, getTypePtr(`t`), `sctr`, `tabList`,
      `parent`, `asglobal`, `nointerface`, `finName`, `namespace`, `errid`,
      `unforgeable`, `staticfuns`, `ishtmldda`)
  )
  stmts.add(newBlockStmt(endstmts))
  return stmts

proc getMemoryUsage*(rt: JSRuntime): string =
  var m: JSMemoryUsage
  JS_ComputeMemoryUsage(rt, addr m)
  template row(title: string, count, size, sz2, cnt2: int64, name: string):
      string =
    let fv0 = $(float(sz2) / float(cnt2))
    var fv = fv0.until('.')
    if fv.len < fv0.len:
      fv &= '.' & fv0[fv.len + 1]
    else:
      fv &= ".0"
    title & ": " & $count & " " & $size & " (" & fv & ")" & name & "\n"
  template row(title: string, count, size, sz2: int64, name: string):
      string =
    row(title, count, size, sz2, count, name)
  template row(title: string, count, size: int64, name: string): string =
    row(title, count, size, size, name)
  var s = ""
  if m.malloc_count != 0:
    s &= row("memory allocated", m.malloc_count, m.malloc_size, "/block")
    s &= row("memory used", m.memory_used_count, m.memory_used_size,
      m.malloc_size - m.memory_used_size, " average slack")
  if m.atom_count != 0:
    s &= row("atoms", m.atom_count, m.atom_size, "/atom")
  if m.str_count != 0:
    s &= row("strings", m.str_count, m.str_size, "/string")
  if m.obj_count != 0:
    s &= row("objects", m.obj_count, m.obj_size, "/object") &
      row("properties", m.prop_count, m.prop_size, m.prop_size, m.obj_count,
        "/object") &
      row("shapes", m.shape_count, m.shape_size, "/shape")
  if m.js_func_count != 0:
    s &= row("js functions", m.js_func_count, m.js_func_size, "/function")
  if m.c_func_count != 0:
    s &= "native functions: " & $m.c_func_count & "\n"
  if m.array_count != 0:
    s &= "arrays: " & $m.array_count & "\n" &
      "fast arrays: " & $m.fast_array_count & "\n" &
      row("fast array elements", m.fast_array_elements,
        m.fast_array_elements * sizeof(JSValue), m.fast_array_elements,
        m.fast_array_count, "")
  if m.binary_object_count != 0:
    s &= "binary objects: " & $m.binary_object_count & " " &
      $m.binary_object_size
  return s

proc eval*(ctx: JSContext, s: string, file: string, eval_flags: int): JSValue =
  return JS_Eval(ctx, cstring(s), csize_t(s.len), cstring(file),
    cint(eval_flags))

proc compileScript*(ctx: JSContext, s: string, file: cstring): JSValue =
  return JS_Eval(ctx, cstring(s), csize_t(s.len), file,
    cint(JS_EVAL_FLAG_COMPILE_ONLY))

proc compileModule*(ctx: JSContext, s: string, file: cstring): JSValue =
  return JS_Eval(ctx, cstring(s), csize_t(s.len), file,
    cint(JS_EVAL_TYPE_MODULE or JS_EVAL_FLAG_COMPILE_ONLY))

proc evalFunction*(ctx: JSContext, val: JSValue): JSValue =
  return JS_EvalFunction(ctx, val)
