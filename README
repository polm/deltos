
     _      _ _            
  __| | ___| | |_ ___  ___ 
 / _` |/ _ \ | __/ _ \/ __|
| (_| |  __/ | || (_) \__ \
 \__,_|\___|_|\__\___/|___/
                           
===============================

Deltos is a tool for managing personal information. 

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

# Features, or How to Get It Done

These seem to be the best way to accomplish the basic idea. 

## Articles go in one directory as UUID named files

Other GUID schemes are fine, but this gives every one a metadata-independent
identity that's easy to generate without a persistent process or tricky locks.

## Metadata searches are enabled by symlink directories

This makes it easy to use anything that interfaces with a filesystem
adequately; shell is enough but higher-level languages aren't ruled out.
The weaknesses of the fs-as-db are strengths here.

## Shown title, hidden link 

A basic scheme for showing one thing and connecting to another: .(My
Title//[uuid]). No ideas for an escape yet, but dot-paren is not usual in
really any language so it's a start.

## Organization

This is one script with several functions. 

All functions take or can be passed a directory; the default one is ~/deltos. 
It can be configured with an environment variable.

deltos new [title]

  Give a filename for a new note, initialized with basic metadata. 

deltos edit [link]

  Takes a link (or plain uuid) and opens it with $EDITOR. 

deltos update

  Update symlink directories to reflect metadata. What metadata to use can be
  configured, but by default directories are made based on title, tags, and
  date (time to the day). 

## Directory structure

DELTOS_HOME/

  root.

by-id/

  this contains the real files immediately beneath it.

by-tag/

  this contains a directory for each tag with symlinks to each article.

by-title/

  this contains a directory for each title with symlinks to each article. Note
  that tiles can be escaped to web slugs or otherwise simplified, causing some
  collisions. This is at least partly inevitable due to the reserved use of "/"
  in Unix systems.

by-date/

  Notes by day. 
