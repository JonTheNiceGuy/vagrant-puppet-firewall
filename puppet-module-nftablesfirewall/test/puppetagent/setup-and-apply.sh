#!/bin/bash
####################################################################
######### Prepare error handling functions for later
####################################################################
# shellcheck disable=SC1091
source /vagrant/puppetagent/_functions.sh

####################################################################
######### Only install and configure the Puppet Agent if Puppet
######### isn't already installed. This includes the first-run
######### deployment of standard puppet modules.
####################################################################
if ! command -v puppet >/dev/null
then
    ################################################################
    ######### Install and configure Puppet
    ################################################################
    dnf -y update
    rpm -Uvh "https://yum.puppet.com/puppet8-release-el-9.noarch.rpm"
    yum install -y puppet-agent git-core
    /opt/puppetlabs/bin/puppet module install puppetlabs-stdlib
    printf "[main]\ncertname = %s\nserver = puppet" "$(hostname -f)" > /etc/puppetlabs/puppet/puppet.conf
    echo "192.168.56.254 puppet" >> /etc/hosts
    systemctl is-active puppet >/dev/null && systemctl disable --now puppet

    ################################################################
    ######### Replicate Packer process by installing standard
    ######### offline build modules
    ################################################################
    for dirname in basevm hardening
    do
        TARGET="/etc/puppetlabs/code/environments/production/modules/$(echo $dirname | sed -E -e 's/.*puppet-module-//')"
        if [ ! -e "$TARGET" ]
        then
            ln -s "/etc/puppetlabs/code/environments/production/src_modules/puppet-module-$dirname" "$TARGET"
        fi
    done
    ################################################################
    # Now the modules are ready, apply them. Puppet uses unusual
    # error code outputs that Bash would like to trap and exit the
    # script with. Instead we'll capture the code and pass it to
    # a function in _functions.sh to return what that code meant.
    ################################################################
    set +e
    /opt/puppetlabs/bin/puppet apply /vagrant/puppetagent/standard_build.pp --detailed-exitcodes
    rc=$?
    set -e
    result $rc

    ################################################################
    ######### Allow Puppet to start normally.
    ################################################################
    systemctl enable puppet.service
fi

####################################################################
######### Ask the puppet server for what should be applied to us
######### Note that this replies on enc.sh and the enc.json or
######### enc.HOSTNAME.json in the test directory. As before the
######### result codes are captured and a log is produced for errors
####################################################################
set +e
/opt/puppetlabs/bin/puppet agent -tv --detailed-exitcodes
rc=$?
set -e
result $rc
error Puppet completed successfully
