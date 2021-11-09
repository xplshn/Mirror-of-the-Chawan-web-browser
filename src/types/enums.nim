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

  DisplayType* = enum
    DISPLAY_INLINE, DISPLAY_BLOCK, DISPLAY_LIST_ITEM, DISPLAY_TABLE_COLUMN,
    DISPLAY_INLINE_BLOCK, DISPLAY_NONE

  InputType* = enum
    INPUT_UNKNOWN, INPUT_BUTTON, INPUT_CHECKBOX, INPUT_COLOR, INPUT_DATE,
    INPUT_DATETIME_LOCAL, INPUT_EMAIL, INPUT_FILE, INPUT_HIDDEN, INPUT_IMAGE,
    INPUT_MONTH, INPUT_NUMBER, INPUT_PASSWORD, INPUT_RADIO, INPUT_RANGE,
    INPUT_RESET, INPUT_SEARCH, INPUT_SUBMIT, INPUT_TEL, INPUT_TEXT, INPUT_TIME,
    INPUT_URL, INPUT_WEEK

  WhitespaceType* = enum
    WHITESPACE_NORMAL, WHITESPACE_NOWRAP, WHITESPACE_PRE, WHITESPACE_PRE_LINE,
    WHITESPACE_PRE_WRAP

  TagType* = enum
    TAG_UNKNOWN, TAG_HTML, TAG_BASE, TAG_HEAD, TAG_LINK, TAG_META, TAG_STYLE,
    TAG_TITLE, TAG_BODY, TAG_ADDRESS, TAG_ARTICLE, TAG_ASIDE, TAG_FOOTER,
    TAG_HEADER, TAG_H1, TAG_H2, TAG_H3, TAG_H4, TAG_H5, TAG_H6, TAG_HGROUP,
    TAG_MAIN, TAG_NAV, TAG_SECTION, TAG_BLOCKQUOTE, TAG_DD, TAG_DIV, TAG_DL,
    TAG_DT, TAG_FIGCAPTION, TAG_FIGURE, TAG_HR, TAG_LI, TAG_OL, TAG_P, TAG_PRE,
    TAG_UL, TAG_A, TAG_ABBR, TAG_B, TAG_BDI, TAG_BDO, TAG_BR, TAG_CITE,
    TAG_CODE, TAG_DATA, TAG_DFN, TAG_EM, TAG_I, TAG_KBD, TAG_MARK, TAG_Q,
    TAG_RB, TAG_RP, TAG_RT, TAG_RTC, TAG_RUBY, TAG_S, TAG_SAMP, TAG_SMALL,
    TAG_SPAN, TAG_STRONG, TAG_SUB, TAG_SUP, TAG_TIME, TAG_U, TAG_VAR, TAG_WBR,
    TAG_AREA, TAG_AUDIO, TAG_IMG, TAG_MAP, TAG_TRACK, TAG_VIDEO,
    TAG_IFRAME, TAG_OBJECT, TAG_PARAM, TAG_PICTURE, TAG_PORTAL, TAG_SOURCE,
    TAG_CANVAS, TAG_NOSCRIPT, TAG_SCRIPT, TAG_DEL, TAG_INS, TAG_CAPTION,
    TAG_COL, TAG_COLGROUP, TAG_TABLE, TAG_TBODY, TAG_TD, TAG_TFOOT, TAG_TH,
    TAG_THEAD, TAG_TR, TAG_BUTTON, TAG_DATALIST, TAG_FIELDSET, TAG_FORM,
    TAG_INPUT, TAG_LABEL, TAG_LEGEND, TAG_METER, TAG_OPTGROUP, TAG_OPTION,
    TAG_OUTPUT, TAG_PROGRESS, TAG_SELECT, TAG_TEXTAREA, TAG_DETAILS,
    TAG_DIALOG, TAG_MENU, TAG_SUMMARY, TAG_BLINK, TAG_CENTER, TAG_CONTENT,
    TAG_DIR, TAG_FONT, TAG_FRAME, TAG_NOFRAMES, TAG_FRAMESET, TAG_STRIKE, TAG_TT

  CSSTokenType* = enum
    CSS_NO_TOKEN, CSS_IDENT_TOKEN, CSS_FUNCTION_TOKEN, CSS_AT_KEYWORD_TOKEN,
    CSS_HASH_TOKEN, CSS_STRING_TOKEN, CSS_BAD_STRING_TOKEN, CSS_URL_TOKEN,
    CSS_BAD_URL_TOKEN, CSS_DELIM_TOKEN, CSS_NUMBER_TOKEN, CSS_PERCENTAGE_TOKEN,
    CSS_DIMENSION_TOKEN, CSS_WHITESPACE_TOKEN, CSS_CDO_TOKEN, CSS_CDC_TOKEN,
    CSS_COLON_TOKEN, CSS_SEMICOLON_TOKEN, CSS_COMMA_TOKEN, CSS_RBRACKET_TOKEN,
    CSS_LBRACKET_TOKEN, CSS_LPAREN_TOKEN, CSS_RPAREN_TOKEN, CSS_LBRACE_TOKEN,
    CSS_RBRACE_TOKEN

  CSSUnit* = enum
    UNIT_CM, UNIT_MM, UNIT_IN, UNIT_PX, UNIT_PT, UNIT_PC,
    UNIT_EM, UNIT_EX, UNIT_CH, UNIT_REM, UNIT_VW, UNIT_VH, UNIT_VMIN, UNIT_VMAX,
    UNIT_PERC

  CSSPosition* = enum
    POSITION_STATIC, POSITION_RELATIVE, POSITION_ABSOLUTE, POSITION_FIXED,
    POSITION_INHERIT

  CSSFontStyle* = enum
    FONTSTYLE_NORMAL, FONTSTYLE_ITALIC, FONTSTYLE_OBLIQUE

  CSSRuleType* = enum
    RULE_ALL, RULE_COLOR, RULE_MARGIN, RULE_MARGIN_TOP, RULE_MARGIN_LEFT,
    RULE_MARGIN_RIGHT, RULE_MARGIN_BOTTOM, RULE_FONT_STYLE, RULE_DISPLAY,
    RULE_CONTENT

  CSSGlobalValueType* = enum
    VALUE_INITIAL, VALUE_INHERIT, VALUE_REVERT, VALUE_UNSET

  CSSValueType* = enum
    VALUE_NONE, VALUE_LENGTH, VALUE_COLOR, VALUE_CONTENT, VALUE_DISPLAY, VALUE_FONT_STYLE

  DrawInstructionType* = enum
    DRAW_TEXT, DRAW_GOTO, DRAW_FGCOLOR, DRAW_BGCOLOR, DRAW_STYLE, DRAW_RESET

  FormatContextType* = enum
    CONTEXT_BLOCK, CONTEXT_INLINE

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
