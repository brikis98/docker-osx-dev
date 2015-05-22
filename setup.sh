#!/bin/bash
#
# A script for setting up a productive development environment with Docker 
# on OS X. See https://github.com/brikis98/docker-osx-dev for more info.

set -e

# Docker environment which we will need to install for docker-osx-dev to work.
DOCKER_HOST="tcp://localhost:2375"

# Environment variable file constants
readonly BASH_PROFILE="$HOME/.bash_profile"
readonly BASH_RC="$HOME/.bashrc"
readonly ZSH_RC="$HOME/.zshrc"

# Url constants
readonly HOSTS_FILE="/etc/hosts"
readonly VAGRANT_HOST="192.168.10.10"
readonly DOCKER_HOST_NAME="dockerhost"

# Console colors
readonly COLOR_INFO='\033[0;32m[INFO]'
readonly COLOR_WARN='\033[1;33m[WARN]'
readonly COLOR_ERROR='\033[0;31m[ERROR]'
readonly COLOR_INSTRUCTIONS='\033[0;37m[INSTRUCTIONS]'
readonly COLOR_END='\033[0m'

# Script constants
readonly BIN_DIR="/usr/local/bin"
readonly DOCKER_OSX_DEV_SCRIPT_NAME="docker-osx-dev"
readonly DOCKER_OSX_DEV_URL="https://raw.githubusercontent.com/brikis98/docker-osx-dev/master/$DOCKER_OSX_DEV_SCRIPT_NAME"

function log_info {
  log "$*" $COLOR_INFO
}

function log_warn {
  log "$*" $COLOR_WARN
}

function log_error {
  log "$*" $COLOR_ERROR
}

function log_instructions {
  log "$*" $COLOR_INSTRUCTIONS
}

function log {
  local readonly message=$1
  local readonly color=$2 || $COLOR_INFO
  echo -e "${color} ${message}${COLOR_END}"
}

# Function to dump a 'stack trace' for failed assertions.
function backtrace {
  local readonly max_trace=20
  frame=0
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

# Assert that arguments of the function are non-empty strings.
function assert_non_empty {
  local var="$1"
  if test -z "$var" ; then
    log_error "internal error: unexpected empty-string argument"
    backtrace
    exit 1
  fi
}

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

function vagrant_plugin_install {
  local readonly plugin_name=$1
  local readonly readable_name=$2

  if vagrant plugin list | grep -q $plugin_name ; then
    log_warn "$readable_name already installed, skipping"
  else
    log_info "Installing $readable_name"
    vagrant plugin install $plugin_name
  fi
}

function get_env_file {
  if [[ -f "$BASH_RC" ]]; then 
    echo "$BASH_RC"
  elif [[ -f "$ZSH_RC" ]]; then
    echo "$ZSH_RC"
  else
    echo "$BASH_PROFILE"
  fi
}

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

function install_dependencies {
  log_info "Updating HomeBrew"
  brew update

  brew_install "caskroom/cask/brew-cask" "Cask" "" false
  brew_install "virtualbox" "VirtualBox" "vboxwebsrv" true
  brew_install "vagrant" "Vagrant" "vagrant" true
  brew_install "docker" "Docker" "docker" false
  brew_install "docker-compose" "Docker Compose" "docker-compose" false
}

function install_vagrant_plugins {
  vagrant_plugin_install vagrant-gatling-rsync "Vagrant Gatling Rsync"
}

# env_is_defined VARNAME
#   Checks if a new $SHELL has $VARNAME defined in its environment.
#   Returns 0 when VARNAME is defined for new shells, 1 otherwise.
function env_is_defined {
  local var="$1"
  assert_non_empty "${var}"

  # First unset the $var in a sub-shell, and then spawn a new shell
  # to see if it gets re-defined from its startup code.
  local setting=$( unset "${var}" ;
                   "${SHELL}" -i -c "env | grep \"^${var}=\"" )
  test -n "${setting}"
}

function add_environment_variables {
  local readonly env_file=$(get_env_file)

  if env_is_defined 'DOCKER_HOST' ; then
    log_warn "${SHELL} setup already defines DOCKER_HOST will not overwrite"
  else
    log_info "Adding DOCKER_HOST to $env_file"
    ( echo '# docker-osx-dev' ;
      echo "export DOCKER_HOST=${DOCKER_HOST}" ) >> "${env_file}"
    log_instructions "New environment variables defined."
    log_instructions "Please source $env_file or run:"
    log_instructions "  export DOCKER_HOST=${DOCKER_HOST}"
  fi

  # Make sure the other DOCKER_XXX variables which may interfere with
  # docker-osx-dev's operation are not defined in the environment of
  # new shells.
  for varname in 'DOCKER_CERT_PATH' 'DOCKER_TLS_VERIFY' ; do
    if env_is_defined "$varname" ; then
      log_error "${SHELL} setup defines ${varname} probably"  \
        "from a previous boot2docker installation.  This may" \
        "interfere with docker-osx-dev."
      log_instructions "Remove ${varname} from ${env_file}"   \
        "or any other place where it is set, and run in the"  \
        "current shell: unset ${varname}"
    fi
  done
}

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

function add_docker_host {
  local readonly host_entry="$VAGRANT_HOST $DOCKER_HOST_NAME"

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
install_vagrant_plugins
install_local_scripts
add_docker_host
add_environment_variables
