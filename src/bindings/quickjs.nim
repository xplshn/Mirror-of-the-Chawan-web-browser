import bindings/constcharp

const qjsheader = "quickjs/quickjs.h"

{.passc: "-Ilib/".}
{.passl: "-Llib/ -lquickjs -lm -lpthread".}

const                         ##  all tags with a reference count are negative
  JS_TAG_FIRST* = -10           ##  first negative tag
  JS_TAG_BIG_INT* = -10
  JS_TAG_BIG_FLOAT* = -9
  JS_TAG_SYMBOL* = -8
  JS_TAG_STRING* = -7
  JS_TAG_SHAPE* = -6            ##  used internally during GC
  JS_TAG_ASYNC_FUNCTION* = -5   ##  used internally during GC
  JS_TAG_VAR_REF* = -4          ##  used internally during GC
  JS_TAG_MODULE* = -3           ##  used internally
  JS_TAG_FUNCTION_BYTECODE* = -2 ##  used internally
  JS_TAG_OBJECT* = -1
  JS_TAG_INT* = 0
  JS_TAG_BOOL* = 1
  JS_TAG_NULL* = 2
  JS_TAG_UNDEFINED* = 3
  JS_TAG_UNINITIALIZED* = 4
  JS_TAG_CATCH_OFFSET* = 5
  JS_TAG_EXCEPTION* = 6
  JS_TAG_FLOAT64* = 7           ##  any larger tag is FLOAT64 if JS_NAN_BOXING

when sizeof(int) < sizeof(int64):
  {.passc: "-DJS_NAN_BOXING".}
  type
    JSValue* {.importc, header: qjsheader.} = distinct uint64

  template JS_VALUE_GET_TAG*(v: untyped): int32 =
    cast[int32](cast[uint64](v) shr 32)

  template JS_VALUE_GET_PTR*(v: untyped): pointer =
    cast[pointer](v)

  template JS_MKVAL*(t, val: untyped): JSValue =
    JSValue((cast[uint64](int64(t)) shl 32) or uint32(val))

  template JS_MKPTR*(t, p: untyped): JSValue =
    JSValue((cast[uint64](int64(t)) shl 32) or cast[uint](p))

  proc `==`*(a, b: JSValue): bool {.borrow.}
else:
  type
    JSValueUnion* {.importc, header: qjsheader, union.} = object
      int32*: int32
      float64*: float64
      `ptr`*: pointer
    JSValue* {.importc, header: qjsheader.} = object
      u*: JSValueUnion
      tag*: int64

  template JS_VALUE_GET_TAG*(v: untyped): int32 =
    cast[int32](v.tag)

  template JS_VALUE_GET_PTR*(v: untyped): pointer =
    cast[pointer](v.u)

  template JS_MKVAL*(t, val: untyped): JSValue =
    JSValue(u: JSValueUnion(`int32`: val), tag: t)

  template JS_MKPTR*(t, p: untyped): JSValue =
    JSValue(u: JSValueUnion(`ptr`: p), tag: t)

type
  JSRuntimeT {.importc: "JSRuntime", header: qjsheader,
    incompleteStruct.} = object
  JSContextT {.importc: "JSContext", header: qjsheader,
    incompleteStruct.} = object
  JSModuleDefT {.importc: "JSModuleDef", header: qjsheader,
    incompleteStruct.} = object

  JSRuntime* = ptr JSRuntimeT
  JSContext* = ptr JSContextT
  JSModuleDef* = ptr JSModuleDefT
  JSCFunction* = proc(ctx: JSContext, this_val: JSValue, argc: cint,
      argv: ptr UncheckedArray[JSValue]): JSValue {.cdecl.}
  JSCFunctionData* = proc(ctx: JSContext, this_val: JSValue, argc: cint, argv: ptr JSValue, magic: cint, func_data: ptr JSValue): JSValue {.cdecl.}
  JSGetterFunction* = proc(ctx: JSContext, this_val: JSValue): JSValue {.cdecl.}
  JSSetterFunction* = proc(ctx: JSContext, this_val: JSValue, val: JSValue): JSValue {.cdecl.}
  JSGetterMagicFunction* = proc(ctx: JSContext, this_val: JSValue, magic: cint): JSValue {.cdecl.}
  JSSetterMagicFunction* = proc(ctx: JSContext, this_val: JSValue, val: JSValue, magic: cint): JSValue {.cdecl.}
  JSInterruptHandler* = proc(rt: JSRuntime, opaque: pointer): cint {.cdecl.}
  JSClassID* = uint32
  JSAtom* = uint32
  JSClassFinalizer* = proc(rt: JSRuntime, val: JSValue) {.cdecl.}
  JSClassCheckDestroy* = proc(rt: JSRuntime, val: JSValue): JS_BOOL {.cdecl.}
  JSClassGCMark* = proc(rt: JSRuntime, val: JSValue, mark_func: JS_MarkFunc) {.cdecl.}
  JS_MarkFunc* = proc(rt: JSRuntime, gp: ptr JSGCObjectHeader) {.cdecl.}
  JSModuleNormalizeFunc* = proc(ctx: JSContext, module_base_name,
    module_name: cstringConst, opaque: pointer): cstring {.cdecl.}
  JSModuleLoaderFunc* = proc(ctx: JSContext, module_name: cstringConst,
    opaque: pointer): JSModuleDef {.cdecl.}
  JSJobFunc* = proc(ctx: JSContext, argc: cint, argv: ptr JSValue): JSValue {.cdecl.}
  JSGCObjectHeader* {.importc, header: qjsheader.} = object
  JSFreeArrayBufferDataFunc* = proc(rt: JSRuntime,
    opaque, p: pointer) {.cdecl.}

  JSPropertyDescriptor* {.importc, header: qjsheader.} = object
    flags*: cint
    value*: JSValue
    getter*: JSValue
    setter*: JSValue

  JSClassExoticMethods* {.importc, header: qjsheader.} =  object
    get_own_property*: proc(ctx: JSContext, desc: ptr JSPropertyDescriptor,
                             obj: JSValue, prop: JSAtom): cint {.cdecl.}
    get_own_property_names*: proc(ctx: JSContext,
                                   ptab: ptr ptr UncheckedArray[JSPropertyEnum],
                                   plen: ptr uint32, obj: JSValue): cint {.cdecl.}
    delete_property*: proc(ctx: JSContext, obj: JSValue, prop: JSAtom): cint {.cdecl.}
    define_own_property*: proc(ctx: JSContext, this_obj: JSValue,
                                prop: JSAtom, val, getter, setter: JSValue,
                                flags: cint): cint {.cdecl.}
    has_property*: proc(ctx: JSContext, obj: JSValue, atom: JSAtom): cint {.cdecl.}
    get_property*: proc(ctx: JSContext, obj: JSValue, atom: JSAtom,
                         receiver: JSValue, flags: cint): JSValue {.cdecl.}
    set_property*: proc(ctx: JSContext, obj: JSValue, atom: JSAtom,
                         value, receiver: JSValue, flags: cint): cint {.cdecl.}

  JSClassExoticMethodsConst* {.importc: "const JSClassExoticMethods *", header: qjsheader.} = ptr JSClassExoticMethods

  JSClassDef* {.importc, header: qjsheader.} = object
    class_name*: cstring
    finalizer*: JSClassFinalizer
    gc_mark*: JSClassGCMark
    call*: pointer
    exotic*: JSClassExoticMethodsConst
    can_destroy*: JSClassCheckDestroy

  JSClassDefConst* {.importc: "const JSClassDef *", header: qjsheader.} = ptr JSClassDef

  JSMemoryUsage* = object
    malloc_size*, malloc_limit*, memory_used_size*: int64
    malloc_count*: int64
    memory_used_count*: int64
    atom_count*, atom_size*: int64
    str_count*, str_size*: int64
    obj_count*, obj_size*: int64
    prop_count*, prop_size*: int64
    shape_count*, shape_size*: int64
    js_func_count*, js_func_size*, js_func_code_size*: int64
    js_func_pc2line_count*, js_func_pc2line_size*: int64
    c_func_count*, array_count*: int64
    fast_array_count*, fast_array_elements*: int64
    binary_object_count*, binary_object_size*: int64

  JSCFunctionEnum* {.size: sizeof(uint8).} = enum
    JS_CFUNC_generic, JS_CFUNC_generic_magic, JS_CFUNC_constructor,
    JS_CFUNC_constructor_magic, JS_CFUNC_constructor_or_func,
    JS_CFUNC_constructor_or_func_magic, JS_CFUNC_f_f, JS_CFUNC_f_f_f,
    JS_CFUNC_getter, JS_CFUNC_setter, JS_CFUNC_getter_magic,
    JS_CFUNC_setter_magic, JS_CFUNC_iterator_next

  JSCFunctionType* {.importc, union.} = object
    generic*: JSCFunction
    getter*: JSGetterFunction
    setter*: JSSetterFunction
    getter_magic*: JSGetterMagicFunction
    setter_magic*: JSSetterMagicFunction

  JSCFunctionListEntryFunc = object
    length*: uint8
    cproto*: JSCFunctionEnum
    cfunc*: JSCFunctionType

  JSCFunctionListEntryGetSet = object
    get*: JSCFunctionType
    set*: JSCFunctionType

  JSCFunctionListEntryAlias = object
    name: cstring
    base: cint

  JSCFunctionListEntryPropList = object
    tab: ptr JSCFunctionListEntry
    len: cint

  JSCFunctionListEntryU* {.union.} = object
    `func`* {.importc: "func".}: JSCFunctionListEntryFunc
    getset: JSCFunctionListEntryGetSet
    alias: JSCFunctionListEntryAlias
    prop_list: JSCFunctionListEntryPropList
    str: cstring
    i32: int32
    i64: int64
    f64: cdouble

  JSCFunctionListEntry* {.importc.} = object
    name*: cstring
    prop_flags*: uint8
    def_type*: uint8
    magic*: int16
    u* {.importc.}: JSCFunctionListEntryU

  JSRefCountHeader* {.importc.} = object
    ref_count* {.importc.}: cint

  JS_BOOL* = distinct cint

  JSPropertyEnum* {.importc.} = object
    is_enumerable*: JS_BOOL
    atom*: JSAtom

  JSClassEnum* {.size: sizeof(uint32).} = enum
    JS_CLASS_OBJECT = 1
    JS_CLASS_ARRAY
    JS_CLASS_ERROR

  JSMallocState* {.importc.} = object
    malloc_count*: csize_t
    malloc_size*: csize_t
    malloc_limit*: csize_t
    opaque*: pointer

  JSMallocFunctions* {.importc.} = object
    js_malloc*: proc(s: ptr JSMallocState, size: csize_t): pointer {.cdecl.}
    js_free*: proc(s: ptr JSMallocState, p: pointer) {.cdecl.}
    js_realloc*: proc(s: ptr JSMallocState, p: pointer, size: csize_t): pointer
      {.cdecl.}
    js_malloc_usable_size*: proc(p: pointer) {.cdecl.}

converter toBool*(js: JS_BOOL): bool {.inline.} =
  cast[cint](js) != 0

converter toJSBool*(b: bool): JS_BOOL {.inline.} =
  cast[JS_BOOL](cint(b))

converter toJSClassID*(e: JSClassEnum): JSClassID {.inline.} =
  JSClassID(e)

const
  JS_NULL* = JS_MKVAL(JS_TAG_NULL, 0)
  JS_UNDEFINED* = JS_MKVAL(JS_TAG_UNDEFINED, 0)
  JS_FALSE* = JS_MKVAL(JS_TAG_BOOL, 0)
  JS_TRUE* = JS_MKVAL(JS_TAG_BOOL, 1)
  JS_EXCEPTION* = JS_MKVAL(JS_TAG_EXCEPTION, 0)
  JS_UNINITIALIZED* = JS_MKVAL(JS_TAG_UNINITIALIZED, 0)

const
  JS_EVAL_TYPE_GLOBAL* = (0 shl 0) ##  global code (default)
  JS_EVAL_TYPE_MODULE* = (1 shl 0) ##  module code
  JS_EVAL_TYPE_DIRECT* = (2 shl 0) ##  direct call (internal use)
  JS_EVAL_TYPE_INDIRECT* = (3 shl 0) ##  indirect call (internal use)
  JS_EVAL_TYPE_MASK* = (3 shl 0)
  JS_EVAL_FLAG_SHEBANG* = (1 shl 2) ##  skip first line beginning with '#!'
  JS_EVAL_FLAG_STRICT* = (1 shl 3) ##  force 'strict' mode
  JS_EVAL_FLAG_STRIP* = (1 shl 4) ##  force 'strip' mode
  JS_EVAL_FLAG_COMPILE_ONLY* = (1 shl 5) ##  internal use

const
  JS_DEF_CFUNC* = 0
  JS_DEF_CGETSET* = 1
  JS_DEF_CGETSET_MAGIC* = 2
  JS_DEF_PROP_STRING* = 3
  JS_DEF_PROP_INT32* = 4
  JS_DEF_PROP_INT64* = 5
  JS_DEF_PROP_DOUBLE* = 6
  JS_DEF_PROP_UNDEFINED* = 7
  JS_DEF_OBJECT* = 8
  JS_DEF_ALIAS* = 9

const
  JS_PROP_CONFIGURABLE* = (1 shl 0)
  JS_PROP_WRITABLE* = (1 shl 1)
  JS_PROP_ENUMERABLE* = (1 shl 2)
  JS_PROP_C_W_E* = (JS_PROP_CONFIGURABLE or JS_PROP_WRITABLE or JS_PROP_ENUMERABLE)
  JS_PROP_LENGTH* = (1 shl 3) # used internally in Arrays
  JS_PROP_TMASK* = (3 shl 4) # mask for NORMAL, GETSET, VARREF, AUTOINIT
  JS_PROP_NORMAL* = (0 shl 4)
  JS_PROP_GETSET* = (1 shl 4)
  JS_PROP_VARREF* = (2 shl 4) # used internally
  JS_PROP_AUTOINIT* = (3 shl 4) # used internally
  JS_PROP_THROW* = (1 shl 14)

const
  JS_GPN_STRING_MASK* = (1 shl 0)
  JS_GPN_SYMBOL_MASK* = (1 shl 1)
  JS_GPN_PRIVATE_MASK* = (1 shl 2)
  JS_GPN_ENUM_ONLY* = (1 shl 3)
  JS_GPN_SET_ENUM* = (1 shl 4)

const
  JS_PARSE_JSON_EXT* = (1 shl 0)

template JS_CFUNC_DEF*(n: string, len: uint8, func1: JSCFunction):
    JSCFunctionListEntry =
  JSCFunctionListEntry(name: cstring(n),
                       prop_flags: JS_PROP_WRITABLE or JS_PROP_CONFIGURABLE,
                       def_type: JS_DEF_CFUNC,
                       u: JSCFunctionListEntryU(
                         `func`: JSCFunctionListEntryFunc(
                           length: len,
                           cproto: JS_CFUNC_generic,
                           cfunc: JSCFunctionType(generic: func1))))

template JS_CFUNC_DEF_NOCONF*(n: string, len: uint8, func1: JSCFunction):
    JSCFunctionListEntry =
  JSCFunctionListEntry(name: cstring(n),
                       prop_flags: JS_PROP_ENUMERABLE,
                       def_type: JS_DEF_CFUNC,
                       u: JSCFunctionListEntryU(
                         `func`: JSCFunctionListEntryFunc(
                           length: len,
                           cproto: JS_CFUNC_generic,
                           cfunc: JSCFunctionType(generic: func1))))

template JS_CGETSET_DEF*(n: string, fgetter: JSGetterFunction,
    fsetter: JSSetterFunction): JSCFunctionListEntry =
  JSCFunctionListEntry(name: cstring(n),
                       prop_flags: JS_PROP_CONFIGURABLE,
                       def_type: JS_DEF_CGETSET,
                       u: JSCFunctionListEntryU(
                         getset: JSCFunctionListEntryGetSet(
                           get: JSCFunctionType(getter: fgetter),
                           set: JSCFunctionType(setter: fsetter))))

template JS_CGETSET_DEF_NOCONF*(n: string, fgetter: JSGetterFunction,
    fsetter: JSSetterFunction): JSCFunctionListEntry =
  JSCFunctionListEntry(name: cstring(n),
                       prop_flags: JS_PROP_ENUMERABLE,
                       def_type: JS_DEF_CGETSET,
                       u: JSCFunctionListEntryU(
                         getset: JSCFunctionListEntryGetSet(
                           get: JSCFunctionType(getter: fgetter),
                           set: JSCFunctionType(setter: fsetter))))

template JS_CGETSET_MAGIC_DEF*(n: string, fgetter, fsetter: typed,
    m: int16): JSCFunctionListEntry =
  JSCFunctionListEntry(name: cstring(n),
                       prop_flags: JS_PROP_CONFIGURABLE,
                       def_type: JS_DEF_CGETSET_MAGIC,
                       magic: m,
                       u: JSCFunctionListEntryU(
                         getset: JSCFunctionListEntryGetSet(
                           get: JSCFunctionType(getter_magic: fgetter),
                           set: JSCFunctionType(setter_magic: fsetter))))


{.push header: qjsheader, importc, cdecl.}

proc JS_NewRuntime*(): JSRuntime
proc JS_NewRuntime2*(mf: ptr JSMallocFunctions, opaque: pointer): JSRuntime
proc JS_FreeRuntime*(rt: JSRuntime)
proc JS_GetRuntime*(ctx: JSContext): JSRuntime

proc JS_ComputeMemoryUsage*(rt: JSRuntime, s: ptr JSMemoryUsage)
proc JS_RunGC*(rt: JSRuntime)

proc JS_NewContext*(rt: JSRuntime): JSContext
proc JS_NewContextRaw*(rt: JSRuntime): JSContext
proc JS_FreeContext*(ctx: JSContext)

proc JS_GetGlobalObject*(ctx: JSContext): JSValue
proc JS_IsInstanceOf*(ctx: JSContext, val: JSValue, obj: JSValue): cint

proc JS_NewArray*(ctx: JSContext): JSValue
proc JS_NewObject*(ctx: JSContext): JSValue
proc JS_NewObjectClass*(ctx: JSContext, class_id: JSClassID): JSValue
proc JS_NewObjectProto*(ctx: JSContext, proto: JSValue): JSValue
proc JS_NewObjectProtoClass*(ctx: JSContext, proto: JSValue, class_id: JSClassID): JSValue
proc JS_NewPromiseCapability*(ctx: JSContext, resolving_funcs: ptr JSValue): JSValue
proc JS_SetOpaque*(obj: JSValue, opaque: pointer)
proc JS_GetOpaque*(obj: JSValue, class_id: JSClassID): pointer
proc JS_GetOpaque2*(ctx: JSContext, obj: JSValue, class_id: JSClassID): pointer
proc JS_GetClassID*(obj: JSValue): JSClassID

proc JS_ParseJSON*(ctx: JSContext, buf: cstring, buf_len: csize_t, filename: cstring): JSValue
proc JS_ParseJSON2*(ctx: JSContext, buf: cstring, buf_len: csize_t,
  filename: cstring, flags: cint): JSValue

proc JS_NewArrayBuffer*(ctx: JSContext, buf: ptr UncheckedArray[uint8],
  len: csize_t, free_func: JSFreeArrayBufferDataFunc, opaque: pointer,
  is_shared: JS_BOOL): JSValue
proc JS_GetArrayBuffer*(ctx: JSContext, psize: ptr csize_t, obj: JSValue): ptr uint8
proc JS_GetTypedArrayBuffer*(ctx: JSContext, obj: JSValue, pbyte_offset,
  pbyte_length, pbytes_per_element: ptr csize_t): JSValue

proc JS_NewClassID*(pclass_id: ptr JSClassID): JSClassID
proc JS_NewClass*(rt: JSRuntime, class_id: JSClassID, class_def: ptr JSClassDef): cint
proc JS_IsRegisteredClass*(rt: JSRuntime, class_id: JSClassID): cint
proc JS_SetClassProto*(ctx: JSContext, class_id: JSClassID, obj: JSValue)
proc JS_GetClassProto*(ctx: JSContext, class_id: JSClassID): JSValue
proc JS_SetConstructor*(ctx: JSContext, func_obj: JSValue, proto: JSValue)
proc JS_SetPrototype*(ctx: JSContext, obj: JSValue, proto_val: JSValue): cint
proc JS_GetPrototype*(ctx: JSContext, val: JSValue): JSValue

proc JS_NewBool*(ctx: JSContext, val: JS_BOOL): JSValue
proc JS_NewInt32*(ctx: JSContext, val: int32): JSValue
proc JS_NewCatchOffset*(ctx: JSContext, val: int32): JSValue
proc JS_NewInt64*(ctx: JSContext, val: int64): JSValue
proc JS_NewUint32*(ctx: JSContext, val: uint32): JSValue
proc JS_NewBigInt64*(ctx: JSContext, val: int64): JSValue
proc JS_NewBigUInt64*(ctx: JSContext, val: uint64): JSValue
proc JS_NewFloat64*(ctx: JSContext, val: cdouble): JSValue

proc JS_NewAtomLen*(ctx: JSContext, str: cstring, len: csize_t): JSAtom
proc JS_NewAtomUInt32*(ctx: JSContext, u: uint32): JSAtom
proc JS_ValueToAtom*(ctx: JSContext, val: JSValue): JSAtom
proc JS_AtomToValue*(ctx: JSContext, atom: JSAtom): JSValue
proc JS_AtomToCString*(ctx: JSContext, atom: JSAtom): cstring
proc JS_FreeAtom*(ctx: JSContext, atom: JSAtom)
proc JS_FreeAtomRT*(rt: JSRuntime, atom: JSAtom)

proc JS_NewCFunction2*(ctx: JSContext, cfunc: JSCFunction, name: cstring, length: cint, proto: JSCFunctionEnum, magic: cint): JSValue
proc JS_NewCFunctionData*(ctx: JSContext, cfunc: JSCFunctionData, length: cint, magic: cint, data_len: cint, data: ptr JSValue): JSValue
proc JS_NewCFunction*(ctx: JSContext, cfunc: JSCFunction, name: cstring, length: cint): JSValue

proc JS_NewString*(ctx: JSContext, str: cstring): JSValue
proc JS_NewStringLen*(ctx: JSContext, str: cstring, len1: csize_t): JSValue
proc JS_NewAtomString*(ctx: JSContext, str: cstring): JSValue
proc JS_ToString*(ctx: JSContext; val: JSValue): JSValue

proc JS_SetProperty*(ctx: JSContext, this_obj: JSValue, prop: JSAtom, val: JSValue): cint
proc JS_SetPropertyUint32*(ctx: JSContext, this_obj: JSValue, idx: uint32, val: JSValue): cint
proc JS_SetPropertyInt64*(ctx: JSContext, this_obj: JSValue, idx: int64, val: JSValue): cint
proc JS_SetPropertyStr*(ctx: JSContext, this_obj: JSValue, prop: cstring, val: JSValue): cint
proc JS_SetPropertyFunctionList*(ctx: JSContext, obj: JSValue, tab: ptr JSCFunctionListEntry, len: cint)
proc JS_GetProperty*(ctx: JSContext, this_obj: JSValue, prop: JSAtom): JSValue
proc JS_GetPropertyStr*(ctx: JSContext, this_obj: JSValue, prop: cstring): JSValue
proc JS_GetPropertyUint32*(ctx: JSContext, this_obj: JSValue, idx: uint32): JSValue
proc JS_GetOwnPropertyNames*(ctx: JSContext,
    ptab: ptr ptr UncheckedArray[JSPropertyEnum], plen: ptr uint32,
    obj: JSValue, flags: cint): cint

proc JS_GetOwnProperty*(ctx: JSContext, desc: ptr JSPropertyDescriptor,
  obj: JSValue, prop: JSAtom): cint
proc JS_Call*(ctx: JSContext, func_obj, this_obj: JSValue, argc: cint,
  argv: ptr JSValue): JSValue
proc JS_NewObjectFromCtor*(ctx: JSContext, ctor: JSValue,
  class_id: JSClassID): JSValue
proc JS_Invoke*(ctx: JSContext, this_obj: JSValue, atom: JSAtom, argc: cint,
  argv: ptr JSValue): JSValue
proc JS_CallConstructor*(ctx: JSContext, func_obj: JSValue, argc: cint,
  argv: ptr JSValue): JSValue

proc JS_DefineProperty*(ctx: JSContext, this_obj: JSValue, prop: JSAtom, val: JSValue, getter: JSValue, setter: JSValue, flags: cint): cint
proc JS_DefinePropertyValue*(ctx: JSContext, this_obj: JSValue, prop: JSAtom, val: JSValue, flags: cint): cint
proc JS_DefinePropertyValueUint32*(ctx: JSContext, this_obj: JSValue, idx: uint32, val: JSValue, flags: cint): cint
proc JS_DefinePropertyValueInt64*(ctx: JSContext, this_obj: JSValue, idx: int64, val: JSValue, flags: cint): cint
proc JS_DefinePropertyValueStr*(ctx: JSContext, this_obj: JSValue, prop: cstring, val: JSValue, flags: cint): cint
proc JS_DefinePropertyValueGetSet*(ctx: JSContext, this_obj: JSValue, prop: JSAtom, getter: JSValue, setter: JSValue, flags: cint): cint

proc JS_FreeValue*(ctx: JSContext, v: JSValue)
proc JS_FreeValueRT*(rt: JSRuntime, v: JSValue)
proc JS_DupValue*(ctx: JSContext, v: JSValue): JSValue

proc JS_ToBool*(ctx: JSContext, val: JSValue): cint # return -1 for JS_EXCEPTION
proc JS_ToInt32*(ctx: JSContext, pres: ptr int32, val: JSValue): cint
proc JS_ToUint32*(ctx: JSContext, pres: ptr uint32, val: JSValue): cint
proc JS_ToInt64*(ctx: JSContext, pres: ptr int64, val: JSValue): cint
proc JS_ToIndex*(ctx: JSContext, plen: ptr uint64, val: JSValue): cint
proc JS_ToFloat64*(ctx: JSContext, pres: ptr float64, val: JSValue): cint
# return an exception if 'val' is a Number
proc JS_ToBigInt64*(ctx: JSContext, pres: ptr int64, val: JSValue): cint
# same as JS_ToInt64 but allow BigInt
proc JS_ToInt64Ext*(ctx: JSContext, pres: ptr int64, val: JSValue): cint

proc JS_ToCStringLen*(ctx: JSContext, plen: ptr csize_t, val1: JSValue): cstring
proc JS_ToCString*(ctx: JSContext, val1: JSValue): cstring
proc JS_FreeCString*(ctx: JSContext, `ptr`: cstring)

proc JS_NewNarrowStringLen*(ctx: JSContext, s: cstring, len: csize_t): JSValue
proc JS_IsStringWideChar*(str: JSValue): JS_BOOL
proc JS_GetNarrowStringBuffer*(str: JSValue): ptr UncheckedArray[uint8]
proc JS_GetStringLength*(str: JSValue): uint32

proc JS_Eval*(ctx: JSContext, input: cstring, input_len: csize_t,
  filename: cstring, eval_flags: cint): JSValue
proc JS_EvalFunction*(ctx: JSContext, val: JSValue): JSValue
proc JS_SetInterruptHandler*(rt: JSRuntime, cb: JSInterruptHandler, opaque: pointer)
proc JS_SetCanBlock*(rt: JSRuntime, can_block: JS_BOOL)
proc JS_SetIsHTMLDDA*(ctx: JSContext, obj: JSValue)

proc JS_IsNumber*(v: JSValue): JS_BOOL
proc JS_IsBigInt*(v: JSValue): JS_BOOL
proc JS_IsBigFloat*(v: JSValue): JS_BOOL
proc JS_IsBigDecimal*(v: JSValue): JS_BOOL
proc JS_IsBool*(v: JSValue): JS_BOOL
proc JS_IsNull*(v: JSValue): JS_BOOL
proc JS_IsUndefined*(v: JSValue): JS_BOOL
proc JS_IsException*(v: JSValue): JS_BOOL
proc JS_IsUninitialized*(v: JSValue): JS_BOOL
proc JS_IsString*(v: JSValue): JS_BOOL
proc JS_IsSymbol*(v: JSValue): JS_BOOL
proc JS_IsObject*(v: JSValue): JS_BOOL

proc JS_IsFunction*(ctx: JSContext, val: JSValue): JS_BOOL
proc JS_IsArray*(ctx: JSContext, v: JSValue): cint

proc JS_Throw*(ctx: JSContext, obj: JSValue): JSValue
proc JS_GetException*(ctx: JSContext): JSValue
proc JS_IsError*(ctx: JSContext, v: JSValue): JS_BOOL
proc JS_NewError*(ctx: JSContext): JSValue
proc JS_ThrowSyntaxError*(ctx: JSContext, fmt: cstring): JSValue {.varargs, discardable.}
proc JS_ThrowTypeError*(ctx: JSContext, fmt: cstring): JSValue {.varargs, discardable.}
proc JS_ThrowReferenceError*(ctx: JSContext, fmt: cstring): JSValue {.varargs, discardable.}
proc JS_ThrowRangeError*(ctx: JSContext, fmt: cstring): JSValue {.varargs, discardable.}
proc JS_ThrowInternalError*(ctx: JSContext, fmt: cstring): JSValue {.varargs, discardable.}

proc JS_SetModuleLoaderFunc*(rt: JSRuntime,
  module_normalize: JSModuleNormalizeFunc, module_loader: JSModuleLoaderFunc,
  opaque: pointer)
proc JS_GetImportMeta*(ctx: JSContext, m: JSModuleDef): JSValue
proc JS_GetModuleName*(ctx: JSContext, m: JSModuleDef): JSAtom

proc JS_EnqueueJob*(ctx: JSContext, job_func: JSJobFunc, argc: cint, argv: ptr JSValue): cint
proc JS_IsJobPending*(rt: JSRuntime): JS_BOOL
proc JS_ExecutePendingJob*(rt: JSRuntime, pctx: ptr JSContext): cint

proc JS_GetRuntimeOpaque*(rt: JSRuntime): pointer
proc JS_SetRuntimeOpaque*(rt: JSRuntime, p: pointer)

proc JS_SetContextOpaque*(ctx: JSContext, opaque: pointer)
proc JS_GetContextOpaque*(ctx: JSContext): pointer

proc js_malloc*(ctx: JSContext, size: csize_t): pointer
proc js_mallocz*(ctx: JSContext, size: csize_t): pointer
proc js_realloc*(ctx: JSContext, p: pointer, size: csize_t): pointer
proc js_free_rt*(rt: JSRuntime, p: pointer)
proc js_free*(ctx: JSContext, p: pointer)

proc js_strdup*(ctx: JSContext, str: cstring): cstring
{.pop.}
