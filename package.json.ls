name: \deltos
version: \1.1.1

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
  livescript: \^1.4.0
  'js-yaml': \^3.2.2
  marked: \^0.3.2
  'node-uuid': \^1.4.1
  'prelude-ls': \^1.1.1
  domino: \^1.0.19
  rss: \^1.0.0
  mkdirp: \^0.5.1

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
  'deltos-cache': './bin/deltos-cache'
  dsearch: './bin/dsearch'

scripts:
  test: \./test.sh

prefer-global: true

repository:
  type: \git
  url: 'git://github.com/polm/deltos.git'
