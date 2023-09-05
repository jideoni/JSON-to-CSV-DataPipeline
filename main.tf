#data "aws_ami" "app_ami" {
#  most_recent = true

#  filter {
#    name   = "name"
#    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
#  }

#  filter {
#    name   = "virtualization-type"
#    values = ["hvm"]
#  }
#
#  owners = ["979382823631"] # Bitnami
#}

resource "aws_s3_bucket" "bucket containing json objects" {
  bucket = "bucket-for-json-objects"
  acl = "private"
}
