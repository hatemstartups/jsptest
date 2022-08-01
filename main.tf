provider "aws" { 
  region  = "us-west-2"
  access_key = "REMOVED FOR SECURITY"
  secret_key = "REMOVED FOR SECURITY"
}

variable "ingressrules" {
  type    = list(number)
  default = [8080,22]
}

resource "aws_security_group" "web_traffic" {
  name        = "Allow web traffic"
  description = "Allow ssh and standard http/https ports inbound and everything outbound"

  dynamic "ingress" {
    iterator = port
    for_each = var.ingressrules
    content {
      from_port   = port.value
      to_port     = port.value
      protocol    = "TCP"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Terraform" = "true"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}


resource "aws_instance" "TomcatServer" {
  ami             = data.aws_ami.ubuntu.id
  instance_type   = "t3.micro"
  security_groups = [aws_security_group.web_traffic.name]
  key_name        = "hatem"

  provisioner "remote-exec" {
    inline = [
      "sudo apt update -qq",
      "sudo apt install -y default-jdk",
      "sudo groupadd tomcat",
      "sudo useradd -s /bin/false -g tomcat -d /opt/tomcat tomcat",
      "cd /tmp",
      "curl -O https://dlcdn.apache.org/tomcat/tomcat-10/v10.0.23/bin/apache-tomcat-10.0.23.tar.gz",
      "sudo mkdir /opt/tomcat",
      "cd /opt/tomcat",
      "sudo tar xzvf /tmp/apache-tomcat-10.0.23.tar.gz -C /opt/tomcat --strip-components=1",
      "sudo chgrp -R tomcat /opt/tomcat",
      "sudo chmod -R g+r conf",
      "sudo chmod g+x conf",
      "sudo chown -R tomcat webapps/ work/ temp/ logs/ bin/ conf/ lib/",
      "sudo chmod 777 /opt/tomcat/webapps/", 
      "cd /opt/tomcat",
      "sudo ufw allow 8080",
      "sudo chmod +rx bin",
      "cd /opt/tomcat/bin",
      "sudo ./startup.sh run",
    ]
  }

  connection {
    type        = "ssh"

    host        = self.public_ip
    user        = "ubuntu"
    private_key = file("./id_rsa")
  }

  tags = {
    "Name"      = "Tomcat_Server"
    "Terraform" = "true"
  }
}


resource "aws_instance" "JenkinsWithAnsible_Server" {
  ami             = data.aws_ami.ubuntu.id
  instance_type   = "t3.micro"
  security_groups = [aws_security_group.web_traffic.name]
  key_name        = "hatem"

  provisioner "remote-exec" {
    inline = [
     "wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -",
      "sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'",
      "sudo apt update -qq",
      "sudo apt install -y default-jdk",
      "sudo apt install -y jenkins",
      "sudo systemctl start jenkins",
      "sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080",
      "sudo sh -c \"iptables-save > /etc/iptables.rules\"",
      "echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections",
      "echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections",
      "sudo apt-get -y install iptables-persistent",
      "sudo ufw allow 8080",
      "sudo apt install -y ansible",
    ]
  }

  connection {
    type        = "ssh"

    host        = self.public_ip
    user        = "ubuntu"
    private_key = file("./id_rsa")
  }

  tags = {
    "Name"      = "JenkinsWithAnsible_Server"
    "Terraform" = "true"
  }
}

