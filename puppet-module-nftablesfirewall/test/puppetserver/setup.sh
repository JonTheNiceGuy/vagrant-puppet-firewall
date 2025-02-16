#!/bin/bash
START_PUPPET=0
################################################################
######### Install the Puppet binary and configure it as a server
################################################################
if ! command -v puppetserver >/dev/null
then
    rpm -Uvh https://yum.puppet.com/puppet8-release-el-9.noarch.rpm
    dnf install -y puppetserver puppet-agent
    alternatives --set java "$(alternatives --list | grep -E 'jre_17.*java-17' | awk '{print $3}')/bin/java"
    /opt/puppetlabs/bin/puppet config set server puppet --section main
    /opt/puppetlabs/bin/puppet config set runinterval 60 --section main
    /opt/puppetlabs/bin/puppet config set autosign true --section server
    START_PUPPET=1
fi

################################################################
######### Link the parent puppet tree to this host, which allows
######### for more than just this module to be tested
################################################################
# We symlink each directory in the parent of this puppet module
# into the production/modules path, to save having to run
# something like r10k. It also means that any changes are
# dynamically provided to the puppetserver.
################################################################
cd /etc/puppetlabs/code/environments/production/src_modules || exit 1
for dirname in puppet-module*
do
    TARGET="/etc/puppetlabs/code/environments/production/modules/$(echo "$dirname" | sed -E -e 's/.*puppet-module-//')"
    if [ ! -e "$TARGET" ]
    then
        ln -s "/etc/puppetlabs/code/environments/production/src_modules/${dirname}" "$TARGET"
    fi
done

################################################################
######### Install common modules
################################################################
/opt/puppetlabs/bin/puppet module install puppetlabs-stdlib

################################################################
######### Setup a very simple "External Node Classifier"
################################################################
# This means we can change what modules and variables are
# deployed to the client device.
################################################################
if ! [ -e /opt/puppetlabs/enc.sh ]
then
    cp /vagrant/puppetserver/enc.sh /opt/puppetlabs/enc.sh && chmod +x /opt/puppetlabs/enc.sh
    /opt/puppetlabs/bin/puppet config set node_terminus exec --section master
    /opt/puppetlabs/bin/puppet config set external_nodes /opt/puppetlabs/enc.sh --section master
    START_PUPPET=1
fi

################################################################
######### Stop and start the Puppet server service
################################################################
if [ $START_PUPPET -eq 1 ] && systemctl is-active puppetserver >/dev/null
then
    systemctl stop puppetserver
fi
if [ $START_PUPPET -eq 1 ]
then
    systemctl start puppetserver
fi
