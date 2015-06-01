#!/usr/bin/env bats
#
# Unit tests for setup.sh. To run these tests, you must have bats 
# installed. See https://github.com/sstephenson/bats 

source src/setup.sh -t
load test_helper

@test "index_of doesn't find match in empty array" {
  array=()
  run index_of "foo" "${array[@]}"
  assert_output -1
}

@test "index_of finds match in 1 item array" {
  array=("foo")
  run index_of "foo" "${array[@]}"
  assert_output 0
}

@test "index_of doesn't find match in 1 item array" {
  array=("abc")
  run index_of "foo" "${array[@]}"
  assert_output -1
}

@test "index_of finds match in 3 item array" {
  array=("abc" "foo" "def")
  run index_of "foo" "${array[@]}"
  assert_output 1
}

@test "index_of doesn't find match in 3 item array" {
  array=("abc" "def" "ghi")
  run index_of "foo" "${array[@]}"
  assert_output -1
}

@test "index_of finds match with multi argument syntax" {
  run index_of "foo" "abc" "def" "ghi" "foo"
  assert_output 3
}

@test "index_of returns index of first match" {
  run index_of foo abc foo def ghi foo
  assert_output 1
}

@test "log called with color, log level, and message prints to stdout" {
  run log "color_start" "color_end" "$LOG_LEVEL_INFO" "foo"
  assert_output "color_start[$LOG_LEVEL_INFO] foocolor_end"
}

@test "log called with color, log level, and multiple messages prints them all to stdout" {
  run log "color_start" "color_end" "$LOG_LEVEL_INFO" "foo" "bar" "baz"
  assert_output "color_start[$LOG_LEVEL_INFO] foo bar bazcolor_end"
}

@test "log called with color and log level reads message from stdin stdout" {
  result=$(echo "foo" | log "color_start" "color_end" "$LOG_LEVEL_INFO")
  assert_equal "color_start[$LOG_LEVEL_INFO] foocolor_end" "$result"
}

@test "log called with disabled log level prints nothing to stdout" {
  run log "color_start" "color_end" "$LOG_LEVEL_DEBUG" "foo"
  assert_output ""
}

@test "join empty arrays" {
  run join ","
  assert_output ""
}

@test "join arrays of length 1" {
  run join "," "foo"
  assert_output "foo"
}

@test "join arrays of length 3" {
  run join ", " "foo" "bar" "baz"
  assert_output "foo, bar, baz"
}

@test "join arrays with empty separator" {
  run join "" "foo" "bar" "baz"
  assert_output "foobarbaz"
}

@test "join arrays passed in as arguments" {
  arr=(foo bar baz)
  run join ", " "${arr[@]}"
  assert_output "foo, bar, baz"
}

@test "assert_non_empty exits on empty value" {
  run assert_non_empty ""
  assert_failure
}

@test "assert_non_empty doesn't exit on non-empty value" {
  run assert_non_empty "foo"
  assert_success
}

@test "env_is_defined returns true for USER variable being defined" {
  run env_is_defined "USER"
  assert_success
}

@test "env_is_defined returns false for non-existent variable being defined" {
  run env_is_defined "not-a-real-environment-variable"
  assert_failure
}

@test "determine_boot2docker_exports_for_env_file handles empty string" {
  run determine_boot2docker_exports_for_env_file
  assert_output ""
}

@test "determine_boot2docker_exports_for_env_file shows an error for an unexpected boot2docker shellinit output" {
  run determine_boot2docker_exports_for_env_file "not-a-valid-shellinit-format"
  assert_failure
}

@test "determine_boot2docker_exports_for_env_file parses a single new export" {
  shellinit="export NEW_ENV_VARIABLE=VALUE"
  run determine_boot2docker_exports_for_env_file "$shellinit"
  assert_output "$(echo -e "$ENV_FILE_COMMENT$shellinit")"
}

@test "determine_boot2docker_exports_for_env_file parses multiple new exports" {
  shellinit="export NEW_ENV_VARIABLE_1=VALUE1
export NEW_ENV_VARIABLE_2=VALUE2
export NEW_ENV_VARIABLE_3=VALUE3"
  run determine_boot2docker_exports_for_env_file "$shellinit"
  assert_output "$(echo -e "$ENV_FILE_COMMENT$shellinit")"
}

@test "determine_boot2docker_exports_for_env_file skips environment variables already defined" {
  shellinit="
export USER=$USER
export HOME=$HOME"
  run determine_boot2docker_exports_for_env_file "$shellinit"
  assert_output ""
}

@test "determine_boot2docker_exports_for_env_file parses multiple new exports and skips environment variables already defined" {
  shellinit="
export NEW_ENV_VARIABLE_1=VALUE1
export USER=$USER
export HOME=$HOME 
export NEW_ENV_VARIABLE_2=VALUE2"
  run determine_boot2docker_exports_for_env_file "$shellinit"
  assert_output "$(echo -e "${ENV_FILE_COMMENT}export NEW_ENV_VARIABLE_1=VALUE1\nexport NEW_ENV_VARIABLE_2=VALUE2")"
}


