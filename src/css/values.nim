import std/macros
import std/options
import std/strutils
import std/tables
import std/unicode

import css/cssparser
import css/selectorparser
import img/bitmap
import layout/layoutunit
import types/color
import types/opt
import types/winattrs
import utils/twtstr

export selectorparser.PseudoElem

type
  CSSShorthandType = enum
    cstNone = ""
    cstAll = "all"
    cstMargin = "margin"
    cstPadding = "padding"
    cstBackground = "background"
    cstListStyle = "list-style"
    cstFlex = "flex"
    cstFlexFlow = "flex-flow"

  CSSUnit* = enum
    UNIT_CM, UNIT_MM, UNIT_IN, UNIT_PX, UNIT_PT, UNIT_PC, UNIT_EM, UNIT_EX,
    UNIT_CH, UNIT_REM, UNIT_VW, UNIT_VH, UNIT_VMIN, UNIT_VMAX, UNIT_PERC,
    UNIT_IC

  CSSPropertyType* = enum
    cptNone = ""
    cptColor = "color"
    cptMarginTop = "margin-top"
    cptMarginLeft = "margin-left"
    cptMarginRight = "margin-right"
    cptMarginBottom = "margin-bottom"
    cptFontStyle = "font-style"
    cptDisplay = "display"
    cptContent = "content"
    cptWhiteSpace = "white-space"
    cptFontWeight = "font-weight"
    cptTextDecoration = "text-decoration"
    cptWordBreak = "word-break"
    cptWidth = "width"
    cptHeight = "height"
    cptListStyleType = "list-style-type"
    cptPaddingTop = "padding-top"
    cptPaddingLeft = "padding-left"
    cptPaddingRight = "padding-right"
    cptPaddingBottom = "padding-bottom"
    cptWordSpacing = "word-spacing"
    cptVerticalAlign = "vertical-align"
    cptLineHeight = "line-height"
    cptTextAlign = "text-align"
    cptListStylePosition = "list-style-position"
    cptBackgroundColor = "background-color"
    cptPosition = "position"
    cptLeft = "left"
    cptRight = "right"
    cptTop = "top"
    cptBottom = "bottom"
    cptCaptionSide = "caption-side"
    cptBorderSpacing = "border-spacing"
    cptBorderCollapse = "border-collapse"
    cptQuotes = "quotes"
    cptCounterReset = "counter-reset"
    cptMaxWidth = "max-width"
    cptMaxHeight = "max-height"
    cptMinWidth = "min-width"
    cptMinHeight = "min-height"
    cptBackgroundImage = "background-image"
    cptChaColspan = "-cha-colspan"
    cptChaRowspan = "-cha-rowspan"
    cptFloat = "float"
    cptVisibility = "visibility"
    cptBoxSizing = "box-sizing"
    cptClear = "clear"
    cptTextTransform = "text-transform"
    cptBgcolorIsCanvas = "-cha-bgcolor-is-canvas"
    cptFlexDirection = "flex-direction"
    cptFlexWrap = "flex-wrap"
    cptFlexGrow = "flex-grow"
    cptFlexShrink = "flex-shrink"
    cptFlexBasis = "flex-basis"

  CSSValueType* = enum
    cvtNone = ""
    cvtLength = "length"
    cvtColor = "color"
    cvtContent = "content"
    cvtDisplay = "display"
    cvtFontStyle = "fontstyle"
    cvtWhiteSpace = "whitespace"
    cvtInteger = "integer"
    cvtTextDecoration = "textdecoration"
    cvtWordBreak = "wordbreak"
    cvtListStyleType = "liststyletype"
    cvtVerticalAlign = "verticalalign"
    cvtTextAlign = "textalign"
    cvtListStylePosition = "liststyleposition"
    cvtPosition = "position"
    cvtCaptionSide = "captionside"
    cvtLength2 = "length2"
    cvtBorderCollapse = "bordercollapse"
    cvtQuotes = "quotes"
    cvtCounterReset = "counterreset"
    cvtImage = "image"
    cvtFloat = "float"
    cvtVisibility = "visibility"
    cvtBoxSizing = "boxsizing"
    cvtClear = "clear"
    cvtTextTransform = "texttransform"
    cvtBgcolorIsCanvas = "bgcoloriscanvas"
    cvtFlexDirection = "flexdirection"
    cvtFlexWrap = "flexwrap"
    cvtNumber = "number"

  CSSGlobalValueType* = enum
    cvtNoglobal, cvtInitial, cvtInherit, cvtRevert, cvtUnset

  CSSDisplay* = enum
    DISPLAY_NONE, DISPLAY_INLINE, DISPLAY_BLOCK, DISPLAY_LIST_ITEM,
    DISPLAY_INLINE_BLOCK, DISPLAY_TABLE, DISPLAY_INLINE_TABLE,
    DISPLAY_TABLE_ROW_GROUP, DISPLAY_TABLE_HEADER_GROUP,
    DISPLAY_TABLE_FOOTER_GROUP, DISPLAY_TABLE_COLUMN_GROUP, DISPLAY_TABLE_ROW,
    DISPLAY_TABLE_COLUMN, DISPLAY_TABLE_CELL, DISPLAY_TABLE_CAPTION,
    DISPLAY_FLOW_ROOT, DISPLAY_FLEX, DISPLAY_INLINE_FLEX

  CSSWhitespace* = enum
    WHITESPACE_NORMAL, WHITESPACE_NOWRAP, WHITESPACE_PRE, WHITESPACE_PRE_LINE,
    WHITESPACE_PRE_WRAP

  CSSFontStyle* = enum
    FONT_STYLE_NORMAL, FONT_STYLE_ITALIC, FONT_STYLE_OBLIQUE

  CSSPosition* = enum
    POSITION_STATIC, POSITION_RELATIVE, POSITION_ABSOLUTE, POSITION_FIXED,
    POSITION_STICKY

  CSSTextDecoration* = enum
    TEXT_DECORATION_NONE, TEXT_DECORATION_UNDERLINE, TEXT_DECORATION_OVERLINE,
    TEXT_DECORATION_LINE_THROUGH, TEXT_DECORATION_BLINK

  CSSWordBreak* = enum
    WORD_BREAK_NORMAL, WORD_BREAK_BREAK_ALL, WORD_BREAK_KEEP_ALL

  CSSListStyleType* = enum
    LIST_STYLE_TYPE_NONE, LIST_STYLE_TYPE_DISC, LIST_STYLE_TYPE_CIRCLE,
    LIST_STYLE_TYPE_SQUARE, LIST_STYLE_TYPE_DECIMAL,
    LIST_STYLE_TYPE_DISCLOSURE_CLOSED, LIST_STYLE_TYPE_DISCLOSURE_OPEN,
    LIST_STYLE_TYPE_CJK_EARTHLY_BRANCH, LIST_STYLE_TYPE_CJK_HEAVENLY_STEM,
    LIST_STYLE_TYPE_LOWER_ROMAN, LIST_STYLE_TYPE_UPPER_ROMAN,
    LIST_STYLE_TYPE_LOWER_ALPHA, LIST_STYLE_TYPE_UPPER_ALPHA,
    LIST_STYLE_TYPE_LOWER_GREEK,
    LIST_STYLE_TYPE_HIRAGANA, LIST_STYLE_TYPE_HIRAGANA_IROHA,
    LIST_STYLE_TYPE_KATAKANA, LIST_STYLE_TYPE_KATAKANA_IROHA,
    LIST_STYLE_TYPE_JAPANESE_INFORMAL

  CSSVerticalAlign2* = enum
    VERTICAL_ALIGN_BASELINE, VERTICAL_ALIGN_SUB, VERTICAL_ALIGN_SUPER,
    VERTICAL_ALIGN_TEXT_TOP, VERTICAL_ALIGN_TEXT_BOTTOM, VERTICAL_ALIGN_MIDDLE,
    VERTICAL_ALIGN_TOP, VERTICAL_ALIGN_BOTTOM

  CSSTextAlign* = enum
    TEXT_ALIGN_START, TEXT_ALIGN_END, TEXT_ALIGN_LEFT, TEXT_ALIGN_RIGHT,
    TEXT_ALIGN_CENTER, TEXT_ALIGN_JUSTIFY, TEXT_ALIGN_CHA_CENTER,
    TEXT_ALIGN_CHA_LEFT, TEXT_ALIGN_CHA_RIGHT

  CSSListStylePosition* = enum
    LIST_STYLE_POSITION_OUTSIDE, LIST_STYLE_POSITION_INSIDE

  CSSCaptionSide* = enum
    CAPTION_SIDE_TOP, CAPTION_SIDE_BOTTOM, CAPTION_SIDE_BLOCK_START,
    CAPTION_SIDE_BLOCK_END,

  CSSBorderCollapse* = enum
    BORDER_COLLAPSE_SEPARATE, BORDER_COLLAPSE_COLLAPSE

  CSSContentType* = enum
    CONTENT_STRING, CONTENT_OPEN_QUOTE, CONTENT_CLOSE_QUOTE,
    CONTENT_NO_OPEN_QUOTE, CONTENT_NO_CLOSE_QUOTE, CONTENT_IMAGE,
    CONTENT_VIDEO, CONTENT_AUDIO, CONTENT_NEWLINE

  CSSFloat* = enum
    FLOAT_NONE, FLOAT_LEFT, FLOAT_RIGHT

  CSSVisibility* = enum
    VISIBILITY_VISIBLE, VISIBILITY_HIDDEN, VISIBILITY_COLLAPSE

  CSSBoxSizing* = enum
    BOX_SIZING_CONTENT_BOX, BOX_SIZING_BORDER_BOX

  CSSClear* = enum
    CLEAR_NONE, CLEAR_LEFT, CLEAR_RIGHT, CLEAR_BOTH, CLEAR_INLINE_START,
    CLEAR_INLINE_END

  CSSTextTransform* = enum
    TEXT_TRANSFORM_NONE, TEXT_TRANSFORM_CAPITALIZE, TEXT_TRANSFORM_UPPERCASE,
    TEXT_TRANSFORM_LOWERCASE, TEXT_TRANSFORM_FULL_WIDTH,
    TEXT_TRANSFORM_FULL_SIZE_KANA, TEXT_TRANSFORM_CHA_HALF_WIDTH

  CSSFlexDirection* = enum
    FLEX_DIRECTION_ROW, FLEX_DIRECTION_ROW_REVERSE, FLEX_DIRECTION_COLUMN,
    FLEX_DIRECTION_COLUMN_REVERSE

  CSSFlexWrap* = enum
    FLEX_WRAP_NOWRAP, FLEX_WRAP_WRAP, FLEX_WRAP_WRAP_REVERSE

const RowGroupBox* = {
  DISPLAY_TABLE_ROW_GROUP, DISPLAY_TABLE_HEADER_GROUP,
  DISPLAY_TABLE_FOOTER_GROUP
}
const ProperTableChild* = RowGroupBox + {
  DISPLAY_TABLE_ROW, DISPLAY_TABLE_COLUMN, DISPLAY_TABLE_COLUMN_GROUP,
  DISPLAY_TABLE_CAPTION
}
const ProperTableRowParent* = RowGroupBox + {
  DISPLAY_TABLE, DISPLAY_INLINE_TABLE
}
const InternalTableBox* = RowGroupBox + {
  DISPLAY_TABLE_CELL, DISPLAY_TABLE_ROW, DISPLAY_TABLE_COLUMN,
  DISPLAY_TABLE_COLUMN_GROUP
}
const TabularContainer* = {DISPLAY_TABLE_ROW} + ProperTableRowParent

type
  CSSLength* = object
    num*: float64
    unit*: CSSUnit
    auto*: bool

  CSSVerticalAlign* = object
    length*: CSSLength
    keyword*: CSSVerticalAlign2

  CSSContent* = object
    t*: CSSContentType
    s*: string
    bmp*: Bitmap

  CSSQuotes* = object
    auto*: bool
    qs*: seq[tuple[s, e: string]]

  CSSCounterReset* = object
    name*: string
    num*: int

  CSSComputedValue* = ref object
    case v*: CSSValueType
    of cvtColor:
      color*: CellColor
    of cvtLength:
      length*: CSSLength
    of cvtFontStyle:
      fontstyle*: CSSFontStyle
    of cvtDisplay:
      display*: CSSDisplay
    of cvtContent:
      content*: seq[CSSContent]
    of cvtQuotes:
      quotes*: CSSQuotes
    of cvtWhiteSpace:
      whitespace*: CSSWhitespace
    of cvtInteger:
      integer*: int
    of cvtNumber:
      number*: float64
    of cvtTextDecoration:
      textdecoration*: set[CSSTextDecoration]
    of cvtWordBreak:
      wordbreak*: CSSWordBreak
    of cvtListStyleType:
      liststyletype*: CSSListStyleType
    of cvtVerticalAlign:
      verticalalign*: CSSVerticalAlign
    of cvtTextAlign:
      textalign*: CSSTextAlign
    of cvtListStylePosition:
      liststyleposition*: CSSListStylePosition
    of cvtPosition:
      position*: CSSPosition
    of cvtCaptionSide:
      captionside*: CSSCaptionSide
    of cvtLength2:
      length2*: tuple[a, b: CSSLength]
    of cvtBorderCollapse:
      bordercollapse*: CSSBorderCollapse
    of cvtCounterReset:
      counterreset*: seq[CSSCounterReset]
    of cvtImage:
      image*: CSSContent
    of cvtFloat:
      float*: CSSFloat
    of cvtVisibility:
      visibility*: CSSVisibility
    of cvtBoxSizing:
      boxsizing*: CSSBoxSizing
    of cvtClear:
      clear*: CSSClear
    of cvtTextTransform:
      texttransform*: CSSTextTransform
    of cvtBgcolorIsCanvas:
      bgcoloriscanvas*: bool
    of cvtFlexDirection:
      flexdirection*: CSSFlexDirection
    of cvtFlexWrap:
      flexwrap*: CSSFlexWrap
    of cvtNone: discard

  CSSComputedValues* = ref array[CSSPropertyType, CSSComputedValue]

  CSSOrigin* = enum
    ORIGIN_USER_AGENT
    ORIGIN_USER
    ORIGIN_AUTHOR

  CSSComputedEntry = tuple
    t: CSSPropertyType
    val: CSSComputedValue
    global: CSSGlobalValueType

  CSSComputedEntries = seq[CSSComputedEntry]

  CSSComputedValuesBuilder* = object
    parent*: CSSComputedValues
    normalProperties: array[CSSOrigin, CSSComputedEntries]
    importantProperties: array[CSSOrigin, CSSComputedEntries]
    preshints*: CSSComputedValues

const ShorthandNames = block:
  var tab = initTable[string, CSSShorthandType]()
  for t in CSSShorthandType:
    if $t != "":
      tab[$t] = t
  tab

const PropertyNames = block:
  var tab = initTable[string, CSSPropertyType]()
  for t in CSSPropertyType:
    if $t != "":
      tab[$t] = t
  tab

const ValueTypes = [
  cptNone: cvtNone,
  cptColor: cvtColor,
  cptMarginTop: cvtLength,
  cptMarginLeft: cvtLength,
  cptMarginRight: cvtLength,
  cptMarginBottom: cvtLength,
  cptFontStyle: cvtFontStyle,
  cptDisplay: cvtDisplay,
  cptContent: cvtContent,
  cptWhiteSpace: cvtWhiteSpace,
  cptFontWeight: cvtInteger,
  cptTextDecoration: cvtTextDecoration,
  cptWordBreak: cvtWordBreak,
  cptWidth: cvtLength,
  cptHeight: cvtLength,
  cptListStyleType: cvtListStyleType,
  cptPaddingTop: cvtLength,
  cptPaddingLeft: cvtLength,
  cptPaddingRight: cvtLength,
  cptPaddingBottom: cvtLength,
  cptWordSpacing: cvtLength,
  cptVerticalAlign: cvtVerticalAlign,
  cptLineHeight: cvtLength,
  cptTextAlign: cvtTextAlign,
  cptListStylePosition: cvtListStylePosition,
  cptBackgroundColor: cvtColor,
  cptPosition: cvtPosition,
  cptLeft: cvtLength,
  cptRight: cvtLength,
  cptTop: cvtLength,
  cptBottom: cvtLength,
  cptCaptionSide: cvtCaptionSide,
  cptBorderSpacing: cvtLength2,
  cptBorderCollapse: cvtBorderCollapse,
  cptQuotes: cvtQuotes,
  cptCounterReset: cvtCounterReset,
  cptMaxWidth: cvtLength,
  cptMaxHeight: cvtLength,
  cptMinWidth: cvtLength,
  cptMinHeight: cvtLength,
  cptBackgroundImage: cvtImage,
  cptChaColspan: cvtInteger,
  cptChaRowspan: cvtInteger,
  cptFloat: cvtFloat,
  cptVisibility: cvtVisibility,
  cptBoxSizing: cvtBoxSizing,
  cptClear: cvtClear,
  cptTextTransform: cvtTextTransform,
  cptBgcolorIsCanvas: cvtBgcolorIsCanvas,
  cptFlexDirection: cvtFlexDirection,
  cptFlexWrap: cvtFlexWrap,
  cptFlexGrow: cvtNumber,
  cptFlexShrink: cvtNumber,
  cptFlexBasis: cvtLength
]

const InheritedProperties = {
  cptColor, cptFontStyle, cptWhiteSpace, cptFontWeight, cptTextDecoration,
  cptWordBreak, cptListStyleType, cptWordSpacing, cptLineHeight, cptTextAlign,
  cptListStylePosition, cptCaptionSide, cptBorderSpacing, cptBorderCollapse,
  cptQuotes, cptVisibility, cptTextTransform
}

func getPropInheritedArray(): array[CSSPropertyType, bool] =
  for prop in CSSPropertyType:
    if prop in InheritedProperties:
      result[prop] = true
    else:
      result[prop] = false

const InheritedArray = getPropInheritedArray()

func shorthandType(s: string): CSSShorthandType =
  return ShorthandNames.getOrDefault(s.toLowerAscii(), cstNone)

func propertyType(s: string): CSSPropertyType =
  return PropertyNames.getOrDefault(s.toLowerAscii(), cptNone)

func valueType(prop: CSSPropertyType): CSSValueType =
  return ValueTypes[prop]

func isSupportedProperty*(s: string): bool =
  return s in PropertyNames

func `$`*(length: CSSLength): string =
  if length.auto:
    return "auto"
  let ss = ($length.unit).split('_')
  let us = ss.toOpenArray(1, ss.high).join('_').toLowerAscii()
  return $length.num & us

func `$`*(content: CSSContent): string =
  if content.s != "":
    return "url(" & content.s & ")"
  return "none"

func `$`*(val: CSSComputedValue): string =
  case val.v
  of cvtColor:
    result &= $val.color
  of cvtImage:
    result &= $val.image
  of cvtLength:
    result &= $val.length
  else:
    result = $val.v

macro `{}`*(vals: CSSComputedValues; s: static string): untyped =
  let t = propertyType(s)
  let vs = ident($valueType(t))
  return quote do:
    `vals`[CSSPropertyType(`t`)].`vs`

macro `{}=`*(vals: CSSComputedValues, s: static string, val: typed) =
  let t = propertyType(s)
  let v = valueType(t)
  let vs = ident($v)
  return quote do:
    `vals`[CSSPropertyType(`t`)] = CSSComputedValue(
      v: CSSValueType(`v`),
      `vs`: `val`
    )

func inherited(t: CSSPropertyType): bool =
  return InheritedArray[t]

func em_to_px(em: float64, window: WindowAttributes): LayoutUnit =
  em * float64(window.ppl)

func ch_to_px(ch: float64, window: WindowAttributes): LayoutUnit =
  ch * float64(window.ppc)

# 水 width, we assume it's 2 chars
func ic_to_px(ic: float64, window: WindowAttributes): LayoutUnit =
  ic * float64(window.ppc) * 2

# x-letter height, we assume it's em/2
func ex_to_px(ex: float64, window: WindowAttributes): LayoutUnit =
  ex * float64(window.ppc) / 2

func px*(l: CSSLength, window: WindowAttributes, p: LayoutUnit): LayoutUnit
    {.inline.} =
  case l.unit
  of UNIT_EM, UNIT_REM: em_to_px(l.num, window)
  of UNIT_CH: ch_to_px(l.num, window)
  of UNIT_IC: ic_to_px(l.num, window)
  of UNIT_EX: ex_to_px(l.num, window)
  of UNIT_PERC: toLayoutUnit(toFloat64(p) * l.num / 100)
  of UNIT_PX: toLayoutUnit(l.num)
  of UNIT_CM: toLayoutUnit(l.num * 37.8)
  of UNIT_MM: toLayoutUnit(l.num * 3.78)
  of UNIT_IN: toLayoutUnit(l.num * 96)
  of UNIT_PC: toLayoutUnit(l.num * 16)
  of UNIT_PT: toLayoutUnit(l.num * 4 / 3)
  of UNIT_VW: toLayoutUnit(float64(window.width_px) * l.num / 100)
  of UNIT_VH: toLayoutUnit(float64(window.height_px) * l.num / 100)
  of UNIT_VMIN:
    toLayoutUnit(min(window.width_px, window.width_px) / 100 * l.num)
  of UNIT_VMAX:
    toLayoutUnit(max(window.width_px, window.width_px) / 100 * l.num)

func blockify*(display: CSSDisplay): CSSDisplay =
  case display
  of DISPLAY_BLOCK, DISPLAY_TABLE, DISPLAY_LIST_ITEM, DISPLAY_NONE,
      DISPLAY_FLOW_ROOT, DISPLAY_FLEX:
     #TODO grid
    return display
  of DISPLAY_INLINE, DISPLAY_INLINE_BLOCK, DISPLAY_TABLE_ROW,
      DISPLAY_TABLE_ROW_GROUP, DISPLAY_TABLE_COLUMN,
      DISPLAY_TABLE_COLUMN_GROUP, DISPLAY_TABLE_CELL, DISPLAY_TABLE_CAPTION,
      DISPLAY_TABLE_HEADER_GROUP, DISPLAY_TABLE_FOOTER_GROUP:
    return DISPLAY_BLOCK
  of DISPLAY_INLINE_TABLE:
    return DISPLAY_TABLE
  of DISPLAY_INLINE_FLEX:
    return DISPLAY_FLEX

const UpperAlphaMap = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".toRunes()
const LowerAlphaMap = "abcdefghijklmnopqrstuvwxyz".toRunes()
const LowerGreekMap = "αβγδεζηθικλμνξοπρστυφχψω".toRunes()
const HiraganaMap = ("あいうえおかきくけこさしすせそたちつてとなにぬねの" &
  "はひふへほまみむめもやゆよらりるれろわゐゑをん").toRunes()
const HiraganaIrohaMap = ("いろはにほへとちりぬるをわかよたれそつねならむ" &
  "うゐのおくやまけふこえてあさきゆめみしゑひもせす").toRunes()
const KatakanaMap = ("アイウエオカキクケコサシスセソタチツテトナニヌネノ" &
  "ハヒフヘホマミムメモヤユヨラリルレロワヰヱヲン").toRunes()
const KatakanaIrohaMap = ("イロハニホヘトチリヌルヲワカヨタレソツネナラム" &
  "ウヰノオクヤマケフコエテアサキユメミシヱヒモセス").toRunes()
const EarthlyBranchMap = "子丑寅卯辰巳午未申酉戌亥".toRunes()
const HeavenlyStemMap = "甲乙丙丁戊己庚辛壬癸".toRunes()

func numToBase(n: int, map: openArray[Rune]): string =
  if n <= 0:
    return $n
  var tmp: seq[Rune]
  var n = n
  while n != 0:
    n -= 1
    tmp &= map[n mod map.len]
    n = n div map.len
  result = ""
  for i in countdown(tmp.high, 0):
    result &= $tmp[i]

func numToFixed(n: int, map: openArray[Rune]): string =
  let n = n - 1
  if n notin 0 .. map.high:
    return $n
  return $map[n]

func listMarker*(t: CSSListStyleType, i: int): string =
  case t
  of LIST_STYLE_TYPE_NONE: return ""
  of LIST_STYLE_TYPE_DISC: return "• " # U+2022
  of LIST_STYLE_TYPE_CIRCLE: return "○ " # U+25CB
  of LIST_STYLE_TYPE_SQUARE: return "□ " # U+25A1
  of LIST_STYLE_TYPE_DISCLOSURE_OPEN: return "▶ " # U+25B6
  of LIST_STYLE_TYPE_DISCLOSURE_CLOSED: return "▼ " # U+25BC
  of LIST_STYLE_TYPE_DECIMAL: return $i & ". "
  of LIST_STYLE_TYPE_UPPER_ROMAN: return romanNumber(i) & ". "
  of LIST_STYLE_TYPE_LOWER_ROMAN: return romanNumberLower(i) & ". "
  of LIST_STYLE_TYPE_UPPER_ALPHA: return numToBase(i, UpperAlphaMap) & ". "
  of LIST_STYLE_TYPE_LOWER_ALPHA: return numToBase(i, LowerAlphaMap) & ". "
  of LIST_STYLE_TYPE_LOWER_GREEK: return numToBase(i, LowerGreekMap) & ". "
  of LIST_STYLE_TYPE_HIRAGANA: return numToBase(i, HiraganaMap) & "、"
  of LIST_STYLE_TYPE_HIRAGANA_IROHA:
    return numToBase(i, HiraganaIrohaMap) & "、"
  of LIST_STYLE_TYPE_KATAKANA: return numToBase(i, KatakanaMap) & "、"
  of LIST_STYLE_TYPE_KATAKANA_IROHA:
    return numToBase(i, KatakanaIrohaMap) & "、"
  of LIST_STYLE_TYPE_CJK_EARTHLY_BRANCH:
    return numToFixed(i, EarthlyBranchMap) & "、"
  of LIST_STYLE_TYPE_CJK_HEAVENLY_STEM:
    return numToFixed(i, HeavenlyStemMap) & "、"
  of LIST_STYLE_TYPE_JAPANESE_INFORMAL: return japaneseNumber(i) & "、"

#TODO this should change by language
func quoteStart*(level: int): string =
  if level == 0:
    return "“"
  return "‘"

func quoteEnd*(level: int): string =
  if level == 0:
    return "“"
  return "‘"

const Colors: Table[string, RGBAColor] = ((func (): Table[string, RGBAColor] =
  for name, rgb in ColorsRGB:
    result[name] = rgb
  result["transparent"] = rgba(0x00, 0x00, 0x00, 0x00)
)())

const Units = {
  "%": UNIT_PERC,
  "cm": UNIT_CM,
  "mm": UNIT_MM,
  "in": UNIT_IN,
  "px": UNIT_PX,
  "pt": UNIT_PT,
  "pc": UNIT_PC,
  "em": UNIT_EM,
  "ex": UNIT_EX,
  "ch": UNIT_CH,
  "ic": UNIT_CH,
  "rem": UNIT_REM,
  "vw": UNIT_VW,
  "vh": UNIT_VH,
  "vmin": UNIT_VMIN,
  "vmax": UNIT_VMAX,
}.toTable()

func cssLength(val: float64, unit: string): Opt[CSSLength] =
  if unit in Units:
    return ok(CSSLength(num: val, unit: Units[unit]))
  return err()

const CSSLengthAuto* = CSSLength(auto: true)

func parseDimensionValues*(s: string): Option[CSSLength] =
  if s == "": return
  var i = 0
  while s[i] in AsciiWhitespace: inc i
  if i >= s.len or s[i] notin AsciiDigit: return
  var n: float64
  while s[i] in AsciiDigit:
    n *= 10
    n += float64(decValue(s[i]))
    inc i
    if i >= s.len: return some(CSSLength(num: n, unit: UNIT_PX))
  if s[i] == '.':
    inc i
    if i >= s.len: return some(CSSLength(num: n, unit: UNIT_PX))
    var d = 1
    while i < s.len and s[i] in AsciiDigit:
      n += float64(decValue(s[i])) / float64(d)
      inc d
      inc i
  if i >= s.len: return some(CSSLength(num: n, unit: UNIT_PX))
  if s[i] == '%': return some(CSSLength(num: n, unit: UNIT_PERC))
  return some(CSSLength(num: n, unit: UNIT_PX))

func skipWhitespace(vals: openArray[CSSComponentValue], i: var int) =
  while i < vals.len:
    if vals[i] != CSS_WHITESPACE_TOKEN:
      break
    inc i

func parseRGBA(value: openArray[CSSComponentValue]): Opt[CellColor] =
  var i = 0
  var commaMode = false
  template check_err(slash: bool) =
    #TODO calc, percentages, etc (cssnumber function or something)
    if not slash and i >= value.len or i < value.len and
        value[i] != CSS_NUMBER_TOKEN:
      return err()
  template next_value(first = false, slash = false) =
    inc i
    value.skipWhitespace(i)
    if i < value.len:
      if value[i] == CSS_COMMA_TOKEN and (commaMode or first):
        # legacy compatibility
        inc i
        value.skipWhitespace(i)
        commaMode = true
      elif commaMode:
        return err()
      elif slash:
        let tok = value[i]
        if tok != CSS_DELIM_TOKEN or CSSToken(tok).cvalue != '/':
          return err()
        inc i
        value.skipWhitespace(i)
    check_err slash
  value.skipWhitespace(i)
  check_err false
  let r = CSSToken(value[i]).nvalue
  next_value true
  let g = CSSToken(value[i]).nvalue
  next_value
  let b = CSSToken(value[i]).nvalue
  next_value false, true
  let a = if i < value.len:
    CSSToken(value[i]).nvalue
  else:
    1
  value.skipWhitespace(i)
  if i < value.len:
    return err()
  return ok(rgba(int(r), int(g), int(b), int(a * 255)).cellColor())

# syntax: -cha-ansi( number | ident )
# where number is an ANSI color (0..255)
# and ident is in NameTable and may start with "bright-"
func parseANSI(value: openArray[CSSComponentValue]): Opt[CellColor] =
  var i = 0
  value.skipWhitespace(i)
  if i != value.high or not (value[i] of CSSToken): # only 1 param is valid
    #TODO numeric functions
    return err()
  let tok = CSSToken(value[i])
  if tok.tokenType == CSS_NUMBER_TOKEN:
    if tok.nvalue notin 0..255:
      return err() # invalid numeric ANSI color
    return ok(ANSIColor(tok.nvalue).cellColor())
  elif tok.tokenType == CSS_IDENT_TOKEN:
    var name = tok.value
    if name.equalsIgnoreCase("default"):
      return ok(defaultColor)
    var bright = false
    if name.startsWithIgnoreCase("bright-"):
      bright = true
      name = name.substr("bright-".len)
    const NameTable = [
      "black",
      "red",
      "green",
      "yellow",
      "blue",
      "magenta",
      "cyan",
      "white"
    ]
    for i, it in NameTable:
      if it.equalsIgnoreCase(name):
        var i = int(i)
        if bright:
          i += 8
        return ok(ANSIColor(i).cellColor())
  return err()

func cssColor*(val: CSSComponentValue): Opt[CellColor] =
  if val of CSSToken:
    let tok = CSSToken(val)
    case tok.tokenType
    of CSS_HASH_TOKEN:
      let c = parseHexColor(tok.value)
      if c.isSome:
        return ok(c.get.cellColor())
    of CSS_IDENT_TOKEN:
      let s = tok.value.toLowerAscii()
      if s in Colors:
        return ok(Colors[s].cellColor())
    else: discard
  elif val of CSSFunction:
    let f = CSSFunction(val)
    if f.name.equalsIgnoreCase("rgb") or f.name.equalsIgnoreCase("rgba"):
      return parseRGBA(f.value)
    elif f.name.equalsIgnoreCase("-cha-ansi"):
      return parseANSI(f.value)
  return err()

func isToken(cval: CSSComponentValue): bool {.inline.} =
  cval of CSSToken

func getToken(cval: CSSComponentValue): CSSToken {.inline.} =
  CSSToken(cval)

func cssIdent[T](map: static openArray[(string, T)], cval: CSSComponentValue):
    Opt[T] =
  if isToken(cval):
    let tok = getToken(cval)
    if tok.tokenType == CSS_IDENT_TOKEN:
      # cmp when len is small enough, otherwise lowercase & hashmap
      when map.len <= 4:
        for (k, v) in map:
          if k.equalsIgnoreCase(tok.value):
            return ok(v)
      else:
        const MapTable = map.toTable()
        let val = tok.value.toLowerAscii()
        if val in MapTable:
          return ok(MapTable[val])
  return err()

func cssIdentFirst[T](map: static openArray[(string, T)], d: CSSDeclaration):
    Opt[T] =
  if d.value.len == 1:
    return cssIdent(map, d.value[0])
  return err()

func cssLength*(val: CSSComponentValue, has_auto: static bool = true,
    allow_negative: static bool = true): Opt[CSSLength] =
  block nofail:
    if val of CSSToken:
      let tok = CSSToken(val)
      case tok.tokenType
      of CSS_NUMBER_TOKEN:
        if tok.nvalue == 0:
          return ok(CSSLength(num: 0, unit: UNIT_PX))
      of CSS_PERCENTAGE_TOKEN:
        when not allow_negative:
          if tok.nvalue < 0:
            break nofail
        return cssLength(tok.nvalue, "%")
      of CSS_DIMENSION_TOKEN:
        when not allow_negative:
          if tok.nvalue < 0:
            break nofail
        return cssLength(tok.nvalue, tok.unit)
      of CSS_IDENT_TOKEN:
        when has_auto:
          if tok.value.equalsIgnoreCase("auto"):
            return ok(CSSLengthAuto)
      else: discard
  return err()

func cssAbsoluteLength(val: CSSComponentValue): Opt[CSSLength] =
  if val of CSSToken:
    let tok = CSSToken(val)
    case tok.tokenType
    of CSS_NUMBER_TOKEN:
      if tok.nvalue == 0:
        return ok(CSSLength(num: 0, unit: UNIT_PX))
    of CSS_DIMENSION_TOKEN:
      if tok.nvalue >= 0:
        return cssLength(tok.nvalue, tok.unit)
    else: discard
  return err()

func cssWordSpacing(cval: CSSComponentValue): Opt[CSSLength] =
  if cval of CSSToken:
    let tok = CSSToken(cval)
    case tok.tokenType
    of CSS_DIMENSION_TOKEN:
      return cssLength(tok.nvalue, tok.unit)
    of CSS_IDENT_TOKEN:
      if tok.value.equalsIgnoreCase("normal"):
        return ok(CSSLengthAuto)
    else: discard
  return err()

func cssGlobal(d: CSSDeclaration): CSSGlobalValueType =
  const GlobalMap = {
    "inherit": cvtInherit,
    "initial": cvtInitial,
    "unset": cvtUnset,
    "revert": cvtRevert
  }
  return cssIdentFirst(GlobalMap, d).get(cvtNoglobal)

func cssQuotes(d: CSSDeclaration): Opt[CSSQuotes] =
  template die =
    return err()
  if d.value.len == 0:
    die
  var res: CSSQuotes
  var sa = false
  var pair: tuple[s, e: string]
  for cval in d.value:
    if res.auto: die
    if isToken(cval):
      let tok = getToken(cval)
      case tok.tokenType
      of CSS_IDENT_TOKEN:
        if res.qs.len > 0: die
        if tok.value.equalsIgnoreCase("auto"):
          res.auto = true
        elif tok.value.equalsIgnoreCase("none"):
          if d.value.len != 1:
            die
        die
      of CSS_STRING_TOKEN:
        if sa:
          pair.e = tok.value
          res.qs.add(pair)
          sa = false
        else:
          pair.s = tok.value
          sa = true
      of CSS_WHITESPACE_TOKEN: discard
      else: die
  if sa:
    die
  return ok(res)

func cssContent(d: CSSDeclaration): seq[CSSContent] =
  for cval in d.value:
    if isToken(cval):
      let tok = getToken(cval)
      case tok.tokenType
      of CSS_IDENT_TOKEN:
        if tok.value == "/":
          break
        elif tok.value.equalsIgnoreCase("open-quote"):
          result.add(CSSContent(t: CONTENT_OPEN_QUOTE))
        elif tok.value.equalsIgnoreCase("no-open-quote"):
          result.add(CSSContent(t: CONTENT_NO_OPEN_QUOTE))
        elif tok.value.equalsIgnoreCase("close-quote"):
          result.add(CSSContent(t: CONTENT_CLOSE_QUOTE))
        elif tok.value.equalsIgnoreCase("no-close-quote"):
          result.add(CSSContent(t: CONTENT_NO_CLOSE_QUOTE))
      of CSS_STRING_TOKEN:
        result.add(CSSContent(t: CONTENT_STRING, s: tok.value))
      else: return

func cssDisplay(cval: CSSComponentValue): Opt[CSSDisplay] =
  const DisplayMap = {
    "block": DISPLAY_BLOCK,
    "inline": DISPLAY_INLINE,
    "list-item": DISPLAY_LIST_ITEM,
    "inline-block": DISPLAY_INLINE_BLOCK,
    "table": DISPLAY_TABLE,
    "table-row": DISPLAY_TABLE_ROW,
    "table-cell": DISPLAY_TABLE_CELL,
    "table-column": DISPLAY_TABLE_COLUMN,
    "table-column-group": DISPLAY_TABLE_COLUMN_GROUP,
    "inline-table": DISPLAY_INLINE_TABLE,
    "table-row-group": DISPLAY_TABLE_ROW_GROUP,
    "table-header-group": DISPLAY_TABLE_HEADER_GROUP,
    "table-footer-group": DISPLAY_TABLE_FOOTER_GROUP,
    "table-caption": DISPLAY_TABLE_CAPTION,
    "flow-root": DISPLAY_FLOW_ROOT,
    "flex": DISPLAY_FLEX,
    "inline-flex": DISPLAY_INLINE_FLEX,
    "none": DISPLAY_NONE
  }
  return cssIdent(DisplayMap, cval)

func cssFontStyle(cval: CSSComponentValue): Opt[CSSFontStyle] =
  const FontStyleMap = {
    "normal": FONT_STYLE_NORMAL,
    "italic": FONT_STYLE_ITALIC,
    "oblique": FONT_STYLE_OBLIQUE
  }
  return cssIdent(FontStyleMap, cval)

func cssWhiteSpace(cval: CSSComponentValue): Opt[CSSWhitespace] =
  const WhiteSpaceMap = {
    "normal": WHITESPACE_NORMAL,
    "nowrap": WHITESPACE_NOWRAP,
    "pre": WHITESPACE_PRE,
    "pre-line": WHITESPACE_PRE_LINE,
    "pre-wrap": WHITESPACE_PRE_WRAP
  }
  return cssIdent(WhiteSpaceMap, cval)

func cssFontWeight(cval: CSSComponentValue): Opt[int] =
  if isToken(cval):
    let tok = getToken(cval)
    if tok.tokenType == CSS_IDENT_TOKEN:
      const FontWeightMap = {
        "normal": 400,
        "bold": 700,
        "lighter": 400,
        "bolder": 700
      }
      return cssIdent(FontWeightMap, cval)
    elif tok.tokenType == CSS_NUMBER_TOKEN:
      if tok.nvalue in 1f64..1000f64:
        return ok(int(tok.nvalue))
  return err()

func cssTextDecoration(d: CSSDeclaration): Opt[set[CSSTextDecoration]] =
  var s: set[CSSTextDecoration]
  for cval in d.value:
    if isToken(cval):
      let tok = getToken(cval)
      if tok.tokenType == CSS_IDENT_TOKEN:
        if tok.value.equalsIgnoreCase("none"):
          if d.value.len != 1:
            return err()
          return ok(s)
        elif tok.value.equalsIgnoreCase("underline"):
          s.incl(TEXT_DECORATION_UNDERLINE)
        elif tok.value.equalsIgnoreCase("overline"):
          s.incl(TEXT_DECORATION_OVERLINE)
        elif tok.value.equalsIgnoreCase("line-through"):
          s.incl(TEXT_DECORATION_LINE_THROUGH)
        elif tok.value.equalsIgnoreCase("blink"):
          s.incl(TEXT_DECORATION_BLINK)
        else:
          return err()
  return ok(s)

func cssWordBreak(cval: CSSComponentValue): Opt[CSSWordBreak] =
  const WordBreakMap = {
    "normal": WORD_BREAK_NORMAL,
    "break-all": WORD_BREAK_BREAK_ALL,
    "keep-all": WORD_BREAK_KEEP_ALL
  }
  return cssIdent(WordBreakMap, cval)

func cssListStyleType(cval: CSSComponentValue): Opt[CSSListStyleType] =
  const ListStyleMap = {
    "none": LIST_STYLE_TYPE_NONE,
    "disc": LIST_STYLE_TYPE_DISC,
    "circle": LIST_STYLE_TYPE_CIRCLE,
    "square": LIST_STYLE_TYPE_SQUARE,
    "decimal": LIST_STYLE_TYPE_DECIMAL,
    "disclosure-open": LIST_STYLE_TYPE_DISCLOSURE_OPEN,
    "disclosure-closed": LIST_STYLE_TYPE_DISCLOSURE_CLOSED,
    "cjk-earthly-branch": LIST_STYLE_TYPE_CJK_EARTHLY_BRANCH,
    "cjk-heavenly-stem": LIST_STYLE_TYPE_CJK_HEAVENLY_STEM,
    "upper-roman": LIST_STYLE_TYPE_UPPER_ROMAN,
    "lower-roman": LIST_STYLE_TYPE_LOWER_ROMAN,
    "upper-latin": LIST_STYLE_TYPE_UPPER_ALPHA,
    "lower-latin": LIST_STYLE_TYPE_LOWER_ALPHA,
    "upper-alpha": LIST_STYLE_TYPE_UPPER_ALPHA,
    "lower-alpha": LIST_STYLE_TYPE_UPPER_ALPHA,
    "lower-greek": LIST_STYLE_TYPE_LOWER_GREEK,
    "hiragana": LIST_STYLE_TYPE_HIRAGANA,
    "hiragana-iroha": LIST_STYLE_TYPE_HIRAGANA_IROHA,
    "katakana": LIST_STYLE_TYPE_KATAKANA,
    "katakana-iroha": LIST_STYLE_TYPE_KATAKANA_IROHA,
    "japanese-informal": LIST_STYLE_TYPE_JAPANESE_INFORMAL
  }
  return cssIdent(ListStyleMap, cval)

func cssVerticalAlign(cval: CSSComponentValue): Opt[CSSVerticalAlign] =
  if isToken(cval):
    let tok = getToken(cval)
    if tok.tokenType == CSS_IDENT_TOKEN:
      const VerticalAlignMap = {
        "baseline": VERTICAL_ALIGN_BASELINE,
        "sub": VERTICAL_ALIGN_SUB,
        "super": VERTICAL_ALIGN_SUPER,
        "text-top": VERTICAL_ALIGN_TEXT_BOTTOM,
        "middle": VERTICAL_ALIGN_MIDDLE,
        "top": VERTICAL_ALIGN_TOP,
        "bottom": VERTICAL_ALIGN_BOTTOM
      }
      let va2 = ?cssIdent(VerticalAlignMap, cval)
      return ok(CSSVerticalAlign(
        keyword: va2
      ))
    else:
      return ok(CSSVerticalAlign(
        keyword: VERTICAL_ALIGN_BASELINE,
        length: ?cssLength(tok, has_auto = false)
      ))
  return err()

func cssLineHeight(cval: CSSComponentValue): Opt[CSSLength] =
  if cval of CSSToken:
    let tok = CSSToken(cval)
    case tok.tokenType
    of CSS_NUMBER_TOKEN:
      return cssLength(tok.nvalue * 100, "%")
    of CSS_IDENT_TOKEN:
      if tok.value == "normal":
        return ok(CSSLengthAuto)
    else:
      return cssLength(tok, has_auto = false)
  return err()

func cssTextAlign(cval: CSSComponentValue): Opt[CSSTextAlign] =
  const TextAlignMap = {
    "start": TEXT_ALIGN_START,
    "end": TEXT_ALIGN_END,
    "left": TEXT_ALIGN_LEFT,
    "right": TEXT_ALIGN_RIGHT,
    "center": TEXT_ALIGN_CENTER,
    "justify": TEXT_ALIGN_JUSTIFY,
    "-cha-center": TEXT_ALIGN_CHA_CENTER
  }
  return cssIdent(TextAlignMap, cval)

func cssListStylePosition(cval: CSSComponentValue): Opt[CSSListStylePosition] =
  const ListStylePositionMap = {
    "inside": LIST_STYLE_POSITION_INSIDE,
    "outside": LIST_STYLE_POSITION_OUTSIDE
  }
  return cssIdent(ListStylePositionMap, cval)

func cssPosition(cval: CSSComponentValue): Opt[CSSPosition] =
  const PositionMap = {
    "static": POSITION_STATIC,
    "relative": POSITION_RELATIVE,
    "absolute": POSITION_ABSOLUTE,
    "fixed": POSITION_FIXED,
    "sticky": POSITION_STICKY
  }
  return cssIdent(PositionMap, cval)

func cssCaptionSide(cval: CSSComponentValue): Opt[CSSCaptionSide] =
  const CaptionSideMap = {
    "top": CAPTION_SIDE_TOP,
    "bottom": CAPTION_SIDE_BOTTOM,
    "block-start": CAPTION_SIDE_BLOCK_START,
    "block-end": CAPTION_SIDE_BLOCK_END,
  }
  return cssIdent(CaptionSideMap, cval)

func cssBorderCollapse(cval: CSSComponentValue): Opt[CSSBorderCollapse] =
  const BorderCollapseMap = {
    "collapse": BORDER_COLLAPSE_COLLAPSE,
    "separate": BORDER_COLLAPSE_SEPARATE
  }
  return cssIdent(BorderCollapseMap, cval)

func cssCounterReset(d: CSSDeclaration): Opt[seq[CSSCounterReset]] =
  template die =
    return err()
  var r: CSSCounterReset
  var s = false
  var res: seq[CSSCounterReset]
  for cval in d.value:
    if isToken(cval):
      let tok = getToken(cval)
      case tok.tokenType
      of CSS_WHITESPACE_TOKEN: discard
      of CSS_IDENT_TOKEN:
        if s:
          die
        r.name = tok.value
        s = true
      of CSS_NUMBER_TOKEN:
        if not s:
          die
        r.num = int(tok.nvalue)
        res.add(r)
        s = false
      else:
        die
  return ok(res)

func cssMaxMinSize(cval: CSSComponentValue): Opt[CSSLength] =
  if isToken(cval):
    let tok = getToken(cval)
    case tok.tokenType
    of CSS_IDENT_TOKEN:
      if tok.value.equalsIgnoreCase("none"):
        return ok(CSSLengthAuto)
    of CSS_NUMBER_TOKEN, CSS_DIMENSION_TOKEN, CSS_PERCENTAGE_TOKEN:
      return cssLength(tok, allow_negative = false)
    else: discard
  return err()

#TODO should be URL (parsed with baseurl of document...)
func cssURL(cval: CSSComponentValue): Option[string] =
  if isToken(cval):
    let tok = getToken(cval)
    if tok == CSS_URL_TOKEN:
      return some(tok.value)
  elif cval of CSSFunction:
    let fun = CSSFunction(cval)
    if fun.name.equalsIgnoreCase("url") or fun.name.equalsIgnoreCase("src"):
      for x in fun.value:
        if not isToken(x):
          break
        let x = getToken(x)
        if x == CSS_WHITESPACE_TOKEN:
          discard
        elif x == CSS_STRING_TOKEN:
          return some(x.value)
        else:
          break

#TODO this should be bg-image, add gradient, etc etc
func cssImage(cval: CSSComponentValue): Opt[CSSContent] =
  if isToken(cval):
    #TODO bg-image only
    let tok = getToken(cval)
    if tok.tokenType == CSS_IDENT_TOKEN and tok.value == "none":
      return ok(CSSContent(t: CONTENT_IMAGE, s: ""))
  let url = cssURL(cval)
  if url.isSome:
    return ok(CSSContent(t: CONTENT_IMAGE, s: url.get))
  return err()

func cssInteger(cval: CSSComponentValue, range: Slice[int]): Opt[int] =
  if isToken(cval):
    let tok = getToken(cval)
    if tok.tokenType == CSS_NUMBER_TOKEN:
      if tok.nvalue in float64(range.a)..float64(range.b):
        return ok(int(tok.nvalue))
  return err()

func cssFloat(cval: CSSComponentValue): Opt[CSSFloat] =
  const FloatMap = {
    "none": FLOAT_NONE,
    "left": FLOAT_LEFT,
    "right": FLOAT_RIGHT
  }
  return cssIdent(FloatMap, cval)

func cssVisibility(cval: CSSComponentValue): Opt[CSSVisibility] =
  const VisibilityMap = {
    "visible": VISIBILITY_VISIBLE,
    "hidden": VISIBILITY_HIDDEN,
    "collapse": VISIBILITY_COLLAPSE
  }
  return cssIdent(VisibilityMap, cval)

func cssBoxSizing(cval: CSSComponentValue): Opt[CSSBoxSizing] =
  const BoxSizingMap = {
    "border-box": BOX_SIZING_BORDER_BOX,
    "content-box": BOX_SIZING_CONTENT_BOX
  }
  return cssIdent(BoxSizingMap, cval)

func cssClear(cval: CSSComponentValue): Opt[CSSClear] =
  const ClearMap = {
    "none": CLEAR_NONE,
    "left": CLEAR_LEFT,
    "right": CLEAR_RIGHT,
    "both": CLEAR_BOTH,
    "inline-start": CLEAR_INLINE_START,
    "inline-end": CLEAR_INLINE_END
  }
  return cssIdent(ClearMap, cval)

func cssTextTransform(cval: CSSComponentValue): Opt[CSSTextTransform] =
  const TextTransformMap = {
    "none": TEXT_TRANSFORM_NONE,
    "capitalize": TEXT_TRANSFORM_CAPITALIZE,
    "uppercase": TEXT_TRANSFORM_UPPERCASE,
    "lowercase": TEXT_TRANSFORM_LOWERCASE,
    "full-width": TEXT_TRANSFORM_FULL_WIDTH,
    "full-size-kana": TEXT_TRANSFORM_FULL_SIZE_KANA,
    "-cha-half-width": TEXT_TRANSFORM_CHA_HALF_WIDTH
  }
  return cssIdent(TextTransformMap, cval)

func cssFlexDirection(cval: CSSComponentValue): Opt[CSSFlexDirection] =
  const FlexDirectionMap = {
    "row": FLEX_DIRECTION_ROW,
    "row-reverse": FLEX_DIRECTION_ROW_REVERSE,
    "column": FLEX_DIRECTION_COLUMN,
    "column-reverse": FLEX_DIRECTION_COLUMN_REVERSE,
  }
  return cssIdent(FlexDirectionMap, cval)

func cssNumber(cval: CSSComponentValue; positive: bool): Opt[float64] =
  if isToken(cval):
    let tok = getToken(cval)
    if tok.tokenType == CSS_NUMBER_TOKEN:
      if not positive or tok.nvalue >= 0:
        return ok(tok.nvalue)
  return err()

func cssFlexWrap(cval: CSSComponentValue): Opt[CSSFlexWrap] =
  const FlexWrapMap = {
    "nowrap": FLEX_WRAP_NOWRAP,
    "wrap": FLEX_WRAP_WRAP,
    "wrap-reverse": FLEX_WRAP_WRAP_REVERSE
  }
  return cssIdent(FlexWrapMap, cval)

proc getValueFromDecl(val: CSSComputedValue, d: CSSDeclaration,
    vtype: CSSValueType, ptype: CSSPropertyType): Err[void] =
  var i = 0
  d.value.skipWhitespace(i)
  if i >= d.value.len:
    return err()
  let cval = d.value[i]
  inc i
  case vtype
  of cvtColor:
    val.color = ?cssColor(cval)
  of cvtLength:
    case ptype
    of cptWordSpacing:
      val.length = ?cssWordSpacing(cval)
    of cptLineHeight:
      val.length = ?cssLineHeight(cval)
    of cptMaxWidth, cptMaxHeight, cptMinWidth,
       cptMinHeight:
      val.length = ?cssMaxMinSize(cval)
    of cptPaddingLeft, cptPaddingRight, cptPaddingTop,
       cptPaddingBottom:
      val.length = ?cssLength(cval, has_auto = false)
    #TODO content for flex-basis
    else:
      val.length = ?cssLength(cval)
  of cvtFontStyle:
    val.fontstyle = ?cssFontStyle(cval)
  of cvtDisplay:
    val.display = ?cssDisplay(cval)
  of cvtContent:
    val.content = cssContent(d)
  of cvtWhiteSpace:
    val.whitespace = ?cssWhiteSpace(cval)
  of cvtInteger:
    if ptype == cptFontWeight:
      val.integer = ?cssFontWeight(cval)
    elif ptype == cptChaColspan:
      val.integer = ?cssInteger(cval, 1 .. 1000)
    elif ptype == cptChaRowspan:
      val.integer = ?cssInteger(cval, 0 .. 65534)
  of cvtTextDecoration:
    val.textdecoration = ?cssTextDecoration(d)
  of cvtWordBreak:
    val.wordbreak = ?cssWordBreak(cval)
  of cvtListStyleType:
    val.liststyletype = ?cssListStyleType(cval)
  of cvtVerticalAlign:
    val.verticalalign = ?cssVerticalAlign(cval)
  of cvtTextAlign:
    val.textalign = ?cssTextAlign(cval)
  of cvtListStylePosition:
    val.liststyleposition = ?cssListStylePosition(cval)
  of cvtPosition:
    val.position = ?cssPosition(cval)
  of cvtCaptionSide:
    val.captionside = ?cssCaptionSide(cval)
  of cvtBorderCollapse:
    val.bordercollapse = ?cssBorderCollapse(cval)
  of cvtLength2:
    val.length2.a = ?cssAbsoluteLength(cval)
    d.value.skipWhitespace(i)
    if i >= d.value.len:
      val.length2.b = val.length2.a
    else:
      let cval = d.value[i]
      val.length2.b = ?cssAbsoluteLength(cval)
  of cvtQuotes:
    val.quotes = ?cssQuotes(d)
  of cvtCounterReset:
    val.counterreset = ?cssCounterReset(d)
  of cvtImage:
    val.image = ?cssImage(cval)
  of cvtFloat:
    val.float = ?cssFloat(cval)
  of cvtVisibility:
    val.visibility = ?cssVisibility(cval)
  of cvtBoxSizing:
    val.boxsizing = ?cssBoxSizing(cval)
  of cvtClear:
    val.clear = ?cssClear(cval)
  of cvtTextTransform:
    val.texttransform = ?cssTextTransform(cval)
  of cvtBgcolorIsCanvas:
    return err() # internal value
  of cvtFlexDirection:
    val.flexdirection = ?cssFlexDirection(cval)
  of cvtFlexWrap:
    val.flexwrap = ?cssFlexWrap(cval)
  of cvtNumber:
    const NeedsPositive = {cptFlexGrow}
    val.number = ?cssNumber(cval, ptype in NeedsPositive)
  of cvtNone:
    discard
  return ok()

func getInitialColor(t: CSSPropertyType): CellColor =
  if t == cptBackgroundColor:
    return Colors["transparent"].cellColor()
  return defaultColor

func getInitialLength(t: CSSPropertyType): CSSLength =
  case t
  of cptWidth, cptHeight, cptWordSpacing, cptLineHeight, cptLeft, cptRight,
      cptTop, cptBottom, cptMaxWidth, cptMaxHeight, cptMinWidth, cptMinHeight,
      cptFlexBasis:
    return CSSLengthAuto
  else:
    return CSSLength(auto: false, unit: UNIT_PX, num: 0)

func getInitialInteger(t: CSSPropertyType): int =
  case t
  of cptChaColspan, cptChaRowspan:
    return 1
  of cptFontWeight:
    return 400 # normal
  else:
    return 0

func getInitialNumber(t: CSSPropertyType): float64 =
  if t == cptFlexShrink:
    return 1
  return 0

func calcInitial(t: CSSPropertyType): CSSComputedValue =
  let v = valueType(t)
  var nv: CSSComputedValue
  case v
  of cvtColor:
    nv = CSSComputedValue(v: v, color: getInitialColor(t))
  of cvtDisplay:
    nv = CSSComputedValue(v: v, display: DISPLAY_INLINE)
  of cvtWordBreak:
    nv = CSSComputedValue(v: v, wordbreak: WORD_BREAK_NORMAL)
  of cvtLength:
    nv = CSSComputedValue(v: v, length: getInitialLength(t))
  of cvtInteger:
    nv = CSSComputedValue(v: v, integer: getInitialInteger(t))
  of cvtQuotes:
    nv = CSSComputedValue(v: v, quotes: CSSQuotes(auto: true))
  of cvtNumber:
    nv = CSSComputedValue(v: v, number: getInitialNumber(t))
  else:
    nv = CSSComputedValue(v: v)
  return nv

func getInitialTable(): array[CSSPropertyType, CSSComputedValue] =
  for i in low(result)..high(result):
    result[i] = calcInitial(i)

let defaultTable = getInitialTable()

template getDefault(t: CSSPropertyType): CSSComputedValue =
  {.cast(noSideEffect).}:
    defaultTable[t]

func getComputedValue(d: CSSDeclaration, ptype: CSSPropertyType,
    vtype: CSSValueType): Opt[CSSComputedEntry] =
  let global = cssGlobal(d)
  let val = CSSComputedValue(v: vtype)
  if global != cvtNoglobal:
    return ok((ptype, val, global))
  ?val.getValueFromDecl(d, vtype, ptype)
  return ok((ptype, val, global))

func lengthShorthand(d: CSSDeclaration, props: array[4, CSSPropertyType]):
    Opt[seq[CSSComputedEntry]] =
  var i = 0
  var cvals: seq[CSSComponentValue]
  while i < d.value.len:
    if d.value[i] != CSS_WHITESPACE_TOKEN:
      cvals.add(d.value[i])
    inc i
  var res: seq[CSSComputedEntry]
  case cvals.len
  of 1: # top, bottom, left, right
    for ptype in props:
      let vtype = valueType(ptype)
      let val = CSSComputedValue(v: vtype)
      ?val.getValueFromDecl(d, vtype, ptype)
      res.add((ptype, val, cssGlobal(d)))
  of 2: # top, bottom | left, right
    for i in 0 ..< props.len:
      let ptype = props[i]
      let vtype = valueType(ptype)
      let val = CSSComputedValue(v: vtype)
      val.length = ?cssLength(cvals[i mod 2])
      res.add((ptype, val, cssGlobal(d)))
  of 3: # top | left, right | bottom
    for i in 0 ..< props.len:
      let ptype = props[i]
      let vtype = valueType(ptype)
      let val = CSSComputedValue(v: vtype)
      let j = if i == 0:
        0 # top
      elif i == 3:
        2 # bottom
      else:
        1 # left, right
      val.length = ?cssLength(cvals[j])
      res.add((ptype, val, cssGlobal(d)))
  of 4: # top | right | bottom | left
    for i in 0 ..< props.len:
      let ptype = props[i]
      let vtype = valueType(ptype)
      let val = CSSComputedValue(v: vtype)
      val.length = ?cssLength(cvals[i])
      res.add((ptype, val, cssGlobal(d)))
  else: discard
  return ok(res)

const PropertyMarginSpec = [
  cptMarginTop, cptMarginRight, cptMarginBottom,
  cptMarginLeft
]

const PropertyPaddingSpec = [
  cptPaddingTop, cptPaddingRight, cptPaddingBottom,
  cptPaddingLeft
]

proc getComputedValues0(res: var seq[CSSComputedEntry]; d: CSSDeclaration):
    Err[void] =
  case shorthandType(d.name)
  of cstNone:
    let ptype = propertyType(d.name)
    let vtype = valueType(ptype)
    res.add(?getComputedValue(d, ptype, vtype))
  of cstAll:
    let global = cssGlobal(d)
    if global != cvtNoglobal:
      for ptype in CSSPropertyType:
        let vtype = valueType(ptype)
        let val = CSSComputedValue(v: vtype)
        res.add((ptype, val, global))
  of cstMargin:
    res.add(?lengthShorthand(d, PropertyMarginSpec))
  of cstPadding:
    res.add(?lengthShorthand(d, PropertyPaddingSpec))
  of cstBackground:
    let global = cssGlobal(d)
    var bgcolorval = getDefault(cptBackgroundColor)
    var bgimageval = getDefault(cptBackgroundImage)
    var valid = true
    if global == cvtNoglobal:
      for tok in d.value:
        if tok == CSS_WHITESPACE_TOKEN:
          continue
        if (let r = cssImage(tok); r.isOk):
          bgimageval = CSSComputedValue(v: cvtImage, image: r.get)
        elif (let r = cssColor(tok); r.isOk):
          bgcolorval = CSSComputedValue(v: cvtColor, color: r.get)
        else:
          #TODO when we implement the other shorthands too
          #valid = false
          discard
    if valid:
      res.add((cptBackgroundColor, bgcolorval, global))
      res.add((cptBackgroundImage, bgimageval, global))
  of cstListStyle:
    let global = cssGlobal(d)
    var positionVal = getDefault(cptListStylePosition)
    var typeVal = getDefault(cptListStyleType)
    var valid = true
    if global == cvtNoglobal:
      for tok in d.value:
        if tok == CSS_WHITESPACE_TOKEN:
          continue
        if (let r = cssListStylePosition(tok); r.isOk):
          positionVal = CSSComputedValue(
            v: cvtListStylePosition,
            liststyleposition: r.get
          )
        elif (let r = cssListStyleType(tok); r.isOk):
          typeVal = CSSComputedValue(
            v: cvtListStyleType,
            liststyletype: r.get
          )
        else:
          #TODO list-style-image
          #valid = false
          discard
    if valid:
      res.add((cptListStylePosition, positionVal, global))
      res.add((cptListStyleType, typeVal, global))
  of cstFlex:
    let global = cssGlobal(d)
    if global == cvtNoglobal:
      var i = 0
      d.value.skipWhitespace(i)
      if i >= d.value.len:
        return err()
      if (let r = cssNumber(d.value[i], positive = true); r.isSome):
        # flex-grow
        let val = CSSComputedValue(v: cvtNumber, number: r.get)
        res.add((cptFlexGrow, val, global))
        inc i
        d.value.skipWhitespace(i)
        if i < d.value.len:
          if not d.value[i].isToken:
            return err()
          if (let r = cssNumber(d.value[i], positive = true); r.isSome):
            # flex-shrink
            let val = CSSComputedValue(v: cvtNumber, number: r.get)
            res.add((cptFlexShrink, val, global))
            inc i
            d.value.skipWhitespace(i)
      if res.len < 1: # flex-grow omitted, default to 1
        let val = CSSComputedValue(v: cvtNumber, number: 1)
        res.add((cptFlexGrow, val, global))
      if res.len < 2: # flex-shrink omitted, default to 1
        let val = CSSComputedValue(v: cvtNumber, number: 1)
        res.add((cptFlexShrink, val, global))
      if i < d.value.len:
        # flex-basis
        let val = CSSComputedValue(v: cvtLength, length: ?cssLength(d.value[i]))
        res.add((cptFlexBasis, val, global))
      else: # omitted, default to 0px
        let val = CSSComputedValue(
          v: cvtLength,
          length: CSSLength(unit: UNIT_PX, num: 0)
        )
        res.add((cptFlexBasis, val, global))
    else:
      res.add((cptFlexGrow, getDefault(cptFlexGrow), global))
      res.add((cptFlexShrink, getDefault(cptFlexShrink), global))
      res.add((cptFlexBasis, getDefault(cptFlexBasis), global))
  of cstFlexFlow:
    let global = cssGlobal(d)
    if global == cvtNoglobal:
      var i = 0
      d.value.skipWhitespace(i)
      if i >= d.value.len:
        return err()
      if (let dir = cssFlexDirection(d.value[i]); dir.isSome):
        # flex-direction
        let val = CSSComputedValue(v: cvtFlexDirection, flexdirection: dir.get)
        res.add((cptFlexDirection, val, global))
        inc i
        d.value.skipWhitespace(i)
      if i < d.value.len:
        let wrap = ?cssFlexWrap(d.value[i])
        let val = CSSComputedValue(v: cvtFlexWrap, flexwrap: wrap)
        res.add((cptFlexWrap, val, global))
    else:
      res.add((cptFlexDirection, getDefault(cptFlexDirection), global))
      res.add((cptFlexWrap, getDefault(cptFlexWrap), global))
  return ok()

proc getComputedValues(d: CSSDeclaration): seq[CSSComputedEntry] =
  var res: seq[CSSComputedEntry] = @[]
  if res.getComputedValues0(d).isOk:
    return res
  return @[]

proc addValues*(builder: var CSSComputedValuesBuilder,
    decls: seq[CSSDeclaration], origin: CSSOrigin) =
  for decl in decls:
    if decl.important:
      builder.importantProperties[origin].add(getComputedValues(decl))
    else:
      builder.normalProperties[origin].add(getComputedValues(decl))

proc applyValue(vals: CSSComputedValues, prop: CSSPropertyType,
    val: CSSComputedValue, global: CSSGlobalValueType,
    parent: CSSComputedValues, previousOrigin: CSSComputedValues) =
  let parentVal = if parent != nil:
    parent[prop]
  else:
    nil
  case global
  of cvtInherit:
    if parentVal != nil:
      vals[prop] = parentVal
    else:
      vals[prop] = getDefault(prop)
  of cvtInitial:
    vals[prop] = getDefault(prop)
  of cvtUnset:
    if inherited(prop):
      # inherit
      if parentVal != nil:
        vals[prop] = parentVal
      else:
        vals[prop] = getDefault(prop)
    else:
      # initial
      vals[prop] = getDefault(prop)
  of cvtRevert:
    if previousOrigin != nil:
      vals[prop] = previousOrigin[prop]
    else:
      vals[prop] = getDefault(prop)
  of cvtNoglobal:
    vals[prop] = val

func inheritProperties*(parent: CSSComputedValues): CSSComputedValues =
  new(result)
  for prop in CSSPropertyType:
    if inherited(prop) and parent[prop] != nil:
      result[prop] = parent[prop]
    else:
      result[prop] = getDefault(prop)

func copyProperties*(props: CSSComputedValues): CSSComputedValues =
  new(result)
  result[] = props[]

func rootProperties*(): CSSComputedValues =
  new(result)
  for prop in CSSPropertyType:
    result[prop] = getDefault(prop)

func hasValues*(builder: CSSComputedValuesBuilder): bool =
  for origin in CSSOrigin:
    if builder.normalProperties[origin].len > 0:
      return true
    if builder.importantProperties[origin].len > 0:
      return true
  return false

func buildComputedValues*(builder: CSSComputedValuesBuilder):
    CSSComputedValues =
  new(result)
  var previousOrigins: array[CSSOrigin, CSSComputedValues]
  block:
    let origin = ORIGIN_USER_AGENT
    for build in builder.normalProperties[origin]:
      result.applyValue(build.t, build.val, build.global, builder.parent, nil)
    previousOrigins[origin] = result.copyProperties()
  # Presentational hints override user agent style, but respect user/author
  # style.
  if builder.preshints != nil:
    for prop in CSSPropertyType:
      if builder.preshints[prop] != nil:
        result[prop] = builder.preshints[prop]
  block:
    let origin = ORIGIN_USER
    let prevOrigin = ORIGIN_USER_AGENT
    for build in builder.normalProperties[origin]:
      result.applyValue(build.t, build.val, build.global, builder.parent,
        previousOrigins[prevOrigin])
    # save user origins so author can use them
    previousOrigins[origin] = result.copyProperties()
  block:
    let origin = ORIGIN_AUTHOR
    let prevOrigin = ORIGIN_USER
    for build in builder.normalProperties[origin]:
      result.applyValue(build.t, build.val, build.global, builder.parent,
        previousOrigins[prevOrigin])
    # no need to save user origins
  block:
    let origin = ORIGIN_AUTHOR
    let prevOrigin = ORIGIN_USER
    for build in builder.importantProperties[origin]:
      result.applyValue(build.t, build.val, build.global, builder.parent,
        previousOrigins[prevOrigin])
    # important, so no need to save origins
  block:
    let origin = ORIGIN_USER
    let prevOrigin = ORIGIN_USER_AGENT
    for build in builder.importantProperties[origin]:
      result.applyValue(build.t, build.val, build.global, builder.parent,
        previousOrigins[prevOrigin])
    # important, so no need to save origins
  block:
    let origin = ORIGIN_USER_AGENT
    for build in builder.importantProperties[origin]:
      result.applyValue(build.t, build.val, build.global, builder.parent, nil)
    # important, so no need to save origins
  # set defaults
  for prop in CSSPropertyType:
    if result[prop] == nil:
      if inherited(prop) and builder.parent != nil and
          builder.parent[prop] != nil:
        result[prop] = builder.parent[prop]
      else:
        result[prop] = getDefault(prop)
  if result{"float"} != FLOAT_NONE:
    #TODO it may be better to handle this in layout
    let display = result{"display"}.blockify()
    if display != result{"display"}:
      result{"display"} = display
