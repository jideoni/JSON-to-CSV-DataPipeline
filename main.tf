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
    ]

    #resources = ["arn:aws:logs:us-east-1:*:*"]
    resources = ["arn:aws:logs:us-east-1:380255901104:/aws/lambda/var.lambda_function_name*"]
  }
}

data "aws_iam_policy_document" "lambda_s3_permissions" {
  statement {
    effect = "Allow"

      actions = [
        "s3:PutObject",
        "s3-object-lambda:*",
      ]

      #resources = ["arn:aws:s3:::var.csv_bucket_name/*"]
      resources = ["arn:aws:s3:::var.csv_bucket_name/*"] 
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
    resources = [aws_sns_topic.conversion_complete_topic.arn]

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

resource "aws_iam_policy" "lambda_s3_permissions" {
  name        = "lambda_s3_permissions"
  path        = "/"
  description = "IAM policy for logging from a lambda"
  policy      = data.aws_iam_policy_document.lambda_s3_permissions.json
}

resource "aws_iam_role_policy_attachment" "lambda_s3" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_s3_permissions.arn
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
  bucket = var.json_bucket_name
}

#create S3 bucket for csv objects
resource "aws_s3_bucket" "csv-bucket" {
  bucket = var.csv_bucket_name
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
  environment {
    variables = {
      csv_bucket_name = var.csv_bucket_name,
      csv_object_name = var.csv_object_name
    }
  }
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

  #lambda_function {
    #lambda_function_arn = aws_lambda_function.csv_to_json_lambda.arn
    #events              = ["s3:ObjectCreated:*"]
    #filter_suffix       = ".json"
  #}

  depends_on = [aws_lambda_permission.allow_bucket]
}

#create sns topic for csv conversion complete
resource "aws_sns_topic" "conversion_complete_topic" {
  name   = var.sns_topic_name
  display_name = "CSV-File-Ready-TF"
  policy = data.aws_iam_policy_document.json_bucket_topic.json
}

#create sns trigger for csv bucket
resource "aws_s3_bucket_notification" "csv_bucket_trigger_sns" {
  bucket = aws_s3_bucket.csv-bucket.id

  topic {
    topic_arn     = aws_sns_topic.conversion_complete_topic.arn
    events        = ["s3:ObjectCreated:*"]
    #filter_suffix = ".csv"
  }
}

#create subscription for email
#resource "aws_sns_topic_subscription" "email_target" {
  #topic_arn = "arn:aws:sns:us-east-1:380255901104:aws_sns_topic.conversion_complete_topic.name" 
  #protocol  = "email"
  #endpoint  = "onibabajide34@gmail.com"
#}

resource "aws_sqs_queue" "JSON_event_queue" {
  name                      = var.JSON_event_queue_name
  delay_seconds             = 1
  max_message_size          = 1024
  message_retention_seconds = 300
  receive_wait_time_seconds = 2
}

data "aws_iam_policy_document" "sqs_allow_message_from_JSON_bucket" {
  statement {
    sid    = "Allow S3 to send events"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.JSON_event_queue.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.json-bucket.arn]
    }
  }
  
}

resource "aws_sqs_queue_policy" "policy_of_sqs_allow_message_from_JSON_bucket" {
  queue_url = aws_sqs_queue.JSON_event_queue.id
  policy    = data.aws_iam_policy_document.sqs_allow_message_from_JSON_bucket.json
}