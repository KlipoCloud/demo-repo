provider "aws" {
  region = "us-east-1"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow HTTP and SSH traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
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

resource "aws_instance" "web2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.web_sg.id]

  root_block_device {
    volume_type = "gp2"
    volume_size = 20
  }
}

# 1. Unassigned Elastic IP (EIP)
resource "aws_eip" "unassigned_eip" {
  tags = {
    Name = "Unassigned-EIP"
  }
}

resource "aws_eip_association" "web_eip_assoc" {
  instance_id   = aws_instance.web.id
  allocation_id = aws_eip.unassigned_eip.id
}

# 2. Unassigned EBS volume
resource "aws_ebs_volume" "unassigned_volume" {
  availability_zone = "us-east-1a"
  size             = 10
  tags = {
    Name = "Unassigned-EBS"
  }
}

#resource "aws_volume_attachment" "web_ebs_attach" {
#  device_name = "/dev/xvdf"  # Mounting as a secondary disk
#  volume_id   = aws_ebs_volume.unassigned_volume.id
#  instance_id = aws_instance.web.id
#}

# 3. Orphaned snapshot (not in use)
resource "aws_ebs_snapshot" "orphaned_snapshot" {
  volume_id = aws_ebs_volume.unassigned_volume.id
  tags = {
    Name = "Orphaned-Snapshot"
  }
}
