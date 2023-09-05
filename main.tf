#data "aws_ami" "app_ami" {
  
#}

resource "aws_s3_bucket" "json-bucket" {
  bucket = "bucket-for-json-objects"
}

resource "aws_s3_bucket" "csv-objects" {
  bucket = "bucket-for-csv-objects"
}
