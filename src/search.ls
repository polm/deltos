# code to search through entries

WINDOW = 5 # max entries to show at once

{philtre} = require \philtre

map = (list, func) ->
  # for nodelists
  Array.prototype.map.call list, func

load-entries-then = (callback) ->
  req = new XMLHttpRequest!
  req.onload = callback
  req.open \GET \/deltos.json true
  req.send!

load-entries-then ->
  entries = it.target.response.split("\n")
    .filter -> it.length > 0
    .map -> JSON.parse it
  window.entries = entries
  input = document.query-selector \.deltos-search
  input.oninput = search
  search!

make-hit-div = (entry) ->
  div = document.create-element \div
  div.innerHTML = make-embed entry
  return div

make-embed = (entry) ->
  out = "<a class=\"result\" href=\"#{entry.link}\">"
  out += '<div class="summary-small">'
  out +='<div class=\"imgwrapper\" '
  if entry.image
    url = entry.image
    # use small thumbnail if we've got imgur
    # A more general solution would be nice...
    if /imgur.com/.test entry.image
      url = (url.substr 0, (url.length - 5)) + \s.jpg
    out += "style=\"background-image: url(#{url})\""
  out += "></div>"
  out += "<h2>#{entry.title}</h2>"
  out += "<p>#{entry.description}</p>"
  out += "</div></a>"

search = ->
  rd = document.query-selector \.deltos-results
  input = document.query-selector \.deltos-search
  summary = document.query-selector \.deltos-results-summary
  rd.innerHTML = ''
  query = input.value.to-lower-case!
  results = philtre query, entries
  input.hits = results.length

  out = results.slice input.offset, input.offset + WINDOW
  summary.innerHTML = "Showing #{input.offset + 1} to #{input.offset + out.length} of #{results.length} hits"
  for entry in out
    rd.append-child make-hit-div entry


search-hits = (entry, query) ->
  if not query or query.length == 0 then return true
  (new RegExp query, \i).test entry.searchable-text

pointer-handler = ->
  results = document.query-selector-all ".deltos-results .result"
  map results, -> it.class-list.remove \selected
  event = it
  re-render = ->
    event.prevent-default!
    search!
    results := document.query-selector-all ".deltos-results .result"

  switch it.key-code
  # page up/down change the offset
  | 33, 34 =>
    if it.key-code == 33
      this.offset = Math.max 0, this.offset - WINDOW
    if it.key-code == 34
      this.offset = Math.min (WINDOW * ~~(this.hits / WINDOW)), this.offset + WINDOW
    re-render!
  # arrow up/down change the selected item
  | 38 =>
    if this.pointer == 0 and this.offset > 0
      this.offset -= WINDOW
      this.pointer = WINDOW
      re-render!
    this.pointer = Math.max -1, this.pointer - 1 # up
  | 40 =>
    if this.pointer + 1 == WINDOW and this.offset + WINDOW < this.hits
      this.offset += WINDOW
      this.pointer = -1
      re-render!
    this.pointer = Math.min (WINDOW - 1), this.pointer + 1
  | 13 => # enter selects current
    if this.pointer > -1 and this.pointer < results.length
      document.location = results[this.pointer].href
  default \ok
  results[this.pointer]?.class-list.add \selected

input = document.query-selector \.deltos-search
input.pointer = -1
input.offset = 0
input.hits = 0
input.onkeydown = pointer-handler

