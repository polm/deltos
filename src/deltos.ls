fs = require \fs
Yaml = require \js-yaml
yaml = ->
  Yaml.safe-load it, schema: Yaml.FAILSAFE_SCHEMA
markdown = require \marked
{Obj, filter, keys, values, group-by, concat, unique, map, take, sort-by, sort-with, reverse, intersection} = require \prelude-ls
uuid = require \node-uuid

# placeholder globals; only required as needed
ls = domino = RSS = eep = Section = {}

# simple memoizer for thunks
memoize = (func) ->
  output = null
  return ->
    if output then return output
    output := func!
    return output

deltos-home = (process.env.DELTOS_HOME or '~/.deltos') + '/'
BASEDIR = deltos-home + '/by-id/'
get-filename = -> BASEDIR + it

# XXX note that eval'd code has full access to the calling context 
# (which is to say the interior of this script)
eval-ls = ->
  eval ls.compile it, bare: true

is-in = (list, item) --> -1 < list.index-of item
tagged = (tag, entry) --> (not tag) or is-in entry.tags, tag # On a null tag, this is always true

init = -> # create the empty directories needed
  fs.mkdir-sync deltos-home
  fs.mkdir-sync BASEDIR

read-config = memoize ->
  try
    yaml fs.read-file-sync (deltos-home + \config), \utf-8
  catch e
    console.error "Error reading config:" + e.message
    process.exit 1

write-post = -> launch-editor new-note it
write-daily = -> launch-editor new-daily!
edit-post = -> launch-editor it

normalize-date = ->
  # This needs to be done to handle some date stupidity
  # YAML can save dates natively, but only recognizes a subset of ISO8601
  # Specifically, 4-character timezones must have a colon (09:00, not 0900)
  # This is stupid.
  it.date = (new Date it.date).toISOString!

read-entry = ->
  # raw entry as string as input
  [header, body] = it.split "\n---\n"
  try
    metadata = yaml header
  catch e
    console.error "Error parsing YAML header:\n" + header
    console.error "Error message:" + e.message
    process.exit 1

  normalize-date metadata
  if not metadata.title
      metadata.title = 'untitled'
  if not metadata.tags.0
      metadata.tags = ['untagged']
  if metadata.location
    metadata.location = "Click <a href=\"http://maps.google.com/?q=#{metadata.location}\">here</a> for a map to this location."
  if metadata.parent # you can set just one parent if you want
    if not metadata.parents then metadata.parents = []
    metadata.parents.push metadata.parent
    delete metadata.parent
  if metadata.parents # add some nice text
    if metadata.parents.length == 1
      collection = read-entry-from-file get-filename metadata.parents.0
      metadata.collections = "This post is part of a collection on <a href=\"/by-id/#{collection.id}.html\">#{collection.title}</a>."
    else
      metadata.collections = "This post is part of collections on "
      colls = []
      for coll in metadata.parents
        collection = read-entry-from-file get-filename coll
        colls.push "<a href=\"/by-id/#{collection.id}.html\">#{collection.title}</a>"
      colls[*-1] = "and " + colls[*-1] + "."
      metadata.collections += colls.join ", "

  metadata.raw-body = body
  return metadata

read-entry-from-file = ->
  entry = fs.read-file-sync it, \utf-8
  read-entry entry

# use this for filtering etc.
get-all-entries = memoize ->
  entries = {}
  for ff in fs.readdir-sync BASEDIR
    entry = read-entry-from-file BASEDIR + ff
    entries[entry.id] = entry

  # populate "children" - this is linear time
  for entry in entries
    if entry.parents
      for parent in entry.parents
        if not entries[parent].children then entries[parent].children = []
        entries[parent].children.push entry.id

  return values entries |> sort-by (.date) |> reverse

local-iso-time = (vsnow=0) ->
  # from here: http://stackoverflow.com/questions/10830357/javascript-toisostring-ignores-timezone-offset
  # Idea is to take a date, add our offset, get that as Z/UTC time, then just change the tz note
  offset = (new Date!).get-timezone-offset!
  offset-ms = offset * 60000
  offset-ms += vsnow
  local-time = (new Date(Date.now! - offset-ms)).toISOString!slice 0, -1
  offset-hours = offset / 60
  offset-double-oh-hours = ~~(offset-hours) * 100
  if offset-hours % 1 != 0 # half-hour offset
    offset-double-oh-hours += 50
  # remember this is the time from UTC to us, not us to UTC
  offset-prefix = \-
  if offset-double-oh-hours < 0
    offset-prefix = \+
    offset-double-oh-hours *= -1
  offset-string = '000000' + offset-double-oh-hours
  offset-string = offset-string.slice (offset-string.length - 4)
  return local-time + offset-prefix + offset-string

get-new-id = ->
  # get a new uuid
  # check it doesn't exist; if it does, make another
  while true
    id = uuid.v4!
    # don't need the whole thing; this'll do for now
    # smallest bits are most random, so let's use those
    id = id.split('').reverse![0 til 8].join ''
    fname = get-filename id
    if not fs.exists-sync fname
      return id


new-note = (title="",tags=[]) ->
  id = get-new-id!
  fname = get-filename id
  # dump the template into it (date, tags, title, ---)
  now = local-iso-time!
  buf = ["id: #id",
         "date: #now",
         "title: #title",
         "tags: [#{tags.join ", "}]",
         "---\n"].join "\n"
  fs.write-file-sync fname, buf
  # finally print the name so it can be used
  return fname

new-daily = ->
  # make a daily note, filling with todos etc.
  today = local-iso-time!.substr 0, 10
  # don't create two dailys for today
  entries = get-all-entries!filter -> tagged(\daily, it) and today == it.date.substr 0, 10
  if entries.length > 0
    return get-filename entries.0.id
  fname = new-note "Daily Notes - #today", [\daily]
  fs.append-file-sync fname, "deltos todos\n"
  #TODO maybe limit based on count or time?
  fs.append-file-sync fname, dump-todos!
  #TODO fortunes?
  fs.append-file-sync fname, "\n\n"
  return fname

no-empty = -> it.filter (-> not (it == null or it == '') )

read-stdin-as-lines-then = (func) ->
  buf = ''
  process.stdin.set-encoding \utf-8
  process.stdin.on \data, -> buf += it
  process.stdin.on \end, -> func (buf.split "\n" |> no-empty)

launch-editor = (file, after) ->
  spawn = require(\child_process).spawn
  # from here:
  # https://gist.github.com/Floby/927052
  cp = spawn process.env.EDITOR, [file], {
    stdio: \inherit
  }

  after?!

dump-todos = ->
  entries = get-all-entries! |> filter (-> it.todo and not it.done) |> sort-by (.todo)
  return entries.map(-> "- .(#{it.title}//#{it.id}) #{it.todo}").join "\n"

dump-tsv = ->
  # dump a simple tsv file with fields (id, tags, title)
  entries = get-all-entries!
  out = []
  for entry in entries
    out.push [entry.id, entry.title, (entry.tags.join ',')].join '\t'
  return out.join "\n"

# HTML / site stuff

html-init = ->
  # the requires for this are slow, so no point in adding them on the cli
  eep := require \./equaeverpoise
  Section := eep.Section
  domino := require \domino
  RSS := require \rss
  ls := require \livescript

begins-with = (prefix, str) -> str.substr(0, prefix.length) == prefix

read-entry-body = ->
  expanded = ''
  if not it then return '' # it's ok to empty
  for line in it.split "\n"
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
      | \archive => line = build-list-page!join("\n")
      | \.rule =>
          # use the markdown thing and replace the default <p> tag
          line = '<p class="rule">' + markdown(words.join ' ').substr 3
      | otherwise => \noop # unknown word, maybe throw error?
    expanded += line + "\n"
  expanded = deltos-link-to-html expanded
  return markdown expanded

get-template = memoize ->
  fs.read-file-sync (deltos-home + \single.html), \utf-8 |> -> domino.create-window(it).document

searchable-text = ->
  domino.create-window(it).document.body.text-content.to-lower-case!

# TODO avoid reading file every time
build-page = (eep, content) ->
  if content.raw-body
    content.body = read-entry-body content.raw-body
    delete content.raw-body
  template = get-template!
  eep.push template.body, content, template.body
  if content.title then template.title = content.title
  return template.outerHTML

entry-rules = ->
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

get-rendered-entries = ->
  # use this when you need the body with markdown etc.
  entries = get-all-entries!
  for entry in entries
    entry.body = read-entry-body entry.raw-body
    delete entry.raw-body
  return entries

render = ->
  entry = read-entry-from-file get-filename it
  entry.link = '/by-id/' + entry.id + \.html
  build-page entry-rules!, entry

render-multiple = (ids) ->
  entries = ids.map -> read-entry-from-file get-filename it
  entries.map (-> it.link = '/by-id/' + it.id + \.html; return it) # make sure they have a link
  # load the body
  entries.map (-> it.body = read-entry-body it.raw-body; delete it.raw-body)

  page = new Section!
  page.list-rule \#column, \entries, entry-rules!

  build-page page, {entries: entries}

to-markdown-link = ->
  tags = it.tags.filter(-> it != \published).join ", "
  "- [#{it.title}](/by-id/#{it.id}.html) <span class=\"tags\">#{tags}</span>"

build-list-page = ->
  tags = [\published].concat process.argv.slice 3
  entries = get-all-entries!
  # remove meta-entries like Archive, top page

  config = read-config!
  for tag in config.site["exclude-tags"]
    entries = entries.filter (-> not tagged tag, it)
  for tag in tags
    entries = entries.filter (-> tagged tag, it)
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

build-private-reference = ->
  build-site true

build-site = (priv=false)->
  html-init!
  config = read-config!
  published = config.site.tag
  site-root = deltos-home + \site/
  if priv then site-root = deltos-home + \private/

  entries = get-rendered-entries!
  if not priv
    entries = entries |> filter (tagged published)
  entries = entries |>
    sort-by (.date) |>
    reverse

  # update individual posts
  for entry in entries
    page = render entry.id
    fname = site-root + "/by-id/" + entry.id + ".html"
    fs.write-file-sync fname, page

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

  fs.write-file-sync (site-root + "index.rss"), rss.xml!

all-to-json = ->
  html-init!
  entries = get-rendered-entries! |> sort-by (.date) |> reverse
  for entry in entries
    entry.tags = entry.tags.map String # numeric tags should still be strings
    entry.body = searchable-text entry.body
    console.log JSON.stringify entry

# Command line handling from here on

commands = []

add-command = (name, desc, func) ->
  func.command = name
  func.desc = desc
  name = name.split(" ").0 # drop arguments etc.
  commands[name] = func

add-command "init", "Set up DELTOS_HOME", init
add-command "new [title...]", "Create a note and print the filename", ->
  console.log new-note process.argv.slice(3).join ' '
add-command "daily", "Create a daily note and open in $EDITOR", ->
  write-daily!
add-command "post [title...]", "Start a new post in $EDITOR", ->
  write-post process.argv.slice(3).join ' '
add-command "edit [id]", "Edit an existing post", ->
  edit-post get-filename process.argv.3
add-command "render [id]", "Render [id] as HTML", ->
  console.log render process.argv.3
add-command \build-site, "Build static HTML", ->
  build-site!
  build-private-reference!
add-command \json, "Dump all entries to JSON", all-to-json
add-command \todos,  "Dump todo list", -> console.log dump-todos!
add-command \tsv,  "Dump basic TSV", -> console.log dump-tsv!
add-command \version, "Show version number", ->
  pkg = require \../package.json
  console.log pkg.version
add-command \help, "Show this help", ->
  console.log "usage: deltos <command> [options...]\n"
  for name,func of commands
    #TODO get tabs right here
    console.log "\t#{func.command}\t\t#{func.desc}"
  process.exit 1

try
  func = commands[process.argv.2]
catch # bad command, print help
  func = commands.help!

if not func
  func = commands.help

func!

