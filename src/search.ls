# This is in a separate file to avoid require loops

{launch-editor, get-filename} = require \./util
{dump-tsv} = require \./db

export launch-search = ->
  spawn = require(\child_process).spawn
  stream = require \stream
  fzf = spawn 'fzf',
    stdio: [\pipe, \pipe, \inherit]
    shell: true

  fzf.stdout.set-encoding \utf-8
  stdin = new stream.Readable!
  dump-tsv -> stdin.push it + '\n'
  stdin.push null
  stdin.pipe fzf.stdin

  fzf.stdout.on \data, ->
    launch-editor get-filename it.trim!.split('\t')[*-1]
