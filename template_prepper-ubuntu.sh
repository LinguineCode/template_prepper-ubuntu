#!/bin/bash

# Official repo: https://github.com/nixmore/template_prepper-ubuntu
# Inspiration from:
#   http://lonesysadmin.net/2013/03/26/preparing-linux-template-vms/
#   https://help.ubuntu.com/community/OpenVZ

if [[ $(lsb_release -i) != *Ubuntu ]]; then
  echo "$0: This script only runs on Ubuntu operating systems" 1>&2
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  echo "$0: This script must be run as root" 1>&2
  exit 1
fi

install_puppet() {
  dpkg -s puppetlabs-release-precise &>/dev/null
  if [ $? -ne 0 ]; then
    wget https://apt.puppetlabs.com/puppetlabs-release-precise.deb
    dpkg -i puppetlabs-release-precise.deb
    rm -f puppetlabs-release-precise.deb
  fi
  
  apt-get update
  apt-get install -y puppet

  grep ^server /etc/puppet/puppet.conf || cat << EOF >> /etc/puppet/puppet.conf
  
server = puppet
report = true
pluginsync = true
EOF

  #sed -i '/ puppet$/ d' /etc/hosts
  #echo "$PUPPETMASTER_HOST puppet" >> /etc/hosts

  sed -i /etc/default/puppet -e 's/START=no/START=yes/'
  puppet resource service puppet enable=true
}

install_packages() {
  apt-get install -y openssh-server
}

regenerate_host_sshkeys() {
  rm -f /etc/ssh/ssh_host_*

  cat << EOF > /etc/rc2.d/S15ssh_gen_host_keys
#!/bin/sh
ssh-keygen -f /etc/ssh/ssh_host_rsa_key -t rsa -N ''
ssh-keygen -f /etc/ssh/ssh_host_dsa_key -t dsa -N ''
rm -f \$0
EOF

  chmod a+x /etc/rc2.d/S15ssh_gen_host_keys
}

cleanup() {
  unset HISTFILE
  apt-get clean
  apt-get autoremove
  rm -rf /home/*/.bash_history
  rm -rf ~root/.bash_history
  rm -rf /tmp/*
  logrotate -f /etc/logrotate.conf
  find /var/log -iname "*.[0-9]" -o -name "*.gz" -delete
  
  rm -f $0
}

install_puppet
install_packages
regenerate_host_sshkeys
cleanup

echo "$0: Complete."
