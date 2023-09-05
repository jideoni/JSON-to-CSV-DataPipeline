import json
import urllib.parse
import boto3
import logging
#from botocore.exceptions import ClientErro

print('Loading function') 
region = 'us-east-1'
#bucket_name = 'csv-bucket-3534r35d'
csv_bucket_name = 'bucket-for-converted-csv-objects'
csv_object_name = 'converted-csv-object'


recieved_object_name = ""
response = ""
s3 = boto3.client('s3')
s3_client = boto3.client('s3')

def lambda_handler(event, context):
    #print("Received event: " + json.dumps(event, indent=2))

    buildCSV = ""
    # Get the object from the event and show its content type
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'], encoding='utf-8')
    recieved_object_name = event['Records'][0]['s3']['object']['key']
    
    csv_object_name = "csv-object-of-" + recieved_object_name
    
    #print(csv_object_name)
    
    create_bucket(csv_bucket_name)
    #print(event['Records'][0]['s3']['object'])
    #print(event['Records'][0]['s3']['object']['key'])
    
    #print(type(recieved_object_name))
    
    try:
        response = s3.get_object(Bucket=bucket, Key=key)
        print("CONTENT TYPE: " + response['ContentType'])
        #print(response)
        #print(response['Body'])
        body = json.loads(response['Body'].read().decode("utf-8"))
        for v,k in body.items():
            buildCSV += str(v) + "," + str(k)
            buildCSV += "\n"
        #print(buildCSV)
        write_to_bucket(csv_bucket_name, buildCSV, csv_object_name)
        
        return response['ContentType']
        
    except Exception as e:
        print(e)
        print('Error getting object {} from bucket {}. Make sure they exist and your bucket is in the same region as this function.'.format(key, bucket))
        raise e
        
def create_bucket(bucket_name, region=None): 
    try:
        if region is None:
            s3_client = boto3.client('s3')
            s3_client.create_bucket(Bucket=bucket_name)
            
        else:
            s3_client = boto3.client('s3', region_name=region)
            location = {'LocationConstraint': region}
            s3_client.create_bucket(Bucket=bucket_name,
                                    CreateBucketConfiguration=location)
    
    except Exception as e:
        print(e)
        return False
    return True
    
def write_to_bucket(bucket_name, csv_body, csv_object_name_local):
    s3_client.put_object(
        Body = csv_body, 
        Bucket= bucket_name,
        Key= csv_object_name_local,
        ContentType='text/csv',
    ) 
