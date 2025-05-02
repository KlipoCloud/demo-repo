# 2. Unassigned EBS volume
resource "aws_ebs_volume" "unassigned_volume" {
  availability_zone = "us-east-1a"
  size              = 10
  tags = {
    Name = "Unassigned-EBS"
  }
}



/*
resource "aws_volume_attachment" "web_ebs_attach" {
  device_name = "/dev/xvdf" # Mounting as a secondary disk
  volume_id   = aws_ebs_volume.unassigned_volume.id
  instance_id = aws_instance.web.id
}

*/

/*
# 3. Orphaned snapshot (not in use)
resource "aws_ebs_snapshot" "orphaned_snapshot" {
  volume_id = aws_ebs_volume.unassigned_volume.id
  tags = {
    Name = "Orphaned-Snapshot"
  }
}

*/
