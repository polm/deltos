exec = require('child_process').exec-sync
fs = require \fs
{get-new-id} = require \./entries
{deltos-home, read-config} = require \./util
width = read-config!.width or 500

process-image = (imgdir, base, ftype) ->
  exec = require('child_process').exec-sync
  fname = imgdir + base + '.o.' + ftype
  # blog size image
  exec "convert \"#fname\" -resize #{width}x1000 #imgdir/#base.l.#ftype"
  # cropped preview, for image block links etc.
  exec "convert \"#fname\" -resize '#{width}x200^' -gravity center -extent #{width}x200 #imgdir/#base.c.#ftype"
  # thumbnail for search
  exec "convert \"#fname\" -gravity center -resize '90x90^' -crop 90x90+0+0 #imgdir/#base.s.#ftype"
  # return blog size so it can optionally be printed for pasting
  return "/img/#base.l.#ftype"

export add-image = (fname, desc='') ->
  # TODO move this to util or something
  imgdir = deltos-home + '/img/'
  ftype = fname.split('.')[*-1] # should be png, jpg, etc.
  {get-new-id} = require \./entries
  base = get-new-id -> imgdir + it
  fs.write-file-sync (imgdir + base), desc # prevents re-use later and aids search
  fs.write-file-sync (imgdir + base + '.o.' + ftype), fs.read-file-sync fname # save a copy
  process-image imgdir, base, ftype
  console.log "Created resized image and thumbnail. Use the URL below in a note:"
  console.log "/img/#base.l.#ftype"

export regenerate-images = ->
  imgdir = deltos-home + '/img/'
  for fname in fs.readdir-sync imgdir
    parts = fname.split('.')
    if parts.length == 1 then continue # placeholder/description file
    if parts[*-2] != 'o' then continue # ignore old files, will be overwritten
    # now we have the original
    process-image imgdir, parts[0], parts[*-1]


