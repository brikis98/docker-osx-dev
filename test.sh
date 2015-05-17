#!/bin/bash
#
# Automated tests for docker-osx-dev 

set -e

function assert_equals {
  local readonly left=$1
  local readonly right=$2

  if [[ "$left" -ne "$right" ]]; then
    echo "Assertion failure: $left != $right"
    exit 1
  fi
}

mkdir fake-project
cd fake-project

./setup.sh

docker-osx-dev init
docker-osx-dev start

out=$(docker run --rm gliderlabs/alpine:3.1 uname)
assert_equals $out "Linux"

docker-osx-dev stop