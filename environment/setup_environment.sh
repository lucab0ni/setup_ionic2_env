#!/bin/bash

# By storing the date now, we can calculate the duration of setup at the
# end of this script.
start_seconds="$(date +%s)"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR=${SCRIPT_DIR}/..

source ${SCRIPT_DIR}/variables.sh

NODEJS_VERSION="6.5.0"

ANDROID_SDK_NAME="android-studio-ide-143.3101438-linux.zip"
ANDROID_SDK_URL="https://dl.google.com/dl/android/studio/ide-zips/2.1.3.0/${ANDROID_SDK_NAME}"

# PACKAGE INSTALLATION
#
# Build a bash array to pass all of the packages we want to install to a single
# apt-get command. This avoids doing all the leg work each time a package is
# set to install. It also allows us to easily comment out or add single
# packages. We set the array as empty to begin with so that we can append
# individual packages to it as required.
apt_package_install_list=()

# Start with a bash array containing all packages we want to install in the
# virtual machine. We'll then loop through each of these and check individual
# status before adding them to the apt_package_install_list array.
apt_package_check_list=(

    # Virtual Environment
    python-virtualenv

    # Java JDK 8
    openjdk-8-jdk
)

npm_package_install_list=(

    # Ionic 2
    ionic@beta
    cordova
)

not_installed() {
  dpkg -s "$1" 2>&1 | grep -q 'Version:'
  if [[ "$?" -eq 0 ]]; then
    apt-cache policy "$1" | grep 'Installed: (none)'
    return "$?"
  else
    return 0
  fi
}

print_pkg_info() {
  local pkg="$1"
  local pkg_version="$2"
  local space_count
  local pack_space_count
  local real_space

  space_count="$(( 20 - ${#pkg} ))" #11
  pack_space_count="$(( 30 - ${#pkg_version} ))"
  real_space="$(( space_count + pack_space_count + ${#pkg_version} ))"
  printf " * $pkg %${real_space}.${#pkg_version}s ${pkg_version}\n"
}

package_check() {
  # Loop through each of our packages that should be installed on the system. If
  # not yet installed, it should be added to the array of packages to install.
  local pkg
  local pkg_version

  for pkg in "${apt_package_check_list[@]}"; do
    if not_installed "${pkg}"; then
      echo " *" "$pkg" [not installed]
      apt_package_install_list+=($pkg)
    else
      pkg_version=$(dpkg -s "${pkg}" 2>&1 | grep 'Version:' | cut -d " " -f 2)
      print_pkg_info "$pkg" "$pkg_version"
    fi
  done
}

package_install() {
    package_check

    if [[ ${#apt_package_install_list[@]} = 0 ]]; then
        echo -e "No apt packages to install.\n"
    else
        # Update all of the package references before installing anything
        echo "Running apt-get update..."
        apt-get -y update

        # Install required packages
        echo "Installing apt-get packages..."
        apt-get -y install ${apt_package_install_list[@]}

        # Remove unnecessary packages
        echo "Removing unnecessary packages..."
        apt-get autoremove -y

        # Clean up apt caches
        apt-get clean
    fi
}

tools_install() {
    # Virtual Environments
    #
    # Virtual environment for pip
    if [ ! -d ${PIP_VIRTUAL_ENV_DIR} ]; then
        echo -e "\nInitializing virtual environment for pip..."
        virtualenv ${PIP_VIRTUAL_ENV_DIR}
    fi
    # Activate virtual environment for pip
    source ${PIP_VIRTUAL_ENV_DIR}/bin/activate

    # Virtual environment for NodeJs
    if [ ! -d ${NODEJS_VIRTUAL_ENV_DIR} ]; then
        echo -e "\nInitializing virtual environment for Node.js..."
        pip install nodeenv
        echo -e "\nInstalling Node.js version: ${NODEJS_VERSION}"
        nodeenv --node=${NODEJS_VERSION} ${NODEJS_VIRTUAL_ENV_DIR}
    fi
    # Activate virtual environment for NodeJs
    source ${NODEJS_VIRTUAL_ENV_DIR}/bin/activate


    # npm
    #
    # Make sure we have the latest npm version and the update checker module
    echo "Updating the node package manager..."
    npm install -g npm

    # Install required packages
    echo "Installing npm packages: ${npm_package_install_list[@]}..."
    npm install -g ${npm_package_install_list[@]}


    # Android SDK
    #
    # Download Android SDK
    echo "Downloading Android SDK..."
    wget --directory-prefix=${TEMP_DIR} ${ANDROID_SDK_URL}

    # Unpack the .zip files into /opt/
    echo "Unpacking Android SDK..."
    sudo unzip ${TEMP_DIR}/${ANDROID_SDK_NAME} -d /opt/
}


### SCRIPT
#set -xv

# Package and Tools Install
echo " "
echo "Main packages check and install."
package_install
tools_install

#set +xv
# And it's done
end_seconds="$(date +%s)"
echo "-----------------------------"
echo "Setup complete in "$(( end_seconds - start_seconds ))" seconds"
