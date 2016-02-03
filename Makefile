all: src/*ls
	lsc -c -o lib src/

clean:
	rm -f lib/*
