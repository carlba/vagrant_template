#!/bin/bash
echo $1

install_remi=no
install_epel=yes
hostname=$1
suffix=.d.birdstep.internal
pre_dependencies="wget"
dependencies="tmux mercurial vim-enhanced htop bash-completion"
ip_filter=10.10.11 #Used for selecting which interface should be used when updating dns-name

yum install -y $pre_dependencies

wget https://raw.github.com/carlba/linuxconf/master/bashrc.d/global.sh
source global.sh

in_array() {
    local hay needle=$1
    shift
    for hay; do
        [[ $hay == $needle ]] && return 0
    done
    return 1
}


function install_remi
{
    wget http://rpms.famillecollet.com/enterprise/remi-release-6.rpm
    yum -y install remi-release-6.rpm
    rm -rf remi-release-6.rpm
}

function install_epel
{

cat <<EOM >/etc/yum.repos.d/epel-bootstrap.repo
[epel]
name=Bootstrap EPEL
mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=epel-\$releasever&arch=\$basearch
failovermethod=priority
enabled=0
gpgcheck=0
EOM

yum --enablerepo=epel -y install epel-release
rm -f /etc/yum.repos.d/epel-bootstrap.repo

}

function set_hostname
{
    #set hostname
    sed -ri s:HOSTNAME=.*:HOSTNAME=$hostname$suffix:g /etc/sysconfig/network
    hostname $hostname$suffix
    sed -i "s/GSSAPIAuthentication yes/#GSSAPIAuthentication yes/g" /etc/ssh/sshd_config
    sed -i "s/#GSSAPIAuthentication no/GSSAPIAuthentication no/g" /etc/ssh/sshd_config
}


function update_dns_name
{
    newhostname=$1
    ipadress=$2
    clear_dns_name $newhostname
    yum -y install bind-utils
    echo -e "update add $newhostname 8000 in a $ipadress \n send \n quit" | nsupdate
}

function clear_dns_name
{
    newhostname=$1
    yum -y install bind-utils
    echo -e "update delete $newhostname \n send \n quit" | nsupdate
}

function permit_root
{
  sudo sed -i "s/#PermitRootLogin yes/PermitRootLogin yes/g" /etc/ssh/sshd_config
  echo Time2Server | sudo passwd root --stdin
  sudo service sshd restart
}



#Network setup
rm -rf /etc/udev/rules.d/70-persistent-net.rules
set_hostname

update_dns_name $hostname$suffix $(getCurrentIP $ip_filter head -1)

#Start with installing barebone dependencies
yum -y install man wget


[[ "$install_remi" == yes ]] && install_remi
[[ "$install_epel" == yes ]] && install_epel

permit_root

#Dependencies
yum -y install $dependencies
