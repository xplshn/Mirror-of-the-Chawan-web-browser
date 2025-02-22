import std/base64
import std/streams

import html/catom
import html/dom
import html/enums
import js/domexception
import js/javascript
import js/tojs
import types/blob
import types/formdata
import utils/twtstr

import chame/tags

proc constructEntryList*(form: HTMLFormElement, submitter: Element = nil,
    encoding = "UTF-8"): seq[FormDataEntry]

proc generateBoundary(): string =
  let urandom = newFileStream("/dev/urandom")
  let s = urandom.readStr(32)
  urandom.close()
  # 32 * 4 / 3 (padded) = 44 + prefix string is 22 bytes = 66 bytes
  return "----WebKitFormBoundary" & base64.encode(s)

proc newFormData0*(): FormData =
  return FormData(boundary: generateBoundary())

proc newFormData*(form: HTMLFormElement = nil,
    submitter: HTMLElement = nil): DOMResult[FormData] {.jsctor.} =
  let this = newFormData0()
  if form != nil:
    if submitter != nil:
      if not submitter.isSubmitButton():
        return errDOMException("Submitter must be a submit button",
          "InvalidStateError")
      if FormAssociatedElement(submitter).form != form:
        return errDOMException("Submitter's form owner is not form",
          "InvalidStateError")
    if not form.constructingEntryList:
      this.entries = constructEntryList(form, submitter)
  return ok(this)

#TODO filename should not be allowed for string entries
# in other words, this should be an overloaded function, not just an or type
proc append*[T: string|Blob](this: FormData, name: string, value: T,
    filename = none(string)) {.jsfunc.} =
  when T is Blob:
    let filename = if filename.isSome:
      filename.get
    elif value of WebFile:
      WebFile(value).name
    else:
      "blob"
    this.entries.add(FormDataEntry(
      name: name,
      isstr: false,
      value: value,
      filename: filename
    ))
  else: # string
    this.entries.add(FormDataEntry(
      name: name,
      isstr: true,
      svalue: value
    ))

proc delete(this: FormData, name: string) {.jsfunc.} =
  for i in countdown(this.entries.high, 0):
    if this.entries[i].name == name:
      this.entries.delete(i)

proc get(ctx: JSContext, this: FormData, name: string): JSValue {.jsfunc.} =
  for entry in this.entries:
    if entry.name == name:
      if entry.isstr:
        return toJS(ctx, entry.svalue)
      else:
        return toJS(ctx, entry.value)
  return JS_NULL

proc getAll(ctx: JSContext, this: FormData, name: string): seq[JSValue]
    {.jsfunc.} =
  for entry in this.entries:
    if entry.name == name:
      if entry.isstr:
        result.add(toJS(ctx, entry.svalue))
      else:
        result.add(toJS(ctx, entry.value))

proc add(list: var seq[FormDataEntry], entry: tuple[name, value: string]) =
  list.add(FormDataEntry(
    name: entry.name,
    isstr: true,
    svalue: entry.value
  ))

func toNameValuePairs*(list: seq[FormDataEntry]):
    seq[tuple[name, value: string]] =
  for entry in list:
    if entry.isstr:
      result.add((entry.name, entry.svalue))
    else:
      result.add((entry.name, entry.name))

# https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#constructing-the-form-data-set
# Warning: we skip the first "constructing entry list" check; the caller must
# do it.
proc constructEntryList*(form: HTMLFormElement; submitter: Element = nil;
    encoding = "UTF-8"): seq[FormDataEntry] =
  assert not form.constructingEntryList
  form.constructingEntryList = true
  var entrylist: seq[FormDataEntry] = @[]
  for field in form.controls:
    if field.findAncestor({TAG_DATALIST}) != nil or
        field.attrb(satDisabled) or
        field.isButton() and Element(field) != submitter:
      continue
    if field of HTMLInputElement:
      let field = HTMLInputElement(field)
      if field.inputType in {itCheckbox, itRadio} and not field.checked:
        continue
      if field.inputType == itImage:
        var name = field.attr(satName)
        if name != "":
          name &= '.'
        entrylist.add((name & 'x', $field.xcoord))
        entrylist.add((name & 'y', $field.ycoord))
        continue
    #TODO custom elements
    let name = field.attr(satName)
    if name == "":
      continue
    if field of HTMLSelectElement:
      let field = HTMLSelectElement(field)
      for option in field.options:
        if option.selected and not option.isDisabled:
          entrylist.add((name, option.value))
    elif field of HTMLInputElement:
      let field = HTMLInputElement(field)
      case field.inputType
      of itCheckbox, itRadio:
        let v = field.attr(satValue)
        let value = if v != "":
          v
        else:
          "on"
        entrylist.add((name, value))
      of itFile:
        #TODO file
        discard
      of itHidden:
        if name.equalsIgnoreCase("_charset_"):
          entrylist.add((name, encoding))
        else:
          entrylist.add((name, field.value))
      else:
        entrylist.add((name, field.value))
    elif field of HTMLButtonElement:
      entrylist.add((name, HTMLButtonElement(field).value))
    elif field of HTMLTextAreaElement:
      entrylist.add((name, HTMLTextAreaElement(field).value))
    else:
      assert false, "Tag type " & $field.tagType &
        " not accounted for in constructEntryList"
    if field of HTMLTextAreaElement or
        field of HTMLInputElement and
        HTMLInputElement(field).inputType in AutoDirInput:
      let dirname = field.attr(satDirname)
      if dirname != "":
        let dir = "ltr" #TODO bidi
        entrylist.add((dirname, dir))
  form.constructingEntryList = false
  return entrylist

proc addFormDataModule*(ctx: JSContext) =
  ctx.registerType(FormData)
