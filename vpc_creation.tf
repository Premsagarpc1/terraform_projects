provider "aws" {
  region     = "us-east-1"
  access_key = "abc"
  secret_key = "exampleabc"
}

#create vpc
resource "aws_vpc" "myfirst_vpc" {
  cidr_block = "10.0.0.0/16"
}

#create subnet
resource "aws_subnet" "myfirst_subnet" {
  vpc_id            = aws_vpc.myfirst_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

#create internet gateway
resource "aws_internet_gateway" "myinternet_gateway" {
  vpc_id = aws_vpc.myfirst_vpc.id
}

#create route table
resource "aws_route_table" "myroute_table" {
  vpc_id = aws_vpc.myfirst_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myinternet_gateway.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.myinternet_gateway.id
  }
}

#associate route table with subnet
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.myfirst_subnet.id
  route_table_id = aws_route_table.myroute_table.id
}

#create security group(port 22,80,443)
resource "aws_security_group" "allow_web" {
  name        = "allow_tls"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.myfirst_vpc.id

  ingress {
    description = "https"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#create neatwork interface with an ip in the subnet created in step 4

resource "aws_network_interface" "myNI" {
  subnet_id       = aws_subnet.myfirst_subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

}

#assign elastic IP to the network interface
#Please note that EIP depends on Internet gateway

resource "aws_eip" "myeip" {
  vpc                       = true
  network_interface         = aws_network_interface.myNI.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_instance.myfirst_instance, aws_internet_gateway.myinternet_gateway]
}

#create ubuntu server install/enable apache server

resource "aws_instance" "myfirst_instance" {
  ami               = "ami-0dfcb1ef8550277af"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "terraformkeypair"

  network_interface {
    network_interface_id = aws_network_interface.myNI.id
    device_index         = 0
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemct1 start apache2
              sudo bash -c "echo your very first web server > /var/www/html/index.html"
              EOF
  tags = {
    Name = "web-server"
  }
}
