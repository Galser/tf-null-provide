# Null provider
provider "aws" {
  profile    = "default"
  region     = "eu-central-1"
}

resource "aws_instance" "example1" {
  ami           = "ami-048d25c1bda4feda7" # Ubuntu 18.04.3 Bionic, custom
  instance_type = "t2.micro"
  tags = {
    "name" = "example1"
  }
}

resource "aws_instance" "example2" {
  ami           = "ami-048d25c1bda4feda7" # Ubuntu 18.04.3 Bionic, custom
  instance_type = "t2.micro"
  tags = {
    "name" = "example2"
  }  
}

data "null_data_source" "all_example_servers" {
    inputs = {
        all_name_tags =  "${join(",", [aws_instance.example1.tags.name, aws_instance.example2.tags.name])}"
        all_private_ips = "${join(",", [aws_instance.example1.private_ip, aws_instance.example2.private_ip])}"
    }
}

output "all_instances_tags" {
  value = "${data.null_data_source.all_example_servers.outputs["all_name_tags"]}"
}

output "all_instances_ips" {
  value = "${data.null_data_source.all_example_servers.outputs["all_private_ips"]}"
}