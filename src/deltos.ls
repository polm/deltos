{launch-editor, deltos-home, get-filename, read-config, edit-config, install-theme} = require \./util
{add-image, regenerate-images} = require \./image
fs = require \fs

process.title = \deltos

# Top-level commands - these are called more or less directly by the command line
#
init = ->
  # create empty directories needed for before first run
  mkdirp = require \mkdirp
  mkdirp.sync deltos-home + \by-id
  mkdirp.sync deltos-home + \site/by-id
  mkdirp.sync deltos-home + \private/by-id


{new-note,new-daily,dump-tsv,dump-tsv-tagged,dump-todos,grep-entries,philtre-entries} = require \./entries

write-daily = -> launch-editor new-daily!
write-post = -> launch-editor new-note it
edit-post = -> launch-editor it

{render, build-site, build-private-reference, dump-json} = require \./html

# Actually handling command line arguments

commands = []

add-command = (name, desc, func) ->
  func.command = name
  func.desc = desc
  name = name.split(" ").0 # drop arguments etc.
  commands[name] = func

add-command "init", "Set up DELTOS_HOME", init
add-command "install-theme [git url]", "Install theme", ->
  install-theme it
add-command "title", "Show title of current deltos", ->
  console.log read-config!.title
add-command "config", "Edit config file", edit-config
add-command "new [title...]", "Create a note and print the filename", (...args) ->
  console.log new-note args.join ' '
add-command "daily", "Create a daily note and open in $EDITOR", ->
  write-daily!
add-command "post [title...]", "Start a new post in $EDITOR", (...args) ->
  write-post args.join ' '
add-command "edit [id]", "Edit an existing post", ->
  edit-post get-filename it
add-command \search, "Interactive search", ->
  {launch-search} = require \./util
  launch-search!
add-command "grep [pattern]", "Grep body of notes", (pat) ->
  grep-entries(pat).map -> console.log it
add-command "philtre [query]", "Philtre notes", (query) ->
  philtre-entries(query).map -> console.log it
add-command "render [id]", "Render [id] as HTML", ->
  console.log render it
add-command \build-site, "Build static HTML", ->
  build-private-reference!
  build-site!
add-command \clean, "Delete built HTML etc.", ->
  dirs = [deltos-home + '/site/by-id/',
          deltos-home + '/private/by-id/']
  for dir in dirs
    for fname in fs.readdir-sync dir
      fs.unlink-sync dir + fname
add-command \add-image, "Add an image to the store", add-image
add-command \regenerate-images, "Destroy and regenerate resized images.", regenerate-images
add-command \json, "Dump all entries to JSON", ->
  console.log dump-json!
add-command \todos,  "Dump todo list", -> console.log dump-todos!
add-command \tagged,  "Dump TSV for posts with tag", ->
  console.log dump-tsv-tagged it
add-command \tsv,  "Dump basic TSV", -> console.log dump-tsv!
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

