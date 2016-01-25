fs = require \fs
ls = require \livescript
markdown = require \marked
{memoize, is-in, tagged, yaml, deltos-home} = require \./util
{get-all-entries} = require \./entries
{map, take, sort-by, sort-with, reverse} = require \prelude-ls

# placeholder globals; only required as needed
ls = domino = RSS = eep = Section = {}

export render = ->
  it.link = '/by-id/' + it.id + \.html
  build-page entry-rules!, it

export build-private-reference = ->
  build-site true

export build-site = (priv=false)->
  html-init!
  config = read-config!
  published = config.site.tag
  site-root = deltos-home + \site/
  if priv then site-root = deltos-home + \private/

  entries = get-entries-to-build published, priv
  build-site-html site-root, entries
  build-rss site-root, config, entries

export all-to-json = ->
  html-init!
  entries = get-rendered-entries! |> sort-by (.date) |> reverse
  for entry in entries
    entry.tags = entry.tags.map String # numeric tags should still be strings
    entry.body = searchable-text entry.body
    console.log JSON.stringify entry

html-init = ->
  # the requires for this are slow, so no point in adding them on the cli
  eep := require \./equaeverpoise
  Section := eep.Section
  domino := require \domino
  RSS := require \rss
  ls := require \livescript

read-config = memoize ->
  try
    yaml fs.read-file-sync (deltos-home + \config), \utf-8
  catch e
    console.error "Error reading config:\n" + e.message
    process.exit 1

build-page = (eep, content) ->
  # This builds a whole page with <head> etc.
  if content.raw-body
    content.body = read-entry-body content
  template = get-template!
  eep.push template.body, content, template.body
  if content.title then template.title = content.title
  return template.outerHTML

get-rendered-entries = ->
  # This just builds a body
  entries = get-all-entries!
  for entry in entries
    entry.body = read-entry-body entry
  return entries

begins-with = (prefix, str) -> str.substr(0, prefix.length) == prefix

# XXX note that eval'd code has full access to the calling context 
# (which is to say the interior of this script)
export eval-ls = ->
  eval ls.compile it, bare: true

read-entry-body = ->
  raw = it.raw-body
  expanded = ''
  if not raw then return '' # it's ok to be empty
  for line in raw.split "\n"
    if begins-with \], line
        line = eval-ls line.substr 1
    else if begins-with \!, line
      line = line.slice 1 # discard exclamation
      words = line.split ' '
      command = words.shift!
      switch command
      | \img =>
        img-tag = "<img src=\"#{words.shift!}\"/>"
        caption = if words.length then ('<p class="caption">' + words.join(' ') + '</p>') else ''
        line = "<div class=\"img\">" + img-tag + caption + "</div>"
      | \video =>
        vid-tag = """<video preload="auto" autoplay="autoplay" loop="loop" style="width: 100%; height: auto;" controls> <source src="#{words.shift!}" type='video/webm; codecs="vp8, vorbis"'></source> </video>"""
        caption = if words.length then ('<p class="caption">' + words.join(' ') + '</p>') else ''
        line = "<div class=\"img\">" + vid-tag + caption + "</div>"
      | \archive => line = build-list-page!.join "\n"
      | \children => line = build-list-page(get-child-entries it).join "\n"
      | \.rule =>
          # use the markdown thing and replace the default <p> tag
          line = '<p class="rule">' + markdown(words.join ' ').substr 3
      | otherwise => \noop # unknown word, maybe throw error?
    expanded += line + "\n"
  expanded = deltos-link-to-html expanded
  return markdown expanded

get-child-entries = (parent) ->
  out = get-all-entries!.filter(-> -1 != parent.children.index-of it.id)
  return out

get-template = memoize ->
  fs.read-file-sync (deltos-home + \single.html), \utf-8 |> ->
    domino.create-window(it).document

searchable-text = ->
  domino.create-window(it).document.body.text-content.to-lower-case!

entry-rules = ->
  # These are Equaeverpoise rules
  # they map selectors to json paths
  page = new Section!
  page.rule \h1, \title
  page.rule \h4, \subtitle
  page.rule \.location, \location
  page.rule \.collections, \collections
  page.rule \.date, \date
  page.rule \.content, \body
  link-pusher = (el, link) -> el.href = link
  page.rule \.article-link, \link, {push: link-pusher}
  return page

deltos-link-to-html = ->
  link-regex = /\.\(([^\/]*)\/\/([^\)]*)\)/g
  it.replace link-regex, (matched, label, dest) -> "<a href=\"/by-id/#{dest}.html\">#{label}</a>"

to-markdown-link = ->
  tags = it.tags.filter(-> it != \published).join ", "
  "- [#{it.title}](/by-id/#{it.id}.html) <span class=\"tags\">#{tags}</span>"

build-list-page = (entries) ->
  if not entries then entries = get-all-entries!

  # remove meta-entries like Archive, top page
  config = read-config!
  for tag in config.site["exclude-tags"]
    entries = entries.filter (-> not tagged tag, it)
  entries = entries.filter (-> tagged \published, it)

  sort-by (.date), entries |>
    reverse |>
    map to-markdown-link

#TODO - what if only some have order? Maybe not worth worrying about.
sort-order-then-date = (a, b) ->
  if a?.order and b?.order
    # for ordering, lower ranks higher
    if a.order < b.order then return 1 else return -1

  # compare by date - assume dates always differ
  if a.date > b.date then return -1 else return 1

# parent is an id, depth is depth remaining (so 0==done)
build-hierarchical-list = (entries, depth, parent=null) ->
  if depth == 0 then return ''# we're done
  if parent # we're only interested in children right now
    children = entries.filter -> it.parents and is-in it.parents, parent
  else # otherwise we want only top-level items
    children = entries.filter -> not it.parents

  children = sort-with sort-order-then-date, children

  out = ''
  spacer = if parent then '  ' else '' # list indentation
  for child in children
    out += spacer + (to-markdown-link child) + "\n"
    if depth > 0
      out +=  build-hierarchical-list(entries, depth - 1, child.id)
                .split("\n").map(-> spacer + it).join '\n'
  return out

get-entries-to-build = (published, priv) ->
  # If this is a public html version, only show entries tagged for publication
  # If private, use everything
  entries = get-rendered-entries!
  if not priv
    entries = entries.filter (tagged published)
  return entries |>
    sort-by (.date) |>
    reverse

build-site-html = (root, entries) ->
  # update individual post html
  for entry in entries
    page = render entry
    fname = root + "/by-id/" + entry.id + ".html"
    fs.write-file-sync fname, page

build-rss = (root, config, entries) ->
  rss = new RSS {
    title: config.site.title
    description: config.site.description
    generator: \deltos
    site_url: config.site.url
    feed_url: config.site.url + "/index.rss"
    pubDate: new Date!
  }

  for tag in config.site["exclude-tags"]
    entries = entries.filter (-> not tagged tag, it)

  for entry in entries
    entry.description = entry.body
    entry.categories = entry.tags
    entry.url = entry.link
    entry.guid = entry.link
    rss.item entry

  fs.write-file-sync (root + "index.rss"), rss.xml!



