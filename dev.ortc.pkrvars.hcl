role_arn        = "arn:aws:iam::232137109144:role/Jelecos_Admin"
vpc_tag_name    = "ecom-dev-vpc" // vpc on dev
subnet_tag_name = "gwlb-sn-a" // subnet on dev
ssh_user        = "ec2-user"
ssh_keyfile    = "~/Documents/keys/ortc-ami-builder-key.pem" // needs to local location of key
ec2_type       = "t3a.small"
region         = "us-west-2"
tomcat_version = "9.0.59"
