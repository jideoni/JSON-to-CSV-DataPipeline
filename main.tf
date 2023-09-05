#data "aws_ami" "app_ami" {

#}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

#create an iam role for lambda
resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "archive_file" "lambda-function" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda_function_payload.zip"
}

#create S3 bucket for json objects
resource "aws_s3_bucket" "json-bucket" {
  bucket = "bucket-for-json-objects"
}

#create S3 bucket for csv objects
resource "aws_s3_bucket" "csv-objects" {
  bucket = "bucket-for-csv-objects"
}

#create lambda function
resource "aws_lambda_function" "test_lambda" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  filename      = "lambda_function_payload.zip"
  function_name = "CSV_to_JSON"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda_handler"

  source_code_hash = data.archive_file.lambda-function.output_base64sha256

  runtime = "python3.9"
}