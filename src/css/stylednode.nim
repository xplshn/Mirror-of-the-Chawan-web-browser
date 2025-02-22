import css/selectorparser
import css/values
import html/dom

import chame/tags

# Container to hold a style and a node.
# Pseudo-elements are implemented using StyledNode objects without nodes. Input
# elements are implemented as internal "pseudo-elements."
#
# To avoid having to invalidate the entire tree on pseudo-class changes, each
# node holds a list of nodes their CSS values depend on. (This list may include
# the node itself.) In addition, nodes also store each value valid for
# dependency d. These are then used for checking the validity of StyledNodes.
#
# In other words - say we have to apply the author stylesheets of the following
# document:
#
# <style>
# div:hover { color: red; }
# :not(input:checked) + p { display: none; }
# </style>
# <div>This div turns red on hover.</div>
# <input type=checkbox>
# <p>This paragraph is only shown when the checkbox above is checked.
#
# That produces the following dependency graph (simplified):
# div -> div (hover)
# p -> input (checked)
#
# Then, to check if a node has been invalidated, we just iterate over all
# recorded dependencies of each StyledNode, and check if their registered value
# of the pseudo-class still matches that of its associated element.
#
# So in our example, for div we check if div's :hover pseudo-class has changed,
# for p we check whether input's :checked pseudo-class has changed.

type
  StyledType* = enum
    STYLED_ELEMENT, STYLED_TEXT, STYLED_REPLACEMENT

  DependencyType* = enum
    DEPEND_HOVER, DEPEND_CHECKED, DEPEND_FOCUS

  DependencyInfo* = object
    # All nodes we depend on, for each dependency type d.
    nodes*: array[DependencyType, seq[StyledNode]]
    # Previous value. The owner StyledNode is marked as invalid when one of
    # these no longer matches the DOM value.
    prev: array[DependencyType, bool]

  StyledNode* = ref object
    parent*: StyledNode
    node*: Node
    pseudo*: PseudoElem
    case t*: StyledType
    of STYLED_TEXT:
      text*: string
    of STYLED_ELEMENT:
      computed*: CSSComputedValues
      children*: seq[StyledNode]
      depends*: DependencyInfo
    of STYLED_REPLACEMENT:
      # replaced elements: quotes, or (TODO) markers, images
      content*: CSSContent

# For debugging
func `$`*(node: StyledNode): string =
  if node == nil:
    return "nil"
  case node.t
  of STYLED_TEXT:
    return "#text " & node.text
  of STYLED_ELEMENT:
    if node.node != nil:
      return $node.node
    return $node.pseudo
  of STYLED_REPLACEMENT:
    return "#replacement"

iterator branch*(node: StyledNode): StyledNode {.inline.} =
  var node = node
  while node != nil:
    yield node
    node = node.parent

iterator elementList*(node: StyledNode): StyledNode {.inline.} =
  for child in node.children:
    yield child

iterator elementList_rev*(node: StyledNode): StyledNode {.inline.} =
  for i in countdown(node.children.high, 0):
    yield node.children[i]

func findElement*(root: StyledNode; elem: Element): StyledNode =
  var stack: seq[StyledNode]
  for child in root.elementList_rev:
    if child.t == STYLED_ELEMENT and child.pseudo == PSEUDO_NONE:
      stack.add(child)
  let en = Node(elem)
  while stack.len > 0:
    let node = stack.pop()
    if node.node == en:
      return node
    for child in node.elementList_rev:
      if child.t == STYLED_ELEMENT and child.pseudo == PSEUDO_NONE:
        stack.add(child)

func isDomElement*(styledNode: StyledNode): bool {.inline.} =
  styledNode.t == STYLED_ELEMENT and styledNode.pseudo == PSEUDO_NONE

# DOM-style getters, for Element interoperability...
func parentElement*(node: StyledNode): StyledNode {.inline.} =
  node.parent

func checked(element: Element): bool =
  if element.tagType == TAG_INPUT:
    let input = HTMLInputElement(element)
    result = input.checked

func isValid*(styledNode: StyledNode): bool =
  if styledNode.t == STYLED_TEXT:
    return true
  if styledNode.t == STYLED_REPLACEMENT:
    return true
  if styledNode.node != nil and Element(styledNode.node).invalid:
    return false
  for d in DependencyType:
    for child in styledNode.depends.nodes[d]:
      assert child.node != nil
      let elem = Element(child.node)
      case d
      of DEPEND_HOVER:
        if child.depends.prev[d] != elem.hover:
          return false
      of DEPEND_CHECKED:
        if child.depends.prev[d] != elem.checked:
          return false
      of DEPEND_FOCUS:
        let focus = elem.document.focus == elem
        if child.depends.prev[d] != focus:
          return false
  return true

proc applyDependValues*(styledNode: StyledNode) =
  let elem = Element(styledNode.node)
  styledNode.depends.prev[DEPEND_HOVER] = elem.hover
  styledNode.depends.prev[DEPEND_CHECKED] = elem.checked
  let focus = elem.document.focus == elem
  styledNode.depends.prev[DEPEND_FOCUS] = focus
  elem.invalid = false

proc addDependency*(styledNode, dep: StyledNode; t: DependencyType) =
  if dep notin styledNode.depends.nodes[t]:
    styledNode.depends.nodes[t].add(dep)

func newStyledElement*(parent: StyledNode; element: Element;
    computed: CSSComputedValues; reg: DependencyInfo): StyledNode =
  return StyledNode(
    t: STYLED_ELEMENT,
    computed: computed,
    node: element,
    parent: parent,
    depends: reg
  )

func newStyledElement*(parent: StyledNode; element: Element): StyledNode =
  return StyledNode(t: STYLED_ELEMENT, node: element, parent: parent)

# Root
func newStyledElement*(element: Element): StyledNode =
  return StyledNode(t: STYLED_ELEMENT, node: element)

func newStyledElement*(parent: StyledNode; pseudo: PseudoElem;
    computed: CSSComputedValues; reg: sink DependencyInfo): StyledNode =
  return StyledNode(
    t: STYLED_ELEMENT,
    computed: computed,
    pseudo: pseudo,
    parent: parent,
    depends: reg
  )

func newStyledElement*(parent: StyledNode; pseudo: PseudoElem;
    computed: CSSComputedValues): StyledNode =
  return StyledNode(
    t: STYLED_ELEMENT,
    computed: computed,
    pseudo: pseudo,
    parent: parent
  )

func newStyledText*(parent: StyledNode; text: string): StyledNode =
  return StyledNode(t: STYLED_TEXT, text: text, parent: parent)

func newStyledText*(parent: StyledNode; text: Text): StyledNode =
  return StyledNode(t: STYLED_TEXT, text: text.data, node: text, parent: parent)

func newStyledReplacement*(parent: StyledNode; content: CSSContent): StyledNode =
  return StyledNode(t: STYLED_REPLACEMENT, parent: parent, content: content)
