resource "aws_key_pair" "demo" {
    key_name   = "demo-key"
    public_key = "${file("~/.ssh/demo.pub")}"
}
