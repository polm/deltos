##############################################
# This includes:
# - functional helpers (memoize, eval wrapper)
# - entry list manipulation (tagged, is-in, etc.)
# - time-related code (local-iso-time, normalize-date)
##############################################

ls = require \livescript

# XXX note that eval'd code has full access to the calling context 
# (which is to say the interior of this script)
export eval-ls = ->
  eval ls.compile it, bare: true

# simple memoizer for thunks
export memoize = (func) ->
  output = null
  return ->
    if output then return output
    output := func!
    return output


export is-in = (list, item) --> -1 < list.index-of item

# On a null tag, this is always true
export tagged = (tag, entry) --> (not tag) or is-in entry.tags, tag

export no-empty = -> it.filter (-> not (it == null or it == '') )

export normalize-date = ->
  # This needs to be done to handle some date stupidity
  # YAML can save dates natively, but only recognizes a subset of ISO8601
  # Specifically, 4-character timezones must have a colon (09:00, not 0900)
  it.date = (new Date it.date).toISOString!

export local-iso-time = (vsnow=0) ->
  # from here: http://stackoverflow.com/questions/10830357/javascript-toisostring-ignores-timezone-offset
  # Idea is to take a date, add our offset, get that as Z/UTC time, then just change the tz note
  offset = (new Date!).get-timezone-offset!
  offset-ms = offset * 60000
  offset-ms += vsnow
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

  after?!

