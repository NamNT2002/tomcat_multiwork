#!/bin/sh

#  create_work_tomcat.sh
#  
#
#  Created by HSP SI Viet Nam on 5/9/14.
#

clear
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, use sudo sh $0"
    exit 1
fi

random_port()
{
    while [[ not != found ]]; do
        # 2000..33500
        port=$((RANDOM + 2000))
        while [[ $port -gt 33500 ]]; do
            port=$((RANDOM + 2000))
        done

        # 2000..65001
        [[ $((RANDOM % 2)) = 0 ]] && port=$((port + 31501)) 

        # 2000..65000
        [[ $port = 65001 ]] && continue
        echo $port
        break
    done
}

centos_create_work()
{	
dir_tomcat='/var/tomcat/work'
	#port shutdown
	while true
	do
		port_shut=$(random_port)
		if [ "$(lsof -i TCP:$port_shut)" == "" ]
		then
			break
		fi
	done
	#port connection
	while true
	do
		port_conn=$(random_port)
		if [ "$(lsof -i TCP:$port_conn)" == "" ] && [ $port_conn -ne $port_shut ]
		then
			break
		fi
	done
	#port ajp
	while true
	do
		port_ajp=$(random_port)
		if [ "$(lsof -i TCP:$port_ajp)" == "" ] && [ $port_ajp -ne $port_shut ] && [ $port_ajp -ne $port_conn ]
		then
			break
		fi
	done
	#create folder work
	while true
	do
		read -p"Ten work: " name_work
		if [ -d /var/tomcat/$name_work ]
		then
			echo "Work da ton tai, vui long dien lai."
			sleep 3
		else
			break
		fi
	done
	cd /tmp
	tar -xf tomcat-default.tar.gz
	mv tomcat-default /var/tomcat/$name_work
	cat > /var/tomcat/$name_work/conf/server.xml << eof
<?xml version='1.0' encoding='utf-8'?>
<Server port="$port_shut" shutdown="SHUTDOWN">
<Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on" />
<Listener className="org.apache.catalina.core.JasperListener" />
<Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />
<Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener" />
<Listener className="org.apache.catalina.core.ThreadLocalLeakPreventionListener" />
<GlobalNamingResources>
<Resource name="UserDatabase" auth="Container"
type="org.apache.catalina.UserDatabase"
description="User database that can be updated and saved"
factory="org.apache.catalina.users.MemoryUserDatabaseFactory"
pathname="conf/tomcat-users.xml" />
</GlobalNamingResources>
<Service name="Catalina">
<Connector port="$port_conn" protocol="HTTP/1.1"
connectionTimeout="20000"
redirectPort="8443" />
<Connector port="$port_ajp" protocol="AJP/1.3" redirectPort="8443" />
<Engine name="Catalina" defaultHost="localhost">
<Realm className="org.apache.catalina.realm.LockOutRealm">
<Realm className="org.apache.catalina.realm.UserDatabaseRealm"
resourceName="UserDatabase"/>
</Realm>

<Host name="localhost"  appBase="webapps"
unpackWARs="true" autoDeploy="true">
<Valve className="org.apache.catalina.valves.AccessLogValve" directory="logs"
prefix="localhost_access_log." suffix=".txt"
pattern="%h %l %u %t &quot;%r&quot; %s %b" />

</Host>
</Engine>
</Service>
</Server>
eof


	cat > /etc/init.d/$name_work << hspservice
#!/bin/bash

# Apache Tomcat7: Start/Stop Chuong Trinh
#
# chkconfig: - 90 10


. /etc/init.d/functions
. /etc/sysconfig/network
CATALINA_HOME=$dir_tomcat
CATALINA_BASE=/var/tomcat/$name_work
export CATALINA_HOME=$dir_tomcat
export CATALINA_BASE=/var/tomcat/$name_work
TOMCAT_USER=tomcat
LOCKFILE=/var/lock/subsys/$name_work

RETVAL=0
start(){
echo "Khoi Dong Chuong Trinh: "
su - \$TOMCAT_USER -c "export CATALINA_HOME=$dir_tomcat && export CATALINA_BASE=/var/tomcat/$name_work && \$CATALINA_HOME/bin/startup.sh"
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
	ln -s $dir_tomcat/bin /var/tomcat/$name_work/bin/
	chown -R tomcat. /var/tomcat/$name_work
	chmod +x /etc/init.d/$name_work
	/etc/init.d/$name_work start
	chkconfig --add $name_work
	chkconfig $name_work on
	iptables -A INPUT -m state --state NEW -p tcp --dport $port_conn -j ACCEPT
	iptables -A INPUT -m state --state NEW -p tcp --dport $port_ajp -j ACCEPT
	iptables -A INPUT -m state --state NEW -p tcp --dport $port_shut -j ACCEPT
	service iptables save
}

main()
{
	centos_create_work
	clear
}
main
get_int=$(route -n | grep 'UG' | awk '{print $NF}')
get_ip=$(ip addr show $get_int | grep 'scope global' | tr '/' ' ' | awk '{print $2}')
echo 'Create Done'
echo "port connect: http://$get_ip:$port_conn"
echo "port ajp: $get_ip:$port_ajp"