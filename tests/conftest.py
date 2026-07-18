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
os.environ.setdefault("SSM_PARAM_NAME", "/test-project/test/status-monitor/targets")

import pytest  # noqa: E402


@pytest.fixture(autouse=True)
def _reset_targets_cache():
    """checker.py and api.py cache the SSM-fetched target list at module
    scope (deliberately — one SSM call per warm container, not per
    invocation). That cache would otherwise leak between tests depending
    on import/execution order."""
    import checker
    import api

    checker._targets_cache = None
    api._targets_cache = None
    yield
    checker._targets_cache = None
    api._targets_cache = None
