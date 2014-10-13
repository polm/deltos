#BASE 
ls = require \LiveScript
fs = require \fs
yaml = require \js-yaml
markdown = require \marked
{Obj, filter, keys, values, group-by, concat, unique, map, take, sort-by, reverse} = require \prelude-ls
uuid = require \node-uuid
create-menu = require \terminal-menu
eep = require \./equaeverpoise
Section = eep.Section
jsdom = require(\jsdom).jsdom

deltos-home = (process.env.DELTOS_HOME + '/') or '~/.deltos/'
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
        img-tag = "<p class=\"img\"><img src=\"#{words.shift!}\"/></p>"
        caption = if words.length then ('<p class="caption">' + words.join(' ') + '</p>') else ''
        line = img-tag + caption
      | otherwise => \noop # unknown word, maybe throw error?
    expanded += line + "\n"
  expanded = deltos-link-to-html expanded
  return markdown expanded

read-entry = ->
  [header, body] = it.split "\n---\n"
  metadata = yaml.safe-load header
  if metadata.date.toISOString
    metadata.date = metadata.date.toISOString!
  #TODO tags don't all have commas, add them
  if not metadata.title
      metadata.title = 'untitled'
  if not metadata.tags.0
      metadata.tags = ['untagged']
  if metadata.tags.0.index-of(' ') > -1
    # didn't have commas
    metadata.tags = metadata.tags.0.split ' '
  metadata.body = read-entry-body body
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

get-all-entries = ->
  for ff in fs.readdir-sync BASEDIR
    read-entry-from-file BASEDIR + ff

by-title = (title, entries) -->
  entries.filter (.title == title)

has-tag = (tag, entries) -->
  entries.filter (.tags.index-of(tag) > -1)

recent-first = (entries) ->
  sort-by (.date), entries

new-note = ->
  # get a new uuid
  # check it doesn't exist; if it does, make another
  while true
    id = uuid.v4!
    fname = [deltos-home, \/by-id/, id].join ''
    if not fs.exists-sync fname
      break
  # dump the template into it (date, tags, title, ---)
  now = (new Date!).toISOString!
  buf = ["id: #{id}",
         "date: #{now}",
         "title: #{process.argv.slice(3).join ' '}",
         "tags: []",
         "---\n"].join "\n"
  fs.write-file-sync fname, buf
  # finally print the name so it can be used
  console.log fname

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
      file =
        title: read-entry-from-file(get-filename ff).title
        id: ff
        mtime: fs.stat-sync(deltos-home + '/by-id/' + ff).mtime
      files.push file
    files = sort-by (.mtime), files
    return files
  catch ee
    console.error "No such tag."
    process.exit 1

search-tag-interactive = -> select-menu search-tag!
search-tag-pipe = ->
  process.stdout.on \error, -> process.exit 0 # This handles piping to head
  search-tag!map (-> console.log it.id)

title-block = ->
  #TODO escape characters
  '<div id="title"><div id="title-box"><h1>' + it + '</h1></div></div>'

body-block = ->
  '<div id="body"><div class="column">' + it + '</div></div>'

background-block = ->
  # This is just a cheap trick to easily change the bg image.
  "<style> \#body {background-image: url(#{it})}</style>"

build-page = (eep, content) ->
  template = fs.read-file-sync (deltos-home + \single.html), \utf-8 |> jsdom
  eep.push template.body, content
  console.log template.children.0.outerHTML

entry-rules = ->
  page = new Section!
  page.rule \h1, \title
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

render-log = -> # For showing several articles, like a log
  # read the list from stdin
  read-stdin-as-lines-then (lines) ->
    entries = lines.map -> read-entry-from-file get-filename it
    entries.map (-> it.link = '/by-id/' + it.id + \.html; return it) # make sure they have a link

    page = new Section!
    page.list-rule \#column, \entries, entry-rules!

    build-page page, {entries: entries}

entry-to-markdown-link = -> "- [#{it.title}](/by-id/#{it.id}.html)"
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


switch process.argv.2
| \new => new-note!
| \update => update-symlinks!
| \stit => search-title!
| \search-title => search-title!
| \stag => search-tag-pipe!
| \search-tag => search-tag-pipe!
| \render => render process.argv.3
| \render-log => render-log!
| \as-markdown-links => as-markdown-links!
| \recent => recent!
| otherwise => console.log "Unknown command, try again."
