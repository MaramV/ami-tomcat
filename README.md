Packer installation instructions https://www.packer.io/downloads
1. `brew tap hashicorp/tap`
2. `brew install hashicorp/tap/packer`

In order to build your ami, you will need to get the key from the s3 bucket, put it on your machine, and update the file path in the pkrvars files

Commands to build ami
1. `packer init tomcat.pkr.hcl`
2. `packer fmt tomcat.pkr.hcl`
3. `packer validate -var-file="{environment}.ortc.pkrvars.hcl" tomcat.pkr.hcl` - Will validate the template files.
4. `packer build -var-file="{environment}.ortc.pkrvars.hcl" tomcat.pkr.hcl` - Will build the packer template file named `coap.pkr.hcl` and create an AMI using the variables file for configuration

For testing, if you don't want to delete the existing AMI, you can create a new one by changing the ami_name (~line 69 in tomcat.pkr.hcl) variable. Example: ortc-tomcat5