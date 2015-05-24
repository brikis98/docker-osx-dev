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
  brew_install "boot2docker" "Boot2Docker" "boot2docker" false
  brew_install "docker-compose" "Docker Compose" "docker-compose" false
  brew_install "fswatch" "fswatch" "fswatch" false
}

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

function install_rsync_on_boot2docker {
  log_info "Installing rsync in the Boot2Docker image"
  boot2docker ssh "tce-load -wi rsync"
}

function add_environment_variables {
  local readonly env_file=$(get_env_file)
  local readonly boot2docker_exports=$(boot2docker shellinit 2>/dev/null)

  if grep -q "^[^#]*$boot2docker_exports" "$env_file" ; then
    log_warn "$env_file already contains Boot2Docker environment variables, will not overwrite"
  else
    log_info "Adding Boot2Docker environment variables to $env_file"
    echo -e "$boot2docker_exports" >> "$env_file"
    log_instructions "Please run the following command to pick up new environment variables: source $env_file"
  fi
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
