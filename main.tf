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

resource "null_resource" "example" {
  # Changes to name tag of any instance goign to triggr local echo
  triggers = {
    example_instance_ids = "${join(",", [aws_instance.example1.tags.name, aws_instance.example2.tags.name])}"
  }

  provisioner "local-exec" {
    command = "echo Name tag in one of two instances had changed."
  }
}

