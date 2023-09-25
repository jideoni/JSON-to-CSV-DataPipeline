#Terraform deployed
import json
import urllib.parse
import boto3
import logging
import os
#from botocore.exceptions import ClientErro

print('Loading function') 
region = 'us-east-1'
#bucket_name = 'csv-bucket-3534r35d'
csv_bucket_name = 'bucket-for-converted-csv-objects'
csv_object_name = 'converted-csv-object'

region = os.environ['region']
csv_bucket_name = os.environ['csv_bucket_name']
csv_object_name = os.environ['csv_object_name']


response = ""
s3 = boto3.client('s3')
s3_client = boto3.client('s3')
#sqs client
sqs = boto3.client('sqs')

def lambda_handler(event, context):
    #print("Received event: " + json.dumps(event, indent=2))

    buildCSV = ""
    # Get the object from the event and show its content type
    for j in event.values():
        for x in j:
            #print(x)
            for a,b in x.items():
                if a == 'body':
                    body_in_string = b
    body_in_json = json.loads(body_in_string)
    
    #bucket = body_in_json['Records'][0]['s3']['bucket']['name']
    for j in body_in_json.values():
        for x in j:
            #print(x)
            for a,b in x.items():
                if a == 's3':
                    for c,d in b.items():
                        if c == 'bucket':
                            for e,f in d.items():
                                if e == 'name':
                                    bucket = f
                                    
    #key = urllib.parse.unquote_plus(body_in_json['Records'][0]['s3']['object']['key'], encoding='utf-8')
    for j in body_in_json.values():
        for x in j:
            #print(x)
            for a,b in x.items():
                if a == 's3':
                    for c,d in b.items():
                        if c == 'object':
                            for e,f in d.items():
                                if e == 'key':
                                    key = f
                                    
    csv_object_name = "csv-object-of-" + key
    
    try:
        response = s3.get_object(Bucket=bucket, Key=key)
        body = json.loads(response['Body'].read().decode("utf-8"))
        for v,k in body.items():
            buildCSV += str(v) + "," + str(k)
            buildCSV += "\n"
        print(buildCSV)
        write_to_bucket(csv_bucket_name, buildCSV, csv_object_name)
        #return response['ContentType']
    except Exception as e:
        print(e)
        print('Error getting object {} from bucket {}. Make sure they exist and your bucket is in the same region as this function.'.format(key, bucket))
        raise e

def write_to_bucket(bucket_name, csv_body, csv_object_name_local):
    s3_client.put_object(
        Body = csv_body, 
        Bucket= bucket_name,
        Key= csv_object_name_local,
        ContentType='text/csv',
    )