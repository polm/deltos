
         _      _ _            
      __| | ___| | |_ ___  ___ 
     / _` |/ _ \ | __/ _ \/ __|
    | (_| |  __/ | || (_) \__ \
     \__,_|\___|_|\__\___/|___/
                               
    ===============================

Deltos is a tool for managing personal information. 

# Getting started

Install with npm.

    npm install -g deltos

Make sure `bin/deltos` is in your path. 

    deltos init
    deltos post My First Post

Write a post. The header is just YAML, so feel free to add fields. Write a
little note and put some tags in the `tags` field, comma separated. Then close
your editor. 

If you want to search using the included tools you'll need
[jq](https://stedolan.github.io/jq/) and
[percol](https://github.com/mooz/percol). Once those are installed you can
search just by running: 

    deltos cache && dsearch

Just type to filter entries displayed, and select one from the list to edit it.
To make sure the cache is regenerated regularly add an entry to your crontab,
remembering to set the environment variable. On most crons you can put in an
entry like this (assuming `deltos-cache` is in your `PATH`): 

    */10 * * * * deltos cache

If you use vim you'll want to check [deltos.vim](http://github.com/polm/deltos.vim). 

# What Deltos Is

Deltos is a system for personal information management that I made for myself. 

I like wikis, but setting them up can be tedious. Running a DB is a hassle, and
I want to be able to use my own text editor.  Even if a wiki uses flat files
there are still issues.

- Unicode support is typically mediocre
- Thinking up titles is tedious
- Links break and chaos is unleashed when titles change

There are downsides to using uuid keys, but I realized I don't really care
about them. The most important thing is **I want to start writing just by
pushing a button.** The next most important thing is **I want to find what I've
written before**. Tags, rich metadata, and files that work with the tools I'm
used to (grep and so on) seemed like the best way to do that. 

A secondary goal is the ability to dump documents to HTML so as to share them
more easily. You are encouraged to rip that bit out and replace it with
something that fits your needs. 
 
# Basic Idea

You create a note. A note probably has a title, has tags, and has a Body, which
is just another kind of metadata but rather longer. The important thing is
writing the body down and not having to think too much about the title or
getting the metadata correct.

Coming back to what you've written, it's important to be able to organize by
various metadata fields, to link notes together, and to use outlines to
organize notes in hierarchies when tags don't cut it. You should also be able
to edit an article, including its metadata, without breaking links or
disrupting the integrity of your web. 

## TODO

- explain html generation
- explain searchable private html reference

## License

CC0, WTFPL, Kopyleft All Rites Reversed. Do as you like. 

-POLM
