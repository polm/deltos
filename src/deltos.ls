#BASE 
ls = require \LiveScript
fs = require \fs
yaml = require \js-yaml
markdown = require \marked
{Obj, filter, keys, values, group-by, concat, unique, map, take, sort-by, reverse, intersection} = require \prelude-ls
uuid = require \node-uuid
create-menu = require \terminal-menu
eep = require \./equaeverpoise
Section = eep.Section
jsdom = require(\jsdom).jsdom
child-process = require \child_process
spawn = child-process.spawn
RSS = require \rss

#TODO clean this up
deltos-home = (process.env.DELTOS_HOME or '~/.deltos') + '/'

# XXX note that eval'd code has full access to the calling context 
# (which is to say the interior of this script)
eval-ls = ->
  eval ls.compile it, bare: true

is-in = (list, item) --> -1 < list.index-of item
tagged = (tag, entry) --> (not tag) or is-in entry.tags, tag # On a null tag, this is always true
no-empty = -> it.filter (-> not (it == null or it == '') )
begins-with = (prefix, str) -> str.substr(0, prefix.length) == prefix

get-filename = ->
  deltos-home + '/by-id/' + it

deltos-link-to-html = ->
  link-regex = /\.\(([^\/]*)\/\/([^\)]*)\)/g
  it.replace link-regex, (matched, label, dest) -> "<a href=\"/by-id/#{dest}.html\">#{label}</a>"

init = -> # create the empty directories needed
  fs.mkdir-sync deltos-home
  fs.mkdir-sync deltos-home + '/by-id'
  fs.mkdir-sync deltos-home + '/by-tag'
  fs.mkdir-sync deltos-home + '/by-title'
  fs.mkdir-sync deltos-home + '/by-date'

read-entry-body = ->
  expanded = ''
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
      | \archive => line = build-list-page!join("\n")
      | otherwise => \noop # unknown word, maybe throw error?
    expanded += line + "\n"
  expanded = deltos-link-to-html expanded
  return markdown expanded

normalize-date = ->
  # This needs to be done to handle some date stupidity
  # YAML can save dates natively, but only recognizes a subset of ISO8601
  # Specifically, 4-character timezones must have a colon (09:00, not 0900)
  # This is stupid.
  it.date = (new Date it.date).toISOString!

read-entry = ->
  # raw entry as string as input
  [header, body] = it.split "\n---\n"
  metadata = yaml.safe-load header

  normalize-date metadata
  if not metadata.title
      metadata.title = 'untitled'
  if not metadata.tags.0
      metadata.tags = ['untagged']

  # TODO remove this section, it's for importing old data
  if metadata.tags.0.index-of(' ') > -1
    # didn't have commas
    metadata.tags = metadata.tags.0.split ' '

  metadata.raw-body = body
  return metadata

check = ->
  console.log it
  return it

indent = -> "    " + it.split("\n").join("\n    ")
quote-indent = -> "    > " + it.split("\n").join("\n    > ")

show = -> map( (.body), it).join "\n"
quote = -> show it |> quote-indent
code = -> show it |> indent

BASEDIR = deltos-home + '/by-id/'

read-entry-from-file = ->
  entry = fs.read-file-sync it, \utf-8
  read-entry entry

# use this for filtering etc.
get-all-entries = ->
  for ff in fs.readdir-sync BASEDIR
    read-entry-from-file BASEDIR + ff

# use this when you need the body with markdown etc.
get-rendered-entries = ->
  entries = get-all-entries!
  for entry in entries
    entry.body = read-entry-body entry.raw-body
    delete entry.raw-body
  return entries

by-title = (title, entries) -->
  entries.filter (.title == title)

has-tag = (tag, entries) -->
  entries.filter (.tags.index-of(tag) > -1)

recent-first = (entries) ->
  sort-by (.date), entries

local-iso-time = ->
  # from here: http://stackoverflow.com/questions/10830357/javascript-toisostring-ignores-timezone-offset
  # Idea is to take a date, add our offset, get that as Z/UTC time, then just change the tz note
  offset = (new Date!).get-timezone-offset!
  offset-ms = offset * 60000
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

new-note = ->
  # get a new uuid
  # check it doesn't exist; if it does, make another
  while true
    id = uuid.v4!
    fname = [deltos-home, \/by-id/, id].join ''
    if not fs.exists-sync fname
      break
  # dump the template into it (date, tags, title, ---)
  now = local-iso-time!
  buf = ["id: #{id}",
         "date: #{now}",
         "title: #{process.argv.slice(3).join ' '}",
         "tags: []",
         "---\n"].join "\n"
  fs.write-file-sync fname, buf
  # finally print the name so it can be used
  return fname

print-new-note-name = ->
  console.log new-note!

update-symlink-dir = (path, matches) ->
  # get all dirs that exist 
  path = deltos-home + '/' + path
  contents = fs.readdir-sync path
  # remove unneeded ones
  for ff in contents
    if 0 > keys(matches).index-of ff
      # we don't need these
      duds = fs.readdir-sync (path + '/' + ff)
      for dud in duds
        # the directory should only contain symlinks
        fs.unlink-sync (path + '/' + ff + '/' + dud)
      fs.rmdir-sync (path + '/' + ff)
  # add new ones
  for key in keys matches
    if 0 > contents.index-of(key)
      try
        fs.mkdir-sync (path + '/' + key)
      catch e
        \nothing
    # now remove old ones and add new ones
    dir-contents = fs.readdir-sync (path + '/' + key)
    for ff in dir-contents
      if 0 > matches[key].index-of ff
        fs.unlink-sync (path + '/' + key + '/' + ff)
    for mat in matches[key]
      if 0 > dir-contents.index-of mat
        fs.symlink-sync ('../../' + '/by-id/' + mat), (path + '/' + key + '/' + mat)

update-symlinks = ->
  #TODO allow custom attributes
  #TODO only check files modified since last update
  # for titles, tags, and day
  cleanup-title = -> it.split('/').join '_'

  yank-ids = -> Obj.map (-> map (.id), it), it

  entries = get-all-entries!

  title-grouped = group-by (-> cleanup-title it.title), entries |> yank-ids
  update-symlink-dir 'by-title', title-grouped

  date-trim = ->
    if it.date.toISOString
      it.date.toISOString!split('T').0
    else
      it.date.split('T').0
  date-grouped = group-by date-trim, entries |> yank-ids
  update-symlink-dir 'by-date', date-grouped

  tags = map (.tags), entries |> concat |> unique
  tag-grouped = {}
  for tag in tags
    tag-grouped[tag] = filter (-> -1 < it.tags.index-of tag), entries |> map (.id)
  update-symlink-dir 'by-tag', tag-grouped

select-menu = (files) ->
  # Sort files by mtime
  files = sort-by (.mtime), files
  # make the menu
  menu = create-menu 800
  menu.reset!
  menu.write "Select note to edit:\n"
  menu.write "--------------------\n"
  for file in files
    menu.add [file.title, file.mtime.toISOString!, file.id].join(' | ') + "\n"
  # TODO add option in case none match
  menu.on \select, ->
    menu.close!
    console.log (it.split(' | ')[*-1])
  menu.create-stream!pipe(process.stdout)

search-title = ->
  # Get all titles (lowercase them)
  titles = fs.readdir-sync (deltos-home + '/by-title')
  files = []
  search = process.argv.slice(3).join(' ').to-lower-case!
  for title in titles
    if title.to-lower-case!index-of(search) < 0
      continue
    for ff in fs.readdir-sync (deltos-home + '/by-title/' + title)
      file =
        title: title
        id: ff
        mtime: fs.stat-sync(deltos-home + '/by-id/' + ff).mtime
      files.push file
  select-menu files

search-tag = ->
  files = []
  tag = process.argv.slice(3).join(' ')
  try
    for ff in fs.readdir-sync (deltos-home + '/by-tag/' + tag)
      entry = read-entry-from-file get-filename ff
      file =
        title: entry.title
        id: ff
        date: entry.date
      files.push file
    files = sort-by (.date), files |> reverse
    return files
  catch ee
    console.error "No such tag."
    process.exit 1

search-tag-interactive = -> select-menu search-tag!

search-tag-pipe = ->
  process.stdout.on \error, -> process.exit 0 # This handles piping to head
  search-tag!map (-> console.log it.id)

# TODO avoid reading file every time
build-page = (eep, content) ->
  if content.raw-body
    content.body = read-entry-body content.raw-body
    delete content.raw-body
  template = fs.read-file-sync (deltos-home + \single.html), \utf-8 |> jsdom
  eep.push template.body, content
  if content.title
      template.title = content.title
  return template.children.0.outerHTML

entry-rules = ->
  page = new Section!
  page.rule \h1, \title
  page.rule \h4, \subtitle
  page.rule \.date, \date
  page.rule \.content, \body
  link-pusher = (el, link) -> el.href = link
  page.rule \.article-link, \link, {push: link-pusher}
  return page

render = ->
  entry = read-entry-from-file get-filename it
  entry.link = '/by-id/' + entry.id + \.html
  build-page entry-rules!, entry

read-stdin-as-lines-then = (func) ->
  buf = ''
  process.stdin.set-encoding \utf-8
  process.stdin.on \data, -> buf += it
  process.stdin.on \end, -> func (buf.split "\n" |> no-empty)

render-multiple = (ids) ->
  entries = ids.map -> read-entry-from-file get-filename it
  entries.map (-> it.link = '/by-id/' + it.id + \.html; return it) # make sure they have a link
  # load the body
  entries.map (-> it.body = read-entry-body it.raw-body; delete it.raw-body)

  page = new Section!
  page.list-rule \#column, \entries, entry-rules!

  build-page page, {entries: entries}

render-log = -> read-stdin-as-lines-then render-multiple

entry-to-markdown-link = -> "- [#{it.title}](/by-id/#{it.id}.html)"
entry-to-dated-markdown-link = -> "- [#{it.title}](/by-id/#{it.id}.html) #{it.date}"
entry-to-tagged-markdown-link = ->
  tags = it.tags.filter(-> it != \published).join ", "
  "- [#{it.title}](/by-id/#{it.id}.html) <span class=\"tags\">#{tags}</span>"
entry-to-link = -> "- .(#{it.title}//#{it.id})"
print-result = (func) -> return -> console.log func ...

as-markdown-links = ->
  read-stdin-as-lines-then (lines) ->
    entries = lines.map -> read-entry-from-file get-filename it
    entries.map print-result entry-to-markdown-link

recent = ->
  tag = it or process.argv.3 or \published
  get-all-entries! |>
    filter (-> tagged tag, it) |>
    sort-by (.date) |>
    reverse |>
    map (-> (print-result entry-to-link) it)

print-list-page = ->
  map (-> console.log it), build-list-page!

build-list-page = ->
  tags = [\published].concat process.argv.slice 3
  entries = get-all-entries!
  # remove meta-entries like Archive, top page
  entries = entries.filter (-> not tagged \dk, it)
  entries = entries.filter (-> not tagged \dampfkraft, it)
  for tag in tags
    entries = entries.filter (-> tagged tag, it)
  sort-by (.date), entries |>
    reverse |>
    map entry-to-tagged-markdown-link

launch-editor = (file, after) ->
  # from here:
  # https://gist.github.com/Floby/927052
  cp = spawn process.env.EDITOR, [file], {
    stdio: \inherit
  }

  after?!

write-post = -> launch-editor new-note!, update-symlinks
edit-post = -> launch-editor it, update-symlinks

todo = ->
  get-all-entries! |>
    filter (.due) |>
    filter (-> not it.done) |>
    sort-by (.due) |>
    reverse |>
    map (-> (print-result entry-to-link) it)

read-config = ->
  yaml.safe-load fs.read-file-sync (deltos-home + \config), \utf-8

blog-update = ->
  config = read-config!
  published = config.blog.tag
  blog-root = deltos-home + \blog/

  console.log "#{local-iso-time!}:: starting entries"
  entries = get-rendered-entries! |>
    filter (tagged published) |>
    sort-by (.date) |>
    reverse

  # update individual posts
  for entry in entries
    page = render entry.id
    fname = blog-root + "/by-id/" + entry.id + ".html"
    fs.write-file-sync fname, page

  console.log "#{local-iso-time!}:: finished entries"
  # update log
  log = take 5, entries |> map (.id) |> render-multiple
  fs.write-file-sync (blog-root + "log.html"), log
  console.log "#{local-iso-time!}:: updated log"

  rss = new RSS {
    title: config.blog.title
    description: config.blog.description
    generator: \deltos
    site_url: config.blog.url
    feed_url: config.blog.url + "/index.rss"
    pubDate: new Date!
  }

  for entry in entries
    entry.description = entry.body
    entry.categories = entry.tags
    entry.url = entry.link
    entry.guid = entry.link
    rss.item entry

  fs.write-file-sync (blog-root + "index.rss"), rss.xml!
  console.log "#{local-iso-time!}:: updated rss"
  console.log "#{local-iso-time!}:: all done"
  process.exit 0

all-to-json = ->
  entries = get-all-entries!
  for entry in entries
    entry.tags = entry.tags.map String # numeric tags should still be strings
    console.log JSON.stringify entry

#TODO make this a list so it can be printed in a help message
switch process.argv.2
| \new => print-new-note-name!
| \update => update-symlinks!
| \stit => search-title!
| \search-title => search-title!
| \stag => search-tag-pipe!
| \search-tag => search-tag-pipe!
| \render => console.log render process.argv.3
| \render-log => console.log render-log!
| \as-markdown-links => as-markdown-links!
| \recent => recent!
| \post => write-post!
| \init => init!
| \todo => todo!
| \edit => edit-post (get-filename process.argv.3)
| \blog-update => blog-update!
| \build-list-page => print-list-page!
| \json => all-to-json!
| otherwise =>
    console.error "Unknown command, try again."
    process.exit 1
