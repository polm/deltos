all: src/*ls package.json
	lsc -c -o lib src/

package.json: package.json.ls
	lsc package.json.ls > package.json

clean:
	rm -f lib/*
