{memoize, normalize-date, local-iso-time, yaml, \
 deltos-home, BASEDIR, get-filename, tagged} = require \./util
fs = require \fs
uuid = require \node-uuid
{filter, values, sort-by, reverse} = require \prelude-ls

export new-note = (title="",tags=[]) ->
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

export dump-todos = ->
  entries = get-all-entries! |> filter (-> it.todo and not it.done) |> sort-by (.todo)
  return entries.map(-> "- .(#{it.title}//#{it.id}) #{it.todo}").join "\n"

export dump-tsv = ->
  # dump a simple tsv file with fields (title, tags, id)
  entries = get-all-entries!
  out = []
  for entry in entries
    out.push [entry.title, (entry.tags.map(-> \# + it).join ','), entry.id].join '\t'
  return out.join "\n"

read-entry = ->
  # "it" is raw entry as string as input
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
export get-all-entries = memoize ->
  entries = {}
  for ff in fs.readdir-sync BASEDIR
    entry = read-entry-from-file BASEDIR + ff
    entries[entry.id] = entry

  # populate "children" - this is not recursive
  for key, entry of entries
    if entry.parent then entry.parents = [entry.parent]
    if entry.parents
      for parent in entry.parents
        if not entries[parent].children then entries[parent].children = []
        entries[parent].children.push entry.id

  return values entries |> sort-by (.date) |> reverse

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

export new-daily = ->
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


