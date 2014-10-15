name: \deltos
version: \1.0.3

description: "Deltos is a note management tool using flat files."

keywords:
  \notes
  \wiki
  \memex
  \dke
  \blog

author: "Paul O'Leary McCann <polm@dampfkraft.com>"
homepage: "http://github.com/polm/deltos"
bugs: "http://github.com/polm/deltos/issues"

license: \WTFPL

dependencies:
  LiveScript: \^1.3.0
  'js-yaml': \^3.2.2
  jsdom: \^1.0.4
  marked: \^0.3.2
  'node-uuid': \^1.4.1
  'prelude-ls': \^1.1.1
  split: \^0.3.0
  'terminal-menu': \^0.3.2

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

scripts:
  test: \false

prefer-global: true

repository:
  type: \git
  url: 'git://github.com/polm/deltos.git'
