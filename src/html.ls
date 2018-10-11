fs = require \fs-extra
{markdown, get-mtime, memoize, is-in, tagged, yaml, yaml-dump, deltos-home, read-config, get-filename, get-url} = require \./util
{get-all-entries, get-raw-entry} = require \./entries
{map, take, sort-by, sort-with, reverse} = require \prelude-ls
{dirname} = require \path
{render-block} = require \./blocks

# placeholder globals; only required as needed
domino = RSS = eep = Section = {}

export render = ->
  it.link = get-url it
  build-page-html entry-rules!, it

export build-site = ->
  # only published entries are rendered to the public html
  entries = get-all-entries!.filter tagged \published

  # hidden entries have html built but don't show up in rss or search
  # good for meta pages (index, archive, search) and drafts
  public-entries = entries.filter -> not tagged \hidden, it

  root = deltos-home + \site/
  after = -> fs.write-file-sync (root + \deltos.json), entries-to-json public-entries, (root + \deltos.json)
  build-site-core entries, root, public-entries, after

build-site-core = (entries, site-root, public-entries, after) ->
  html-init!
  clean-dir site-root, entries
  flag-updated site-root, entries
  build-site-html site-root, entries
  if public-entries
    public-entries = public-entries |> sort-by (.date) |> reverse
    build-rss site-root, read-config!, public-entries
  after?!

clean-dir = (root, entries) ->
  # anything not in the list of entries should be deleted
  # example case: you un-publish something
  try
    files = fs.readdir-sync "#{root}/by-id/"
  catch
    # this can happen if the directory doesn't exist, which means we're done
    return

  #assumption: all files are of the form [id].[something]
  for file in files
    id = file.split('.').0
    if entries.filter(-> id == it.id).length < 1
      fs.remove-sync "#{root}/by-id/#{file}"

flag-updated = (root, entries) ->
  for entry in entries
    # first check: file mtime
    html-fname = "#{root}/by-id/#{entry.id}/index.html"
    if get-mtime(html-fname) < get-mtime get-filename(entry.id) + '/deltos'
      entry.updated = true

  for entry in entries
    if entry.updated then continue # no point in marking it again
    # second check: did a child or parent update?
    if entry.children
      for child in entries.filter(-> is-in entry.children, it.id)
        if child.updated then entry.updated = true
    if entry.parents
      for parent in entries.filter(-> is-in entry.parents, it.id)
        if parent.updated then entry.updated = true

export dump-json = ->
  entries = get-rendered-entries! |> sort-by (.date) |> reverse
  entries-to-json entries

entries-to-json = (entries, cache-file) ->
  cache = {}
  if cache-file
    try
      lines = fs.read-file-sync(cache-file, \utf-8).split "\n"
      for line in lines
        if line == '' then continue
        entry = JSON.parse(line)
        cache[entry.id] = entry
    catch e
      # probably just the file not existing
      \ok

  html-init!
  out = []
  for entry in entries
    if cache-file and cache[entry.id] and !entry.updated
      data = cache[entry.id]
    else
      entry.updated = true
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
  if tagged \hidden, content
    content.date = '' # hidden pages shouldn't show dates
  template = get-template content.template
  # if the entry has not been updated, this can be skipped
  if content.updated
    eep.push template.body, content, template.body
    if content.title then template.title = content.title
    add-meta-tags template, content
  else
    template = {outerHTML: false}
  return {dom: template, entry: content}

build-page-html = (eep, content) ->
  build-page-core(eep, content).dom.outerHTML

build-page-data = (eep, content) ->
  # for JSON dump
  build-page-core(eep, content).entry

add-meta-tags = (dom, entry) ->
  # some opengraph consumers (like Twitter) can't use relative image paths
  if entry.first-image and not entry.meta-image
    parts = entry.first-image.split '/'
    fname = parts[*-1]
    ftype = fname.split('.')[*-1]
    path = parts[0 til -1].join '/'
    entry.thumbnail = read-config!.url + path + '/' + (fname.substr 0, (fname.length - 6)) + '.s.' + ftype
    entry.meta-image = read-config!.url + entry.first-image
  metadata = get-meta-data dom, entry
  for key in <[ title description image ]>
    set-meta dom, "og:#key", metadata[key]
    entry[key] = metadata[key]

  # set the meta description
  dom.query-selector("meta[name=\"description\"]").set-attribute \content, metadata.description

  # Twitter's summary_large_image looks better when an image is available,
  # but looks horrible with small logos, so adjust accordingly
  card-type = if entry.meta-image then \summary_large_image else \summary
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
  image: (entry.meta-image or default-image dom)

get-rendered-entries = ->
  # This just builds a body
  entries = get-all-entries!
  for entry in entries
    entry.body = read-entry-body entry
  return entries

begins-with = (prefix, str) -> str.substr(0, prefix.length) == prefix

RENDERED_CACHE = {}
read-entry-body = (entry) ->
  if RENDERED_CACHE[entry.id] then return RENDERED_CACHE[entry.id]

  if entry.children
    # have to read dependencies first so metadata is right
    # would be great if this was more general
    entries = get-all-entries!
    for child in entry.children
      child-entry = entries.filter(-> child == it.id).0
      read-entry-body child-entry

  expanded = ''
  for block in entry.raw-body.split "\n\n"
    expanded += "\n\n" + render-block block, entry
  expanded = markdown expanded
  RENDERED_CACHE[entry.id] = expanded
  return expanded

get-template = memoize (template="single") ->
  fs.read-file-sync (deltos-home + "theme/#{template}.html"), \utf-8 |> ->
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

build-site-html = (root, entries) ->
  # update individual post html
  for entry in entries
    suffix = "/by-id/#{entry.id}"

    # this returns false if the entry does not need updating
    html = render entry
    if not html then continue

    fs.mkdirp-sync "#{root}#{suffix}"
    fs.write-file-sync "#{root}#{suffix}/index.html", html

    if entry.slug # for fixed names
      # have to symlink to a file (rather than dir) here so that the root index.html works
      fs.remove-sync "#{root}/#{entry.slug}.html"
      fs.mkdirp-sync dirname "#{root}/#{entry.slug}"
      fs.symlink-sync "#{root}#{suffix}/index.html", "#{root}/#{entry.slug}.html"

    # write a deltos source file for other people to import
    [head, body] = get-raw-entry entry.id
    head.source = "#{read-config!.url}#{suffix}/index.html"

    orig = get-filename(entry.id)

    # this will get the meta and deltos files + others
    for fname in fs.readdir-sync orig
      fs.remove-sync "#{root}#{suffix}/#fname"
      fs.symlink-sync orig + '/' + fname, "#{root}#{suffix}/#fname"

build-rss = (root, config, entries) ->
  # first make the default RSS
  make-rss-file config, root, \index, entries

  # now make other files
  config.rss = config.rss or {}
  {philtre} = require \philtre
  for name, query of config.rss
    entries-current = philtre query, entries
    make-rss-file config, root, name, entries-current

make-rss-file = (config, root, name, entries) ->
  rss = new RSS {
    title: config.title
    description: config.description
    generator: \deltos
    site_url: config.url
    feed_url: config.url + "/#name.rss"
    pubDate: new Date!
    author: config.author
  }

  # This determines the number of entries in the feed.
  # Could be a config var but haven't felt the need.
  for entry in entries.slice 0, 5
   rss.item do
     title: entry.title
     date: entry.date
     description: entry.body
     categories: entry.tags
     url: entry.link
     guid: entry.link.split('#').0

  fs.write-file-sync (root + name + ".rss"), rss.xml!
