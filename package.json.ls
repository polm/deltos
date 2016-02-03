name: \deltos
version: \1.2.2

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
  'js-yaml': \^3.2.2
  marked: \^0.3.2
  'node-uuid': \^1.4.1
  'prelude-ls': \^1.1.1
  domino: \^1.0.19
  rss: \^1.0.0
  mkdirp: \^0.5.1
  searchy: \^0.0.2

dev-dependencies: {}

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
  dsearch: './bin/dsearch'

scripts:
  test: \./test.sh

prefer-global: true

repository:
  type: \git
  url: 'git://github.com/polm/deltos.git'
