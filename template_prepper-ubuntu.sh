#!/bin/bash

# Official repo: https://github.com/nixmore/template_prepper-ubuntu
# Inspiration from:
#   http://lonesysadmin.net/2013/03/26/preparing-linux-template-vms/
#   https://help.ubuntu.com/community/OpenVZ

# Run it like this:
# wget https://raw.github.com/nixmore/template_prepper-ubuntu/master/template_prepper-ubuntu.sh -O - | bash

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
  
  puppet resource service puppet ensure=stopped enable=true

  grep ^server /etc/puppet/puppet.conf || \
cat << EOF >> /etc/puppet/puppet.conf
[agent]
server = puppet
report = true
pluginsync = true
EOF
  
    sed -i /etc/default/puppet -e 's/START=no/START=yes/'
  
}

install_packages() {
  apt-get install -y openssh-server
}

create_firstboot_script() {
  rm -f /etc/ssh/ssh_host_*

  cat << EOF > /etc/rc2.d/S15firstboot
#!/bin/bash

generate_sshkeys() {
ssh-keygen -f /etc/ssh/ssh_host_rsa_key -t rsa -N ''
ssh-keygen -f /etc/ssh/ssh_host_dsa_key -t dsa -N ''
}
 
set_hostname() {
HOSTNAME="\$(ifconfig -a | head -1 | awk '{print \$NF}' | sed -e 's/\://g')"
echo "\$HOSTNAME" > /etc/hostname
sed -i 's/127.0.1.1\tubuntu/127.0.1.1\t'\$HOSTNAME'/g' /etc/hosts
}

clear_bashhistory() {
 find /home -name ".bash_history" -delete
 find ~root -name ".bash_history" -delete
}

generate_sshkeys
set_hostname
clear_bashhistory

rm -f \$0
EOF

  chmod a+x /etc/rc2.d/S15firstboot
}

cleanup() {
  rm -rf ~root/.bash_history
  rm -rf /home/*/.bash_history
  
  apt-get clean
  apt-get autoremove
  
  rm -rf /tmp/*
  logrotate -f /etc/logrotate.conf
  find /var/log -iname "*.[0-9]" -o -name "*.gz" -delete
  
  rm -f $0
}

install_puppet
install_packages
create_firstboot_script
cleanup

echo "$0: Complete."

exit
