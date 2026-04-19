import json
import boto3
import os
import uuid
from datetime import datetime, timezone

s3 = boto3.client("s3")
BUCKET = os.environ["BUCKET_NAME"]

def handler(event, context):
    try:
        body = json.loads(event.get("body") or '{}')
        if not body :
                return {
                    "statusCode": 400,
                    "body": json.dumps({"error": "empty request body"})
                }
        payload = {
            "id": str(uuid.uuid4()),
            "timestamp":datetime.now(timezone.utc).isoformat(),
            "data": body
            }
        key = f"events/{payload["timestamp"][:10]}/{payload['id']}.json"
        s3.put_object(
            Bucket=BUCKET,
            Key=key,
            Body=json.dumps(payload),
            ContentType="aapplication/json"
        )
        return{
            "statusCode": 200,
            "body": json.dumps({"id": payload["id"], "key":key})
        }
    except Exception as e:
        return {
            "statusCode":500,
            "body": json.dumps({"error": str(e)})
        }