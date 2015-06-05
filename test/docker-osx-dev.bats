#!/usr/bin/env bats
#
# Unit tests for docker-osx-dev. To run these tests, you must have bats 
# installed. See https://github.com/sstephenson/bats 

source src/docker-osx-dev "test_mode"
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
  run log "color_start" "color_end" "timestamp" "$LOG_LEVEL_INFO" "foo"
  assert_output "color_starttimestamp [$LOG_LEVEL_INFO] foocolor_end"
}

@test "log called with color, log level, and multiple messages prints them all to stdout" {
  run log "color_start" "color_end" "timestamp" "$LOG_LEVEL_INFO" "foo" "bar" "baz"
  assert_output "color_starttimestamp [$LOG_LEVEL_INFO] foo bar bazcolor_end"
}

@test "log called with color and log level reads message from stdin stdout" {
  result=$(echo "foo" | log "color_start" "color_end" "timestamp" "$LOG_LEVEL_INFO")
  assert_equal "color_starttimestamp [$LOG_LEVEL_INFO] foocolor_end" "$result"
}

@test "log called with disabled log level prints nothing to stdout" {
  run log "color_start" "color_end" "timestamp" "$LOG_LEVEL_DEBUG" "foo"
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

@test "assert_valid_log_level accepts DEBUG" {
  run assert_valid_log_level "$LOG_LEVEL_DEBUG"
  assert_success
}

@test "assert_valid_log_level rejects an invalid value" {
  run assert_valid_log_level "INVALID_LOG_LEVEL"
  assert_failure
}

@test "configure_paths_to_sync with non-existent docker-compose file results in syncing the current directory" {
  configure_paths_to_sync not-a-real-docker-compose-file > /dev/null
  assert_equal "$(pwd)" "$PATHS_TO_SYNC"
}

@test "configure_paths_to_sync with docker-compose file with no volumes results in syncing the current directory" {
  configure_paths_to_sync test/resources/docker-compose-no-volumes.yml > /dev/null
  assert_equal "$(pwd)" "$PATHS_TO_SYNC" 
}

@test "configure_paths_to_sync reads paths to sync from docker-compose file" {
  configure_paths_to_sync "test/resources/docker-compose-one-volume.yml" > /dev/null
  assert_equal "/host" "$PATHS_TO_SYNC"
}

@test "configure_paths_to_sync with one path from command line" {
  configure_paths_to_sync "test/resources/docker-compose-no-volumes.yml" "/foo" > /dev/null
  assert_equal "/foo" "$PATHS_TO_SYNC"
}

@test "configure_paths_to_sync with multiple paths from command line" {
  configure_paths_to_sync "test/resources/docker-compose-no-volumes.yml" "/foo" "/bar" "/baz/blah" > /dev/null
  assert_equal "/foo /bar /baz/blah" "$PATHS_TO_SYNC"
}

@test "configure_paths_to_sync with multiple paths from command line and paths from docker-compose.yml" {
  configure_paths_to_sync "test/resources/docker-compose-one-volume.yml" "/foo" "/bar" "/baz/blah" > /dev/null
  assert_equal "/foo /bar /baz/blah /host" "$PATHS_TO_SYNC"
}

@test "configure_excludes with non-existent ignore file results in default excludes" {
  configure_excludes "not-a-real-ignore-file" > /dev/null
  assert_equal "$DEFAULT_EXCLUDES" "$EXCLUDES"
}

@test "configure_excludes with empty ignore file results in default excludes" {
  configure_excludes "test/resources/ignore-file-empty.txt" > /dev/null
  assert_equal "$DEFAULT_EXCLUDES" "$EXCLUDES"
}

@test "configure_excludes loads ignores from ignore file" {
  configure_excludes "test/resources/ignore-file-with-one-entry.txt" > /dev/null
  assert_equal "foo" "$EXCLUDES"
}

@test "configure_excludes uses single command line arg" {
  configure_excludes "not-a-real-ignore-file" "foo" > /dev/null
  assert_equal "foo" "$EXCLUDES"
}

@test "configure_excludes uses multiple command line args" {
  configure_excludes "not-a-real-ignore-file" "foo" "bar" "baz" > /dev/null
  assert_equal "foo bar baz" "$EXCLUDES"
}

@test "configure_excludes uses ignore file and multiple command line args" {
  configure_excludes "test/resources/ignore-file-with-one-entry.txt" "foo" "bar" "baz" > /dev/null
  assert_equal "foo bar baz foo" "$EXCLUDES"
}

@test "load_ignore_paths skips non-existent files" {
  run load_ignore_paths "not-a-real-file"
  assert_output ""
}

@test "load_ignore_paths handles empty ignore files" {
  run load_ignore_paths "test/resources/ignore-file-empty.txt"
  assert_output ""
}

@test "load_ignore_paths handles ignore file with one entry" {
  run load_ignore_paths "test/resources/ignore-file-with-one-entry.txt"
  assert_output "foo"
}

@test "load_ignore_paths handles ignore file with multiple entries" {
  run load_ignore_paths "test/resources/ignore-file-with-multiple-entries.txt"
  assert_output "foo bar baz"
}

@test "load_ignore_paths handles ignore file with comments" {
  run load_ignore_paths "test/resources/ignore-file-with-comments.txt"
  assert_output "foo bar baz"
}

@test "load_paths_from_docker_compose skips non-existent files" {
  run load_paths_from_docker_compose "not-a-real-file"
  assert_output ""
}

@test "load_paths_from_docker_compose handles docker compose files with no volumes" {
  run load_paths_from_docker_compose "test/resources/docker-compose-no-volumes.yml"
  assert_output ""
}

@test "load_paths_from_docker_compose handles docker compose files with one volume" {
  run load_paths_from_docker_compose "test/resources/docker-compose-one-volume.yml"
  assert_output "/host"
}

@test "load_paths_from_docker_compose handles docker compose files with multiple volumes" {
  run load_paths_from_docker_compose "test/resources/docker-compose-multiple-volumes.yml"
  assert_output "/host1 /foo/bar/baz /source/path"
}

@test "load_paths_from_docker_compose handles docker compose files with multiple containers and multiple volumes" {
  run load_paths_from_docker_compose "test/resources/docker-compose-multiple-containers-with-volumes.yml"
  assert_output "/host1 /host2 /foo/bar /"
}

@test "load_paths_from_docker_compose handles docker compose files with non-mounted volumes" {
  run load_paths_from_docker_compose "test/resources/docker-compose-non-mounted-volumes.yml"
  assert_output "/host /a"
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

@test "assert_valid_arg empty string is not valid" {
  run assert_valid_arg "" "--foo"
  assert_failure
}

@test "assert_valid_arg parameter that starts with a dash is not valid" {
  run assert_valid_arg "-b" "--foo"
  assert_failure
}

@test "assert_valid_arg parameter that starts with two dashes is not valid" {
  run assert_valid_arg "--bar" "--foo"
  assert_failure
}

@test "assert_valid_arg normal string is valid" {
  run assert_valid_arg "normal-string" "--foo"
  assert_success
}




