#!/bin/sh

#  tomcat_multiwork.sh
#  
#
#  Created by HSP SI Viet Nam on 5/9/14.
#
#Check Install packet
clear
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, use sudo sh $0"
    exit 1
fi
#Base Configure
centos_base()
{
	sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
	setenforce 0
	if [ "$(rpm -qa | grep java-1.7)" = "" ]
	then
		yum -y install java-1.7.0-openjdk
	fi
	if [ "$(rpm -qa mlocate | grep mlocate)" == "" ]
	then
		yum -y install mlocate
	fi
	if [ "$(rpm -qa wget | grep wget)" == "" ]
	then
		yum -y install wget
	fi
	if [ "$(rpm -qa man | grep man )" == "" ]
	then
		yum -y install man
	fi
	if [ "$(rpm -qa lsof | grep lsof)" == "" ]
	then
		yum -y install lsof
	fi
}

centos_inst_tomcat()
{
	dir_tomcat='/var/tomcat/work'
	mkdir -p $dir_tomcat
	cd /tmp
	wget http://mirror.nexcess.net/apache/tomcat/tomcat-7/v7.0.68/bin/apache-tomcat-7.0.68.tar.gz
	tar -xf apache-tomcat-7.0.68.tar.gz

	#mv apache-tomcat-7.0.68 $dir_tomcat
	cp -ar /tmp/apache-tomcat-7.0.68/* $dir_tomcat/
	mv /tmp/apache-tomcat-7.0.68/ /tmp/tomcat-default
	#mv apache-tomcat-7.0.68 tomcat-default
	tar -cf tomcat-default.tar.gz tomcat-default/ --remove-file
	rm -rf /tmp/apache-tomcat-7.0.68.tar.gz
	cd ~
	useradd -M -d $dir_tomcat tomcat
	chown -R tomcat. $dir_tomcat
	cat > /etc/init.d/tomcat << hspservice
#!/bin/bash

# Apache Tomcat7: Start/Stop Chuong Trinh
#
# chkconfig: - 90 10


. /etc/init.d/functions
. /etc/sysconfig/network

CATALINA_HOME=$dir_tomcat
TOMCAT_USER=tomcat
LOCKFILE=/var/lock/subsys/tomcat

RETVAL=0
start(){
echo "Khoi Dong Chuong Trinh: "
su - \$TOMCAT_USER -c "\$CATALINA_HOME/bin/startup.sh"
RETVAL=\$?
echo
[ \$RETVAL -eq 0 ] && touch \$LOCKFILE
return \$RETVAL
}

stop(){
echo "Ngat Chuong Trinh: "
\$CATALINA_HOME/bin/shutdown.sh
RETVAL=\$?
echo
[ \$RETVAL -eq 0 ] && rm -f \$LOCKFILE
return \$RETVAL
}

case "\$1" in
start)
start
;;
stop)
stop
;;
restart)
stop
start
;;
status)
status tomcat
;;
*)
echo \$"Usage: \$0 {start|stop|restart|status}"
exit 1
;;
esac
exit \$?
hspservice
chmod +x /etc/init.d/tomcat
/etc/init.d/tomcat start
chkconfig --add tomcat
chkconfig tomcat on
}

centos_base_iptables()
{
	iptables -P INPUT ACCEPT
	iptables -P FORWARD ACCEPT
	iptables -P OUTPUT ACCEPT

	#clean all rules iptables
	iptables -t nat -P PREROUTING ACCEPT
	iptables -t nat -P OUTPUT ACCEPT
	iptables -t nat -P POSTROUTING ACCEPT
	iptables -t mangle -P PREROUTING ACCEPT
	iptables -t mangle -P INPUT ACCEPT
	iptables -t mangle -P FORWARD ACCEPT
	iptables -t mangle -P OUTPUT ACCEPT
	iptables -t mangle -P POSTROUTING ACCEPT

	#Dell all
	iptables -F
	iptables -t nat -F
	iptables -t mangle -F

	iptables -X
	iptables -t nat -X
	iptables -t mangle -X

	#Zero all packets and counters
	iptables -Z
	iptables -t nat -Z
	iptables -t mangle -Z


	#Set rule iptables
	iptables -A INPUT -p tcp -m tcp --dport 80 -j LOG
	iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
	iptables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
	iptables -A INPUT -p icmp -j ACCEPT
	iptables -A INPUT -i lo -j ACCEPT
	iptables -A INPUT -m state --state NEW -p tcp --dport 80 -j ACCEPT
	iptables -A INPUT -m state --state NEW -p tcp --dport 22 -j ACCEPT
	iptables -A INPUT -m state --state NEW -p tcp --dport 8080 -j ACCEPT
	iptables -A OUTPUT -m state --state NEW -p tcp --dport 22 -j ACCEPT
	iptables -A OUTPUT -m state --state NEW -p tcp --dport 8080 -j ACCEPT
	/etc/init.d/iptables save
	iptables -P INPUT DROP
	iptables -P FORWARD DROP
	#iptables -P OUTPUT DROP
	/etc/init.d/iptables save
	chkconfig iptables on
}

centos_create_work()
{
cd /tmp
wget https://raw.githubusercontent.com/NamNT2002/tomcat_multiwork/master/vhost.sh
mv /tmp/vhost.sh /usr/bin/create_work
chmod +x /usr/bin/create_work
}

main()
{
	centos_base
	centos_inst_tomcat
	centos_base_iptables
	centos_create_work
}
#End Create service
main
clear
echo 'Create New Working'
echo 'Please input: create_work'
echo 'Thanks!'
