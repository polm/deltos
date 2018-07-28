JS = $(wildcard lib/*.js)

all: $(JS) package.json
	
lib/%.js: src/%.ls
	lsc -c -o lib $<

package.json: package.json.ls
	lsc package.json.ls > package.json

clean:
	rm -f lib/*
