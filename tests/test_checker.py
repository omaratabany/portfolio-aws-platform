import json
from unittest.mock import MagicMock, patch

import checker


def _mock_ssm_targets(targets):
    checker.ssm.get_parameter = MagicMock(
        return_value={"Parameter": {"Value": json.dumps(targets)}}
    )


def test_get_targets_fetches_from_ssm_once_and_caches():
    _mock_ssm_targets([{"name": "example", "url": "https://example.com"}])

    first = checker.get_targets()
    second = checker.get_targets()

    assert first == [{"name": "example", "url": "https://example.com"}]
    assert second is first
    checker.ssm.get_parameter.assert_called_once_with(Name=checker.SSM_PARAM_NAME)


def test_check_target_success():
    fake_resp = MagicMock()
    fake_resp.status = 200
    fake_resp.__enter__ = lambda self: fake_resp
    fake_resp.__exit__ = lambda self, *a: False

    with patch("checker.urllib.request.urlopen", return_value=fake_resp):
        is_up, status_code, latency_ms = checker.check_target("https://example.com")

    assert is_up is True
    assert status_code == 200
    assert latency_ms >= 0


def test_check_target_connection_failure_counts_as_down():
    with patch("checker.urllib.request.urlopen", side_effect=OSError("network unreachable")):
        is_up, status_code, latency_ms = checker.check_target("https://example.com")

    assert is_up is False
    assert status_code == 0


def test_get_previous_status_returns_none_when_no_row_exists():
    checker.TABLE.get_item = MagicMock(return_value={})
    assert checker.get_previous_status("site") is None


def test_get_previous_status_returns_stored_value():
    checker.TABLE.get_item = MagicMock(return_value={"Item": {"is_up": False}})
    assert checker.get_previous_status("site") is False


def test_record_check_writes_a_history_row_and_a_latest_row():
    checker.TABLE.put_item = MagicMock()

    checker.record_check("site", True, 200, 42, "2026-07-17T12:00:00+00:00")

    assert checker.TABLE.put_item.call_count == 2
    history_call, latest_call = checker.TABLE.put_item.call_args_list
    assert history_call.kwargs["Item"]["sk"] == "2026-07-17T12:00:00+00:00"
    assert latest_call.kwargs["Item"]["sk"] == checker.LATEST_SK
    assert latest_call.kwargs["Item"]["is_up"] is True


def test_alert_skipped_on_first_ever_check():
    checker.sns.publish = MagicMock()
    checker.alert_on_change("site", None, True, 200, 50, "t")
    checker.sns.publish.assert_not_called()


def test_alert_skipped_when_status_unchanged():
    checker.sns.publish = MagicMock()
    checker.alert_on_change("site", True, True, 200, 50, "t")
    checker.sns.publish.assert_not_called()


def test_alert_fires_on_status_flip():
    checker.sns.publish = MagicMock()
    checker.alert_on_change("site", True, False, 500, 50, "t")

    checker.sns.publish.assert_called_once()
    assert "DOWN" in checker.sns.publish.call_args.kwargs["Subject"]


def test_handler_checks_every_target_from_ssm():
    _mock_ssm_targets([{"name": "example", "url": "https://example.com"}])
    checker.TABLE.get_item = MagicMock(return_value={})
    checker.TABLE.put_item = MagicMock()
    checker.sns.publish = MagicMock()

    fake_resp = MagicMock()
    fake_resp.status = 200
    fake_resp.__enter__ = lambda self: fake_resp
    fake_resp.__exit__ = lambda self, *a: False

    with patch("checker.urllib.request.urlopen", return_value=fake_resp):
        resp = checker.handler({}, None)

    assert resp["statusCode"] == 200
    body = json.loads(resp["body"])
    assert body == [{"target": "example", "is_up": True, "status_code": 200}]
    checker.sns.publish.assert_not_called()  # no previous status, no flip
