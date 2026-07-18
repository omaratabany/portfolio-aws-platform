import json
import os
import time
import urllib.request
import urllib.error
import boto3
from datetime import datetime, timezone

dynamodb = boto3.resource("dynamodb")
sns = boto3.client("sns")
ssm = boto3.client("ssm")

TABLE = dynamodb.Table(os.environ["TABLE_NAME"])
TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]
SSM_PARAM_NAME = os.environ["SSM_PARAM_NAME"]

# Sort key "LATEST" is lexicographically greater than every ISO-8601
# timestamp string this function writes (they all start with a digit,
# "LATEST" starts with a letter) — that's what lets api.py cheaply
# separate "the current-status pointer row" from "history rows" with a
# plain string comparison, no extra index.
LATEST_SK = "LATEST"

# Fetched lazily, not at import time — an SSM call during module import
# would fire on every cold start whether or not a test is just importing
# this module, and makes mocking awkward. Cached per warm container: one
# SSM call per cold start, not one per invocation.
_targets_cache = None


def get_targets():
    global _targets_cache
    if _targets_cache is None:
        response = ssm.get_parameter(Name=SSM_PARAM_NAME, WithDecryption=True)
        _targets_cache = json.loads(response["Parameter"]["Value"])
    return _targets_cache


def check_target(url, timeout_s=8):
    start = time.monotonic()
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "status-checker/1.0"})
        with urllib.request.urlopen(req, timeout=timeout_s) as resp:
            latency_ms = int((time.monotonic() - start) * 1000)
            return resp.status < 500, resp.status, latency_ms
    except urllib.error.HTTPError as e:
        latency_ms = int((time.monotonic() - start) * 1000)
        return e.code < 500, e.code, latency_ms
    except Exception:
        latency_ms = int((time.monotonic() - start) * 1000)
        return False, 0, latency_ms


def get_previous_status(name):
    resp = TABLE.get_item(Key={"target": name, "sk": LATEST_SK})
    item = resp.get("Item")
    return item["is_up"] if item else None


def record_check(name, is_up, status_code, latency_ms, checked_at):
    item = {
        "is_up": is_up,
        "status_code": status_code,
        "latency_ms": latency_ms,
        "checked_at": checked_at,
    }
    # History row: one per check, keyed by timestamp.
    TABLE.put_item(Item={"target": name, "sk": checked_at, **item})
    # Pointer row: overwritten every check, so "current status" is a
    # single GetItem instead of a Query + sort on every page load.
    TABLE.put_item(Item={"target": name, "sk": LATEST_SK, **item})


def alert_on_change(name, previous_is_up, is_up, status_code, latency_ms, checked_at):
    if previous_is_up is None or previous_is_up == is_up:
        return
    state = "UP" if is_up else "DOWN"
    sns.publish(
        TopicArn=TOPIC_ARN,
        Subject=f"[status] {name} is {state}",
        Message=(
            f"{name} changed to {state} at {checked_at}\n"
            f"HTTP {status_code}, {latency_ms}ms"
        ),
    )


def handler(event, context):
    checked_at = datetime.now(timezone.utc).isoformat()
    results = []

    for target in get_targets():
        name, url = target["name"], target["url"]
        previous_is_up = get_previous_status(name)
        is_up, status_code, latency_ms = check_target(url)

        record_check(name, is_up, status_code, latency_ms, checked_at)
        alert_on_change(name, previous_is_up, is_up, status_code, latency_ms, checked_at)

        results.append({"target": name, "is_up": is_up, "status_code": status_code})

    return {"statusCode": 200, "body": json.dumps(results)}
