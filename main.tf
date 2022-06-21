data "aws_subnet" "subnet" {
  filter {
    name   = "tag:Name"
    values = ["tko-public"]
  }
}
resource "aws_internet_gateway" "IGW" {    
    vpc_id =  aws_vpc.vlad.id         
}
resource "aws_vpc" "vlad" {
    cidr_block =  var.vlad_vpc_cidr
    instance_tenancy = "default"
}
resource "aws_subnet" "vlad_public_subnet" {
    vpc_id = aws_vpc.vlad.id
    cidr_block = var.vlad_public_subnets
  
}
resource "aws_subnet" "vlad_private_subnet" {
    vpc_id = aws_vpc.vlad.id
    cidr_block = var.vlad_private_subnets
}
resource "aws_route_table" "PublicRT" {
    vpc_id = aws_vpc.vlad.id
        route {
            cidr_block = "0.0.0.0/0"
            gateway_id = aws_internet_gateway.IGW.id
        }
}
resource "aws_route_table" "PrivateRT" {
    vpc_id = aws_vpc.vlad.id
        route  {
            cidr_block = "0.0.0.0/0"
            nat_gateway_id = aws_nat_gateway.NATgw.id 
        }
}
 resource "aws_route_table_association" "PublicRTassociation" {
    subnet_id = aws_subnet.vlad_public_subnet.id
    route_table_id = aws_route_table.PublicRT.id
 }
 resource "aws_route_table_association" "PrivateRTassociation" {
    subnet_id = aws_subnet.vlad_private_subnet.id
    route_table_id = aws_route_table.PrivateRT.id
 }
 resource "aws_eip" "nateIP" {
   vpc   = true
 }
 resource "aws_nat_gateway" "NATgw" {
   allocation_id = aws_eip.nateIP.id
   subnet_id = aws_subnet.vlad_public_subnet.id
 }

resource "aws_security_group" "websg" {
    vpc_id = aws_vpc.vlad.id
    
    egress {
        from_port = 0
        to_port = 0
        protocol = -1
        cidr_blocks = ["0.0.0.0/0"]
    }    
    ingress {
        from_port = 80
        to_port = 8080
        protocol = "tcp"        
        cidr_blocks = ["0.0.0.0/0"]
    }   
}
resource "aws_security_group" "mysqlsg" {
  vpc_id = aws_vpc.vlad.id
  ingress {
        from_port = 3306
        to_port = 3306
        protocol = "tcp"        
        cidr_blocks = [var.vlad_public_subnets]
    }
  }


resource "aws_instance" "webserver" {
    ami           = var.ami
    instance_type = "t2.micro"
    subnet_id = aws_subnet.vlad_public_subnet.id
    vpc_security_group_ids = ["${aws_security_group.websg.id}"]
    user_data = <<EOF
#!/bin/bash
apt-get update -y
apt-get install default-jdk -y
apt-get install tomcat8 -y
apt-get install tomcat8-admin -y
DB_PASS="${random_password.password.result}"
DB_USER=root
DB_NAME=test
DB_HOSTNAME="${aws_instance.mysqlserver.private_ip}"
mkdir /home/artifacts
cd /home/artifacts || exit
git clone https://github.com/QualiTorque/sample_java_spring_source.git
mkdir /home/user/.config/torque-java-spring-sample -p
jdbc_url=jdbc:mysql://$DB_HOSTNAME/$DB_NAME
bash -c "cat >> /home/user/.config/torque-java-spring-sample/app.properties" <<EOL
# Dadabase connection settings:
jdbc.url=$jdbc_url
jdbc.username=$DB_USER
jdbc.password=$DB_PASS
EOL
#remove the tomcat default ROOT web application
rm -rf /var/lib/tomcat8/webapps/ROOT
# deploy the application as the ROOT web application
cp sample_java_spring_source/artifacts/torque-java-spring-sample-1.0.0-BUILD-SNAPSHOT.war /var/lib/tomcat8/webapps/ROOT.war
systemctl start tomcat8
EOF
}
resource "aws_instance" "mysqlserver" {
    ami = var.ami
    instance_type = "t2.micro"
    subnet_id = aws_subnet.vlad_private_subnet.id
    vpc_security_group_ids = [ "${aws_security_group.mysqlsg.id}" ]
     user_data = <<EOF
        #!/bin/bash
        apt-get update -y
        DB_PASS="${random_password.password.result}"
        DB_USER=root
        DB_NAME=test
        # Preparing MYSQL for silent installation
        export DEBIAN_FRONTEND="noninteractive"
        echo "mysql-server mysql-server/root_password password $DB_PASS" | debconf-set-selections
        echo "mysql-server mysql-server/root_password_again password $DB_PASS" | debconf-set-selections
        # Installing MYSQL
        apt-get install mysql-server -y
        #apt-get install mysql-client -y
        # Setting up local permission file
        mkdir /home/pk;
        bash -c "cat >> /home/pk/my.cnf" <<EOL
        [client]
        ## for local server use localhost
        host=localhost
        user=$DB_USER
        password=$DB_PASS
        [mysql]
        pager=/usr/bin/less
        EOL
        # Creating database
        mysql --defaults-extra-file=/home/pk/my.cnf << EOL
        CREATE DATABASE $DB_NAME;
        EOL
        # Configuring Remote Connection Access: updating sql config to not bind to a specific address
        sed -i 's/bind-address/#bind-address/g' /etc/mysql/mysql.conf.d/mysqld.cnf
        # granting db access
        mysql --defaults-extra-file=/home/pk/my.cnf << EOL
        GRANT ALL ON *.* TO $DB_USER@'%' IDENTIFIED BY "$DB_PASS";
        EOL
        mysql --defaults-extra-file=/home/pk/my.cnf -e "FLUSH PRIVILEGES;"
        systemctl restart mysql.service
        EOF
}
resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}