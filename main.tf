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

resource "aws_cloudwatch_log_group" "CSV_to_JSON-function-log-group" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = 30
}

data "aws_iam_policy_document" "lambda_logging" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [aws_lambda_function.csv_to_json_lambda.arn]
  }
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"
  policy      = data.aws_iam_policy_document.lambda_logging.json
}

#create an iam role for lambda
resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

data "archive_file" "lambda-function" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda_function_payload.zip"
}

#create S3 bucket for json objects
resource "aws_s3_bucket" "json-bucket" {
  bucket = "bucket-for-json-objects-uploads"
}

#create S3 bucket for csv objects
resource "aws_s3_bucket" "csv-objects" {
  bucket = "bucket-for-csv-objects"
}

#create lambda function
resource "aws_lambda_function" "csv_to_json_lambda" {
  filename      = "lambda_function_payload.zip"
  function_name = "var.lambda_function_name"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda_handler"

  source_code_hash = data.archive_file.lambda-function.output_base64sha256

  runtime = "python3.9"

  timeout = 3

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.example,
  ]
}