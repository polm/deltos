all: src/deltos.ls src/equaeverpoise.ls
	lsc -c -o lib src/

clean:
	rm -f lib/*
