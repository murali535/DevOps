#!/bin/bash

log=/tmp/stack.log
id=$(id -u)
conn_http_url=http://mirrors.estointernet.in/apache/tomcat/tomcat-connectors/jk/tomcat-connectors-1.2.46-src.tar.gz
conn_tar_file=$(echo $conn_http_url | cut -d / -f8) #echo $conn_http_url | awk -f / '{print $NF}'
conn_dir_home=$(echo $conn_tar_file | sed -e 's/.tar.gz//g')

tomcat_http_url=$(curl -s https://tomcat.apache.org/download-90.cgi | grep Core: -A 20 | grep nofollow | grep tar.gz | cut -d '"' -f2)
tomcat_tar_file=$(echo $tomcat_http_url | awk -F / '{print $NF}')
tomcat_dir_home=$(echo $tomcat_tar_file | sed -e 's/.tar.gz//g')

student_war=https://github.com/devops2k18/DevOpsDecember/raw/master/APPSTACK/student.war
mysql_jar_url=https://github.com/devops2k18/DevOpsDecember/raw/master/APPSTACK/mysql-connector-java-5.1.40.jar
mysql_jar=$(echo $mysql_jar_url | awk -F / '{print $NF}')

G="\e[32m"
R="\e[31m"
N="\e[0m"
Y="\e[33m"

VALIDATE (){
	if [ $1 -eq 0 ]; then
		echo -e "$2 is $G success $N"
	else
		echo -e "$2 is $R failed $N"
    exit 1 
    
	fi
}

SKIP() {
	echo -e "$1 ... $Y skipping $N"
}

if [ $id -ne 0 ]; then
	echo "you should be root user to perform this"
	exit 1
fi
	
yum install httpd -y &>>$log

VALIDATE $? "installing web server"

systemctl restart httpd &>>$log

VALIDATE $? "restarting web server"

yum install gcc httpd-devel -y &>>$log

VALIDATE $? "installing gcc and httpd-devel"

if [ -f /opt/$conn_tar_file ]; then
	SKIP "Downloading mod_jk"
else
	wget $conn_http_url -O /opt/$conn_tar_file &>>$log
	VALIDATE $? "Downloading mod_jk"
fi

cd /opt

if [ -d /opt/$conn_dir_home ]; then
	SKIP "extracting mod_jk"
else 
	tar -xf $conn_tar_file
	VALIDATE $? "extracting mod_jk"
fi

if [ -f /etc/httpd/modules/mod_jk.so ]; then
	SKIP "compiling mod_jk"
else
	cd $conn_dir_home/native
	./configure --with-apxs=/bin/apxs &>>$log && make clean &>>$log && make &>>$log && make install &>>$log
	VALIDATE $? "compiling mod_jk"
fi 	

cd /etc/httpd/conf.d

echo 'LoadModule jk_module modules/mod_jk.so
JkWorkersFile conf.d/workers.properties
JkLogFile logs/mod_jk.log
JkLogLevel info
JkLogStampFormat "[%a %b %d %H:%M:%S %Y]"
JkOptions +ForwardKeySize +ForwardURICompat -ForwardDirectories
JkRequestLogFormat "%w %V %T"
JkMount /student tomcatA
JkMount /student/* tomcatA' > modjk.conf

VALIDATE $? "creating modjk.conf"

echo '### Define workers
worker.list=tomcatA
### Set properties
worker.tomcatA.type=ajp13
worker.tomcatA.host=10.128.0.5
worker.tomcatA.port=8009' > workers.properties

VALIDATE $? "creating workers.properties"

cd /opt

if [ -f $tomcat_tar_file ]; then
	SKIP "Downloading tomcat"
else
	wget $tomcat_http_url &>>$log
	VALIDATE $? "Downloading tomcat"
fi

if [ -d $tomcat_dir_home ]; then
	SKIP "extracting tomcat"
else 
	tar -xf $tomcat_tar_file 
	VALIDATE $? "extracting tomcat"
fi	 	


cd $tomcat_dir_home/webapps

rm -rf *;

wget $student_war &>>$log

VALIDATE $? "Downloading student project"


cd ../lib

if [ -f $mysql_jar ]; then
	SKIP "downloading mysql driver"
else
	wget $mysql_jar_url &>>$log
	VALIDATE $? "downloading mysql jar"
fi

cd ../conf

sed -i -e '/TestDB/ d' context.xml
 
sed -i -e '$ i <Resource name="jdbc/TestDB" auth="Container" type="javax.sql.DataSource" maxTotal="100" maxIdle="30" maxWaitMillis="10000" username="student" password="student@1" driverClassName="com.mysql.jdbc.Driver" url="jdbc:mysql://localhost:3306/studentapp"/>' context.xml	

VALIDATE $? "configuring content.xml"

yum install mariadb mariadb-server -y &>>$log

VALIDATE $? "installing mariadb"

systemctl restart mariadb &>>$log

VALIDATE $? "starting mariadb"

echo "create database if not exists studentapp;
use studentapp;
CREATE TABLE if not exists Students(student_id INT NOT NULL AUTO_INCREMENT,
	student_name VARCHAR(100) NOT NULL,
    student_addr VARCHAR(100) NOT NULL,
	student_age VARCHAR(3) NOT NULL,
	student_qual VARCHAR(20) NOT NULL,
	student_percent VARCHAR(10) NOT NULL,
	student_year_passed VARCHAR(10) NOT NULL,
	PRIMARY KEY (student_id)
);
grant all privileges on studentapp.* to 'student'@'localhost' identified by 'student@1';" > /tmp/student.sql

mysql < /tmp/student.sql

VALIDATE $? "creating database"

cd ../bin

sh shutdown.sh &>>$log

sh startup.sh &>>$log

VALIDATE $? "Restarting tomcat"



































