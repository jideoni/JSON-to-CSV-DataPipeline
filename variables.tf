variable "lambda_function_name" {
  default = "CSV_to_JSON"
}

variable "json_bucket_name" {
  description = "The name of the JSON S3 bucket"
  default = "bucket-for-json-objects-uploads"
}

variable "csv_bucket_name" {
  description = "The name of the CSV S3 bucket"
  default = "bucket-for-converted-csv-objects"
}

variable "sns_topic_name" {
  description = "The name of the SNS topic for publishing notification from CSV S3 bucket"
  default = "JSON_to_CSV_conversion_complete"
}