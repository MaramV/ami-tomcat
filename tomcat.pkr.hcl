# Commands to build ami
# `packer init tomcat.pkr.hcl`
# `packer fmt tomcat.pkr.hcl`
# `packer validate -var-file="qa.ortc.pkrvars.hcl" tomcat.pkr.hcl` - Will validate the template files.
# `packer build -var-file="qa.ortc.pkrvars.hcl" tomcat.pkr.hcl` - Will build the packer template file named `coap.pkr.hcl` and create an AMI using the variables file for configuration

packer {
  required_plugins {
    amazon = {
      version = " >= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "role_arn" {
  type = string
}

variable "vpc_tag_name" {
  type = string
}

variable "subnet_tag_name" {
  type = string
}

variable "ssh_user" {
  type = string
}

variable "ssh_keyfile" {
  type = string
}

variable "ec2_type" {
  type = string
}

variable "region" {
  type = string
}

variable "tomcat_version" {
  type = string
}

variable "s3_bucket" {
  type = string
}

locals {
  packerdate     = formatdate("YYYYMMDD", timestamp())
  packerdatetime = formatdate("YYYYMMDD-hhmmss", timestamp())
}

source "amazon-ebs" "ortc-tomcat" {
  # assume_role {
  #   role_arn = "${var.role_arn}"
  # }
  vpc_filter {
    filters = {
      "tag:Name" = "${var.vpc_tag_name}"
    }
  }
  subnet_filter {
    filters = {
      "tag:Name" : "${var.subnet_tag_name}"
    }
    most_free = true
    random    = false
  }
  ami_name                    = "ortc-tomcat"
  force_deregister            = true
  force_delete_snapshot       = true
  instance_type               = "${var.ec2_type}"
  region                      = "${var.region}"
  associate_public_ip_address = true
  launch_block_device_mappings {
    device_name = "/dev/xvda"
    volume_size = 25
  }
  tags = {
    Name : "ortc-tomcat"
    Build_Name : "ortc-tomcat-${local.packerdate}"
    Base_AMI_Name   = "{{ .SourceAMIName }}"
    Build_Timestamp = "${local.packerdatetime}"
    map-migrated    = "d-server-00il1notdel4uu"
  }
  temporary_iam_instance_profile_policy_document {
    Statement {
      Action   = ["s3:*"]
      Effect   = "Allow"
      Resource = ["*"]
    }
    Version = "2012-10-17"
  }
  run_tags = {
    AMI_Build_Date = "${local.packerdatetime}",
    environment    = "qa",
    Project        = "Ecomm Rearch"
  }
  run_volume_tags = {
    environment = "qa",
    Project     = "Ecomm Rearch"
  }
  source_ami_filter {
    filters = {
      name                = "amzn2-ami-kernel-5*"
      architecture        = "x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }
  ssh_username = "${var.ssh_user}"
}

build {
  name = "ortc-tomcat"
  sources = [
    "source.amazon-ebs.ortc-tomcat"
  ]
  provisioner "file" {
    sources = [
      "otcweblogic.tar",
      "tomcat.service",
      "context.xml",
      "context_activemq.xml",
      "context_activemq_co.xml",
      "logging.properties",
      "tomcat-users.xml",
      "tomcat_manager.conf",
      "tomcat_server.xml",
      "tomcat_server_co.xml",
      "setenv.sh",
      "setenv_co.sh",
      "codedeployagent.yml",
      "dhclient.conf",
      "cloudwatch_config.json",
      "tomcat_logrotate",
      "postrotate.sh"
    ]
    destination = "/tmp/"
  }
  provisioner "shell" {
    inline = [
      "sudo yum update -y",
      # Install AWS SSM Agent
      # "sudo yum install -y https://s3.${var.region}.amazonaws.com/amazon-ssm-${var.region}/latest/linux_amd64/amazon-ssm-agent.rpm", Not sure why this is not needed anymore
      "sudo systemctl status amazon-ssm-agent",
      # Install and Configure AWS CloudWatch Agent
      "sudo mkdir -p /usr/share/collectd/",
      "sudo touch /usr/share/collectd/types.db",
      "sudo yum install -y https://s3.${var.region}.amazonaws.com/amazoncloudwatch-agent-${var.region}/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm",
      "sudo cp /tmp/cloudwatch_config.json /opt/aws/amazon-cloudwatch-agent/bin/config.json",
      "sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -s -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json",
      "sudo service amazon-cloudwatch-agent restart",
      # Install Java and Configure Tomcat, library for HTTPS/8443
      # "sudo amazon-linux-extras install java-openjdk11 -y",
      # "sudo yum install java-1.8.0-amazon-corretto -y",
      "sudo yum install java-1.8.0-openjdk -y",
      "sudo groupadd --system tomcat",
      "sudo useradd -d /usr/share/tomcat -r -s /bin/false -g tomcat tomcat",
      "sudo yum -y install wget",
      "wget https://archive.apache.org/dist/tomcat/tomcat-9/v${var.tomcat_version}/bin/apache-tomcat-${var.tomcat_version}.tar.gz",
      "sudo tar xvf apache-tomcat-${var.tomcat_version}.tar.gz -C /usr/share/",
      "sudo ln -s /usr/share/apache-tomcat-${var.tomcat_version}/ /usr/share/tomcat",
      "sudo mv /tmp/tomcat.service /etc/systemd/system/tomcat.service",
      "sudo mv /tmp/tomcat_server.xml /usr/share/tomcat/conf/server.xml",
      "sudo chown -R tomcat:tomcat /tmp/setenv.sh",
      "sudo mv /tmp/tomcat-users.xml /usr/share/tomcat/conf/tomcat-users.xml",
      # Logrotate
      "sudo cp /tmp/tomcat_logrotate /etc/logrotate.d", 
      "sudo mkdir -p /usr/share/logrotate/",
      "sudo cp /tmp/postrotate.sh /usr/share/logrotate",
      "sudo cp /tmp/logging.properties /usr/share/tomcat/conf/logging.properties",
      "sudo yum install dos2unix -y",
      "sudo dos2unix /etc/logrotate.d/tomcat_logrotate",
      "sudo dos2unix /usr/share/logrotate/postrotate.sh",
      "sudo yum install -y mod_ssl",
      # Pull HTTPS/8443 Certificates
      "sudo mkdir /usr/share/tomcat/cert",
      "sudo aws s3 sync s3://${var.s3_bucket}/orientaltrading_cert/ /usr/share/tomcat/cert/",
      "sudo chmod -R 744 /usr/share/tomcat/cert",
      # Pull jars from S3 to Tomcat lib directory
      "sudo aws s3 sync s3://${var.s3_bucket}/tomcat_lib/ /usr/share/tomcat/lib/",
      # Set Tomcat directory ownership, restart Tomcat
      "sudo chown -R tomcat:tomcat /usr/share/apache-tomcat-${var.tomcat_version}/",
      "sudo chown -R tomcat:tomcat /usr/share/tomcat/",
      "sudo chown -R tomcat:tomcat /usr/share/tomcat/*",
      #"sudo chown -R tomcat:tomcat /usr/share/tomcat/bin/setenv.sh",
      "sudo rm -rf /usr/share/tomcat/webapps/docs",
      "sudo rm -rf /usr/share/tomcat/webapps/examples",
      # Register service and restart Tomcat
      "sudo systemctl daemon-reload",
      "sudo systemctl restart tomcat",
      "sudo systemctl enable tomcat",
      "sudo systemctl status tomcat",
      # Add Directory for unpacking CodeDeploy projects
      "sudo mkdir /opt/tomcat/",
      # Install AWS CodeDeploy Agent
      "sudo yum install ruby -y",
      "sudo yum erase codedeploy-agent -y",
      "cd /home/ec2-user",
      "wget https://aws-codedeploy-us-west-2.s3.us-west-2.amazonaws.com/latest/install",
      "chmod +x ./install",
      "sudo ./install auto",
      "wget http://archive.apache.org/dist/activemq/5.11.1/apache-activemq-5.11.1-bin.tar.gz",
      "sudo service codedeploy-agent start",
      "sudo service codedeploy-agent status",
      # Update for on prem DNS resolution
      "sudo cp /tmp/dhclient.conf /etc/dhcp/dhclient.conf",
    ]
  }
  post-processor "shell-local" {
    inline = ["echo $env"]
  }
}