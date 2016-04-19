JS = $(wildcard lib/*.js)

all: $(JS) search.browser.js package.json
	
lib/%.js: src/%.ls
	lsc -c -o lib $<

package.json: package.json.ls
	lsc package.json.ls > package.json

search.browser.js: lib/search.js
	browserify lib/search.js > search.browser.js

clean:
	rm -f lib/*
