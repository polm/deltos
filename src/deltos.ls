{Obj, filter, keys, values, group-by, concat, unique, map, \
  take, sort-by, sort-with, reverse, intersection} = require \prelude-ls
{read-stdin-as-lines-then, launch-editor, deltos-home, \
  get-filename} = require \./util

# Top-level commands - these are called more or less directly by the command line
#
init = ->
  # create empty directories needed for before first run
  mkdirp = require \mkdirp
  mkdirp.sync deltos-home + \by-id
  mkdirp.sync deltos-home + \site
  mkdirp.sync deltos-home + \private

{new-note,dump-tsv,dump-todos} = require \./entries

write-daily = -> launch-editor new-daily!
write-post = -> launch-editor new-note it
edit-post = -> launch-editor it

{render, build-site, build-private-reference, all-to-json} = require \./html

# Actually handling command line arguments

commands = []

add-command = (name, desc, func) ->
  func.command = name
  func.desc = desc
  name = name.split(" ").0 # drop arguments etc.
  commands[name] = func

add-command "init", "Set up DELTOS_HOME", init
add-command "new [title...]", "Create a note and print the filename", ->
  console.log new-note process.argv.slice(3).join ' '
add-command "daily", "Create a daily note and open in $EDITOR", ->
  write-daily!
add-command "post [title...]", "Start a new post in $EDITOR", ->
  write-post process.argv.slice(3).join ' '
add-command "edit [id]", "Edit an existing post", ->
  edit-post get-filename process.argv.3
add-command "render [id]", "Render [id] as HTML", ->
  console.log render process.argv.3
add-command \build-site, "Build static HTML", ->
  build-private-reference!
  build-site!
add-command \json, "Dump all entries to JSON", all-to-json
add-command \todos,  "Dump todo list", -> console.log dump-todos!
add-command \tsv,  "Dump basic TSV", -> console.log dump-tsv!
add-command \version, "Show version number", ->
  pkg = require \../package.json
  console.log pkg.version
add-command \help, "Show this help", ->
  console.log "usage: deltos <command> [options...]\n"
  for name,func of commands
    #TODO get tabs right here
    console.log "\t#{func.command}\t\t#{func.desc}"
  process.exit 1

try
  func = commands[process.argv.2]
catch # bad command, print help
  func = commands.help!

if not func
  func = commands.help

func!

