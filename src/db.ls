sqlite = require \better-sqlite3
{deltos-home} = require \./util
{read-entry, get-all-entries-quick} = require \./entries
{unlink-sync} = require \fs

db-path = deltos-home + '/deltos.db'

get-db = ->
  db = new sqlite deltos-home + '/deltos.db'

get-prepared-statements = (db) ->
  # to add core entry data
  ss = {}
  ss.entry-insert = db.prepare "
    insert into entry (id, date, title, thread)
    values (@id, @date, @title, @thread)"

  ss.wipe-entry = db.prepare "
    delete from entry where id = @id"

  # to add tags
  ss.tag-insert = db.prepare "
    insert into entry_tag (entry_id, tag)
    values (@id, @tag)"

  # when updating tags, easiest to wipe them first
  ss.wipe-tags = db.prepare "
    delete from entry_tag where entry_id = @id"

  return ss

create-entry = (db, ss, entry) ->
  entry.thread = entry.thread or null
  ss.entry-insert.run entry
  for tag in entry.tags
    ss.tag-insert.run id: entry.id, tag: tag

export db-init = ->
  # delete db if it exists
  try
    fs.unlink-sync db-path
  catch e
    \ok # probably didn't exist, but we don't care

  # create db
  db = get-db!
  # create tables
  db.prepare("create table entry (
      id varchar(8) primary key,
      date text,
      title text,
      thread text)").run!
  db.prepare("create index date_idx on entry(date)").run!
  db.prepare("create index thread_idx on entry(thread)").run!
  db.prepare("create table entry_tag (
      entry_id varchar(8),
      tag text)").run!
  db.prepare("create index entry_id_idx on entry_tag(entry_id)").run!
  db.prepare("create index tag_idx on entry_tag(tag)").run!

  ss = get-prepared-statements db

  # read entries into the db
  get-all-entries-quick (entry) ->
    create-entry db, ss, entry

export db-update = (id) ->
  # Run an update on one entry. Typically run after editing.

  # First see if it exists, and add it if not.
  db = get-db!
  entry = read-entry id
  row = db.prepare("select * from entry where id = @id").get entry
  ss = get-prepared-statements db

  # delete any data that exists
  ss.wipe-entry.run entry
  ss.wipe-tags.run entry

  # create the entry
  create-entry db, ss, entry
  db.close!

export db-dump = (output) ->
  # quickly read out entries
  # TODO: build db if it doesn't exist
  db = get-db!
  entries = db.prepare("select * from entry order by date desc").iterate!
  until (iterator = entries.next!).done
    entry = iterator.value
    console.log entry
  db.close!

export get-thread = (name) ->
  if not name then return ''
  db = get-db!
  return db.prepare("select * from entry where thread = ? order by date desc").all(name)

export dump-tsv = (printer) ->
  if not printer then printer = console.log
  db = get-db!
  tagdb = get-db!
  tag-query = tagdb.prepare("select tag from entry_tag where entry_id = ?")
  entries = db.prepare("select * from entry order by date desc").iterate!
  until (iterator = entries.next!).done
    entry = iterator.value
    tags = tag-query.all(entry.id).map(-> \# + it.tag).join ','
    printer [entry.title, tags, entry.date.substr(0,10), entry.id].join '\t'
  db.close!
  tagdb.close!
