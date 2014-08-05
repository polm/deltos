#BASE 
ls = require \LiveScript
fs = require \fs
yaml = require \js-yaml
markdown = require \marked
{Obj, filter, keys, values, group-by, concat, unique, map, take, sort-by} = require \prelude-ls
uuid = require \node-uuid

deltos-home = (process.env.DELTOS_HOME + '/') or '~/.deltos/'
# XXX note that eval'd code has full access to the calling context 
# (which is to say the interior of this script)
eval-ls = ->
  eval ls.compile it, bare: true

# RESOURCES

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

entries = []
get-entries = ->
  for ff in fs.readdir-sync BASEDIR
    entry = fs.read-file-sync BASEDIR + ff, \utf-8
    read-entry entry

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
        console.log \done
        fs.unlink-sync (path + '/' + ff + '/' + dud)
      console.log \rmdir
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
    console.log \====dir-contents
    console.log dir-contents
    console.log key
    for ff in dir-contents
      console.log \unlinking
      console.log key
      console.log matches[key]
      console.log ff
      if 0 > matches[key].index-of ff
        fs.unlink-sync (path + '/' + key + '/' + ff)
    for mat in matches[key]
      if 0 > dir-contents.index-of mat
        fs.symlink-sync (deltos-home + '/by-id/' + mat), (path + '/' + key + '/' + mat)
    console.log \=====out

update-symlinks = ->
  #TODO allow custom attributes
  #TODO only check files modified since last update
  # for titles, tags, and day
  cleanup-title = -> it.split('/').join '_'

  yank-ids = -> Obj.map (-> map (.id), it), it

  title-grouped = group-by (-> cleanup-title it.title), entries |> yank-ids
  update-symlink-dir 'by-title', title-grouped
  console.log \========titleover

  fix-date = ->
    check = it.to-string!split(\T).0
    if check.length < 1
      return it
    else
      return check

  console.log  (group-by (-> fix-date it.date), entries |> yank-ids)
  date-grouped = group-by (-> fix-date it.date), entries |> yank-ids
  update-symlink-dir 'by-date', date-grouped

  tags = map (.tags), entries |> concat |> unique
  tag-grouped = {}
  for tag in tags
    tag-grouped[tag] = filter (-> -1 < it.tags.index-of tag), entries |> map (.id)
  console.log \=====tags
  console.log tags
  console.log tag-grouped 
  update-symlink-dir 'by-tag', tag-grouped

switch process.argv.2
| \new => new-note!
| \update => update-symlinks!
| otherwise => console.log "Unknown command, try again."
