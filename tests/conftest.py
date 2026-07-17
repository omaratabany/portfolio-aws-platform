import os
import sys
import pathlib

FUNCTIONS_DIR = pathlib.Path(__file__).resolve().parent.parent / "functions"
sys.path.insert(0, str(FUNCTIONS_DIR))

# checker.py / api.py read these at import time — set before anything
# under test gets imported, and before boto3 constructs any resource.
# AWS_DEFAULT_REGION is normally injected automatically by the Lambda
# runtime (AWS_REGION); it has to be set explicitly for local test runs.
os.environ.setdefault("AWS_DEFAULT_REGION", "eu-central-1")
os.environ.setdefault("BUCKET_NAME", "test-bucket")
os.environ.setdefault("TABLE_NAME", "test-uptime-checks")
os.environ.setdefault("SNS_TOPIC_ARN", "arn:aws:sns:eu-central-1:000000000000:test-topic")
os.environ.setdefault("TARGETS", '[{"name": "example", "url": "https://example.com"}]')
