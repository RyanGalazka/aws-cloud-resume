import json
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('cloud-resume-view-counter')

def lambda_handler(event, context):
    response = table.get_item(Key={'id': '1'})
    views = response.get('Item', {}).get('views', 0) + 1
    print(views)
    table.put_item(Item={'id': '1', 'views': views})
    return views