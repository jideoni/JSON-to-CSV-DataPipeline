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

data "aws_iam_policy_document" "lambda_logging" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "s3:GetObject",
      "s3:PutObject",
      "s3:CreateBucket",
      "s3:*",
      " s3-object-lambda:*",
    ]

    resources = ["arn:aws:logs:*:*:*"]
  }
}

data "aws_iam_policy_document" "json_bucket_topic" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions   = ["SNS:Publish"]
    resources = ["arn:aws:sns:us-east-1:380255901104:JSON_to_CSV_conversion_complete"]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.csv-bucket.arn]
    }
  }
}



resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"
  policy      = data.aws_iam_policy_document.lambda_logging.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
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
  bucket = "bucket-for-json-objects-uploads"
}

#create S3 bucket for csv objects
resource "aws_s3_bucket" "csv-bucket" {
  bucket = "bucket-for-converted-csv-objects"
}

#create lambda function
resource "aws_lambda_function" "csv_to_json_lambda" {
  filename      = "lambda_function_payload.zip"
  function_name = var.lambda_function_name
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda_function.lambda_handler"

  source_code_hash = data.archive_file.lambda-function.output_base64sha256

  runtime = "python3.9"

  timeout = 3

  #depends_on = [
    #aws_iam_role_policy_attachment.lambda_logs,
    #aws_cloudwatch_log_group.CSV_to_JSON-function-log-group,
  #]
}

#create lambda permission resource
resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromJSON-S3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.csv_to_json_lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.json-bucket.arn
}

#create S3 bucket notification resource to trigger lambda function
resource "aws_s3_bucket_notification" "json_bucket_trigger_lambda" {
  bucket = aws_s3_bucket.json-bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.csv_to_json_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    #filter_prefix       = "AWSLogs/"
    filter_suffix       = ".json"
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}

#create sns topic for csv conversion complete
resource "aws_sns_topic" "conversion_complete_topic" {
  name   = "JSON_to_CSV_conversion_complete"
  policy = data.aws_iam_policy_document.json_bucket_topic.json
}

#create sns trigger for csv bucket
resource "aws_s3_bucket_notification" "csv_bucket_trigger_sns" {
  bucket = aws_s3_bucket.csv-bucket.id

  topic {
    topic_arn     = aws_sns_topic.conversion_complete_topic.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".csv"
  }
}

#create subscription for email
resource "aws_sns_topic_subscription" "email_target" {
  topic_arn = "arn:aws:sns:us-east-1:380255901104:JSON_to_CSV_conversion_complete" 
  protocol  = "email"
  endpoint  = "onibabajide34@gmail.com"
}