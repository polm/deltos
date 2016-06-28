{memoize, local-iso-time, get-yesterday, yaml, yaml-dump, \
 deltos-home, BASEDIR, get-filename, tagged, get-slug} = require \./util
fs = require \fs
uuid = require \node-uuid
{filter, values, sort-by, reverse} = require \prelude-ls

export new-note = (title="", tags=[], metadata={}) ->
  base = do
    id: get-new-id!
    date: local-iso-time!
    title: title
    tags: tags
  for key of metadata
    base[key] = metadata[key]
  fname = get-filename base.id
  fs.write-file-sync fname, (yaml-dump base) + "---\n"
  # finally print the name so it can be used
  return fname

export dump-todos = ->
  entries = get-all-entries! |> filter (-> it.todo and not it.done) |> sort-by (.todo)
  return entries.map(-> "- .(#{it.title}//#{it.id}) #{it.todo}").join "\n"

export render-tsv-entry = (entry) ->
  [entry.title, (entry.tags.map(-> \# + it).join ','), entry.id].join '\t'

export dump-tsv = ->
  dump-tsv-core get-all-entries!

export dump-tsv-tagged = (tag) ->
  dump-tsv-core (get-all-entries! |> filter tagged tag)

dump-tsv-core = (entries) ->
  # dump a simple tsv file with fields (title, tags, id)
  out = []
  for entry in entries
    out.push render-tsv-entry entry
  return out.join "\n"

export grep-entries = (pat) ->
  # smart case - ignore case unless caps in search pattern
  ignorecase = if /[A-Z]/.test pat then '' else \i
  regex = new RegExp pat, ignorecase
  entries = get-all-entries!
  hits = []
  for entry in entries
    for line in entry.raw-body.split "\n"
      if regex.test line then hits.push "#{entry.id}: #line"
  return hits

export philtre-entries = (query) ->
  # use philtre lib
  {philtre} = require \philtre
  out = []
  for hit in philtre query, get-all-entries!
    out.push "#{hit.id}: #{hit.title}"
  return out

read-entry = (id) ->
  raw-text = fs.read-file-sync get-filename(id), \utf-8
  try
    [header, body] = raw-text.split "\n---\n"
    metadata = yaml header
  catch e
    console.error "Error parsing YAML header:\n" + header
    console.error "Error message:" + e.message
    metadata = do
      id: id
      title: "Error parsing header"
      date: new Date!
      tags: [\error]
    body = "Could not parse entry.\n\nError message:" + e.message
    body += "\n\n# Original entry:\n\n" + raw-text

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
      collection = read-entry metadata.parents.0
      metadata.collections = "This post is part of a collection on <a href=\"/by-id/#{collection.id}.html\##{get-slug collection}\">#{collection.title}</a>."
    else
      metadata.collections = "This post is part of collections on "
      colls = []
      for coll in metadata.parents
        collection = read-entry coll
        colls.push "<a href=\"/by-id/#{collection.id}.html\##{get-slug collection}\">#{collection.title}</a>"
      colls[*-1] = "and " + colls[*-1] + "."
      metadata.collections += colls.join ", "

  metadata.raw-body = body
  return metadata

# use this for filtering etc.
export get-all-entries = memoize ->
  entries = {}
  for ff in fs.readdir-sync BASEDIR
    entry = read-entry ff
    entries[entry.id] = entry

  # populate "children" - this is not recursive
  for key, entry of entries
    if entry.parent then entry.parents = [entry.parent]
    if entry.parents
      for parent in entry.parents
        if not entries[parent].children then entries[parent].children = []
        entries[parent].children.push entry.id

  return values entries |> sort-by (.date) |> reverse

export get-raw-entry = ->
  [head, body] = get-entry-parts it
  return [(yaml head), body]

get-entry-parts = ->
  text = fs.read-file-sync (get-filename it), \utf-8
  head = text.split("\n---\n").0
  body = text.split("\n---\n")[1 to].join "\n---\n"
  return [head, body]

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
  entries = get-all-entries!
  existing = entries.filter(-> it.daily == today)?0
  if existing then return get-filename existing.id

  yesterday = entries.filter(-> it.daily == get-yesterday!)?0

  fname = new-note "Daily Notes - #today", [], daily: today
  fs.append-file-sync fname, "\ndeltos todos\n"
  fs.append-file-sync fname, dump-todos!
  fs.append-file-sync fname, "\n\n"
  if yesterday
    fs.append-file-sync fname, ".(Yesterday//#{yesterday.id})\n\n"
  return fname


