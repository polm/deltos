#!/bin/bash
# Run some simple tests
set -e
set -u
set -o pipefail
set -x 

cd "$(dirname "$0")"
export DELTOS_HOME=./dtest

deltos="./bin/deltos"

$deltos init
$deltos tsv > /dev/null
$deltos json > /dev/null
./bin/deltos-cache

# to test creation, make a file...
newtest=$($deltos new Testy)
# add a random identifier
testwords=$(echo -n "$RANDOM")
echo -e "\nwords words $testwords\n" >> $newtest
# build the site
$deltos build-site
# and make sure it shows up in the html output
grep -q "$testwords" $DELTOS_HOME/private/by-id/$(basename $newtest).html

# TODO
# - maybe figure how to test interactive parts?
# - check RSS
# - check exclusion / published tag use
