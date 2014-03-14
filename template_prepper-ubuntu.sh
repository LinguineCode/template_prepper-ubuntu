#!/bin/bash

# Official repo: https://github.com/nixmore/template_prepper-ubuntu
# Inspiration from: http://lonesysadmin.net/2013/03/26/preparing-linux-template-vms/
#                   and https://help.ubuntu.com/community/OpenVZ

PUPPETMASTER_HOST="10.34.140.10"

install_puppet() {
  cat << EOF > /etc/apt/sources.list.d/puppetlabs.list 
# Puppetlabs products
deb http://apt.puppetlabs.com precise main
deb-src http://apt.puppetlabs.com precise main

# Puppetlabs dependencies
deb http://apt.puppetlabs.com precise dependencies
deb-src http://apt.puppetlabs.com precise dependencies

# Puppetlabs devel (uncomment to activate)
# deb http://apt.puppetlabs.com precise devel
# deb-src http://apt.puppetlabs.com precise devel
EOF

  apt-get update
  apt-get install -y puppet

  cat << EOF >> /etc/puppet/puppet.conf
server = puppet
report = true
pluginsync = true
EOF

  sed -i '/ puppet$/ d' /etc/hosts
  echo "$PUPPETMASTER_HOST puppet" >> /etc/hosts

  puppet resource service puppet enable=true
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
  find /home -mindepth 2 -delete
  find ~root -mindepth 1 -delete
  find /tmp -mindepth 1 -delete
  logrotate -f /etc/logrotate.conf
  find /var/log -iname "*.[0-9]" -o -name "*.gz" -delete
}

install_puppet
regenerate_host_sshkeys
cleanup
