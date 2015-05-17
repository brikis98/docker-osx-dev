#!/bin/bash
#
# Automated tests for docker-osx-dev 

set -e

readonly TEST_FOLDER="test-project"
readonly TEST_FILE="test-file"
readonly TEST_FILE_CONTENTS="test file contents"

function assert_equals {
  local readonly left=$1
  local readonly right=$2

  if [[ "$left" -ne "$right" ]]; then
    echo "Assertion failure: $left != $right"
    exit 1
  fi
}

function test_setup {
  # We're just looking for the script to run without errors
  ./setup.sh  
}

function create_test_project {
  mkdir "$TEST_FOLDER"
  cd "$TEST_FOLDER"
  echo "$TEST_FILE_CONTENTS" > "$TEST_FILE"
}

function test_docker_osx_dev_start {
  # We're just looking for the scripts to run without errors  
  docker-osx-dev init
  docker-osx-dev start
}

function test_docker_run {
  local readonly out=$(docker run --rm gliderlabs/alpine:3.1 uname)
  assert_equals "$out" "Linux"  
}

function test_docker_mount {
  local readonly out=$(docker run --rm -v $(pwd):/src gliderlabs/alpine:3.1 cd /src && cat foo)
  assert_equals "$out" "$TEST_FILE_CONTENTS"
}

function test_docker_osx_dev_stop {
  # We're just looking for the scripts to run without errors  
  docker-osx-dev stop
}

test_setup
create_test_project
test_docker_osx_dev_start
test_docker_run
test_docker_mount
test_docker_osx_dev_stop