name: \deltos
version: \1.3.0

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
  'markdown-it': \^6.0.0
  'node-uuid': \^1.4.1
  'prelude-ls': \^1.1.1
  domino: \^1.0.19
  rss: \^1.0.0
  mkdirp: \^0.5.1
  searchy: \^0.0.19
  philtre: \^1.0.1

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
