import std/options
import std/os
import std/streams
import std/strutils
import std/tables

import bindings/quickjs
import config/chapath
import config/mailcap
import config/mimetypes
import config/toml
import js/error
import js/fromjs
import js/javascript
import js/propertyenumlist
import js/regex
import js/tojs
import loader/headers
import types/cell
import types/color
import types/cookie
import types/opt
import types/urimethodmap
import types/url
import utils/twtstr

import chagashi/charset

type
  ColorMode* = enum
    cmMonochrome, cmANSI, cmEightBit, cmTrueColor

  FormatMode* = set[FormatFlags]

  ChaPathResolved* = distinct string

  ActionMap = object
    t: Table[string, string]

  SiteConfig* = object
    url*: Option[Regex]
    host*: Option[Regex]
    rewrite_url*: (proc(s: URL): JSResult[URL])
    cookie*: Option[bool]
    third_party_cookie*: seq[Regex]
    share_cookie_jar*: Option[string]
    referer_from*: Option[bool]
    scripting*: Option[bool]
    document_charset*: seq[Charset]
    images*: Option[bool]
    stylesheet*: Option[string]
    proxy*: Option[URL]
    default_headers*: TableRef[string, string]

  OmniRule* = object
    match*: Regex
    substitute_url*: (proc(s: string): JSResult[string])

  StartConfig = object
    visual_home* {.jsgetset.}: string
    startup_script* {.jsgetset.}: string
    headless* {.jsgetset.}: bool
    console_buffer* {.jsgetset.}: bool

  CSSConfig = object
    stylesheet* {.jsgetset.}: string

  SearchConfig = object
    wrap* {.jsgetset.}: bool
    ignore_case* {.jsgetset.}: bool

  EncodingConfig = object
    display_charset* {.jsgetset.}: Option[Charset]
    document_charset* {.jsgetset.}: seq[Charset]

  CommandConfig = object
    jsObj*: JSValue
    init*: seq[tuple[k, cmd: string]] # initial k/v map
    map*: Table[string, JSValue] # qualified name -> function

  ExternalConfig = object
    tmpdir* {.jsgetset.}: ChaPathResolved
    editor* {.jsgetset.}: string
    mailcap*: Mailcap
    mime_types*: MimeTypes
    cgi_dir* {.jsgetset.}: seq[ChaPathResolved]
    urimethodmap*: URIMethodMap
    download_dir* {.jsgetset.}: string
    w3m_cgi_compat* {.jsgetset.}: bool

  InputConfig = object
    vi_numeric_prefix* {.jsgetset.}: bool
    use_mouse* {.jsgetset.}: bool

  NetworkConfig = object
    max_redirect* {.jsgetset.}: int32
    prepend_https* {.jsgetset.}: bool
    prepend_scheme* {.jsgetset.}: string
    proxy* {.jsgetset.}: URL
    default_headers* {.jsgetset.}: Table[string, string]

  DisplayConfig = object
    color_mode* {.jsgetset.}: Option[ColorMode]
    format_mode* {.jsgetset.}: Option[FormatMode]
    no_format_mode* {.jsgetset.}: FormatMode
    emulate_overline* {.jsgetset.}: bool
    alt_screen* {.jsgetset.}: Option[bool]
    highlight_color* {.jsgetset.}: RGBAColor
    highlight_marks* {.jsgetset.}: bool
    double_width_ambiguous* {.jsgetset.}: bool
    minimum_contrast* {.jsgetset.}: int32
    force_clear* {.jsgetset.}: bool
    set_title* {.jsgetset.}: bool
    default_background_color* {.jsgetset.}: Option[RGBColor]
    default_foreground_color* {.jsgetset.}: Option[RGBColor]
    query_da1* {.jsgetset.}: bool
    columns* {.jsgetset.}: int32
    lines* {.jsgetset.}: int32
    pixels_per_column* {.jsgetset.}: int32
    pixels_per_line* {.jsgetset.}: int32
    force_columns* {.jsgetset.}: bool
    force_lines* {.jsgetset.}: bool
    force_pixels_per_column* {.jsgetset.}: bool
    force_pixels_per_line* {.jsgetset.}: bool

  Config* = ref object
    jsctx: JSContext
    configdir {.jsget.}: string
    `include` {.jsget.}: seq[ChaPathResolved]
    start* {.jsget.}: StartConfig
    search* {.jsget.}: SearchConfig
    css* {.jsget.}: CSSConfig
    encoding* {.jsget.}: EncodingConfig
    external* {.jsget.}: ExternalConfig
    network* {.jsget.}: NetworkConfig
    input* {.jsget.}: InputConfig
    display* {.jsget.}: DisplayConfig
    #TODO getset
    siteconf*: seq[SiteConfig]
    omnirule*: seq[OmniRule]
    cmd*: CommandConfig
    page* {.jsget.}: ActionMap
    line* {.jsget.}: ActionMap

  ForkServerConfig* = object
    tmpdir*: string
    ambiguous_double*: bool

jsDestructor(ActionMap)
jsDestructor(StartConfig)
jsDestructor(CSSConfig)
jsDestructor(SearchConfig)
jsDestructor(EncodingConfig)
jsDestructor(ExternalConfig)
jsDestructor(NetworkConfig)
jsDestructor(DisplayConfig)
jsDestructor(Config)

converter toStr*(p: ChaPathResolved): string {.inline.} =
  return string(p)

proc fromJSChaPathResolved(ctx: JSContext; val: JSValue):
    JSResult[ChaPathResolved] =
  return cast[JSResult[ChaPathResolved]](fromJS[string](ctx, val))

proc `[]=`(a: var ActionMap; b, c: string) =
  a.t[b] = c

proc `[]`*(a: ActionMap; b: string): string =
  a.t[b]

proc contains*(a: ActionMap; b: string): bool =
  return b in a.t

proc getOrDefault(a: ActionMap; b: string): string =
  return a.t.getOrDefault(b)

proc hasKeyOrPut(a: var ActionMap; b, c: string): bool =
  return a.t.hasKeyOrPut(b, c)

func getRealKey(key: string): string =
  var realk: string
  var control = 0
  var meta = 0
  var skip = false
  for c in key:
    if c == '\\':
      skip = true
    elif skip:
      realk &= c
      skip = false
    elif c == 'M' and meta == 0:
      inc meta
    elif c == 'C' and control == 0:
      inc control
    elif c == '-' and control == 1:
      inc control
    elif c == '-' and meta == 1:
      inc meta
    elif meta == 1:
      realk &= 'M' & c
      meta = 0
    elif control == 1:
      realk &= 'C' & c
      control = 0
    else:
      if meta == 2:
        realk &= '\e'
        meta = 0
      if control == 2:
        realk &= getControlChar(c)
        control = 0
      else:
        realk &= c
  if control == 1:
    realk &= 'C'
  if meta == 1:
    realk &= 'M'
  if skip:
    realk &= '\\'
  return realk

proc getter(a: ptr ActionMap; s: string): Option[string] {.jsgetprop.} =
  a.t.withValue(s, p):
    return some(p[])
  return none(string)

proc setter(a: ptr ActionMap; k, v: string) {.jssetprop.} =
  let k = getRealKey(k)
  if k == "":
    return
  a[][k] = v
  var teststr = k
  teststr.setLen(teststr.high)
  for i in countdown(k.high, 0):
    if teststr notin a[]:
      a[][teststr] = "client.feedNext()"
    teststr.setLen(i)

proc delete(a: ptr ActionMap; k: string): bool {.jsdelprop.} =
  let k = getRealKey(k)
  let ina = k in a[]
  a[].t.del(k)
  return ina

func names(ctx: JSContext, a: ptr ActionMap): JSPropertyEnumList
    {.jspropnames.} =
  let L = uint32(a[].t.len)
  var list = newJSPropertyEnumList(ctx, L)
  for key in a[].t.keys:
    list.add(key)
  return list

proc bindPagerKey(config: Config; key, action: string) {.jsfunc.} =
  (addr config.page).setter(key, action)

proc bindLineKey(config: Config; key, action: string) {.jsfunc.} =
  (addr config.line).setter(key, action)

proc hasprop(a: ptr ActionMap; s: string): bool {.jshasprop.} =
  return s in a[]

proc openFileExpand(dir, file: string): FileStream =
  if file.len == 0:
    return nil
  if file[0] == '/':
    return newFileStream(file)
  else:
    return newFileStream(dir / file)

proc readUserStylesheet(dir, file: string): string =
  let x = ChaPath(file).unquote()
  if x.isNone:
    raise newException(ValueError, x.error)
  let s = openFileExpand(dir, x.get)
  if s != nil:
    result = s.readAll()
    s.close()

proc getForkServerConfig*(config: Config): ForkServerConfig =
  return ForkServerConfig(
    tmpdir: config.external.tmpdir,
    ambiguous_double: config.display.double_width_ambiguous
  )

type ConfigParser = object
  config: Config
  dir: string
  warnings: seq[string]

proc parseConfigValue(ctx: var ConfigParser; x: var object; v: TomlValue;
  k: string)
proc parseConfigValue(ctx: var ConfigParser; x: var bool; v: TomlValue;
  k: string)
proc parseConfigValue(ctx: var ConfigParser; x: var string; v: TomlValue;
  k: string)
proc parseConfigValue(ctx: var ConfigParser; x: var ChaPath; v: TomlValue;
  k: string)
proc parseConfigValue[T](ctx: var ConfigParser; x: var seq[T]; v: TomlValue;
  k: string)
proc parseConfigValue(ctx: var ConfigParser; x: var Charset; v: TomlValue;
  k: string)
proc parseConfigValue(ctx: var ConfigParser; x: var int32; v: TomlValue;
  k: string)
proc parseConfigValue(ctx: var ConfigParser; x: var int64; v: TomlValue;
  k: string)
proc parseConfigValue(ctx: var ConfigParser; x: var Option[ColorMode];
  v: TomlValue; k: string)
proc parseConfigValue(ctx: var ConfigParser; x: var Option[FormatMode];
  v: TomlValue; k: string)
proc parseConfigValue(ctx: var ConfigParser; x: var FormatMode; v: TomlValue;
  k: string)
proc parseConfigValue(ctx: var ConfigParser; x: var RGBAColor; v: TomlValue;
  k: string)
proc parseConfigValue(ctx: var ConfigParser; x: var RGBColor; v: TomlValue;
  k: string)
proc parseConfigValue(ctx: var ConfigParser; x: var ActionMap; v: TomlValue;
  k: string)
proc parseConfigValue(ctx: var ConfigParser; x: var CSSConfig; v: TomlValue;
  k: string)
proc parseConfigValue[U; V](ctx: var ConfigParser; x: var Table[U, V];
  v: TomlValue; k: string)
proc parseConfigValue[U; V](ctx: var ConfigParser; x: var TableRef[U, V];
  v: TomlValue; k: string)
proc parseConfigValue[T](ctx: var ConfigParser; x: var set[T]; v: TomlValue;
  k: string)
proc parseConfigValue(ctx: var ConfigParser; x: var TomlTable; v: TomlValue;
  k: string)
proc parseConfigValue(ctx: var ConfigParser; x: var Regex; v: TomlValue;
  k: string)
proc parseConfigValue(ctx: var ConfigParser; x: var URL; v: TomlValue;
  k: string)
proc parseConfigValue[T](ctx: var ConfigParser; x: var proc(x: T): JSResult[T];
  v: TomlValue; k: string)
proc parseConfigValue(ctx: var ConfigParser; x: var ChaPathResolved;
  v: TomlValue; k: string)
proc parseConfigValue(ctx: var ConfigParser; x: var MimeTypes; v: TomlValue;
  k: string)
proc parseConfigValue(ctx: var ConfigParser; x: var Mailcap; v: TomlValue;
  k: string)
proc parseConfigValue(ctx: var ConfigParser; x: var URIMethodMap; v: TomlValue;
  k: string)
proc parseConfigValue(ctx: var ConfigParser; x: var CommandConfig; v: TomlValue;
  k: string)

proc typeCheck(v: TomlValue; t: TomlValueType; k: string) =
  if v.t != t:
    raise newException(ValueError, "invalid type for key " & k &
      " (got " & $v.t & ", expected " & $t & ")")

proc typeCheck(v: TomlValue; t: set[TomlValueType]; k: string) =
  if v.t notin t:
    raise newException(ValueError, "invalid type for key " & k &
      " (got " & $v.t & ", expected " & $t & ")")

proc parseConfigValue(ctx: var ConfigParser; x: var object; v: TomlValue;
    k: string) =
  typeCheck(v, tvtTable, k)
  for fk, fv in x.fieldPairs:
    when typeof(fv) isnot JSContext:
      let kebabk = snakeToKebabCase(fk)
      if kebabk in v:
        let kkk = if k != "":
          k & "." & fk
        else:
          fk
        ctx.parseConfigValue(fv, v[kebabk], kkk)

proc parseConfigValue[U, V](ctx: var ConfigParser; x: var Table[U, V];
    v: TomlValue; k: string) =
  typeCheck(v, tvtTable, k)
  x.clear()
  for kk, vv in v:
    var y: V
    let kkk = k & "[" & kk & "]"
    ctx.parseConfigValue(y, vv, kkk)
    x[kk] = y

proc parseConfigValue[U, V](ctx: var ConfigParser; x: var TableRef[U, V];
    v: TomlValue; k: string) =
  typeCheck(v, tvtTable, k)
  x = TableRef[U, V]()
  for kk, vv in v:
    var y: V
    let kkk = k & "[" & kk & "]"
    ctx.parseConfigValue(y, vv, kkk)
    x[kk] = y

proc parseConfigValue(ctx: var ConfigParser; x: var bool; v: TomlValue;
    k: string) =
  typeCheck(v, tvtBoolean, k)
  x = v.b

proc parseConfigValue(ctx: var ConfigParser; x: var string; v: TomlValue;
    k: string) =
  typeCheck(v, tvtString, k)
  x = v.s

proc parseConfigValue(ctx: var ConfigParser; x: var ChaPath;
    v: TomlValue; k: string) =
  typeCheck(v, tvtString, k)
  x = ChaPath(v.s)

proc parseConfigValue[T](ctx: var ConfigParser; x: var seq[T]; v: TomlValue;
    k: string) =
  typeCheck(v, {tvtString, tvtArray}, k)
  if v.t != tvtArray:
    var y: T
    ctx.parseConfigValue(y, v, k)
    x = @[y]
  else:
    if not v.ad:
      x.setLen(0)
    for i in 0 ..< v.a.len:
      var y: T
      ctx.parseConfigValue(y, v.a[i], k & "[" & $i & "]")
      x.add(y)

proc parseConfigValue(ctx: var ConfigParser; x: var TomlTable; v: TomlValue;
    k: string) =
  typeCheck(v, {tvtTable}, k)
  x = v.tab

proc parseConfigValue(ctx: var ConfigParser; x: var Charset; v: TomlValue;
    k: string) =
  typeCheck(v, tvtString, k)
  x = getCharset(v.s)
  if x == CHARSET_UNKNOWN:
    raise newException(ValueError, "unknown charset '" & v.s & "' for key " &
      k)

proc parseConfigValue(ctx: var ConfigParser; x: var int32; v: TomlValue;
    k: string) =
  typeCheck(v, tvtInteger, k)
  x = int32(v.i)

proc parseConfigValue(ctx: var ConfigParser; x: var int64; v: TomlValue;
    k: string) =
  typeCheck(v, tvtInteger, k)
  x = v.i

proc parseConfigValue(ctx: var ConfigParser; x: var Option[ColorMode];
    v: TomlValue; k: string) =
  typeCheck(v, tvtString, k)
  case v.s
  of "auto": x = none(ColorMode)
  of "monochrome": x = some(cmMonochrome)
  of "ansi": x = some(cmANSI)
  of "8bit", "eight-bit": x = some(cmEightBit)
  of "24bit", "true-color": x = some(cmTrueColor)
  else:
    raise newException(ValueError, "unknown color mode '" & v.s &
      "' for key " & k)

proc parseConfigValue(ctx: var ConfigParser; x: var Option[FormatMode];
    v: TomlValue; k: string) =
  typeCheck(v, {tvtString, tvtArray}, k)
  if v.t == tvtString and v.s == "auto":
    x = none(FormatMode)
  else:
    var y: FormatMode
    ctx.parseConfigValue(y, v, k)
    x = some(y)

proc parseConfigValue(ctx: var ConfigParser; x: var FormatMode; v: TomlValue;
    k: string) =
  typeCheck(v, tvtArray, k)
  for i in 0 ..< v.a.len:
    let kk = k & "[" & $i & "]"
    let vv = v.a[i]
    typeCheck(vv, tvtString, kk)
    case vv.s
    of "bold": x.incl(ffBold)
    of "italic": x.incl(ffItalic)
    of "underline": x.incl(ffUnderline)
    of "reverse": x.incl(ffReverse)
    of "strike": x.incl(ffStrike)
    of "overline": x.incl(ffOverline)
    of "blink": x.incl(ffBlink)
    else:
      raise newException(ValueError, "unknown format mode '" & vv.s &
        "' for key " & kk)

proc parseConfigValue(ctx: var ConfigParser; x: var RGBAColor; v: TomlValue;
    k: string) =
  typeCheck(v, tvtString, k)
  let c = parseRGBAColor(v.s)
  if c.isNone:
    raise newException(ValueError, "invalid color '" & v.s &
      "' for key " & k)
  x = c.get

proc parseConfigValue(ctx: var ConfigParser; x: var RGBColor; v: TomlValue;
    k: string) =
  typeCheck(v, tvtString, k)
  let c = parseLegacyColor(v.s)
  if c.isNone:
    raise newException(ValueError, "invalid color '" & v.s &
      "' for key " & k)
  x = c.get

proc parseConfigValue[T](ctx: var ConfigParser; x: var Option[T]; v: TomlValue;
    k: string) =
  if v.t == tvtString and v.s == "auto":
    x = none(T)
  else:
    var y: T
    ctx.parseConfigValue(y, v, k)
    x = some(y)

proc parseConfigValue(ctx: var ConfigParser; x: var ActionMap; v: TomlValue;
    k: string) =
  typeCheck(v, tvtTable, k)
  for kk, vv in v:
    typeCheck(vv, tvtString, k & "[" & kk & "]")
    let rk = getRealKey(kk)
    var buf: string
    for i in 0 ..< rk.high:
      buf &= rk[i]
      discard x.hasKeyOrPut(buf, "client.feedNext()")
    x[rk] = vv.s

proc parseConfigValue[T: enum](ctx: var ConfigParser; x: var T; v: TomlValue;
    k: string) =
  typeCheck(v, tvtString, k)
  let e = strictParseEnum[T](v.s)
  if e.isNone:
    raise newException(ValueError, "invalid value '" & v.s & "' for key " & k)
  x = e.get

proc parseConfigValue[T](ctx: var ConfigParser; x: var set[T]; v: TomlValue;
    k: string) =
  typeCheck(v, {tvtString, tvtArray}, k)
  if v.t == tvtString:
    var xx: T
    xx.parseConfigValue(v, k)
    x = {xx}
  else:
    x = {}
    for i in 0 ..< v.a.len:
      let kk = k & "[" & $i & "]"
      var xx: T
      xx.parseConfigValue(v.a[i], kk)
      x.incl(xx)

proc parseConfigValue(ctx: var ConfigParser; x: var CSSConfig; v: TomlValue;
    k: string) =
  typeCheck(v, tvtTable, k)
  for kk, vv in v:
    let kkk = if k != "":
      k & "." & kk
    else:
      kk
    case kk
    of "include":
      typeCheck(vv, {tvtString, tvtArray}, kkk)
      case vv.t
      of tvtString:
        x.stylesheet &= readUserStylesheet(ctx.dir, vv.s)
      of tvtArray:
        for child in vv.a:
          x.stylesheet &= readUserStylesheet(ctx.dir, vv.s)
      else: discard
    of "inline":
      typeCheck(vv, tvtString, kkk)
      x.stylesheet &= vv.s

proc parseConfigValue(ctx: var ConfigParser; x: var Regex; v: TomlValue;
    k: string) =
  typeCheck(v, tvtString, k)
  let y = compileMatchRegex(v.s)
  if y.isNone:
    raise newException(ValueError, "invalid regex " & k & " : " & y.error)
  x = y.get

proc parseConfigValue(ctx: var ConfigParser; x: var URL; v: TomlValue;
    k: string) =
  typeCheck(v, tvtString, k)
  let y = parseURL(v.s)
  if y.isNone:
    raise newException(ValueError, "invalid URL " & k)
  x = y.get

proc parseConfigValue[T](ctx: var ConfigParser; x: var proc(x: T): JSResult[T];
    v: TomlValue; k: string) =
  typeCheck(v, tvtString, k)
  let fun = ctx.config.jsctx.eval(v.s, "<config>", JS_EVAL_TYPE_GLOBAL)
  x = getJSFunction[T, T](ctx.config.jsctx, fun)

proc parseConfigValue(ctx: var ConfigParser; x: var ChaPathResolved;
    v: TomlValue; k: string) =
  typeCheck(v, tvtString, k)
  let y = ChaPath(v.s).unquote()
  if y.isErr:
    raise newException(ValueError, y.error)
  x = ChaPathResolved(y.get)

proc parseConfigValue(ctx: var ConfigParser; x: var MimeTypes; v: TomlValue;
    k: string) =
  var paths: seq[ChaPathResolved]
  ctx.parseConfigValue(paths, v, k)
  x = default(MimeTypes)
  for p in paths:
    let f = openFileExpand(ctx.config.configdir, p)
    if f != nil:
      x.parseMimeTypes(f)

const DefaultMailcap = block:
  let ss = newStringStream(staticRead"res/mailcap")
  parseMailcap(ss).get

proc parseConfigValue(ctx: var ConfigParser; x: var Mailcap; v: TomlValue;
    k: string) =
  var paths: seq[ChaPathResolved]
  ctx.parseConfigValue(paths, v, k)
  x = default(Mailcap)
  for p in paths:
    let f = openFileExpand(ctx.config.configdir, p)
    if f != nil:
      let res = parseMailcap(f)
      if res.isSome:
        x.add(res.get)
      else:
        ctx.warnings.add("Error reading mailcap: " & res.error)
  x.add(DefaultMailcap)

const DefaultURIMethodMap = parseURIMethodMap(staticRead"res/urimethodmap")

proc parseConfigValue(ctx: var ConfigParser; x: var URIMethodMap; v: TomlValue;
    k: string) =
  var paths: seq[ChaPathResolved]
  ctx.parseConfigValue(paths, v, k)
  x = default(URIMethodMap)
  for p in paths:
    let f = openFileExpand(ctx.config.configdir, p)
    if f != nil:
      x.parseURIMethodMap(f.readAll())
  x.append(DefaultURIMethodMap)

func isCompatibleIdent(s: string): bool =
  if s.len == 0 or s[0] notin AsciiAlpha + {'_', '$'}:
    return false
  for i in 1 ..< s.len:
    if s[i] notin AsciiAlphaNumeric + {'_', '$'}:
      return false
  return true

proc parseConfigValue(ctx: var ConfigParser; x: var CommandConfig; v: TomlValue;
    k: string) =
  typeCheck(v, tvtTable, k)
  for kk, vv in v:
    let kkk = k & "." & kk
    typeCheck(vv, {tvtTable, tvtString}, kkk)
    if not kk.isCompatibleIdent():
      raise newException(ValueError, "invalid command name: " & kkk)
    if vv.t == tvtTable:
      ctx.parseConfigValue(x, vv, kkk)
    else: # tvtString
      # skip initial "cmd.", we don't need it
      x.init.add((kkk.substr("cmd.".len), vv.s))

type ParseConfigResult* = object
  success*: bool
  warnings*: seq[string]
  errorMsg*: string

proc parseConfig(config: Config; dir: string; stream: Stream; name = "<input>";
  laxnames = false): ParseConfigResult

proc parseConfig(config: Config; dir: string; t: TomlValue): ParseConfigResult =
  var ctx = ConfigParser(config: config, dir: dir)
  config.configdir = dir
  try:
    var myRes = ParseConfigResult(success: true)
    ctx.parseConfigValue(config[], t, "")
    #TODO: for omnirule/siteconf, check if substitution rules are specified?
    while config.`include`.len > 0:
      #TODO: warn about recursive includes
      var includes = config.`include`
      config.`include`.setLen(0)
      for s in includes:
        let res = config.parseConfig(dir, openFileExpand(dir, s))
        if not res.success:
          return res
        myRes.warnings.add(res.warnings)
    myRes.warnings.add(ctx.warnings)
    return myRes
  except ValueError as e:
    return ParseConfigResult(
      success: false,
      warnings: ctx.warnings,
      errorMsg: e.msg
    )

proc parseConfig(config: Config; dir: string; stream: Stream; name = "<input>";
    laxnames = false): ParseConfigResult =
  let toml = parseToml(stream, dir / name, laxnames)
  if toml.isOk:
    return config.parseConfig(dir, toml.get)
  else:
    return ParseConfigResult(
      success: false,
      errorMsg: "Fatal error: failed to parse config\n" & toml.error & '\n'
    )

proc parseConfig*(config: Config; dir, s: string; name = "<input>";
    laxnames = false): ParseConfigResult =
  return config.parseConfig(dir, newStringStream(s), name, laxnames)

const defaultConfig = staticRead"res/config.toml"

proc readConfig(config: Config; dir, name: string): ParseConfigResult =
  let fs = if name.len > 0 and name[0] == '/':
    newFileStream(name)
  else:
    newFileStream(dir / name)
  if fs != nil:
    return config.parseConfig(dir, fs)
  return ParseConfigResult(success: true)

proc loadConfig*(config: Config; s: string) {.jsfunc.} =
  let s = if s.len > 0 and s[0] == '/':
    s
  else:
    getCurrentDir() / s
  if not fileExists(s):
    return
  discard config.parseConfig(parentDir(s), newFileStream(s))

proc getNormalAction*(config: Config; s: string): string =
  return config.page.getOrDefault(s)

proc getLinedAction*(config: Config; s: string): string =
  return config.line.getOrDefault(s)

type ReadConfigResult = tuple
  config: Config
  res: ParseConfigResult

proc readConfig*(pathOverride: Option[string]; jsctx: JSContext):
    ReadConfigResult =
  let config = Config(jsctx: jsctx)
  var res = config.parseConfig("res", newStringStream(defaultConfig))
  if not res.success:
    return (nil, res)
  if pathOverride.isNone:
    when defined(debug):
      res = config.readConfig(getCurrentDir() / "res", "config.toml")
      if not res.success:
        return (nil, res)
    res = config.readConfig(getConfigDir() / "chawan", "config.toml")
  else:
    res = config.readConfig(getCurrentDir(), pathOverride.get)
  if not res.success:
    return (nil, res)
  return (config, res)

# called after parseConfig returns
proc initCommands*(config: Config): Err[string] =
  let ctx = config.jsctx
  let obj = JS_NewObject(ctx)
  defer: JS_FreeValue(ctx, obj)
  if JS_IsException(obj):
    return err(ctx.getExceptionStr())
  for i in countdown(config.cmd.init.high, 0):
    let (k, cmd) = config.cmd.init[i]
    if k in config.cmd.map:
      # already in map; skip
      continue
    var objIt = obj
    let name = k.afterLast('.')
    if name.len < k.len:
      for ss in k.substr(0, k.high - name.len - 1).split('.'):
        var prop = JS_GetPropertyStr(ctx, objIt, cstring(ss))
        if JS_IsUndefined(prop):
          prop = JS_NewObject(ctx)
          ctx.definePropertyE(objIt, ss, prop)
        if JS_IsException(prop):
          return err(ctx.getExceptionStr())
        objIt = prop
    if cmd == "":
      config.cmd.map[k] = JS_UNDEFINED
      continue
    let fun = ctx.eval(cmd, "<" & k & ">", JS_EVAL_TYPE_GLOBAL)
    if JS_IsException(fun):
      return err(ctx.getExceptionStr())
    if not JS_IsFunction(ctx, fun):
      return err(k & " is not a function")
    ctx.definePropertyE(objIt, name, JS_DupValue(ctx, fun))
    config.cmd.map[k] = fun
  config.cmd.jsObj = JS_DupValue(ctx, obj)
  config.cmd.init = @[]
  ok()

proc addConfigModule*(ctx: JSContext) =
  ctx.registerType(ActionMap)
  ctx.registerType(StartConfig)
  ctx.registerType(CSSConfig)
  ctx.registerType(SearchConfig)
  ctx.registerType(EncodingConfig)
  ctx.registerType(ExternalConfig)
  ctx.registerType(NetworkConfig)
  ctx.registerType(DisplayConfig)
  ctx.registerType(Config)
