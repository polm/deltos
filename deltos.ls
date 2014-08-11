#BASE 
ls = require \LiveScript
fs = require \fs
yaml = require \js-yaml
markdown = require \marked
{Obj, filter, keys, values, group-by, concat, unique, map, take, sort-by} = require \prelude-ls
uuid = require \node-uuid
create-menu = require \terminal-menu

deltos-home = (process.env.DELTOS_HOME + '/') or '~/.deltos/'
# XXX note that eval'd code has full access to the calling context 
# (which is to say the interior of this script)
eval-ls = ->
  eval ls.compile it, bare: true

# RESOURCES

get-filename = ->
  deltos-home + '/by-id/' + it

read-entry-body = ->
  expanded = ''
  for line in it.split "\n"
    if line[0] == \]
        expanded += eval-ls line.substr 1
    else expanded += line
    expanded += "\n"
  return markdown expanded

read-entry = ->
  [header, body] = it.split "\n---\n"
  metadata = yaml.safe-load header
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

entries = []
get-entries = ->
  for ff in fs.readdir-sync BASEDIR
    read-entry-from-file BASEDIR + ff

entries = get-entries!

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

  title-grouped = group-by (-> cleanup-title it.title), entries |> yank-ids
  update-symlink-dir 'by-title', title-grouped

  fix-date = ->
    check = it.to-string!split(\T).0
    if check.length < 1
      return it
    else
      return check

  date-grouped = group-by (-> fix-date it.date), entries |> yank-ids
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
    select-menu files
  catch ee
    console.error "No such tag."
    process.exit 1

switch process.argv.2
| \new => new-note!
| \update => update-symlinks!
| \stit => search-title!
| \search-title => search-title!
| \stag => search-tag!
| \search-tag => search-tag!
| otherwise => console.log "Unknown command, try again."
