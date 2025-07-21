variable "key_pair_name" {
  description = "key_pair_name"
  type        = string
}

resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main_vpc"
  }
}

resource "aws_subnet" "main_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/28"
  availability_zone       = "eu-west-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "main_subnet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "main_igw"
  }
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "main_route_table"
  }
}

resource "aws_route_table_association" "subnet_assoc" {
  subnet_id      = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_security_group" "instance_sg" {
  name        = "instance_sg"
  description = "Allow SSH and all internal traffic"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description     = "Allow all traffic from same SG"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    self            = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "instance_sg"
  }
}

resource "aws_placement_group" "main_pg" {
  name     = "main_placement_group"
  strategy = "cluster"
}

locals {
    instance_names = ["instance_1", "instance_2"]
}

// ami-0fbb72557598f5284 (64-bit (x86)) / ami-0393eeb161ec86a1a (64-bit (Arm))
resource "aws_instance" "instances" {
    count                       = length(local.instance_names)
    ami                         = "ami-0fbb72557598f5284"
    instance_type               = "c6in.8xlarge"
    subnet_id                   = aws_subnet.main_subnet.id
    vpc_security_group_ids      = [aws_security_group.instance_sg.id]
    associate_public_ip_address = true
    key_name                    = var.key_pair_name
    placement_group             = aws_placement_group.main_pg.name

    root_block_device {
        volume_size = 50
        volume_type = "gp2"
    }

    tags = {
        Name = local.instance_names[count.index]
    }
}

output "instance_public_ips" {
    value = {
        for idx, instance in aws_instance.instances :
        local.instance_names[idx] => instance.public_ip
    }
}

output "instance_private_ips" {
    value = {
        for idx, instance in aws_instance.instances :
        local.instance_names[idx] => instance.private_ip
    }
}

resource "local_file" "ansible_hosts" {
    content = <<EOT
[instance_1]
${aws_instance.instances[0].public_ip}
[instance_2]
${aws_instance.instances[1].public_ip}
EOT
    filename = "${path.module}/hosts.ini"
}

resource "local_file" "ansible_vars" {
    content = <<EOT
instance_1_private_ip: ${aws_instance.instances[0].private_ip}
instance_2_private_ip: ${aws_instance.instances[1].private_ip}
EOT
    filename = "${path.module}/vars.yaml"
}
