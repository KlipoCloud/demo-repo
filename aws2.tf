# 1. Unassigned Elastic IP (EIP)
resource "aws_eip" "unassigned_eip" {
  tags = {
    Name = "Unassigned-EIP"
  }
}


/*
resource "aws_eip_association" "web_eip_assoc" {
  instance_id   = aws_instance.web.id
  allocation_id = aws_eip.unassigned_eip.id
}

*/
