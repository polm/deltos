##############################################
# This includes:
# - functional helpers (memoize, eval wrapper)
# - entry list manipulation (tagged, is-in, etc.)
# - time-related code (local-iso-time, get-yesterday)
##############################################
# Prepare widely-used environment settings
export deltos-home = (process.env.DELTOS_HOME or (process.env.HOME + '/.deltos')) + '/'
export BASEDIR = deltos-home + '/by-id/'
export get-filename = -> BASEDIR + it

CONFIG = deltos-home + \config.yaml

fs = require \fs
Yaml = {}
export yaml = ->
  if not Yaml.safe-load then
    Yaml := require(\js-yaml)
  # The failsafe schema interperets all terminal values as strings
  # We don't need support for numbers, and some "special" features
  # can cause issues
  # The bug this initially fixed was zero-initial short numeric 
  # uuids like "06382" being interpreted as octal
  Yaml.safe-load it, schema: Yaml.FAILSAFE_SCHEMA

export yaml-dump = ->
  if not Yaml.safe-load then
    Yaml := require(\js-yaml)
  # flowlevel controls how compact the exported yaml is
  # as with reading, we only expect strings
  Yaml.safe-dump it, schema: Yaml.FAILSAFE_SCHEMA, flow-level: 1

Markdown = {}

export markdown = ->
  if not Markdown.render
    Markdown := require(\markdown-it)(html: true)
             .use( (require \markdown-it-anchor), {permalink: true,
             permalinkSymbol: \☙, level: 1, permalinkBefore: true})
  Markdown.render it

# simple memoizer for one-argument functions or thunks
export memoize = (func) ->
  output = {}
  return ->
    if output[it] != undefined then return output[it]
    output[it] = func it
    return output[it]

export is-in = (list, item) --> -1 < list.index-of item

# On a null tag, this is always true
export tagged = (tag, entry) --> (not tag) or is-in entry.tags, tag

export no-empty = -> it.filter (-> not (it == null or it == '') )

# get a url-safe form of the title
export get-slug = (entry) ->
  entry.title.replace(/ /g, '-').replace /[!@#$%^&\*\.\(\)\[\]\/\\'"{}?<>]/g, ''

export local-iso-time = (vsnow=0) ->
  # from here: http://stackoverflow.com/questions/10830357/javascript-toisostring-ignores-timezone-offset
  # Idea is to take a date, add our offset, get that as Z/UTC time, then just change the tz note
  offset = (new Date!).get-timezone-offset!
  offset-ms = offset * 60000
  offset-ms -= vsnow
  local-time = (new Date(Date.now! - offset-ms)).toISOString!slice 0, -1
  offset-hours = offset / 60
  offset-double-oh-hours = ~~(offset-hours) * 100
  if offset-hours % 1 != 0 # half-hour offset
    offset-double-oh-hours += 50
  # remember this is the time from UTC to us, not us to UTC
  offset-prefix = \-
  if offset-double-oh-hours < 0
    offset-prefix = \+
    offset-double-oh-hours *= -1
  offset-string = '000000' + offset-double-oh-hours
  offset-string = offset-string.slice (offset-string.length - 4)
  return local-time + offset-prefix + offset-string

export get-yesterday = ->
  # This is tricky since we want to handle daylight savings etc.
  today = local-iso-time!.substr 0, 10
  hour = 1000 * 60 * 60
  maybe-yesterday = local-iso-time (-22 * hour)

  # short day
  if maybe-yesterday != today then return maybe-yesterday.substr 0, 10

  # normal case
  maybe-yesterday = local-iso-time (-24 * hour)
  if maybe-yesterday != today then return maybe-yesterday.substr 0, 10

  # long day
  return local-iso-time(-26 * hour).substr 0, 10

export read-stdin-as-lines-then = (func) ->
  buf = ''
  process.stdin.set-encoding \utf-8
  process.stdin.on \data, -> buf += it
  process.stdin.on \end, -> func (buf.split "\n" |> no-empty)

export launch-editor = (file, after) ->
  spawn = require(\child_process).spawn
  # from here:
  # https://gist.github.com/Floby/927052
  cp = spawn process.env.EDITOR, [file], {
    stdio: \inherit
  }

  cp.on \close, -> after?!

export read-config = memoize ->
  try
    yaml fs.read-file-sync CONFIG, \utf-8
  catch e
    console.error "Error reading config:\n" + e.message
    process.exit 1

export edit-config = ->
  launch-editor CONFIG

export install-theme = (theme-git-url) ->
  # clone theme from url into home/theme
  exec = require(\child_process).exec-sync
  exec "git clone '#theme-git-url' '#deltos-home/theme'"
  try
    fs.mkdir-sync "#deltos-home/site"
    fs.mkdir-sync "#deltos-home/site/by-id"
  catch
    \ok # probably already existed, don't worry

  # symlink most files into site/
  for file in fs.readdir-sync "#deltos-home/theme"
    if file == "single.html" then continue
    if file == "README.md" then continue
    fs.symlink-sync "#deltos-home/theme/#file", "#deltos-home/site/#file"

export get-mtime = (fname) ->
  try
    +fs.stat-sync(fname).mtime
  catch # happens if file doesn't exist
    0

export get-url = ->
  if it.slug then return "/#{it.slug}.html"
  "/by-id/#{it.id}\##{get-slug it}"
