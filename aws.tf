provider "aws" {
  region = "us-east-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

variable "access_key" {
  description = "Access Key for AWS."
  type = string
}

variable "secret_key" {
  description = "Secret Key for AWS."
  type = string
}

variable "key_pair" {
  description = "Exact name of key pair for EC2 Instance."
  type = string
}

# AWS VPC
resource "aws_vpc" "pVpc" { 
  cidr_block = "10.0.0.0/16"
  
  tags = {
    "Name" = "ProjVPC"
  }
} 

# AWS Internet Gateway
resource "aws_internet_gateway" "pGW" {
  vpc_id = aws_vpc.pVpc.id

  tags = {
    "Name" = "projGW"
  }
}

# AWS Route Table
resource "aws_route_table" "pRT" {
  vpc_id = aws_vpc.pVpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.pGW.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id             = aws_internet_gateway.pGW.id
  }

  tags = {
    Name = "projRT"
  }
}

# AWS Subnet
resource "aws_subnet" "pSbnt" {
  vpc_id = aws_vpc.pVpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    "Name" = "ProdSBNT"
  }
}

# Link Subnet with Route Table
resource "aws_route_table_association" "pRTA" {
  subnet_id      = aws_subnet.pSbnt.id
  route_table_id = aws_route_table.pRT.id
}

# AWS Security Group
resource "aws_security_group" "pSG" {
  name        = "allow_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.pVpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80  
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
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

  tags = {
    Name = "allow_web"
  }
}

# AWS Network Interface
resource "aws_network_interface" "pNIC" {
  subnet_id       = aws_subnet.pSbnt.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.pSG.id]

}

# AWS Elastic IP
resource "aws_eip" "pEIP" {
  vpc                       = true
  network_interface         = aws_network_interface.pNIC.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.pGW]
}

output "public_ip" {
  value = aws_eip.pEIP.public_ip
}

# AWS EC2 Instance using Ubuntu 20.04
resource "aws_instance" "pInst" {
  ami           = "ami-0885b1f6bd170450c"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"  # Must be same as AZ in Subnet
  key_name = var.key_pair
  
  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.pNIC.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              EOF    

  tags = {
    Name = "Terraform"
  }
}

output "server_ip" {
  value = aws_instance.pInst.private_ip
}

output "server_id" {
  value = aws_instance.pInst.id
}