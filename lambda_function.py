#Terraform deployed
import json
import urllib.parse
import boto3
import logging
import os
#from botocore.exceptions import ClientErro

print('Loading function') 
#region = os.environ['region']
csv_bucket_name = os.environ['csv_bucket_name']
csv_object_name = os.environ['csv_object_name']


response = ""
#s3 client
s3 = boto3.client('s3')
#sqs client
sqs = boto3.client('sqs')

def lambda_handler(event, context):
    #print("Received event: " + json.dumps(event, indent=2))
    buildCSV = ""
    # Get the object from the event and show its content type
    records = event['Records'][0]
    body_in_string = records.get('body')
    body_in_json = json.loads(body_in_string)
    s3_records = body_in_json['Records'][0]
    s3_details = s3_records.get('s3')
    
    #Retrieve bucket name
    #bucket = body_in_json['Records'][0]['s3']['bucket']['name']
    s3_bucket = s3_details.get('bucket')
    bucket = s3_bucket.get('name')
        
    #Retrieve object key
    #key = urllib.parse.unquote_plus(body_in_json['Records'][0]['s3']['object']['key'], encoding='utf-8')
    s3_object = s3_details.get('object')
    key = s3_object.get('key')

    csv_object_name = "csv-object-of-" + key
    
    try:
        response = s3.get_object(Bucket=bucket, Key=key)
        print("CONTENT TYPE: " + response['ContentType'])
        body = json.loads(response['Body'].read().decode("utf-8"))
        
        buildCSV = ",".join(body.keys())
        buildCSV += "\n"
        buildCSV += ",".join(body.values())

        write_to_bucket(csv_bucket_name, buildCSV, csv_object_name)
    except Exception as e:
        print(e)
        print('Error getting object {} from bucket {}. Make sure they exist and your bucket is in the same region as this function.'.format(key, bucket))
        raise e

def write_to_bucket(bucket_name, csv_body, csv_object_name_local):
    s3.put_object(
        Body = csv_body, 
        Bucket= bucket_name,
        Key= csv_object_name_local,
        ContentType='text/csv',
    )