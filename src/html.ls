fs = require \fs
markdown = require \marked
{memoize, is-in, tagged, yaml, deltos-home, read-config} = require \./util
{get-all-entries} = require \./entries
{map, take, sort-by, sort-with, reverse} = require \prelude-ls

# placeholder globals; only required as needed
domino = RSS = eep = Section = {}

export render = ->
  it.link = '/by-id/' + it.id + \.html
  build-page-html entry-rules!, it

export build-private-reference = ->
  build-site-core get-all-entries!, deltos-home + \private/

export build-site = ->
  # only published entries are rendered to the public html
  entries = get-all-entries!.filter tagged \published
  # hidden entries have html built but don't show up in rss or search
  # good for meta pages (index, archive, search) and drafts
  rss-entries = entries.filter -> not tagged \hidden, it
  root = deltos-home + \site/
  after = -> fs.write-file-sync (root + \deltos.json), entries-to-json entries
  build-site-core entries, root, rss-entries, after

build-site-core = (entries, site-root, rss-entries, after) ->
  html-init!
  build-site-html site-root, entries
  if rss-entries
    rss-entries = rss-entries |> sort-by (.date) |> reverse
    build-rss site-root, read-config!, rss-entries
  after?!

export dump-json = ->
  entries = get-rendered-entries! |> sort-by (.date) |> reverse
  entries-to-json entries

entries-to-json = (entries) ->
  html-init!
  out = []
  for entry in entries
    data = build-page-data entry-rules!, entry
    out.push JSON.stringify data
  return out.join "\n"

html-init = ->
  # the requires for this are slow, so no point in adding them on the cli
  eep := require \./equaeverpoise
  Section := eep.Section
  domino := require \domino
  RSS := require \rss

build-page-core = (eep, content) ->
  # This builds a whole page with <head> etc.
  if content.raw-body
    content.body = read-entry-body content
  template = get-template!
  eep.push template.body, content, template.body
  if content.title then template.title = content.title
  add-meta-tags template, content
  return {dom: template, entry: content}

build-page-html = (eep, content) ->
  build-page-core(eep, content).dom.outerHTML

build-page-data = (eep, content) ->
  # for JSON dump
  {dom, entry} = build-page-core(eep, content)
  entry.searchable-text = entry.title + "\n" + dom.query-selector('.content').text-content
  return entry

add-meta-tags = (dom, entry) ->
  metadata = get-meta-data dom, entry
  for key in <[ title description image ]>
    set-meta dom, "og:#key", metadata[key]
    entry[key] = metadata[key]
  # Twitter's summary_large_image looks better when an image is available,
  # but looks horrible with small logos, so adjust accordingly
  card-type = if entry.first-image then \summary_large_image else \summary
  set-meta dom, \twitter:card, card-type

default-image = (dom) ->
  # a logo here for pages that are text-only
  dom.query-selector("meta[property=\"og:image\"]")?.attributes.default?.value

set-meta = (dom, prop, val) ->
  # used for open graph/twitter cards
  if not val then val = ''
  dom.query-selector("meta[property=\"#prop\"]").set-attribute \content, val

get-meta-data = (dom, entry) ->
  # while it's a little weird, this is data for meta-tags rather than generic "metadata"
  title: entry.title
  description: dom.query-selector(\p)?.text-content.split("\n").join ' '
  image: (entry.first-image or default-image dom)

get-rendered-entries = ->
  # This just builds a body
  entries = get-all-entries!
  for entry in entries
    entry.body = read-entry-body entry
  return entries

begins-with = (prefix, str) -> str.substr(0, prefix.length) == prefix

read-entry-body = ->
  raw = it.raw-body
  expanded = ''
  if not raw then return '' # it's ok to be empty
  for line in raw.split "\n"
    if begins-with \!, line
      line = line.slice 1 # discard exclamation
      words = line.split ' '
      command = words.shift!
      switch command
      | \img =>
        img-src = words.shift!
        img-tag = "<img src=\"#{img-src}\"/>"
        caption = if words.length then ('<p class="caption">' + words.join(' ') + '</p>') else ''
        line = "<div class=\"img\">" + img-tag + caption + "</div>"
        # used for meta tags
        if not it.first-image
          it.first-image = img-src
      | \video =>
        vid-tag = """<video preload="auto" autoplay="autoplay" loop="loop" style="width: 100%; height: auto;" controls> <source src="#{words.shift!}" type='video/webm; codecs="vp8, vorbis"'></source> </video>"""
        caption = if words.length then ('<p class="caption">' + words.join(' ') + '</p>') else ''
        line = "<div class=\"img\">" + vid-tag + caption + "</div>"
      # note: this originally had spaces but that causes marked to add a <p> tag :(
      | \search => line = '<div class="search"><input class="deltos-search" type="text"></input><div class="deltos-results"></div><script src="/search.js"></script></div>'
      | \archive => line = build-list-page!.join "\n"
      | \children => line = build-list-page(get-child-entries it).join "\n"
      | \recent => line = build-list-page!.slice(0, 5).join "\n"
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
  #TODO group magic tags somewhere else
  tags = it.tags.filter(-> it != \published).join ", "
  "- [#{it.title}](/by-id/#{it.id}.html) <span class=\"tags\">#{tags}</span>"

build-list-page = (entries) ->
  if not entries then entries = get-all-entries!

  # remove hidden entries
  entries = entries
    .filter (tagged \published)
    .filter (-> not tagged \hidden, it)

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

build-site-html = (root, entries) ->
  # update individual post html
  for entry in entries
    fname = root + "/by-id/" + entry.id + ".html"
    fs.write-file-sync fname, render entry

build-rss = (root, config, entries) ->
  rss = new RSS {
    title: config.site.title
    description: config.site.description
    generator: \deltos
    site_url: config.site.url
    feed_url: config.site.url + "/index.rss"
    pubDate: new Date!
  }

  for entry in entries
    entry.description = entry.body
    entry.categories = entry.tags
    entry.url = entry.link
    entry.guid = entry.link
    rss.item entry

  fs.write-file-sync (root + "index.rss"), rss.xml!



