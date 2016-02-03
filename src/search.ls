# code to search through entries

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

make-hit-div = (hit, query) ->
  div = document.create-element \div
  div.innerHTML = make-embed hit
  return div

make-embed = (entry) ->
  out = "<a class=\"result\" href=\"/by-id/#{entry.id}.html\">"
  out += '<div class="summary-small">'
  out +='<div class=\"imgwrapper\" '
  if entry.image
    out += "style=\"background-image: url(#{entry.image})\""
  out += "></div>"
  out += "<h2>#{entry.title}</h2>"
  out += "<p>#{entry.description}</p>"
  out += "</div></a>"

search = ->
  rd = document.query-selector \.deltos-results
  input = document.query-selector \.deltos-search
  rd.innerHTML = ''
  query = input.value.to-lower-case!
  for entry in entries
    if query.length == 0 or -1 < entry.body.index-of query
      rd.append-child make-hit-div entry
    if rd.length > 50 then return # we have enough

input = document.query-selector \.deltos-search
input.onfocus = ->
  input.scroll-into-view!

