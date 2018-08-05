{memoize, local-iso-time, get-yesterday, yaml, yaml-dump, \
 deltos-home, BASEDIR, get-filename, tagged, get-slug, get-url, get-mtime} = require \./util
fs = require \fs
uuid = require \uuid
{map, filter, values, sort-by, reverse} = require \prelude-ls

export new-note = (title="", tags=[], metadata={}) ->
  base = do
    id: get-new-id!
    date: local-iso-time!
    title: title
    tags: tags
  for key of metadata
    base[key] = metadata[key]
  fname = get-filename base.id
  fs.mkdir-sync fname
  fs.write-file-sync fname + '/deltos', (yaml-dump base) + '---\n'
  # finally print the name so it can be used
  return fname

export dump-todos = ->
  entries = get-all-entries! |> filter (-> it.todo and not it.done) |> sort-by (.todo)
  return entries.map(-> "- .(#{it.title}//#{it.id}) #{it.todo}").join "\n"

export render-tsv-entry = (entry) ->
  [entry.title, (entry.tags.map(-> \# + it).join ','), entry.id].join '\t'

export dump-tsv = ->
  get-all-entries-quick -> console.log render-tsv-entry it

export dump-tsv-tagged = (tag) ->
  dump-tsv-core (get-all-entries! |> filter tagged tag)

dump-tsv-core = (entries) ->
  # dump a simple tsv file with fields (title, tags, id)
  for entry in entries
    console.log render-tsv-entry entry

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
  try
    [metadata, body] = get-entry-parts id
  catch e
    console.error "Entry ID: " + id
    console.error "Error parsing YAML header:\n" + metadata
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
      metadata.collections = "This post is part of a collection on <a href=\"#{get-url collection}\">#{collection.title}</a>."
    else
      metadata.collections = "This post is part of collections on "
      colls = []
      for coll in metadata.parents
        collection = read-entry coll
        colls.push "<a href=\"#{get-url collection}\">#{collection.title}</a>"
      colls[*-1] = "and " + colls[*-1] + "."
      metadata.collections += colls.join ", "

  metadata.raw-body = body
  return metadata

rev-date = (a, b) ->
  if a.date == b.date then return 0
  if a.date < b.date then return 1
  return -1

# use this for filtering etc.
export get-all-entries = memoize ->
  entries = {}
  for ff in fs.readdir-sync BASEDIR
    base = BASEDIR + '/' + ff
    entry = read-entry ff
    entries[entry.id] = entry

  # populate "children" - this is not recursive
  for key, entry of entries
    if entry.parent then entry.parents = [entry.parent]
    if entry.parents
      for parent in entry.parents
        if not entries[parent].children then entries[parent].children = []
        entries[parent].children.push entry.id

  entries = values entries |> sort-by (.date) |> reverse
  write-full-cache entries
  return entries

get-all-entries-quick = (output) ->
  # this if for tsv dump or other cases where you just want the list quick
  # parents are not populated
  for ff in fs.readdir-sync BASEDIR
    base = BASEDIR + '/' + ff
    output read-entry ff

export get-raw-entry = ->
  [head, body] = get-entry-parts it
  return [(yaml head), body]

get-entry-parts = ->
  raw = fs.read-file-sync get-filename(it) + '/deltos', \utf-8
  parts = raw.split '\n---\n'
  header = parts.shift!
  body = parts.join '\n---\n'
  metadata = yaml header
  return [(yaml header), body]

export get-new-id = (fname-getter=get-filename) ->
  # get a new uuid
  # check it doesn't exist; if it does, make another
  while true
    id = uuid.v4!
    # don't need the whole thing; this'll do for now
    # smallest bits are most random, so let's use those
    id = id.split('').reverse![0 til 8].join ''
    fname = fname-getter id
    if not fs.exists-sync fname
      return id
