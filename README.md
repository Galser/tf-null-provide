# tf-null-provide
Terrraform null provider. 

# Requirements
This repo assumes general knowledge about Terraform for AWS, if not, please get yourself accustomed first by going through [getting started guide](https://learn.hashicorp.com/terraform?track=getting-started#getting-started) . Please also have your AWS credentials prepared in some way, preferably environment variables. See in details here : [Section - Keeping Secrets](https://aws.amazon.com/blogs/apn/terraform-beyond-the-basics-with-aws/)


# Null provider
Null provider (original documentation can be found here: https://www.terraform.io/docs/providers/null/index.html ) in Terraform is a special case. By itself it does nothing except to have the same lifecycle as other providers. But it can be used as a workaround for some tricky situation and help to orchestrate stuff.
> Note: Usage of null provider can make configuration less readable. Apply with care.

Null provider has 2 parts - *resource* and *data source*

## Null provider __resource__

The **null_resource** resource implements the standard resource lifecycle but takes no further action.

The **triggers** argument allows specifying an arbitrary set of values that, when changed, will cause the resource to be replaced (think of IPs of cluster components, for example)

One attribute is exported - **id** - an arbitrary value that changes each time the resource is replaced. Can be used to cause other resources to be updated or replaced in response to null_resource changes.

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
            "name" = "example2"
        }
    }

    resource "null_resource" "example" {
    # Changes to any instance tga "name" wil trigger this "
        triggers = {
            example_instance_ids = "${join(",", [aws_instance.example1.tags.name, aws_instance.example2.tags.name])}"
        }

        provisioner "local-exec" {
            command = "echo Name tag in one of two instances had changed."
        }
    }
    ```
    The most important part here is attribute **triggers** - is it optional and presents map of arbitrary strings that, when changed, will force the null resource to be replaced, re-running any associated provisioners - and that can be very usefull.
- Init Terraform with : 
    ```
    terraform init
    ```
- Now, let's run apply for our code :
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
- By itself is not very useful, but let's assume that some changes required to tags, this is going to demo the null_resource trigger. To do it, we need to change `name` tag for second instance to  `"example_two"` :
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
    This operation does not require for instance to be recreated, and as such can be performed in-place, but, the tag `name` is going to change, thus triggering the replacement (changing lifecycle) of our null_resource :
    ```
    ...
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
    Here we can clearly observe the message : *"Name tag in one of two instances had changed."*, and instead of simple echo it can be some provisioner.
- Do not forget ro destroy instances after experiments ,by running :
    ```
    terraform destroy
    ```
    And replying `yes` to the question
> Please note that code above is not the example of the good style, as most values are hard-coded, but that's intentional - to make it more readable and clear for null_provider example explanation.

## Null provider : data source

The **null_data_source** data source implements the standard data source lifecycle but does not interact with any external APIs.
When distinguishing from data resources, the primary kind of resource (as declared by a resource block) is known as a managed resource. Both kinds of resources take arguments and export attributes for use in configuration, but while managed resources cause Terraform to create, update, and delete infrastructure objects, data resources cause Terraform only to read objects. For brevity, managed resources are often referred to just as "resources" when the meaning is clear from context.

The following arguments are supported:

  **inputs** - (Optional) A map of arbitrary strings that is copied into the outputs attribute, and accessible directly for interpolation.

  **has_computed_default** - (Optional) If set, its literal value will be stored and returned. If not, its value defaults to "default". This argument exists primarily for testing and has little practical use.

This data soruce also exports the following attributes :

  **outputs** - After the data source is "read", a copy of the inputs map.

  **random** - A random value. This is primarily for testing and has little practical use; prefer the random provider for more practical random number use-cases.

Now, to tests.
### Example 1

- Let's reuse the file `main.tf` from previous section that we have already. Delete the last part with resource **"null_resource"** description and instead add **null_data_source**, as follows : 
    ```terraform
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
    ```
- Let's apply our new configuration. Run :
    ```
    terraform apply
    ```
    Output should end with : 
    ```
    aws_instance.example1: Creating...
    aws_instance.example2: Creating...
    aws_instance.example1: Still creating... [10s elapsed]
    aws_instance.example2: Still creating... [10s elapsed]
    aws_instance.example1: Still creating... [20s elapsed]
    aws_instance.example2: Still creating... [20s elapsed]
    aws_instance.example1: Creation complete after 22s [id=i-03e10aecdae8845a5]
    aws_instance.example2: Still creating... [30s elapsed]
    aws_instance.example2: Creation complete after 32s [id=i-0b5dc6db9209d05c6]
    data.null_data_source.all_example_servers: Refreshing state...

    Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

    Outputs:

    all_instances_ips = 172.31.36.68,172.31.42.223
    all_instances_tags = example1,example2
    ```    
    And here, two outputs **all_instances_ips** and **all_instances_tags** are taken  from  our new data source. For example, we can use this data source and feed it to some load-balancer.

- Please destroy the existing infrastructure, as we going to test another example. Execute :
    ```
    terraform destroy
    ```
    And replying `yes` to the question
    

### Example 2
- Let's create file *main.tf* with following content :
    ```terraform
    variable "departments_map" {
    type = "map"
    default = {
        "11" = "CorpIT"
        "03" = "Finnace"
        "911" = "Security"
    }  
    }

    variable "department" { 
        default = "11" 
    }


    data "null_data_source" "full_token" {
        inputs = {
            name = "${var.company["name"]}"
            tax_id    = "${var.company["tax_id"]}"
            department = var.departments_map[var.department]
        }
    }

    output "full_token_data" {
        value = "${data.null_data_source.full_token.inputs}"
    }
    ```
- Now, let's run apply for our code :
    ```
    terraform.apply
    ```
- Output going to end up with something similar to : 
    ```
    data.null_data_source.full_token: Refreshing state...

    Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

    Outputs:

    full_token_data = {
      "department" = "CorpIT"
      "name" = "GRRipper"
      "tax_id" = "18121245"
    }
    ```
    And as you can see, there is a message on top : *"data.null_data_source.full_token: Refreshing state..."* - very simple for our case indeed, but very useful to gather together collections of intermediate values to re-use elsewhere later, in configuration. Like in the example above - now we have full token data with all fields (and some of them interpolated from a map) in one place, accessible via one data source. 



# todo


# done

- [x] create an intro
- [x] make and test example for null provider **resource**
- [x] make and test example for null provider **data source**
