{memoize, local-iso-time, get-yesterday, yaml, yaml-dump, \
 deltos-home, BASEDIR, get-filename, tagged, get-slug, get-mtime} = require \./util
fs = require \fs
uuid = require \node-uuid
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
  dump-tsv-core get-all-entries!

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

load-full-cache = -> load-cache deltos-home + '/cache.json'
write-full-cache = -> write-cache deltos-home + '/cache.json', it
load-meta-cache = -> load-cache deltos-home + '/cache.meta.json'
write-meta-cache = -> write-cache deltos-home + '/cache.meta.json', it

load-cache = (cfile) ->
  if not fs.exists-sync cfile
    return {date: 0, entries: []} # no cache

  lines = fs.read-file-sync(cfile, \utf-8).split "\n"
  cache = JSON.parse lines.shift!
  cache.entries = lines.filter(-> it.length > 0).map JSON.parse
  return cache

export all-entries-cache-first = (entries, transformer, progress) ->
  find-fresh = (cache) ->
    files = fs.readdir-sync BASEDIR

    edict = {}
    for entry in cache.entries
      edict[entry.id] = entry

    next-file = ->
      if files.length == 0 then return
      file = files.shift!
      if not edict[file] # not in cache, probably new
        entry = read-entry file
        if transformer then entry = transformer entry
        cache.entries.push entry
        cache.entries.sort rev-date
        progress?!
        return set-timeout next-file, 0

      base = get-filename(file)
      if cache.date < get-mtime("#base/deltos")
        entry = read-entry file
        if transformer then entry = transformer entry
        oldind = cache.index-of edict[file]
        cache.entries oldind, 1, entry
        progress?!
        return set-timeout next-file, 0

    next-file!
  load-cache-async (deltos-home + '/cache.json'), entries, transformer, progress, find-fresh

load-cache-async = (cfile, entries, transformer, progress, done) ->
  if not fs.exists-sync cfile
    done?!
    return false

  split = require \split
  cdate = false

  fs.create-read-stream(cfile)
    .pipe(split!)
    .on \data, (line) ->
      line = line.trim!
      if line.length == 0 then return
      if not cdate
        cdate := JSON.parse(line).date
        return

      entry = JSON.parse line
      if transformer then entry = transformer entry
      entries.push entry
      if entries.length % 200 == 0 then progress?!
    .on \end, ->
      progress?!
      done? {date: cdate, entries: entries}

  return entries


rev-date = (a, b) ->
  if a.date == b.date then return 0
  if a.date < b.date then return 1
  return -1

write-cache = (cfile, entries) ->
  # format is a metadata object on the first line, followed by one entry per line
  out = JSON.stringify(date: (new Date!.toISOString!)) + "\n"
  for entry in entries
    out += JSON.stringify(entry) + "\n"
  fs.write-file-sync cfile, out

export get-all-entries-async = (entries, transformer, progress, finish) ->
  files = fs.readdir-sync BASEDIR
  cache = load-full-cache!

  # sort filenames by mtime - this isn't 100% right, but it will prevent jitter
  fobs = files.map -> {fname: it, date: get-mtime get-filename(it) + \/deltos}
  fobs.sort rev-date
  files = fobs.map (.fname)
  #files = sort-by (-> get-mtime get-filename(it) + \/deltos), files |> reverse

  read-file = ->
    if files.length == 0
      entries.sort rev-date
      progress?!
      return finish?!

    id = files.shift!
    entry = cache.entries[id] or read-entry id
    #entry = read-entry files.shift!
    if transformer
      entry = transformer entry
    entries.push entry
    if files.length % 100 == 0
      entries.sort rev-date
      progress?!
    set-timeout read-file, 0

  read-file!
  return entries

# use this for filtering etc.
export get-all-entries = memoize ->
  cache = load-full-cache!
  entry-list = cache.entries
  entries = {}
  for entry in entry-list
    entries[entry.id] = entry
  cdate = ~~+(new Date cache.date)
  for ff in fs.readdir-sync BASEDIR
    base = BASEDIR + '/' + ff
    if cdate < get-mtime("#base/deltos") or not cdate
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

export new-daily = ->
  # make a daily note, filling with todos etc.
  today = local-iso-time!.substr 0, 10
  # don't create two dailys for today
  entries = get-all-entries!
  existing = entries.filter(-> it.daily == today)?0
  if existing then return get-filename existing.id

  yesterday = entries.filter(-> it.daily == get-yesterday!)?0

  fname = new-note "Daily Notes - #today", [], daily: today
  fname += '/deltos'
  fs.append-file-sync fname, "\ndeltos todos\n"
  fs.append-file-sync fname, dump-todos!
  fs.append-file-sync fname, "\n\n"
  if yesterday
    fs.append-file-sync fname, ".(Yesterday//#{yesterday.id})\n\n"
  return fname

