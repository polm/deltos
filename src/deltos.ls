{launch-editor, deltos-home, get-filename, read-config, edit-config, install-theme} = require \./util
{new-note,new-daily,dump-tsv,dump-tsv-tagged,dump-todos,grep-entries,philtre-entries} = require \./entries
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
  mkdirp.sync deltos-home + \private/by-id
add-command "install-theme [git url]", "Install theme", install-theme
add-command "title", "Show title of current deltos", ->
  console.log read-config!.title
add-command "config", "Edit config file", edit-config
add-command "new [title...]", "Create a note and print the filename", (...args) ->
  console.log new-note args.join ' '
add-command "daily", "Create a daily note and open in $EDITOR", ->
  launch-editor new-daily!
add-command "post [title...]", "Start a new post in $EDITOR", (...args) ->
  launch-editor new-note (args.join ' ')
add-command "edit [id]", "Edit an existing post", ->
  launch-editor get-filename it
add-command \search, "Interactive search", ->
  {launch-search} = require \./util
  launch-search!
add-command "grep [pattern]", "Grep body of notes", (pat) ->
  grep-entries(pat).map -> console.log it
add-command "philtre [query]", "Philtre notes", (query) ->
  philtre-entries(query).map -> console.log it
add-command "render [id]", "Render [id] as HTML", ->
  {render} = require \./html
  console.log render it
add-command \build-site, "Build static HTML", ->
  {build-site, build-private-reference} = require \./html
  build-private-reference!
  build-site!
add-command \clean, "Delete built HTML etc.", ->
  fs = require \fs-extra
  dirs = [deltos-home + '/site/by-id/',
          deltos-home + '/private/by-id/']
  fs.remove-sync deltos-home + '/cache.json'
  for dir in dirs
    for fname in fs.readdir-sync dir
      fs.remove-sync dir + fname
add-command \json, "Dump all entries to JSON", ->
  {dump-json} = require \./html
  console.log dump-json!
add-command \todos,  "Dump todo list", -> console.log dump-todos!
add-command \tagged,  "Dump TSV for posts with tag", dump-tsv-tagged
add-command \tsv,  "Dump basic TSV", dump-tsv
add-command \version, "Show version number", ->
  pkg = require \../package.json
  console.log pkg.version
add-command \help, "Show this help", ->
  console.log "usage: deltos <command> [options...]\n"
  for name,func of commands
    pad = (' ' * (25 - func.command.length))
    console.log "    #{func.command}#pad#{func.desc}"
  process.exit 1

try
  func = commands[process.argv.2]
catch # bad command, print help
  func = commands.help!

if not func
  func = commands.help

func.apply null, process.argv.slice 3
