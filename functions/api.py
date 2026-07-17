import json
import os
import boto3
from decimal import Decimal
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource("dynamodb")
TABLE = dynamodb.Table(os.environ["TABLE_NAME"])
TARGETS = json.loads(os.environ["TARGETS"])

LATEST_SK = "LATEST"
HEADERS = {"Content-Type": "application/json"}


def _json_default(o):
    if isinstance(o, Decimal):
        return int(o) if o % 1 == 0 else float(o)
    raise TypeError(f"not JSON serializable: {o!r}")


def get_status():
    items = []
    for target in TARGETS:
        resp = TABLE.get_item(Key={"target": target["name"], "sk": LATEST_SK})
        item = resp.get("Item")
        if item:
            items.append(item)
    return items


def get_history(target_name, limit=50):
    resp = TABLE.query(
        KeyConditionExpression=Key("target").eq(target_name) & Key("sk").lt(LATEST_SK),
        ScanIndexForward=False,  # newest first
        Limit=limit,
    )
    return resp.get("Items", [])


def handler(event, context):
    route = event.get("routeKey", "")

    try:
        if route == "GET /status":
            body = get_status()
        elif route == "GET /history/{target}":
            target_name = event["pathParameters"]["target"]
            body = get_history(target_name)
        else:
            return {"statusCode": 404, "headers": HEADERS, "body": json.dumps({"error": "not found"})}

        return {"statusCode": 200, "headers": HEADERS, "body": json.dumps(body, default=_json_default)}
    except Exception as e:
        return {"statusCode": 500, "headers": HEADERS, "body": json.dumps({"error": str(e)})}
