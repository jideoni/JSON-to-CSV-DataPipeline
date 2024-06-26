##########################################################################################
########################################   S3  ###########################################
##########################################################################################
#create JSON bucket
resource "aws_s3_bucket" "json-bucket" {
  bucket = var.json_bucket_name
}

#create S3 bucket for csv objects
resource "aws_s3_bucket" "csv-bucket" {
  bucket = var.csv_bucket_name
}

#JSON bucket bucket-policy
data "aws_iam_policy_document" "lambda_s3_get_permissions" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListAllMyBuckets",
    ]
    resources = ["${aws_s3_bucket.json-bucket.arn}/*"]
  }
}

resource "aws_iam_policy" "lambda_s3_permissions_to_get_from_s3" {
  name        = "lambda_s3_get_permissions"
  path        = "/"
  description = "IAM policy for get from s3"
  policy      = data.aws_iam_policy_document.lambda_s3_get_permissions.json
}

resource "aws_iam_role_policy_attachment" "lambda_s3_get" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_s3_permissions_to_get_from_s3.arn
}

#CSV bucket bucket-policy
data "aws_iam_policy_document" "lambda_s3_put_permissions_document" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:ListAllMyBuckets",
    ]
    resources = ["${aws_s3_bucket.csv-bucket.arn}/*"]
  }
}

resource "aws_iam_policy" "lambda_s3_put_permissions" {
  name        = "lambda_s3_put_permissions"
  path        = "/"
  description = "IAM policy for put to s3"
  policy      = data.aws_iam_policy_document.lambda_s3_put_permissions_document.json
}

resource "aws_iam_role_policy_attachment" "lambda_s3" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_s3_put_permissions.arn
}

data "aws_iam_policy_document" "allow_access_from_lambda_fn_document" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:*",
    ]

    resources = [
      aws_s3_bucket.json-bucket.arn,
      "${aws_s3_bucket.json-bucket.arn}/*",
    ]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_lambda_function.csv_to_json_lambda.arn]
    }
  }
}

#SNS permissions for CSV bucket
data "aws_iam_policy_document" "allow_S3_to_publish" {
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

resource "aws_s3_bucket_policy" "allow_access_from_lambda_fn" {
  bucket = aws_s3_bucket.json-bucket.id
  policy = data.aws_iam_policy_document.allow_access_from_lambda_fn_document.json
}

#create JSON bucket notification resource to send message to Queue
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.json-bucket.id

  queue {
    queue_arn     = aws_sqs_queue.JSON_event_queue.arn
    events        = ["s3:ObjectCreated:*"]
    #filter_suffix = ".json"
  }
}

#create CSV bucket notification
resource "aws_s3_bucket_notification" "csv_bucket_trigger_sns" {
  #bucket = aws_s3_bucket.csv-bucket.id
  bucket = var.csv_bucket_name

  topic {
    topic_arn     = aws_sns_topic.conversion_complete_topic.arn
    events        = ["s3:ObjectCreated:*"]
    #filter_suffix = ".csv"
  }
}

##########################################################################################
####################################   CLOUDWATCH  #######################################
##########################################################################################
#cloudwatch group creation
resource "aws_cloudwatch_log_group" "json-csv-log-group" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = 90
}

##########################################################################################
####################################   LAMBDA ############################################
##########################################################################################
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

#SQS permissions for lambda
data "aws_iam_policy_document" "allow_lambda_to_receiveSQSMessage" {
  statement {
    effect    = "Allow"
    actions   = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]
    resources = [aws_sqs_queue.JSON_event_queue.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_lambda_function.csv_to_json_lambda.arn]
    }
  }
}

resource "aws_iam_policy" "lambda_SQS_recieve" {
  name        = "lambda_SQS_recieve_name"
  path        = "/"
  description = "IAM policy for logging from a lambda"
  policy      = data.aws_iam_policy_document.allow_lambda_to_receiveSQSMessage.json
}

resource "aws_iam_role_policy_attachment" "lambda_SQS" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_SQS_recieve.arn
}

#CloudWatch permissions for lambda
data "aws_iam_policy_document" "lambda_logging" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.json-csv-log-group.arn}:*"]
  }
  statement {
    effect = "Allow"

    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]

    resources = [aws_sqs_queue.JSON_event_queue.arn]
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

#Lambda archive (code file) definition
data "archive_file" "lambda-function" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda_function_payload.zip"
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

#create event source mapping
resource "aws_lambda_event_source_mapping" "from_sqs" {
  event_source_arn = aws_sqs_queue.JSON_event_queue.arn
  function_name    = aws_lambda_function.csv_to_json_lambda.arn
}

#create lambda SQS invokation
resource "aws_lambda_permission" "allow_sqs" {
  statement_id  = "AllowExecutionFromJSON-SQS-Queue"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.csv_to_json_lambda.arn
  principal     = "sqs.amazonaws.com"
  source_arn    = aws_sqs_queue.JSON_event_queue.arn
}

##########################################################################################
#####################################   SNS   ############################################
##########################################################################################
resource "aws_sns_topic_policy" "attach_allow_s3_policy" {
  arn = aws_sns_topic.conversion_complete_topic.arn
  policy = data.aws_iam_policy_document.allow_S3_to_publish.json
}

#create sns topic for csv conversion complete
resource "aws_sns_topic" "conversion_complete_topic" {
  name   = var.sns_topic_name
  display_name = "CSV-File-Ready-TF"
}

#create subscription for email
resource "aws_sns_topic_subscription" "email_target" {
  #topic_arn = "arn:aws:sns:us-east-1:380255901104:aws_sns_topic.conversion_complete_topic.name"
  topic_arn = aws_sns_topic.conversion_complete_topic.arn 
  protocol  = "email"
  endpoint  = var.your_email
}

##########################################################################################
#####################################   SQS   ############################################
##########################################################################################
#Queue access policy document
data "aws_iam_policy_document" "sqs_allow_message_from_JSON_bucket" {
  statement {
    sid    = "Allow S3 to send events"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions   = ["SQS:SendMessage"]
    resources = [aws_sqs_queue.JSON_event_queue.arn]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.json-bucket.arn]
    }
  }
  statement {
    sid    = "Allow Lambda to recieve events"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions   = ["SQS:ReceiveMessage"]
    resources = [aws_sqs_queue.JSON_event_queue.arn]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_lambda_function.csv_to_json_lambda.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "policy_of_sqs_allow_message_from_JSON_bucket" {
  queue_url = aws_sqs_queue.JSON_event_queue.id
  policy    = data.aws_iam_policy_document.sqs_allow_message_from_JSON_bucket.json
}

#SQS queue creation
resource "aws_sqs_queue" "JSON_event_queue" {
  name                      = var.JSON_event_queue_name
  delay_seconds             = 0
  max_message_size          = 256000
  message_retention_seconds = 300
  receive_wait_time_seconds = 2
  sqs_managed_sse_enabled    = false
} 