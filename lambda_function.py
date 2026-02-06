import boto3
import json

def lambda_handler(event, context):
    # On pointe explicitement vers LocalStack interne
    ec2 = boto3.client('ec2', region_name='us-east-1', endpoint_url='http://localstack:4566')

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