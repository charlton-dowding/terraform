# Create a Basic AWS Instance with Terraform

The purpose of this documentation is to explain to you, the reader, how to create, deploy and connect to a basic AWS instance and its associated infrastructure using Terraform.

## Introduction

In terraform, we write our code in HashiCorp Configuration Language (HCL), which uses a type of syntax that is meant to balance machine readability with user readability. Terraform can also read JSON configurations in order to reinforce that machine friendliness property, but we are only going to be focusing on HCL in this example. 

Terraform reads files with the .tf extension, and so our HCL code should always be saved in this particular format. All .tf files should also be stored within our root folder directly, which I have called “demo” for the purpose of this documentation. For example, the variables Terraform file var.tf should have a path of the form ~/…/demo/var.tf. We do this because Terraform is executed through console commands within our working directory, which should, by convention, be our project’s root folder. Terraform will be looking for .tf files directly within this directory and so if they are saved somewhere else, it is likely that they will not be considered. Note that it is assumed that you have terraform installed and initialised within your project’s root folder already. If this is not the case then you can follow Terraform’s installation instructions [here](https://www.terraform.io/intro/getting-started/install.html).

Terraform has a wide range of features and there many Terraform console commands to play around with; however, for this example and in general, there are three core commands that should always be remembered: terraform plan, terraform apply, and terraform destroy. The command terraform init is also important and is used at the beginning of every project in order to initialise local settings and data.

Now, assuming that we have already created a set of Terraform scripts and that we want to subsequently test them, we should first execute the terraform plan command. This will ensure that there are no syntax errors in our code; that our code can be logically executed; and, most importantly, that we know what will happen to our infrastructure when our code is applied.

If we are happy that our code is set to do what we want it to do, we can then execute terraform apply, which will read and execute the code in all of our .tf files. It is important to note that Terraform will apply all of our code in the correct order regardless of what object is stored where. So, if one object in one.tf depends on another object in two.tf then the later object in two.tf will be executed first. This means that we can structure our .tf files however we want, and so in our file naming, we can prioritise readability and maintainability over everything else.

Finally, once we feel that we no longer need the instances and infrastructure created by Terraform, we can destroy everything that we have generated with terraform destroy. But be careful, this will terminate all resources that were created by Terraform, leaving us with a completely blank slate. Luckily, as this command is so powerful, there is a ‘yes’ confirmation failsafe that we need to type in manually afterwards in order to fully execute it.

## The Cloud Service Provider - provider.tf

To start off our Terraform script, we will need to declare a cloud service provider, which, for this example, will be AWS; this is so that Terraform knows which service we want to use. Within the body of this provider object, we can state the region we want our services to run in and we can give Terraform access to our AWS account by making it aware of our account credentials, which, for AWS, consists of an access key and a secret key.
```
provider "aws" {
    region = "${var.aws_region}"
    access_key = "${var.aws_access_key_id}"
    secret_key = "${var.aws_secret_access_key}"
}
```
For security, readability, and maintainability reasons, the region and the access keys have not been assigned directly, and have instead been taken from our var.tf file, which is where all our variables are stored. If a required variable is not hardcoded in var.tf, then the user can input it directly into the console themselves when terraform apply is executed. This is what we have done for our access key and secret key as we will see later on.

Now, before we jump straight into our instance configuration, there are a few more security issues that we must address. It is often necessary, particularly in a corporate environment, to ensure that only specified users can access our instances. This prevents those with malicious intent from getting their hands on our infrastructure and on our products. Therefore, there are a couple of security measures that we can take to mitigate these risks.

## Key Pairs - keys.tf

We have already talked about how we use our access keys to authenticate access to the provider. In a similar vein, we can create and provide RSA encrypted key-pairs to authenticate access to our instances. Key-pairs are pairs of public .pub and private .pem keys that allow only private key holders to access instances containing the respective public key. 

In theory, there is nothing stopping us from creating RSA encrypted key-pairs ourselves, however, for this example, I have kept things simple and used the AWS key-pair service to generate my private and public keys. We can now create a key-pair resource using our public key, which will restrict the access of all instances with this public key to only those users who hold our private key. Of course, the beauty of RSA encryption means that we do not need to state the private key in the resource as only the public key is required for encryption.
```
resource "aws_key_pair" "demo" {
    key_name   = "demo-key"
    public_key = "${file("~/.ssh/demo.pub")}"
}
```
Note that we have given the key a name tag as this allows us to use multiple keys for a multitude of instances whilst retaining readability and a well-defined infrastructure. For this example, we will only be using the one key-pair, but it is good practice to give all your resources name tags and even description tags when appropriate.
Security Groups - sg.tf

As a second security measure, whereas key-pairs restrict the access to our instance with respect to the specific user, we can use security groups to restrict the access to our instance with respect to the port and protocol. We want to define a security group for our instance in order to restrict incoming and outgoing traffic to our specifications. Similarly, as in the key-pair resource, we will define the resource by type and name, whilst providing a name tag within the code body to ensure a more clearly named and ordered infrastructure.
```
resource "aws_security_group" "demo" {
    name = "demo-sg"
    ...
}
```
With respect to incoming traffic, often called ingress, we only want SSH connections that use our key-pair authentication system, where SSH is a TCP protocol that connects through port 22. Also, we only want specific clients to have access to our instance, and so we will restrict the incoming connections to come from approved IP addresses only.

With respect to outgoing traffic, often called egress, we can close all ports as our particular example doesn’t require outgoing traffic. In this case we do not need to define anything, as all ports are closed by default when no specifications are defined.
```
resource "aws_security_group" "demo" {
    name = "demo-sg"
    ingress {
        from_port = "22"
        to_port = "22"
        protocol = "tcp"
        cidr_blocks = ["Collection of approved IP Addresses"]
    }
}
```
## Instances – instances.tf

Now that we have defined our provider, key-pair, and security group, we can begin to define our AWS instance resource. Within the body of this resource is where everything comes together and we can assign a multitude of attributes in order to customise our instance. 

Let us first begin with the instance type, which defines the CPU, storage, memory and networking capacity that we want. As our example is as simple as instances come, we can happily use the t2.micro instance with no performance issues at all. This is very important as this instance type is part of the AWS free tier, which you should be able to use for any small-scale deployments, and which, as the name suggests, is completely free. Yay! So, at this stage, our code currently looks like the following: 
```
resource "aws_instance" "demo" {
    instance_type = "t2.micro"
    ...
}
```
After declaring the instance type, we now want to specify the AMI that we wish to use. The AMI, or Amazon Machine Image, creates a virtual machine within EC2 and the configuration of this VM is dependent on the specific AMI used to create it. We can search through these AMIs, by their unique id, in order to find a specific image that we desire, or we can create our own customised image snapshot of a virtual machine and save it in an AMI format using an image builder, such as Packer. For this example, the basic Amazon Linux image will do just fine, and once again the id is not declared as a string literal but is instead stored as a variable in var.tf and then referenced. Adding the key-pair and security group assignments to this resource along with a name tag and we get the following finished product:
```
resource "aws_instance" "demo" {
    instance_type = "t2.micro"
    ami = "${var.aws_ami}"
    key_name = "${aws_key_pair.demo.key_name}"
    security_groups = ["${aws_security_group.demo.name}"]
    tags {Name = "demo-instance"}
}
```
Note that when referencing attributes from other resources using the $ symbol, the syntax is: "${resource-type.resource-name.attribute-name}".

## Variables – var.tf

All of the variables used throughout this example are defined in var.tf as follows:
```
variable "aws_access_key_id" {}
variable "aws_secret_access_key" {}
variable "aws_region"{
    default="us-east-1"
}
variable "aws_ami"{
    default = "ami-8c1be5f6"
}
```
Note that, as we stated at the beginning, the access key and secret key are not hard coded, since they are inputted directly through the console for security purposes. 

## Outputs – out.tf

To conclude, once our instance is effectively up and running, we want to be able to access it through SSH. However, we are going to need the instance's IP address if we want to connect to it this way. Defining a public IP address output will display what we want on the console.
```
output "ip" {
    value = "${aws_instance.demo.public_ip}"
}
```
Finally, with the public IP address, we can now connect to the instance through the console with: ssh –i ~/.ssh/demo.pem ec2-user@(INSERT PUBLIC IP). And then, Voilà! Fantastisch! We have connected to our first Terraform-generated instance.

