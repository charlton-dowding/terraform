resource "aws_instance" "demo" {
    instance_type = "t2.micro"
    ami = "${var.aws_ami}"
    key_name = "${aws_key_pair.demo.key_name}"
    security_groups = ["${aws_security_group.demo.name}"]
    tags {
        Name = "demo-instance"
    }
}
