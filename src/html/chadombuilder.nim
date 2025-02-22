import std/deques
import std/options

import html/catom
import html/dom
import html/enums
import js/error
import js/fromjs
import js/javascript
import types/url

import chagashi/charset

import chame/htmlparser
import chame/tags

export htmlparser.ParseResult

# DOMBuilder implementation for Chawan.

type CharsetConfidence* = enum
  ccTentative, ccCertain, ccIrrelevant

type
  HTML5ParserWrapper* = ref object
    parser: HTML5Parser[Node, CAtom]
    builder*: ChaDOMBuilder
    opts: HTML5ParserOpts[Node, CAtom]
    # hack so we don't have to worry about leaks or the GC deallocating parser
    refs: seq[Document]
    stoppedFromScript: bool

  ChaDOMBuilder = ref object of DOMBuilder[Node, CAtom]
    charset*: Charset
    confidence*: CharsetConfidence
    document*: Document
    factory: CAtomFactory
    poppedScript: HTMLScriptElement

type
  DOMBuilderImpl = ChaDOMBuilder
  HandleImpl = Node
  AtomImpl = CAtom

include chame/htmlparseriface

type DOMParser = ref object # JS interface

jsDestructor(DOMParser)

#TODO this is disgusting and should be removed
proc setActiveParser(document: Document, wrapper: HTML5ParserWrapper) =
  document.parser = cast[pointer](wrapper)
  wrapper.refs.add(document)

proc getDocumentImpl(builder: ChaDOMBuilder): Node =
  return builder.document

proc atomToTagTypeImpl(builder: ChaDOMBuilder, atom: CAtom): TagType =
  return builder.factory.toTagType(atom)

proc tagTypeToAtomImpl(builder: ChaDOMBuilder, tagType: TagType): CAtom =
  return builder.factory.toAtom(tagType)

proc strToAtomImpl(builder: ChaDOMBuilder, s: string): CAtom =
  return builder.factory.toAtom(s)

proc finish(builder: ChaDOMBuilder) =
  while builder.document.scriptsToExecOnLoad.len > 0:
    #TODO spin event loop
    let script = builder.document.scriptsToExecOnLoad.popFirst()
    script.execute()
  #TODO events

proc restart*(wrapper: HTML5ParserWrapper, charset: Charset) =
  let builder = wrapper.builder
  let document = newDocument(builder.factory)
  document.setActiveParser(wrapper)
  wrapper.refs.add(document)
  document.contentType = "text/html"
  let oldDocument = builder.document
  document.url = oldDocument.url
  let window = oldDocument.window
  if window != nil:
    document.window = window
    window.document = document
  builder.document = document
  builder.charset = charset
  assert document.factory != nil
  wrapper.parser = initHTML5Parser(builder, wrapper.opts)

proc setQuirksModeImpl(builder: ChaDOMBuilder, quirksMode: QuirksMode) =
  if not builder.document.parser_cannot_change_the_mode_flag:
    builder.document.mode = quirksMode

proc setEncodingImpl(builder: ChaDOMBuilder, encoding: string):
    SetEncodingResult =
  if builder.confidence != ccTentative:
    return SET_ENCODING_CONTINUE
  if builder.charset in {CHARSET_UTF_16_LE, CHARSET_UTF_16_BE}:
    builder.confidence = ccCertain
    return SET_ENCODING_CONTINUE
  let charset = getCharset(encoding)
  if charset == CHARSET_UNKNOWN:
    return SET_ENCODING_CONTINUE
  builder.confidence = ccCertain
  if charset == builder.charset:
    return SET_ENCODING_CONTINUE
  builder.charset = if charset == CHARSET_X_USER_DEFINED:
    CHARSET_WINDOWS_1252
  else:
    charset
  return SET_ENCODING_STOP

proc getTemplateContentImpl(builder: ChaDOMBuilder, handle: Node): Node =
  return HTMLTemplateElement(handle).content

proc getParentNodeImpl(builder: ChaDOMBuilder, handle: Node): Option[Node] =
  return option(handle.parentNode)

proc getLocalNameImpl(builder: ChaDOMBuilder, handle: Node): CAtom =
  return Element(handle).localName

proc getNamespaceImpl(builder: ChaDOMBuilder, handle: Node): Namespace =
  return Element(handle).namespace

proc createHTMLElementImpl(builder: ChaDOMBuilder): Node =
  return builder.document.newHTMLElement(TAG_HTML)

proc createElementForTokenImpl(builder: ChaDOMBuilder, localName: CAtom,
    namespace: Namespace, intendedParent: Node, htmlAttrs: Table[CAtom, string],
    xmlAttrs: seq[ParsedAttr[CAtom]]): Node =
  let document = builder.document
  let element = document.newHTMLElement(localName, namespace)
  for k, v in htmlAttrs:
    element.attr(k, v)
  for attr in xmlAttrs:
    element.attrns(attr.name, attr.prefix, attr.namespace, attr.value)
  if element.tagType in ResettableElements:
    element.resetElement()
  if element of HTMLScriptElement:
    let script = HTMLScriptElement(element)
    script.parserDocument = document
    script.forceAsync = false
    # Note: per standard, we could set already started to true here when we
    # are parsing from document.write, but that sounds like a horrible idea.
  return element

proc createCommentImpl(builder: ChaDOMBuilder, text: string): Node =
  return builder.document.createComment(text)

proc createDocumentTypeImpl(builder: ChaDOMBuilder, name, publicId,
    systemId: string): Node =
  return builder.document.newDocumentType(name, publicId, systemId)

proc insertBeforeImpl(builder: ChaDOMBuilder, parent, child: Node,
    before: Option[Node]) =
  discard parent.insertBefore(child, before.get(nil))

proc insertTextImpl(builder: ChaDOMBuilder, parent: Node, text: string,
    before: Option[Node]) =
  let prevSibling = if before.isSome:
    before.get.previousSibling
  else:
    parent.lastChild
  if prevSibling != nil and prevSibling of Text:
    Text(prevSibling).data &= text
    if parent of Element:
      Element(parent).invalid = true
  else:
    let text = builder.document.createTextNode(text)
    discard parent.insertBefore(text, before.get(nil))

proc removeImpl(builder: ChaDOMBuilder, child: Node) =
  child.remove(suppressObservers = true)

proc moveChildrenImpl(builder: ChaDOMBuilder, fromNode, toNode: Node) =
  var tomove = fromNode.childList
  for node in tomove:
    node.remove(suppressObservers = true)
  for child in tomove:
    toNode.insert(child, nil)

proc addAttrsIfMissingImpl(builder: ChaDOMBuilder, handle: Node,
    attrs: Table[CAtom, string]) =
  let element = Element(handle)
  for k, v in attrs:
    if not element.attrb(k):
      element.attr(k, v)

proc setScriptAlreadyStartedImpl(builder: ChaDOMBuilder, script: Node) =
  HTMLScriptElement(script).alreadyStarted = true

proc associateWithFormImpl(builder: ChaDOMBuilder, element, form,
    intendedParent: Node) =
  if form.inSameTree(intendedParent):
    #TODO remove following test eventually
    if element of FormAssociatedElement:
      let element = FormAssociatedElement(element)
      element.setForm(HTMLFormElement(form))
      element.parserInserted = true

proc elementPoppedImpl(builder: ChaDOMBuilder, element: Node) =
  let element = Element(element)
  if element of HTMLTextAreaElement:
    element.resetElement()
  elif element of HTMLScriptElement:
    assert builder.poppedScript == nil or not builder.document.scriptingEnabled
    builder.poppedScript = HTMLScriptElement(element)

proc newChaDOMBuilder(url: URL, window: Window, factory: CAtomFactory,
    confidence: CharsetConfidence, charset = DefaultCharset): ChaDOMBuilder =
  let document = newDocument(factory)
  document.contentType = "text/html"
  document.url = url
  if window != nil:
    document.window = window
    window.document = document
  return ChaDOMBuilder(
    document: document,
    factory: factory,
    confidence: confidence,
    charset: charset
  )

# https://html.spec.whatwg.org/multipage/parsing.html#parsing-html-fragments
proc parseHTMLFragment*(element: Element, s: string): seq[Node] =
  let url = parseURL("about:blank").get
  let factory = element.document.factory
  let builder = newChaDOMBuilder(url, nil, factory, ccIrrelevant)
  let document = builder.document
  document.mode = element.document.mode
  let state = case element.tagType
  of TAG_TITLE, TAG_TEXTAREA: RCDATA
  of TAG_STYLE, TAG_XMP, TAG_IFRAME, TAG_NOEMBED, TAG_NOFRAMES: RAWTEXT
  of TAG_SCRIPT: SCRIPT_DATA
  of TAG_NOSCRIPT:
    if element.document != nil and element.document.scriptingEnabled:
      RAWTEXT
    else:
      DATA
  of TAG_PLAINTEXT:
    PLAINTEXT
  else: DATA
  let root = document.newHTMLElement(TAG_HTML)
  document.append(root)
  let opts = HTML5ParserOpts[Node, CAtom](
    isIframeSrcdoc: false, #TODO?
    scripting: false,
    ctx: some((Node(element), element.localName)),
    initialTokenizerState: state,
    openElementsInit: @[(Node(root), root.localName)],
    pushInTemplate: element.tagType == TAG_TEMPLATE
  )
  var parser = initHTML5Parser(builder, opts)
  let res = parser.parseChunk(s.toOpenArray(0, s.high))
  # scripting is false and confidence is certain -> this must be continue
  assert res == PRES_CONTINUE
  parser.finish()
  builder.finish()
  return root.childList

proc newHTML5ParserWrapper*(window: Window, url: URL, factory: CAtomFactory,
    confidence: CharsetConfidence, charset: Charset): HTML5ParserWrapper =
  let opts = HTML5ParserOpts[Node, CAtom](scripting: window.settings.scripting)
  let builder = newChaDOMBuilder(url, window, factory, confidence, charset)
  let wrapper = HTML5ParserWrapper(
    builder: builder,
    opts: opts,
    parser: initHTML5Parser(builder, opts)
  )
  builder.document.setActiveParser(wrapper)
  return wrapper

proc parseBuffer*(wrapper: HTML5ParserWrapper, buffer: openArray[char]):
    ParseResult =
  let builder = wrapper.builder
  let document = builder.document
  var res = wrapper.parser.parseChunk(buffer)
  # set insertion point for when it's needed
  var ip = wrapper.parser.getInsertionPoint()
  while res == PRES_SCRIPT:
    #TODO microtask
    let script = builder.poppedScript
    builder.poppedScript = nil
    document.writeBuffers.add(DocumentWriteBuffer())
    script.prepare()
    while document.parserBlockingScript != nil:
      let script = document.parserBlockingScript
      document.parserBlockingScript = nil
      #TODO style sheet
      script.execute()
      assert document.parserBlockingScript != script
    if wrapper.stoppedFromScript:
      # document.write inserted a meta charset tag
      break
    assert document.writeBuffers[^1].toOA().len == 0
    discard document.writeBuffers.pop()
    assert document.writeBuffers.len == 0
    if ip == buffer.len:
      # script was at the end of the buffer; nothing to parse
      break
    # parse rest of input buffer
    res = wrapper.parser.parseChunk(buffer.toOpenArray(ip, buffer.high))
    ip += wrapper.parser.getInsertionPoint() # move insertion point
  return res

# Called from dom whenever document.write is executed.
# We consume everything pushed into the top buffer.
proc CDB_parseDocumentWriteChunk(wrapper: pointer) {.exportc.} =
  let wrapper = cast[HTML5ParserWrapper](wrapper)
  let builder = wrapper.builder
  let document = builder.document
  let buffer = document.writeBuffers[^1]
  var res = wrapper.parser.parseChunk(buffer.toOA())
  if res == PRES_SCRIPT:
    document.writeBuffers.add(DocumentWriteBuffer())
    while true:
      buffer.i += wrapper.parser.getInsertionPoint()
      #TODO microtask
      let script = builder.poppedScript
      builder.poppedScript = nil
      script.prepare()
      while document.parserBlockingScript != nil:
        let script = document.parserBlockingScript
        document.parserBlockingScript = nil
        #TODO style sheet
        script.execute()
        assert document.parserBlockingScript != script
      res = wrapper.parser.parseChunk(buffer.toOA())
      if res != PRES_SCRIPT:
        break
    assert document.writeBuffers[^1].i == document.writeBuffers[^1].data.len
    discard document.writeBuffers.pop()
  assert builder.poppedScript == nil
  buffer.i = buffer.data.len
  if res == PRES_STOP:
    wrapper.stoppedFromScript = true

proc finish*(wrapper: HTML5ParserWrapper) =
  wrapper.parser.finish()
  wrapper.builder.finish()
  for r in wrapper.refs:
    r.parser = nil
  wrapper.refs.setLen(0)

proc newDOMParser(): DOMParser {.jsctor.} =
  return DOMParser()

proc parseFromString(ctx: JSContext, parser: DOMParser, str, t: string):
    JSResult[Document] {.jsfunc.} =
  case t
  of "text/html":
    let global = JS_GetGlobalObject(ctx)
    let window = if ctx.hasClass(Window):
      fromJS[Window](ctx, global).get(nil)
    else:
      Window(nil)
    JS_FreeValue(ctx, global)
    let url = if window != nil and window.document != nil:
      window.document.url
    else:
      newURL("about:blank").get
    #TODO this is probably broken in client (or at least sub-optimal)
    let factory = if window != nil: window.factory else: newCAtomFactory()
    let builder = newChaDOMBuilder(url, window, factory, ccIrrelevant)
    var parser = initHTML5Parser(builder, HTML5ParserOpts[Node, CAtom]())
    let res = parser.parseChunk(str)
    assert res == PRES_CONTINUE
    parser.finish()
    builder.finish()
    return ok(builder.document)
  of "text/xml", "application/xml", "application/xhtml+xml", "image/svg+xml":
    return err(newInternalError("XML parsing is not supported yet"))
  else:
    return err(newTypeError("Invalid mime type"))

proc addHTMLModule*(ctx: JSContext) =
  ctx.registerType(DOMParser)
