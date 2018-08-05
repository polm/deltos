name: \deltos
version: \1.4.0

description: "Deltos is a note management tool using flat files."

keywords:
  \notes
  \wiki
  \memex

author: "Paul O'Leary McCann <polm@dampfkraft.com>"
homepage: "http://github.com/polm/deltos"
bugs: "http://github.com/polm/deltos/issues"

license: \WTFPL

dependencies:
  'better-sqlite': \^4.1.4
  'js-yaml': \^3.2.2
  'markdown-it': \^8.3.1
  'markdown-it-anchor': \^4.0.0
  'uuid': \^3.0.0
  'prelude-ls': \^1.1.1
  domino: \^1.0.19
  rss: \^1.0.0
  mkdirp: \^0.5.1
  searchy: \^0.0.23
  philtre: \^1.0.2
  'fs-extra': \^2.1.2
  split: \^1.0.0

dev-dependencies:
  livescript: \^1.4.0

engines:
  node: '>= 0.10.0'

directories:
  lib: './lib'
  bin: './bin'

files:
  \lib
  \bin
  \README.md

main: './lib'
bin:
  deltos: './bin/deltos'

scripts:
  test: \./test.sh

prefer-global: true

repository:
  type: \git
  url: 'git://github.com/polm/deltos.git'
