# code to search through entries

WINDOW = 5 # max entries to show at once

{philtre} = require \philtre
URL = require \url

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

  # If we have a special thumbnail url, use it
  # if not just use the full-size image
  # not good for slow connections, but fine as a fallback
  # The default here is already assigned when calculating metadata
  url = entry.image
  if entry.thumbnail
    url = URL.parse(entry.thumbnail).path
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

  # if the query changed, reset state
  if input.previous != query
    input.offset = 0
    input.pointer = -1
    input.previous = query

  results = philtre query, entries
  input.hits = results.length

  out = results.slice input.offset, input.offset + WINDOW

  summary.innerHTML = "#{results.length} hits"
  for entry in results
    rd.append-child make-hit-div entry

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
      this.pointer = Math.max -1, this.pointer - WINDOW # up
    if it.key-code == 34
      this.pointer = Math.min (results.length - 1), this.pointer + WINDOW # down
    event.prevent-default!
  # arrow up/down change the selected item
  | 38 =>
    this.pointer = Math.max -1, this.pointer - 1 # up
  | 40 =>
    this.pointer = Math.min (results.length - 1), this.pointer + 1
  | 13 => # enter selects current
    if this.pointer > -1 and this.pointer < results.length
      document.location = results[this.pointer].href
  default \ok
  selected = results[this.pointer]
  if selected
    console.log selected
    console.log selected.parent-element
    selected.class-list.add \selected
    grand = selected.parent-element.parent-element
    grand.scroll-top = selected.offset-top - grand.offset-top

input = document.query-selector \.deltos-search
input.pointer = -1
input.offset = 0
input.hits = 0
input.previous = ''
input.onkeydown = pointer-handler
input.focus!

