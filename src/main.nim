import version

# Note: we can't just import std/os or the compiler cries. (No idea why.)
from std/os import getEnv, putEnv, commandLineParams, getCurrentDir, createDir
import std/options

import server/forkserver
import config/chapath
import config/config
import js/javascript
import local/client
import local/term
import utils/strwidth
import utils/twtstr

import chagashi/charset

const ChaVersionStr = block:
  var s = "Chawan browser v0.1 "
  when defined(debug):
    s &= "(debug)"
  else:
    s &= "(release)"
  s &= '\n'
  s

proc help(i: int) =
  let s = ChaVersionStr & """
Usage: cha [options] [URL(s) or file(s)...]
Options:
    --                          Interpret all following arguments as URLs
    -c, --css <stylesheet>      Pass stylesheet (e.g. -c 'a{color: blue}')
    -d, --dump                  Print page to stdout
    -h, --help                  Print this usage message
    -o, --opt <config>          Pass config options (e.g. -o 'page.q="quit()"')
    -r, --run <script/file>     Run passed script or file
    -v, --version               Print version information
    -C, --config <file>         Override config path
    -I, --input-charset <enc>   Specify document charset
    -M, --monochrome            Set color-mode to 'monochrome'
    -O, --display-charset <enc> Specify display charset
    -T, --type <type>           Specify content mime type
    -V, --visual                Visual startup mode
"""
  if i == 0:
    stdout.write(s)
  else:
    stderr.write(s)
  quit(i)

proc version() =
  stdout.write(ChaVersionStr)
  quit(0)

type ParamParseContext = object
  params: seq[string]
  i: int
  configPath: Option[string]
  contentType: Option[string]
  charset: Charset
  dump: bool
  visual: bool
  opts: seq[string]
  stylesheet: string

proc getnext(ctx: var ParamParseContext): string =
  inc ctx.i
  if ctx.i < ctx.params.len:
    return ctx.params[ctx.i]
  help(1)

proc parseConfig(ctx: var ParamParseContext) =
  ctx.configPath = some(ctx.getnext())

proc parseMonochrome(ctx: var ParamParseContext) =
  ctx.opts.add("display.color-mode = monochrome")

proc parseVisual(ctx: var ParamParseContext) =
  ctx.visual = true

proc parseContentType(ctx: var ParamParseContext) =
  ctx.contentType = some(ctx.getnext())

proc getCharset(ctx: var ParamParseContext): Charset =
  let s = ctx.getnext()
  let charset = getCharset(s)
  if charset == CHARSET_UNKNOWN:
    stderr.write("Unknown charset " & s & "\n")
    quit(1)
  return charset

proc parseInputCharset(ctx: var ParamParseContext) =
  ctx.charset = ctx.getCharset()

proc parseOutputCharset(ctx: var ParamParseContext) =
  ctx.opts.add("encoding.display-charset = '" & $ctx.getCharset() & "'")

proc parseDump(ctx: var ParamParseContext) =
  ctx.dump = true

proc parseCSS(ctx: var ParamParseContext) =
  ctx.stylesheet &= ctx.getnext()

proc parseOpt(ctx: var ParamParseContext) =
  ctx.opts.add(ctx.getnext())

proc parseRun(ctx: var ParamParseContext) =
  let script = dqEscape(ctx.getnext())
  ctx.opts.add("start.startup-script = \"\"\"" & script & "\"\"\"")
  ctx.opts.add("start.headless = true")
  ctx.dump = true

proc main() =
  putEnv("CHA_LIBEXEC_DIR", ChaPath"${%CHA_LIBEXEC_DIR}".unquoteGet())
  let forkserver = newForkServer()
  var ctx = ParamParseContext(params: commandLineParams(), i: 0)
  var escapeAll = false
  var pages: seq[string] = @[]
  while ctx.i < ctx.params.len:
    let param = ctx.params[ctx.i]
    if escapeAll: # after --
      pages.add(param)
      inc ctx.i
      continue
    if param.len == 0:
      inc ctx.i
      continue
    if param[0] == '-':
      if param.len == 1:
        # If param == "-", i.e. it is a single dash, then ignore it.
        # (Some programs use single-dash to read from stdin, but we do that
        # automatically when stdin is not a tty. So ignoring it entirely
        # is probably for the best.)
        inc ctx.i
        continue
      if param[1] != '-':
        for j in 1 ..< param.len:
          const NeedsNextParam = {'C', 'I', 'O', 'T', 'c', 'o', 'r'}
          if j != param.high and param[j] in NeedsNextParam:
            # expecting next parameter, but not the last char...
            help(1)
          case param[j]
          of 'C': ctx.parseConfig()
          of 'I': ctx.parseInputCharset()
          of 'M': ctx.parseMonochrome()
          of 'O': ctx.parseOutputCharset()
          of 'T': ctx.parseContentType()
          of 'V': ctx.parseVisual()
          of 'c': ctx.parseCSS()
          of 'd': ctx.parseDump()
          of 'h': help(0)
          of 'o': ctx.parseOpt()
          of 'r': ctx.parseRun()
          of 'v': version()
          else: help(1)
      else:
        case param
        of "--config": ctx.parseConfig()
        of "--input-charset": ctx.parseInputCharset()
        of "--monochrome": ctx.parseMonochrome()
        of "--output-charset": ctx.parseOutputCharset()
        of "--type": ctx.parseContentType()
        of "--visual": ctx.parseVisual()
        of "--css": ctx.parseCSS()
        of "--dump": ctx.parseDump()
        of "--help": help(0)
        of "--opt": ctx.parseOpt()
        of "--run": ctx.parseRun()
        of "--version": version()
        of "--": escapeAll = true
        else: help(1)
    else:
      pages.add(param)
    inc ctx.i
  let jsrt = newJSRuntime()
  let jsctx = jsrt.newJSContext()
  var warnings = newSeq[string]()
  let (config, res) = readConfig(ctx.configPath, jsctx)
  if not res.success:
    stderr.write(res.errorMsg)
    quit(1)
  warnings.add(res.warnings)
  for opt in ctx.opts:
    let res = config.parseConfig(getCurrentDir(), opt, laxnames = true)
    if not res.success:
      stderr.write(res.errorMsg)
      quit(1)
    warnings.add(res.warnings)
  config.css.stylesheet &= ctx.stylesheet
  block commands:
    let res = config.initCommands()
    if res.isErr:
      stderr.write("Error parsing commands: " & res.error)
      quit(1)
  set_cjk_ambiguous(config.display.double_width_ambiguous)
  if pages.len == 0 and stdin.isatty():
    if ctx.visual:
      pages.add(config.start.visual_home)
    elif (let httpHome = getEnv("HTTP_HOME"); httpHome != ""):
      pages.add(httpHome)
    elif (let wwwHome = getEnv("WWW_HOME"); wwwHome != ""):
      pages.add(wwwHome)
  if pages.len == 0 and not config.start.headless:
    if stdin.isatty():
      help(1)
  # make sure tmpdir actually exists; if we do this later, then forkserver may
  # try to open an empty dir
  createDir(config.external.tmpdir)
  forkserver.loadForkServerConfig(config)
  let client = newClient(config, forkserver, jsctx, warnings)
  try:
    client.launchClient(pages, ctx.contentType, ctx.charset, ctx.dump)
  except CatchableError:
    client.flushConsole()
    raise

main()
