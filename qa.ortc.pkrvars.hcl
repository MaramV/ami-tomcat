role_arn        = "arn:aws:iam::246338920281:role/Jelecos_Admin"
vpc_tag_name    = "ecom-qa1-vpc" // vpc on qa
subnet_tag_name = "alb-qa1-sn-a" // subnet on qa
s3_bucket        = "246338920281-ec2-resources"
ssh_user        = "ec2-user"
ssh_keyfile    = "~/Documents/keys/otc-qa-key-west-2.pem"
ec2_type       = "t3a.medium"
region         = "us-west-2"
tomcat_version = "9.0.59"
