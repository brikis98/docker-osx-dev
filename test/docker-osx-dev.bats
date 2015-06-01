#!/usr/bin/env bats
#
# Unit tests for docker-osx-dev. To run these tests, you must have bats 
# installed. See https://github.com/sstephenson/bats 

source src/docker-osx-dev -t
load test_helper

@test "index_of doesn't find match in empty array" {
  array=()
  index=$(index_of "foo" "${array[@]}")
  assert_equal -1 "$index"
}

@test "index_of finds match in 1 item array" {
  array=("foo")
  index=$(index_of "foo" "${array[@]}")
  assert_equal 0 "$index"
}

@test "index_of doesn't find match in 1 item array" {
  array=("abc")
  index=$(index_of "foo" "${array[@]}")
  assert_equal -1 "$index"
}

@test "index_of finds match in 3 item array" {
  array=("abc" "foo" "def")
  index=$(index_of "foo" "${array[@]}")
  assert_equal 1 "$index"
}

@test "index_of doesn't find match in 3 item array" {
  array=("abc" "def" "ghi")
  index=$(index_of "foo" "${array[@]}")
  assert_equal -1 "$index"
}

@test "index_of finds match with multi argument syntax" {
  index=$(index_of "foo" "abc" "def" "ghi" "foo")
  assert_equal 3 "$index"
}

@test "index_of returns index of first match" {
  index=$(index_of foo abc foo def ghi foo)
  assert_equal 1 "$index"
}

@test "log called with color, log level, and message prints to stdout" {
  result=$(log "color_start" "color_end" "$LOG_LEVEL_INFO" "foo")
  assert_equal "color_start[$LOG_LEVEL_INFO] foocolor_end" "$result"
}

@test "log called with color, log level, and multiple messages prints them all to stdout" {
  result=$(log "color_start" "color_end" "$LOG_LEVEL_INFO" "foo" "bar" "baz")
  assert_equal "color_start[$LOG_LEVEL_INFO] foo bar bazcolor_end" "$result"
}

@test "log called with color and log level reads message from stdin stdout" {
  result=$(echo "foo" | log "color_start" "color_end" "$LOG_LEVEL_INFO")
  assert_equal "color_start[$LOG_LEVEL_INFO] foocolor_end" "$result"
}

@test "log called with disabled log level prints nothing to stdout" {
  result=$(log "color_start" "color_end" "$LOG_LEVEL_DEBUG" "foo")
  assert_equal "" "$result"
}

@test "join empty arrays" {
  result=$(join ",")
  assert_equal "" "$result"
}

@test "join arrays of length 1" {
  result=$(join "," "foo")
  assert_equal "foo" "$result"
}

@test "join arrays of length 3" {
  result=$(join ", " "foo" "bar" "baz")
  assert_equal "foo, bar, baz" "$result"
}

@test "join arrays with empty separator" {
  result=$(join "" "foo" "bar" "baz")
  assert_equal "foobarbaz" "$result"
}

@test "join arrays passed in as arguments" {
  arr=(foo bar baz)
  result=$(join ", " "${arr[@]}")
  assert_equal "foo, bar, baz" "$result"
}



