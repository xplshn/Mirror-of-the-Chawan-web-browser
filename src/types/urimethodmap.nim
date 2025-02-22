# w3m's URI method map format.

import std/strutils
import std/tables

import types/opt
import types/url
import utils/twtstr

type URIMethodMap* = object
  map*: Table[string, string]

func rewriteURL(pattern, surl: string): string =
  result = ""
  var was_perc = false
  for c in pattern:
    if was_perc:
      if c == '%':
        result &= '%'
      elif c == 's':
        result &= surl
      else:
        result &= '%'
        result &= c
      was_perc = false
    elif c != '%':
      result &= c
    else:
      was_perc = true
  if was_perc:
    result &= '%'

type URIMethodMapResult* = enum
  URI_RESULT_NOT_FOUND, URI_RESULT_SUCCESS, URI_RESULT_WRONG_URL

proc findAndRewrite*(this: URIMethodMap, url: var URL): URIMethodMapResult =
  let protocol = url.protocol
  if protocol in this.map:
    let surl = this.map[protocol].rewriteURL($url)
    let x = newURL(surl)
    if x.isNone:
      return URI_RESULT_WRONG_URL
    url = x.get
    return URI_RESULT_SUCCESS
  return URI_RESULT_NOT_FOUND

proc parseURIMethodMap*(this: var URIMethodMap, s: string) =
  for line in s.split('\n'):
    if line.len == 0 or line[0] == '#':
      continue # comments
    var k = ""
    var i = 0
    while i < line.len and line[i] notin AsciiWhitespace + {':'}:
      k &= line[i].toLowerAscii()
      inc i
    if i >= line.len or line[i] != ':':
      continue # invalid
    k &= ':'
    inc i # skip colon
    while i < line.len and line[i] in AsciiWhitespace:
      inc i
    var v = line.until(AsciiWhitespace, i)
    # Basic w3m compatibility.
    # If needed, w3m-cgi-compat covers more cases.
    if v.startsWith("file:/cgi-bin/"):
      v = "cgi-bin:" & v.substr("file:/cgi-bin/".len)
    elif v.startsWith("file:///cgi-bin/"):
      v = "cgi-bin:" & v.substr("file:///cgi-bin/".len)
    elif v.startsWith("/cgi-bin/"):
      v = "cgi-bin:" & v.substr("/cgi-bin/".len)
    discard this.map.hasKeyOrPut(k, v)

proc parseURIMethodMap*(s: string): URIMethodMap =
  result = URIMethodMap()
  result.parseURIMethodMap(s)

proc append*(this: var URIMethodMap, that: URIMethodMap) =
  for k, v in that.map:
    discard this.map.hasKeyOrPut(k, v)
