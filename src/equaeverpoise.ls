#prelude funcs: map, pairs-to-obj
prelude = require \prelude-ls
pairs-to-obj = prelude.pairs-to-obj

string2html = (el, html) ->
  # el needs to be an actual node we can grab a document from
  div = el.owner-document.create-element \div
  div.innerHTML = html
  return div.child-nodes

get-first-child = ->
  # We want the first child that's an actual node, not a comment or text
  fc = it.first-child
  while fc.node-type != 1
    fc = fc.next-sibling
  return fc

class Rule
  # A rule for a single mapping
  (@selector, @accessor, opts=null) ~>
    @_push = opts?.push
    @_pull = opts?.extract

  push: (root, data) ~>
    if @_push
      @_push root.query-selector(@selector), data[@accessor]
    else
      root.query-selector(@selector).innerHTML = data[@accessor]

  pull: (root) ~>
    if @_pull
      [@accessor, @_pull root.query-selector(@selector)]
    else
      [@accessor, root.query-selector(@selector).innerHTML]

class ListRule
  # A rule for lists
  # There's no good way to tell how many "children" a list has unless they're all a single node,
  # so that assumption is baked in here
  (@selector, @accessor, opts=null) ~>
    @_push = opts?.push or @default-push
    @_pull = opts?.extract or @default-pull

  default-push: (node, item) ->
    node.innerHTML = item
    return node

  default-pull: (node) ->
    node.innerHTML

  push: (root, data) ~>
    base = root.query-selector(@selector)
    template = get-first-child(base).outerHTML
    base.innerHTML = ''
    for item in data[@accessor]
      node = string2html(root, template).0
      @_push(node, item)
      base.append-child node

  pull: (root) ~>
    results = []
    for node in root.query-selector(@selector).child-nodes
      if node.node-type == 1
        results.push @_pull node

    return [@accessor, results]

class Section
  # A page section
  -> @rules = []

  rule: (sel, acc, opts) ~>
    @rules.push new Rule sel, acc, opts

  push: (root, data) ~>
    @rules.map -> it.push root, data

  pull: (root) ~>
    pairs-to-obj @rules.map -> it.pull root

  subsection: (sel, sec) ~>
    @rules.push sel

  list-rule: (sel, acc, opts) ~>
    @rules.push new ListRule sel, acc, opts

export Section
