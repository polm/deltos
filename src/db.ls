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

export db-dump = (output) ->
  # quickly read out entries
  # TODO: build db if it doesn't exist
  db = get-db!
  entries = db.prepare("select * from entry order by date desc").iterate!
  until (iterator = entries.next!).done
    entry = iterator.value
    console.log entry
  db.close!

export get-thread-next = (id) ->
  db = get-db!
  entry = db.prepare("select * from entry where id = ?").get(id)
  if not entry or not entry.thread then return id
  next-id = db.prepare("""select id from entry where date > @date and thread = @thread
    order by date asc limit 1""")
    .get(entry)
  db.close!
  # default to returning the current item
  return next-id?.id or id

export get-thread-prev = (id) ->
  db = get-db!
  entry = db.prepare("select * from entry where id = ?").get(id)
  if not entry or not entry.thread then return id
  next-id = db.prepare("""select id from entry where date < @date and thread = @thread
    order by date desc limit 1""")
    .get(entry)
  db.close!
  return next-id?.id or id

export get-thread-latest = (name) ->
  if not name then return ''
  db = get-db!
  entry = db.prepare("select * from entry where thread = ? order by date desc limit 1").get(name)
  if not entry then return ''
  return entry.id
