import tables
import strutils

type
  NodeType* = enum
    UNKNOWN_NODE = 0,
    ELEMENT_NODE = 1,
    ATTRIBUTE_NODE = 2,
    TEXT_NODE = 3,
    CDATA_SECTION_NODE = 4,
    ENTITY_REFERENCE_NODE = 5,
    ENTITY_NODE = 6
    PROCESSING_INSTRUCTION_NODE = 7,
    COMMENT_NODE = 8,
    DOCUMENT_NODE = 9,
    DOCUMENT_TYPE_NODE = 10,
    DOCUMENT_FRAGMENT_NODE = 11,
    NOTATION_NODE = 12

  InputType* = enum
    INPUT_UNKNOWN, INPUT_BUTTON, INPUT_CHECKBOX, INPUT_COLOR, INPUT_DATE,
    INPUT_DATETIME_LOCAL, INPUT_EMAIL, INPUT_FILE, INPUT_HIDDEN, INPUT_IMAGE,
    INPUT_MONTH, INPUT_NUMBER, INPUT_PASSWORD, INPUT_RADIO, INPUT_RANGE,
    INPUT_RESET, INPUT_SEARCH, INPUT_SUBMIT, INPUT_TEL, INPUT_TEXT, INPUT_TIME,
    INPUT_URL, INPUT_WEEK

  TagType* = enum
    TAG_UNKNOWN, TAG_APPLET, TAG_BIG, TAG_HTML, TAG_BASE, TAG_BASEFONT,
    TAG_BGSOUND, TAG_HEAD, TAG_LINK, TAG_LISTING, TAG_META, TAG_STYLE,
    TAG_TITLE, TAG_BODY, TAG_ADDRESS, TAG_ARTICLE, TAG_ASIDE, TAG_FOOTER,
    TAG_HEADER, TAG_H1, TAG_H2, TAG_H3, TAG_H4, TAG_H5, TAG_H6, TAG_HGROUP,
    TAG_MAIN, TAG_NAV, TAG_SECTION, TAG_BLOCKQUOTE, TAG_DD, TAG_DIV, TAG_DL,
    TAG_DT, TAG_FIGCAPTION, TAG_FIGURE, TAG_HR, TAG_LI, TAG_OL, TAG_P, TAG_PRE,
    TAG_UL, TAG_A, TAG_ABBR, TAG_B, TAG_BDI, TAG_BDO, TAG_BR, TAG_NOBR,
    TAG_CITE, TAG_CODE, TAG_DATA, TAG_DFN, TAG_EM, TAG_EMBED, TAG_I, TAG_KBD,
    TAG_MARK, TAG_MARQUEE, TAG_Q, TAG_RB, TAG_RP, TAG_RT, TAG_RTC, TAG_RUBY,
    TAG_S, TAG_SAMP, TAG_SMALL, TAG_SPAN, TAG_STRONG, TAG_SUB, TAG_SUP,
    TAG_TIME, TAG_U, TAG_VAR, TAG_WBR, TAG_AREA, TAG_AUDIO, TAG_IMG, TAG_IMAGE,
    TAG_MAP, TAG_TRACK, TAG_VIDEO, TAG_IFRAME, TAG_OBJECT, TAG_PARAM,
    TAG_PICTURE, TAG_PORTAL, TAG_SOURCE, TAG_CANVAS, TAG_NOSCRIPT, TAG_NOEMBED,
    TAG_PLAINTEXT, TAG_XMP, TAG_SCRIPT, TAG_DEL, TAG_INS, TAG_CAPTION, TAG_COL,
    TAG_COLGROUP, TAG_TABLE, TAG_TBODY, TAG_TD, TAG_TFOOT, TAG_TH, TAG_THEAD,
    TAG_TR, TAG_BUTTON, TAG_DATALIST, TAG_FIELDSET, TAG_FORM, TAG_INPUT,
    TAG_KEYGEN, TAG_LABEL, TAG_LEGEND, TAG_METER, TAG_OPTGROUP, TAG_OPTION,
    TAG_OUTPUT, TAG_PROGRESS, TAG_SELECT, TAG_TEXTAREA, TAG_DETAILS,
    TAG_DIALOG, TAG_MENU, TAG_SUMMARY, TAG_BLINK, TAG_CENTER, TAG_CONTENT,
    TAG_DIR, TAG_FONT, TAG_FRAME, TAG_NOFRAMES, TAG_FRAMESET, TAG_STRIKE,
    TAG_TT, TAG_TEMPLATE, TAG_SARCASM

func getTagTypeMap(): Table[string, TagType] =
  for i in TagType:
    let enumname = $TagType(i)
    let tagname = enumname.split('_')[1..^1].join("_").tolower()
    result[tagname] = TagType(i)

func getInputTypeMap(): Table[string, InputType] =
  for i in InputType:
    let enumname = $InputType(i)
    let tagname = enumname.split('_')[1..^1].join("_").tolower()
    result[tagname] = InputType(i)

const tagTypeMap = getTagTypeMap()
const inputTypeMap = getInputTypeMap()


func tagType*(s: string): TagType =
  if tagTypeMap.hasKey(s):
    return tagTypeMap[s]
  else:
    return TAG_UNKNOWN

func inputType*(s: string): InputType =
  if inputTypeMap.hasKey(s):
    return inputTypeMap[s]
  else:
    return INPUT_UNKNOWN

const tagNameMap = (func(): Table[TagType, string] =
  for k, v in tagTypeMap:
    result[v] = k
)()

func tagName*(t: TagType): string =
  return tagNameMap[t]

const SelfClosingTagTypes* = {
  TAG_LI, TAG_P
}

const VoidTagTypes* = {
  TAG_AREA, TAG_BASE, TAG_BR, TAG_COL, TAG_FRAME, TAG_HR, TAG_IMG, TAG_INPUT,
  TAG_SOURCE, TAG_TRACK, TAG_LINK, TAG_META, TAG_PARAM, TAG_WBR, TAG_HR
}

const PClosingTagTypes* = {
  TAG_ADDRESS, TAG_ARTICLE, TAG_ASIDE, TAG_BLOCKQUOTE, TAG_DETAILS, TAG_DIV,
  TAG_DL, TAG_FIELDSET, TAG_FIGCAPTION, TAG_FIGURE, TAG_FOOTER, TAG_FORM,
  TAG_H1, TAG_H2, TAG_H3, TAG_H4, TAG_H5, TAG_H6, TAG_HEADER, TAG_HGROUP,
  TAG_HR, TAG_MAIN, TAG_MENU, TAG_NAV, TAG_OL, TAG_P, TAG_PRE, TAG_SECTION,
  TAG_TABLE, TAG_UL
}

const HTagTypes* = {
  TAG_H1, TAG_H2, TAG_H3, TAG_H4, TAG_H5, TAG_H6
}

const HeadTagTypes* = {
  TAG_BASE, TAG_LINK, TAG_META, TAG_TITLE, TAG_NOSCRIPT, TAG_SCRIPT, TAG_NOFRAMES, TAG_STYLE, TAG_HEAD
}

# 4.10.2 Categories
const FormAssociatedElements* = {
  TAG_BUTTON, TAG_FIELDSET, TAG_INPUT, TAG_OBJECT, TAG_OUTPUT, TAG_SELECT, TAG_TEXTAREA, TAG_IMG
}

#TODO support all the other ones
const SupportedFormAssociatedElements* = {
  TAG_SELECT, TAG_INPUT
}

const ListedElements* = {
  TAG_BUTTON, TAG_FIELDSET, TAG_INPUT, TAG_OBJECT, TAG_OUTPUT, TAG_SELECT, TAG_TEXTAREA
}

const SubmittableElements* = {
  TAG_BUTTON, TAG_INPUT, TAG_SELECT, TAG_TEXTAREA
}

const ResettableElements* = {
  TAG_INPUT, TAG_OUTPUT, TAG_SELECT, TAG_TEXTAREA
}

const AutocapitalizeInheritingElements* = {
  TAG_BUTTON, TAG_FIELDSET, TAG_INPUT, TAG_OUTPUT, TAG_SELECT, TAG_TEXTAREA
}

const LabelableElements* = {
  # input only if type not hidden
  TAG_BUTTON, TAG_INPUT, TAG_METER, TAG_OUTPUT, TAG_PROGRESS, TAG_SELECT, TAG_TEXTAREA
}

#https://html.spec.whatwg.org/multipage/parsing.html#the-stack-of-open-elements
#NOTE MathML not implemented
#TODO SVG foreignObject, SVG desc, SVG title
const SpecialElements* = {
 TAG_ADDRESS, TAG_APPLET, TAG_AREA, TAG_ARTICLE, TAG_ASIDE, TAG_BASE,
 TAG_BASEFONT, TAG_BGSOUND, TAG_BLOCKQUOTE, TAG_BODY, TAG_BR, TAG_BUTTON,
 TAG_CAPTION, TAG_CENTER, TAG_COL, TAG_COLGROUP, TAG_DD, TAG_DETAILS, TAG_DIR,
 TAG_DIV, TAG_DL, TAG_DT, TAG_EMBED, TAG_FIELDSET, TAG_FIGCAPTION, TAG_FIGURE,
 TAG_FOOTER, TAG_FORM, TAG_FRAME, TAG_FRAMESET, TAG_H1, TAG_H2, TAG_H3, TAG_H4,
 TAG_H5, TAG_H6, TAG_HEAD, TAG_HEADER, TAG_HGROUP, TAG_HR, TAG_HTML,
 TAG_IFRAME, TAG_IMG, TAG_INPUT, TAG_KEYGEN, TAG_LI, TAG_LINK, TAG_LISTING,
 TAG_MAIN, TAG_MARQUEE, TAG_MENU, TAG_META, TAG_NAV, TAG_NOEMBED, TAG_NOFRAMES,
 TAG_NOSCRIPT, TAG_OBJECT, TAG_OL, TAG_P, TAG_PARAM, TAG_PLAINTEXT, TAG_PRE,
 TAG_SCRIPT, TAG_SECTION, TAG_SELECT, TAG_SOURCE, TAG_STYLE, TAG_SUMMARY,
 TAG_TABLE, TAG_TBODY, TAG_TD, TAG_TEMPLATE, TAG_TEXTAREA, TAG_TFOOT, TAG_TH,
 TAG_THEAD, TAG_TITLE, TAG_TR, TAG_TRACK, TAG_UL, TAG_WBR, TAG_XMP 
}
