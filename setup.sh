#!/bin/bash
#
# A script for setting up a productive development environment with Docker 
# on OS X. See https://github.com/brikis98/docker-osx-dev for more info.

set -e

# Environment variable file constants
readonly BASH_PROFILE="$HOME/.bash_profile"
readonly BASH_RC="$HOME/.bashrc"
readonly ZSH_RC="$HOME/.zshrc"

# Url constants
readonly HOSTS_FILE="/etc/hosts"
readonly DOCKER_HOST_NAME="dockerhost"

# Console colors
readonly COLOR_DEBUG='\033[1;36m'
readonly COLOR_INFO='\033[0;32m'
readonly COLOR_WARN='\033[1;33m'
readonly COLOR_ERROR='\033[0;31m'
readonly COLOR_INSTRUCTIONS='\033[0;37m'
readonly COLOR_END='\033[0m'

# Log levels 
readonly LOG_LEVEL_DEBUG="DEBUG"
readonly LOG_LEVEL_INFO="INFO"
readonly LOG_LEVEL_WARN="WARN"
readonly LOG_LEVEL_ERROR="ERROR"
readonly LOG_LEVEL_INSTRUCTIONS="INSTRUCTIONS"
readonly LOG_LEVELS=($LOG_LEVEL_DEBUG $LOG_LEVEL_INFO $LOG_LEVEL_WARN $LOG_LEVEL_ERROR $LOG_LEVEL_INSTRUCTIONS)
readonly CURRENT_LOG_LEVEL="${DOCKER_OSX_DEV_LOG_LEVEL:-$LOG_LEVEL_INFO}"

# Script constants
readonly BIN_DIR="/usr/local/bin"
readonly DOCKER_OSX_DEV_SCRIPT_NAME="docker-osx-dev"
readonly DOCKER_OSX_DEV_URL="https://raw.githubusercontent.com/brikis98/docker-osx-dev/master/$DOCKER_OSX_DEV_SCRIPT_NAME"


# Helper function to log an INFO message. See the log function for details.
function log_info {
  log $COLOR_INFO $LOG_LEVEL_INFO "$@"
}

# Helper function to log a WARN message. See the log function for details.
function log_warn {
  log $COLOR_WARN $LOG_LEVEL_WARN "$@"
}

# Helper function to log a DEBUG message. See the log function for details.
function log_debug {
  log $COLOR_DEBUG $LOG_LEVEL_DEBUG "$@"
}

# Helper function to log an ERROR message. See the log function for details.
function log_error {
  log $COLOR_ERROR $LOG_LEVEL_ERROR "$@"
}

# Helper function to log an INSTRUCTIONS message. See the log function for details.
function log_instructions {
  log $COLOR_INSTRUCTIONS $LOG_LEVEL_INSTRUCTIONS "$@"
}

#
# Usage: index_of VALUE ARRAY
#
# Returns the first index where VALUE appears in ARRAY. If ARRAY does not
# contain VALUE, returns -1.
#
# Examples:
#
# index_of foo ("abc" "foo" "def")
#   Returns: 1
#
# index_of foo ("abc" "def")
#   Returns -1
#
function index_of {
  local readonly value="$1"
  shift
  local readonly array=("$@")

  for (( i = 0; i < ${#array[@]}; i++ )); do
    if [ "${array[$i]}" = "${value}" ]; then
      echo $i
      return
    fi
  done 

  echo -1
}

#
# Usage: log COLOR LEVEL [MESSAGE ...]
#
# Logs MESSAGE to stdout with color COLOR if the log level is at least LEVEL.
# If no MESSAGE is specified, reads from stdin. The log level is determined by 
# the DOCKER_OSX_DEV_LOG_LEVEL environment variable.
#
# Examples:
#
# log $COLOR_INFO $LOG_LEVEL_INFO "Hello, World"
#   Prints: "[INFO] Hello, World" to stdout in green.
#
# echo "Hello, World" | log $COLOR_RED $LOG_LEVEL_ERROR 
#   Prints: "[ERROR] Hello, World" to stdout in red.
#
function log {
  if [[ "$#" -gt 2 ]]; then
    do_log "$@"
  elif [[ "$#" -eq 2 ]]; then
    while read message; do 
      do_log "$1" "$2" "$message"
    done
  else
    echo "Internal error: invalid number of arguments passed to log function: $@"
    exit 1
  fi
}

#
# Usage: do_log COLOR LEVEL MESSAGE ...
#
# Logs MESSAGE to stdout with color COLOR if the log level is at least LEVEL.
# The log level is determined by the DOCKER_OSX_DEV_LOG_LEVEL environment 
# variable.
#
# Examples:
#
# do_log $COLOR_INFO $LOG_LEVEL_INFO "Hello, World"
#   Prints: "[INFO] Hello, World" to stdout in green.
#
function do_log {
  local readonly color="$1"
  shift
  local readonly log_level="$1"
  shift
  local readonly message="$@"

  local readonly log_level_index=$(index_of "$log_level" "${LOG_LEVELS[@]}")
  local readonly current_log_level_index=$(index_of "$CURRENT_LOG_LEVEL" "${LOG_LEVELS[@]}")

  if [[ "$log_level_index" -ge "$current_log_level_index" ]]; then
    echo -e "${color}[${log_level}] ${message}${COLOR_END}"
  fi   
}

#
# Dumps a 'stack trace' for failed assertions.
#
function backtrace {
  local readonly max_trace=20
  local frame=0
  while test $frame -lt $max_trace ; do
    frame=$(( $frame + 1 ))
    local bt_file=${BASH_SOURCE[$frame]}
    local bt_function=${FUNCNAME[$frame]}
    local bt_line=${BASH_LINENO[$frame-1]}  # called 'from' this line
    if test -n "${bt_file}${bt_function}" ; then
      log_error "  at ${bt_file}:${bt_line} ${bt_function}()"
    fi
  done
}

#
# Usage: assert_non_empty VAR
#
# Asserts that VAR is not empty and exits with an error code if it is.
#
function assert_non_empty {
  local readonly var="$1"
  if test -z "$var" ; then
    log_error "internal error: unexpected empty-string argument"
    backtrace
    exit 1
  fi
}

#
# Usage: env_is_defined VAR
#
# Checks if a new SHELL has VAR defined in its environment.
# Returns 0 when VAR is defined for new shells, 1 otherwise.
#
function env_is_defined {
  local readonly var="$1"
  assert_non_empty "$var"

  # First unset the $var in a sub-shell, and then spawn a new shell
  # to see if it gets re-defined from its startup code.
  local readonly setting=$(unset "$var" ;
                           "$SHELL" -i -c -l "env | grep \"^${var}=\"")
  test -n "$setting"
}

# 
# Usage: brew_install PACKAGE_NAME READABLE_NAME COMMAND_NAME USE_CASK
#
# Checks if PACKAGE_NAME is already installed by using brew as well as by 
# searching for COMMAND_NAME on the PATH and if it can't find it, uses brew to
# install PACKAGE_NAME. If USE_CASK is set to true, uses brew cask
# instead. 
#
# Examples:
#
# brew_install virtualbox VirtualBox vboxwebsrv true
#   Result: checks if brew cask already has virtualbox installed or vboxwebsrv 
#   is on the PATH, and if not, uses brew cask to install it.
#
function brew_install {
  local readonly package_name="$1"
  local readonly readable_name="$2"
  local readonly command_name="$3"
  local readonly use_cask="$4"
  
  local brew_command="brew"
  if [[ "$use_cask" = true ]]; then
    brew_command="brew cask"
  fi

  if eval "$brew_command list $package_name" > /dev/null 2>&1 ; then
    log_warn "$readable_name is already installed by HomeBrew, skipping"
  elif type "$command_name" > /dev/null 2>&1 ; then
    log_warn "Found command $command_name, assuming $readable_name is already installed and skipping"
  else
    log_info "Installing $readable_name"
    eval "$brew_command install $package_name"
  fi  
}

#
# Usage: get_env_file
#
# Tries to find and return the proper environment file for the current user.
#
# Examples:
#
# get_env_file
#   Returns: ~/.bash_profile
#
function get_env_file {
  if [[ -f "$BASH_RC" ]]; then 
    echo "$BASH_RC"
  elif [[ -f "$ZSH_RC" ]]; then
    echo "$ZSH_RC"
  else
    echo "$BASH_PROFILE"
  fi
}

#
# Checks that this script can be run on the current machine and exits with an 
# error code if any of the requirements are missing.
#
function check_prerequisites {
  local readonly os=$(uname)

  if [[ ! "$os" = "Darwin" ]]; then
    log_error "This script should only be run on OS X"
    exit 1
  fi

  if ! type brew > /dev/null 2>&1 ; then 
    log_error "This script requires HomeBrew, but it's not installed. Aborting."
    exit 1
  fi
}

#
# Installs all the dependencies for docker-osx-dev.
#
function install_dependencies {
  log_info "Updating HomeBrew"
  brew update

  brew_install "caskroom/cask/brew-cask" "Cask" "" false
  brew_install "virtualbox" "VirtualBox" "vboxwebsrv" true
  brew_install "boot2docker" "Boot2Docker" "boot2docker" false
  brew_install "docker-compose" "Docker Compose" "docker-compose" false
  brew_install "fswatch" "fswatch" "fswatch" false
}

#
# Initializes and starts up the Boot2Docker VM.
#
function init_boot2docker {
  if boot2docker status >/dev/null ; then
    log_error "Boot2Docker already initialized. You must destroy your Boot2Docker image so docker-osx-dev can re-create it without VirtualBox shares."
    log_instructions "Perform the following:\n\tboot2docker stop\n\tboot2docker destroy\n\tRe-run this install.sh script"
    exit 1
  else
    log_info "Initializing Boot2Docker"
    boot2docker init
    boot2docker start --vbox-share=disable
  fi
}

# 
# Installs rsync on the Boot2Docker VM.
#
function install_rsync_on_boot2docker {
  log_info "Installing rsync in the Boot2Docker image"
  boot2docker ssh "tce-load -wi rsync"
}

#
# Adds environment variables necessary for running Boot2Docker
#
function add_environment_variables {
  local readonly env_file=$(get_env_file)
  local readonly boot2docker_exports=$(boot2docker shellinit 2>/dev/null)
  local env_changed=false

  while read -r export_line; do
    local readonly var_name=$(echo "$export_line" | sed -e 's/export \(.*\)=.*/\1/')

    if env_is_defined "$var_name" ; then
      log_warn "Your shell (${SHELL}) already defines $var_name (e.g. perhaps in ${env_file}), will not overwrite"
    else
      log_info "Adding $var_name to $env_file"
      
      if ! $env_changed ; then
        echo -e "\n# docker-osx-dev" >> "$env_file"
        env_changed=true
      fi

      echo "$export_line" >> "${env_file}"
    fi
  done <<< "$boot2docker_exports"

  if $env_changed ; then
    log_instructions "New environment variables defined. To pick them up in the current shell, run:\n\tsource $env_file"
  fi    
}

#
# Installs the local scripts for docker-osx-dev
#
function install_local_scripts {
  local readonly script_path="$BIN_DIR/$DOCKER_OSX_DEV_SCRIPT_NAME"
  if [[ -f "$script_path" ]]; then
    log_warn "$script_path already exists, will not overwrite"
  else
    log_info "Adding $script_path"
    curl -L "$DOCKER_OSX_DEV_URL" > "$script_path"
    chmod +x "$script_path"
  fi
}

#
# Adds Docker entries to /etc/hosts 
#
function add_docker_host {
  local readonly boot2docker_ip=$(boot2docker ip)
  local readonly host_entry="$boot2docker_ip $DOCKER_HOST_NAME"

  if grep -q "^[^#]*$DOCKER_HOST_NAME" "$HOSTS_FILE" ; then
    log_warn "$HOSTS_FILE already contains $DOCKER_HOST_NAME, will not overwrite"
  else
    log_info "Adding $DOCKER_HOST_NAME entry to $HOSTS_FILE so you can use http://$DOCKER_HOST_NAME URLs for testing"
    log_instructions "Modifying $HOSTS_FILE requires sudo privileges, please enter your password."
    sudo -k sh -c "echo $host_entry >> $HOSTS_FILE"
  fi
}

check_prerequisites
install_dependencies
init_boot2docker
install_rsync_on_boot2docker
install_local_scripts
add_docker_host
add_environment_variables
