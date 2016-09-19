#!/bin/bash

set -o pipefail  # trace ERR through pipes
set -o errtrace  # trace ERR through 'time command' and other functions
set -o nounset   ## set -u : exit the script if you try to use an uninitialised variable
set -o errexit   ## set -e : exit the script if any statement returns a non-true return value

export PYTHONUNBUFFERED=1

SCRIPT_DIR=$(dirname $(readlink -f "$0"))

export ANSIBLE_CONFIG="${SCRIPT_DIR}/ansible/ansible.cfg"

########################
# Pre provision provisioning
########################

# install ansible if needed
if [ -z $(command -v ansible-playbook) ]; then
    echo " ***************************************************************************** "
    echo " *** Starting installation of ansible "
    echo " ***************************************************************************** "
    if [ -n $(command -v yum) ]; then
    	echo " *** DEBUG : yum *** "
        yum -y install epel-release
        yum -y install gcc \
        	libffi-devel \
            python-devel \
        	openssl-devel \
            python-pip \
            python-yaml \
            libselinux-python \
            git
    elif [ -z $(command -v apt-get) ]; then
    	echo " *** DEBUG : apt *** "
        apt-get update
        apt-get -q -y --force-yes install software-properties-common \
			python-yaml \
			python-pip \
			git
    fi

    echo " *** Starting installing Ansible "
    pip install --upgrade pip
    pip install --upgrade setuptools
 	pip install ansible
fi

########################
# Provision with ansible
########################

echo " ***************************************************************************** "
echo " *** Starting provision with ansible (will take some time...)"
echo " ***************************************************************************** "

ANSIBLE_EXTRA_VARS=""

# fix windows compatiblity
cp -a "$SCRIPT_DIR/inventory" "/tmp/$$.inventory"
chmod -x -- "/tmp/$$.inventory"

# run ansible
cd $SCRIPT_DIR
ansible-playbook "$SCRIPT_DIR/playbook.yml" --inventory="/tmp/$$.inventory" --extra-vars="$ANSIBLE_EXTRA_VARS" --tags="bootstrap"

# remove inventory file
rm -f -- "/tmp/$$.inventory"
