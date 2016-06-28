# default blocks for deltos
child_process = require \child_process
Markdown = require(\markdown-it)(html: true)
markdown = -> Markdown.render it
{get-all-entries} = require \./entries
{map, sort-by, sort-with, reverse} = require \prelude-ls
{is-in, tagged, get-filename} = require \./util
fs = require \fs

blocks = {}

blocks.img = (block, entry) ->
  words = block.split(' ')
  words.shift!
  img-src = words.shift!
  tag = "<img src=\"#{img-src}\"/>"
  caption = if words.length then ('<p class="caption">' + markdown(words.join(' ')).substr 3) else ''
  # for meta-tags
  if not entry.first-image
    entry.first-image = img-src
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
  markdown build-list-page!.join "\n"

blocks.children = (block, entry) ->
  build-list-page(get-child-entries entry).join "\n"

get-child-entries = (parent) ->
  get-all-entries!.filter(-> -1 != parent.children.index-of it.id)

blocks.recent = (block, entry) ->
  entry.updated = true
  markdown build-list-page!.slice(0, 5).join "\n"

build-list-page = (entries) ->
  if not entries then entries = get-all-entries!

  # remove hidden entries
  entries = entries
    .filter (tagged \published)
    .filter (-> not tagged \hidden, it)

  sort-by (.date), entries |>
    reverse |>
    map to-markdown-link

to-markdown-link = ->
  tags = it.tags.filter(-> it != \published).join ", "
  "- [#{it.title}](/by-id/#{it.id}.html\##{get-slug it}) <span class=\"tags\">#{tags}</span>"

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
  result = child_process.exec-sync "kinkan '#url'"
  fname = get-filename entry.id
  raw-file = fs.read-file-sync fname, \utf-8
  raw-file = raw-file.split(lines.0).join(lines.0 + "\n" + result)
  fs.write-file-sync fname, raw-file, \utf-8
  return result

#TODO make generating this automatic
blockmap =
  img: img
  video: video
  search: search
  archive: archive
  children: children
  recent: recent
  embed: embed

deltos-link-to-html = ->
  link-regex = /\.\(([^\/]*)\/\/([^\)]*)\)/g
  entries = get-all-entries!
  it.replace link-regex, (matched, label, dest) ->
    entry = entries.filter(-> it.id == dest).0
    "<a href=\"/by-id/#{dest}.html\##{get-slug entry}\">#{label}</a>"

export get-slug = (entry) ->
  entry.title.replace(/ /g, '-').replace /[!@#$%^&\*\.\(\)\[\]\/\\'"{}?<>]/g, ''

#TODO give this a better name
process-block = (keyword, block, entry) ->
  try
    blocks[keyword] block, entry
  catch e
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
    return markdown deltos-link-to-html block

