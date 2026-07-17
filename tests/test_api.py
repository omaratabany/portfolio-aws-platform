import json
from decimal import Decimal
from unittest.mock import MagicMock

import api


def test_get_status_skips_targets_with_no_data():
    api.TABLE.get_item = MagicMock(return_value={})
    assert api.get_status() == []


def test_get_status_returns_latest_row_per_target():
    api.TABLE.get_item = MagicMock(
        return_value={"Item": {"target": "example", "sk": "LATEST", "is_up": True}}
    )
    result = api.get_status()
    assert len(result) == 1
    assert result[0]["is_up"] is True


def test_get_history_queries_below_latest_sort_key():
    api.TABLE.query = MagicMock(return_value={"Items": [{"sk": "2026-07-17T12:00:00+00:00"}]})
    result = api.get_history("example")

    assert result == [{"sk": "2026-07-17T12:00:00+00:00"}]
    api.TABLE.query.assert_called_once()
    assert "KeyConditionExpression" in api.TABLE.query.call_args.kwargs


def test_handler_status_route():
    api.TABLE.get_item = MagicMock(
        return_value={"Item": {"target": "example", "sk": "LATEST", "is_up": True}}
    )
    resp = api.handler({"routeKey": "GET /status"}, None)

    assert resp["statusCode"] == 200
    assert json.loads(resp["body"])[0]["is_up"] is True


def test_handler_history_route():
    api.TABLE.query = MagicMock(return_value={"Items": []})
    event = {"routeKey": "GET /history/{target}", "pathParameters": {"target": "example"}}

    resp = api.handler(event, None)
    assert resp["statusCode"] == 200


def test_handler_unknown_route_returns_404():
    resp = api.handler({"routeKey": "GET /nope"}, None)
    assert resp["statusCode"] == 404


def test_decimal_default_converts_whole_and_fractional_values():
    assert api._json_default(Decimal("42")) == 42
    assert api._json_default(Decimal("42.5")) == 42.5
