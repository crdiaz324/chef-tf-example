variable "casops_az1_fqdn" { default = "casops-000.somedomain.com" }

resource "aws_instance" "casops_az1" {
    tags {
        Name = "${var.casops_az1_fqdn}"
    }
    instance_type = "t2.xlarge"
    availability_zone = "${var.aws_az1}"
    key_name = "aws-shared"
    ami = "${var.ami_centos7}"
    subnet_id = "${module.aws-subnets.data_az1_id}"
    source_dest_check = "false"
    vpc_security_group_ids = ["${module.aws-sgs.default_sg_id}"]
     
    user_data = <<EOF
#cloud-config
hostname: ${var.casops_az1_fqdn}
fqdn: ${var.casops_az1_fqdn} 
runcmd:
 - '/etc/init.d/iptables stop'
 - 'chkconfig iptables off'
EOF

    root_block_device {
        volume_type = "gp2"
        volume_size = "300"
        delete_on_termination = "true"
    }

   provisioner "remote-exec" {
   connection {
        host = "${var.ipa_server}"
        user = "${var.ipauser}"
        password = "${var.ipapw}"
        agent = "true"
   }

   inline = [ 
   "echo ${var.ipapw} | kinit",
   "ipa host-del ${aws_instance.casops_az1.tags.Name} --updatedns --continue", 
   "ipa host-add --password=mysecretpassword --ip-address=${aws_instance.casops_az1.private_ip} ${aws_instance.casops_az1.tags.Name}"
    ]
   

   }

   provisioner "chef" {
       run_list = ["${var.chef_vpc_role}", "role[casops-rsa]"]
       node_name = "${aws_instance.casops_az1.tags.Name}"
       server_url = "${var.chef_url}"
       version = "${var.chef_client_version}"
       validation_client_name = "${var.chef_validator_name}"
       validation_key = "${file("./chef/${var.chef_validator_name}.pem")}"
       ssl_verify_mode = ":verify_none"
       attributes_json = "{ \"tags\": [\"cas\"]}"  
       connection {
         user = "centos"

       }
   }
}
