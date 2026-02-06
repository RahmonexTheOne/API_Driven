import boto3
import json
import os

def lambda_handler(event, context):
    # LocalStack nous donne son adresse interne
    ls_host = os.environ.get("LOCALSTACK_HOSTNAME", "localhost")
    endpoint_url = f"http://{ls_host}:4566"
    
    # On configure Boto3 pour utiliser cette adresse interne
    ec2 = boto3.client('ec2', region_name='us-east-1', endpoint_url=endpoint_url)

    try:
        body = json.loads(event.get('body', '{}'))
        instance_id = body.get('instance_id')
        action = body.get('action')

        if not instance_id or not action:
            return {"statusCode": 400, "body": json.dumps("Missing parameters")}

        msg = ""
        if action == "start":
            ec2.start_instances(InstanceIds=[instance_id])
            msg = f"Instance {instance_id} starting..."
        elif action == "stop":
            ec2.stop_instances(InstanceIds=[instance_id])
            msg = f"Instance {instance_id} stopping..."
        else:
            return {"statusCode": 400, "body": json.dumps("Invalid action")}

        return {
            "statusCode": 200,
            "body": json.dumps({"message": msg, "status": "success"})
        }

    except Exception as e:
        return {"statusCode": 500, "body": json.dumps(str(e))}