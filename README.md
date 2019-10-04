# tf-null-provide
Terrraform null provider. 

# Requirements
This repo assumes general knowledge about Git and  Terraform for AWS, if not , please get yourself accustomed first by going for example through [getting started guide](https://learn.hashicorp.com/terraform?track=getting-started#getting-started) . Please also have your AWS credentials prepared in some way, prefferably  environment variables. See indetaisl here : [Section - Keeping Secrets](https://aws.amazon.com/blogs/apn/terraform-beyond-the-basics-with-aws/)


# Null provider
Null provider (original documentation cna be fond here : https://www.terraform.io/docs/providers/null/index.html ) in Terraform is a special case. By itself it do nothing. But it can be used as workaround for some tricky situation and help to orchestrate stuff.
> Note : Usage of null provider can make configuration less readable. Apply with care

Null provider have 2 parts - *resource* and *data source*

## Null provider __resource__

The **null_resource** resource implements the standard resource lifecycle but takes no further action.

The **triggers** argument allows specifying an arbitrary set of values that, when changed, will cause the resource to be replaced.

- Create file [main1.tf](main1.tf) with the following content
    ```terraform
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
            "name" = "example1"
        }
    }

    resource "null_resource" "example" {
    # Changes to any instance privae IP will trigger below
        triggers = {
            example_instance_ids = "${join(",", [aws_instance.example1.tags.name, aws_instance.example2.tags.name])}"
        }

        provisioner "local-exec" {
            command = "echo Name tag in one of two instances had changed."
        }
    }
    ```
- Init Terraform with : 
```
terraform init
```
- Now, let's run apply this file :
    ```
    terraform.apply
    ```
- Output going to end up with something similar to : 
    ```
    null_resource.example: Provisioning with 'local-exec'...
    null_resource.example (local-exec): Executing: ["/bin/sh" "-c" "echo Name tag in one of two instances had changed."]
    null_resource.example (local-exec): Name tag in one of two instances had changed.
    null_resource.example: Creation complete after 0s [id=7218323933607884117]

    Apply complete! Resources: 3 added, 0 changed, 0 destroyed.
    ```
- By itself is not very useful, but let's assume that some changes required to tags. this is going to demo the null_resource trigger. To demo it, we need to change 
`name` tag for second instance to  `"example_two"` :
  ```terraform
  ...
  resource "aws_instance" "example2" {
  ami           = "ami-048d25c1bda4feda7" # Ubuntu 18.04.3 Bionic, custom
  instance_type = "t2.micro"
  tags = {
      "name" = "example_two"
   }  
  }
  ...
  ```
- And run apply :
    ```
    terraform.apply
    ```
    This operation does not re  quire for instance to bre recrated, and as such can be performed in-place, but, the tag `name` is going to change, thus triggering the recreation (changing lifecycle) of our null_resource :
    ```
    # null_resource.example must be replaced
    -/+ resource "null_resource" "example" {
        ~ id       = "4492157253109344989" -> (known after apply)
        ~ triggers = { # forces replacement
            ~ "example_instance_ids" = "example1,example2" -> "example1,example_two"
            }
        }

    Plan: 1 to add, 1 to change, 1 to destroy.

    Do you want to perform these actions?
    Terraform will perform the actions described above.
    Only 'yes' will be accepted to approve.

    Enter a value: yes

    null_resource.example: Destroying... [id=4492157253109344989]
    null_resource.example: Destruction complete after 0s
    aws_instance.example2: Modifying... [id=i-044a9d7a2921cf662]
    aws_instance.example2: Modifications complete after 2s [id=i-044a9d7a2921cf662]
    null_resource.example: Creating...
    null_resource.example: Provisioning with 'local-exec'...
    null_resource.example (local-exec): Executing: ["/bin/sh" "-c" "echo Name tag in one of two instances had changed."]
    null_resource.example (local-exec): Name tag in one of two instances had changed.
    null_resource.example: Creation complete after 0s [id=1939029593196223676]
    ```
    Here we can clearly observe the message : "Name tag in one of two instances had changed."
- Do not forget ro destroy instances after experiments ,by running :
    ```
    terraform destroy
    ```


# todo

- [ ] make and test example for null provider **data source**

# done

- [x] create intro
- [x] make and test example for null provider **resource**

