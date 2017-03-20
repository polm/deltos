# default blocks for deltos
child_process = require \child_process
Markdown = require(\markdown-it)(html: true)
markdown = -> Markdown.render it
{get-all-entries} = require \./entries
{map, sort-by, sort-with, reverse} = require \prelude-ls
{deltos-home, read-config, is-in, tagged, get-filename, get-slug} = require \./util
width = read-config!.width or 500
exec = require('child_process').exec-sync
fs = require \fs-extra

blocks = {}

blocks.img = (block, entry) ->
  words = block.split(' ')
  words.shift!
  img-src = words.shift!trim!

  src-file = get-filename(entry.id) + '/' + img-src
  fname = img-src.split('/')[*-1]
  ftype = img-src.split('.')[*-1]

  thumbroot = get-filename(entry.id) + '/img/'
  img-src = "/by-id/#{entry.id}/img/#fname.l.#ftype"
  big-src = "/by-id/#{entry.id}/#fname"

  if not fs.exists-sync thumbroot + fname + '.l.' + ftype
    # this is done for every image
    fs.mkdirp thumbroot
    exec "convert \"#src-file\" -resize #{width}x1000 #thumbroot/#fname.l.#ftype"

  tag = "<a href=\"#{big-src}\"><img src=\"#{img-src}\"/></a>"
  caption = if words.length then ('<p class="caption">' + markdown(words.join(' ')).substr 3) else ''
  # for meta-tags
  if not entry.first-image
    cropped-header = "#thumbroot/#fname.c.#ftype"
    if not fs.exists-sync cropped-header
      # this is only necessary for the first image
      exec "convert \"#src-file\" -resize '#{width}x200^' -gravity center -extent #{width}x200 #thumbroot/#fname.c.#ftype"
      exec "convert \"#src-file\" -resize '90x90^' -gravity center -crop 90x90+0+0 #thumbroot/#fname.s.#ftype"

    entry.first-image = "/by-id/#{entry.id}/img/#fname.c.#ftype"
  return "<div class=\"img\">" + tag + caption + "</div>"

blocks.video = (block, entry) ->
  words = block.split(' ')
  words.shift!
  vid-tag = """<video preload="auto" autoplay="autoplay" loop="loop" style="width: 100%; height: auto;" controls> <source src="#{words.shift!}" type='video/webm; codecs="vp8, vorbis"'></source> </video>"""
  caption = if words.length then ('<p class="caption">' + words.join(' ') + '</p>') else ''
  return "<div class=\"img\">" + vid-tag + caption + "</div>"

blocks.search = (block, entry) ->
  return '<div class="search"><input class="deltos-search" type="text"></input><div class="deltos-results-summary"></div><div class="deltos-results"></div><script src="/search.js"></script></div>'

blocks.archive = (block, entry) ->
  entry.updated = true
  build-image-list-page!.join "\n"

blocks.children = (block, entry) ->
  build-list-page(get-child-entries entry).join "\n"

get-child-entries = (parent) ->
  get-all-entries!.filter(-> -1 != parent.children?.index-of it.id)

blocks.recent = (block, entry) ->
  entry.updated = true
  build-image-list-page!.slice(0, 5).join "\n"

build-list-page = (entries, linker=to-markdown-link) ->
  if not entries then entries = get-all-entries!

  # remove hidden entries
  entries = entries
    .filter (tagged \published)
    .filter (-> not tagged \hidden, it)

  sort-by (.date), entries |>
    reverse |>
    map linker

build-image-list-page = (entries) ->
  build-list-page entries, to-image-block

to-markdown-link = ->
  tags = it.tags.filter(-> it != \published).join ", "
  day = it.date.substr 0, 10
  "- [#{it.title}](/by-id/#{it.id}\##{get-slug it}) #day <span class=\"tags\">#{tags}</span>"

to-image-block = ->
  out = "<a href=\"/by-id/#{it.id}\">"
  out += '<div class="img img-block">'
  if it.first-image
    out += "<img src=\"#{it.first-image}\">"
  out += "<div class=\"text-overlay\">#{it.title}</div>"
  out += "</div></a>"
  return out

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

blocks.embed = (block, entry) ->
  lines = block.split "\n"
  if lines.length > 1 # we have a cache
    return lines.slice(1).join '\n'
  url = lines.0.split(' ').slice(1).join ' '
  result = child_process.exec-sync "OEMBED_WIDTH=#width kinkan '#url'"
  fname = get-filename entry.id
  raw-file = fs.read-file-sync fname, \utf-8
  raw-file = raw-file.split(lines.0).join(lines.0 + "\n" + result)
  fs.write-file-sync fname, raw-file, \utf-8
  return result

blocks.big = (block, entry) ->
  lines = block.split '\n'
  lines.shift! # we don't care about the first
  out = '<div class="bigholder">'
  for line in lines
    out += '<span class="bigtext">' + line + '</span>'
  out += '</div>'
  return out

blocks.class = (block, entry) ->
  style = block.split("\n").0.split(' ').1 # first word after "class" is value to use
  body = block.split("\n").slice(1).join("\n")
  # render body as normal, but change p tag to have class
  # assume <p> tag
  out = "<p class=\"#style\">" + (markdown deltos-link-to-html body).slice 3

deltos-link-to-html = ->
  link-regex = /\.\(([^\/]*)\/\/([^\)]*)\)/g
  entries = get-all-entries!
  it.replace link-regex, (matched, label, dest) ->
    entry = entries.filter(-> it.id == dest).0
    "<a href=\"/by-id/#{dest}\##{get-slug entry}\">#{label}</a>"

#TODO give this a better name
process-block = (keyword, block, entry) ->
  try
    blocks[keyword] block, entry
  catch e
    # TODO: render this error in the html
    console.log "keyword: " + keyword
    throw e

export render-block = (block, entry) ->
  # remove any newlines on front of block
  while block.0 == "\n"
    block = block.substr 1
  if block.0 == \! # special block
    block = block.slice 1 # get rid of !
    keyword = block.split("\n").0.split(' ').0 # get first word
    return process-block keyword, block, entry
  else # default block
    return deltos-link-to-html block

