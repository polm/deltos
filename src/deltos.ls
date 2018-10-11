{launch-editor, deltos-home, get-filename, read-config, edit-config, install-theme} = require \./util
{read-entry, new-note,dump-todos,grep-entries,philtre-entries} = require \./entries
{db-init, db-update, db-dump, get-thread, get-thread-next, get-thread-prev, get-thread-latest, dump-tsv} = require \./db
process.title = \deltos

# Top-level commands - these are called more or less directly by the command line

commands = {}

add-command = (name, desc, func) ->
  func.command = name
  func.desc = desc
  name = name.split(" ").0 # drop arguments etc.
  commands[name] = func

add-command "init", "Set up DELTOS_HOME", ->
  # create empty directories needed for before first run
  mkdirp = require \mkdirp
  mkdirp.sync deltos-home + \by-id
  mkdirp.sync deltos-home + \site/by-id
  db-init!
add-command "install-theme [git url]", "Install theme", install-theme
add-command "title", "Show title of current deltos", ->
  console.log read-config!.title
add-command "config", "Edit config file", edit-config
add-command "new [title...]", "Create a note and print the filename", (...args) ->
  console.log get-filename new-note args.join ' '
add-command "reply [id]", "Reply to a note in a thread", (id) ->
  base = read-entry id
  if not base.thread
    console.log "No thread!"
    process.exit 1
  console.log get-filename new-note base.title, base.tags, thread: base.thread, 'reply-to': id
add-command "post [title...]", "Start a new post in $EDITOR", (...args) ->
  id = new-note (args.join ' ')
  fname = get-filename id
  launch-editor fname, -> db-update id
add-command "edit [id]", "Edit an existing post", (id) ->
  launch-editor (get-filename id), -> db-update id
add-command \search, "Interactive search", ->
  {launch-search} = require \./search
  launch-search!
add-command "grep [pattern]", "Grep body of notes", (pat) ->
  grep-entries(pat).map -> console.log it
add-command "philtre [query]", "Philtre notes", (query) ->
  philtre-entries(query).map -> console.log it
add-command "render [id]", "Render [id] as HTML", ->
  {render} = require \./html
  console.log render it
add-command \build-site, "Build static HTML", ->
  {build-site} = require \./html
  build-site!
add-command \clean, "Delete built HTML", ->
  fs = require \fs-extra
  dirs = [deltos-home + '/site/by-id/']
  for dir in dirs
    for fname in fs.readdir-sync dir
      fs.remove-sync dir + fname
add-command \json, "Dump all entries to JSON", ->
  {dump-json} = require \./html
  console.log dump-json!
add-command \todos,  "Dump todo list", -> console.log dump-todos!
add-command \tsv,  "Dump basic TSV", dump-tsv
add-command \db-init, "Init db", ->
  db-init!
add-command "db-update [id]", "Update [id]'s db entry", ->
  db-update it
add-command "db-dump", "Dump db info", ->
  db-dump!
add-command \version, "Show version number", ->
  pkg = require \../package.json
  console.log pkg.version
add-command \help, "Show this help", ->
  console.log "usage: deltos <command> [options...]\n"
  for name,func of commands
    pad = (' ' * (25 - func.command.length))
    console.log "    #{func.command}#pad#{func.desc}"
  process.exit 1

add-command \get-thread, "Get posts in thread", (name) ->
  for entry in get-thread name
    console.log entry.id

try
  func = commands[process.argv.2]
catch # bad command, print help
  func = commands.help!

if not func
  func = commands.help

func.apply null, process.argv.slice 3
