import algorithm

import utils/strwidth
import utils/twtstr

type DirlistItemType = enum
  ITEM_FILE, ITEM_LINK, ITEM_DIR

type DirlistItem* = object
  name*: string
  modified*: string
  case t*: DirlistItemType
  of ITEM_LINK:
    linkto*: string
  of ITEM_FILE:
    nsize*: int
  of ITEM_DIR:
    discard

type NameWidthTuple = tuple[name: string, width: int, item: ptr DirlistItem]

func makeDirlist*(items: seq[DirlistItem]): string =
  var names: seq[NameWidthTuple]
  var maxw = 20
  for item in items:
    var name = item.name
    if item.t == ITEM_LINK:
      name &= '@'
    elif item.t == ITEM_DIR:
      name &= '/'
    let w = name.width()
    maxw = max(w, maxw)
    names.add((name, w, unsafeAddr item))
  names.sort(proc(a, b: NameWidthTuple): int = cmp(a.name, b.name))
  var outs = "<A HREF=\"../\">[Upper Directory]</A>\n"
  for (name, width, itemp) in names.mitems:
    let item = itemp[]
    var path = percentEncode(item.name, PathPercentEncodeSet)
    if item.t == ITEM_LINK:
      if item.linkto.len > 0 and item.linkto[^1] == '/':
        # If the target is a directory, treat it as a directory. (For FTP.)
        path &= '/'
    elif item.t == ITEM_DIR:
      path &= '/'
    var line = "<A HREF=\"" & path & "\">" & htmlEscape(name) & "</A>"
    while width <= maxw:
      if width mod 2 == 0:
        line &= ' '
      else:
        line &= '.'
      inc width
    if line[^1] != ' ':
      line &= ' '
    line &= htmlEscape(item.modified)
    if item.t == ITEM_FILE:
      line &= ' ' & convertSize(item.nsize)
    elif item.t == ITEM_LINK:
      line &= " -> " & htmlEscape(item.linkto)
    outs &= line & '\n'
  return outs
