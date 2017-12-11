resource "aws_security_group" "demo" {
    name = "demo-sg"
    ingress {
        from_port = "22"
        to_port = "22"
        protocol = "tcp"
        cidr_blocks = ["Collection of approved IP Addresses"]
    }
}
