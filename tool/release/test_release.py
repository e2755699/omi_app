"""發布工具的隔離測試（假的 API，不連 Apple／GitHub）。

  python -m unittest discover -s tool/release -p "test_*.py"
"""

import io
import json
import sys
import unittest
import urllib.error
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).parent))

import asc  # noqa: E402
import report  # noqa: E402

APP, GROUP, BUILD = "app1", "group1", "build1"


class FakeClient:
    """每次查 /v1/builds 就往下一個狀態走（停在最後一個）。"""

    def __init__(self, states, auto_distribute=False, assign_error=None):
        self.states = list(states)
        self.index = -1
        self.members = set()
        self.posts = []
        self.auto_distribute = auto_distribute
        self.assign_error = assign_error

    @property
    def state(self):
        return self.states[max(self.index, 0)]

    def get_all(self, path, params=None):
        if path == "/v1/builds":
            self.index = min(self.index + 1, len(self.states) - 1)
            if isinstance(self.state, Exception):
                raise self.state
            if self.state.get("processing") is None:
                return []
            if self.auto_distribute and self.state.get("internal") == "IN_BETA_TESTING":
                self.members.add(BUILD)
            return [{"id": BUILD, "attributes": {"version": "7", "processingState": self.state["processing"],
                                                 "expired": self.state.get("expired", False)}}]
        if path == f"/v1/betaGroups/{GROUP}/builds":
            return [{"id": m} for m in self.members]
        raise AssertionError(path)

    def get(self, path, params=None):
        assert path == f"/v1/builds/{BUILD}/buildBetaDetail", path
        return {"data": {"attributes": {"internalBuildState": self.state.get("internal")}}}

    def post(self, path, body):
        self.posts.append(path)
        if self.assign_error:
            raise self.assign_error
        self.members.add(body["data"][0]["id"])
        # Apple 加進內部群組後狀態變成 IN_BETA_TESTING
        for state in self.states[self.index:]:
            if isinstance(state, dict) and state.get("internal") == "READY_FOR_BETA_TESTING":
                state["internal"] = "IN_BETA_TESTING"
        return {}


class Clock:
    def __init__(self):
        self.now = 0.0
        self.sleeps = []

    def __call__(self):
        return self.now

    def sleep(self, seconds):
        self.sleeps.append(seconds)
        self.now += seconds


def run(client, deadline=90 * 60, find_deadline=30 * 60):
    clock = Clock()
    result = asc.wait_for_ready(client, APP, GROUP, "1.0.0", "7", deadline_s=deadline,
                                find_deadline_s=find_deadline, clock=clock, sleep=clock.sleep)
    return result, clock


NOT_FOUND = {"processing": None}
PROCESSING = {"processing": "PROCESSING"}


class WaitForReadyTest(unittest.TestCase):
    def test_ready_after_processing_and_single_group_assignment(self):
        client = FakeClient([NOT_FOUND, PROCESSING, {"processing": "VALID", "internal": "READY_FOR_BETA_TESTING"}])
        result, _ = run(client)
        self.assertEqual(result.status, "ready")
        self.assertEqual(client.posts, [f"/v1/betaGroups/{GROUP}/relationships/builds"])

    def test_auto_distributed_group_is_only_checked(self):
        client = FakeClient([PROCESSING, {"processing": "VALID", "internal": "IN_BETA_TESTING"}], auto_distribute=True)
        result, _ = run(client)
        self.assertEqual(result.status, "ready")
        self.assertEqual(client.posts, [])

    def test_apple_rejection_is_failed(self):
        result, _ = run(FakeClient([PROCESSING, {"processing": "INVALID"}]))
        self.assertEqual((result.status, result.phase, result.reason), ("failed", "apple_processing", "invalid"))

    def test_expired_build_is_failed(self):
        result, _ = run(FakeClient([{"processing": "VALID", "expired": True}]))
        self.assertEqual((result.status, result.reason), ("failed", "expired"))

    def test_missing_build_becomes_unknown_not_failed(self):
        result, clock = run(FakeClient([NOT_FOUND]), find_deadline=10 * 60)
        self.assertEqual((result.status, result.reason), ("unknown", "build_not_found_by_deadline"))
        self.assertLess(clock.now, 15 * 60)

    def test_auth_error_stops_immediately(self):
        result, clock = run(FakeClient([asc.AuthError("HTTP 401: NOT_AUTHORIZED")]))
        self.assertEqual((result.status, result.phase), ("unknown", "authorization"))
        self.assertEqual(clock.sleeps, [])

    def test_transient_api_error_recovers(self):
        client = FakeClient([asc.ApiError(503, "down"), {"processing": "VALID", "internal": "IN_BETA_TESTING"}],
                            auto_distribute=True)
        result, _ = run(client)
        self.assertEqual(result.status, "ready")

    def test_deadline_gives_unknown_with_last_state(self):
        result, clock = run(FakeClient([PROCESSING]), deadline=20 * 60)
        self.assertEqual((result.status, result.reason), ("unknown", "timeout_while_processing"))
        self.assertLessEqual(clock.now, 20 * 60)

    def test_missing_export_compliance_does_not_wait_until_deadline(self):
        result, clock = run(FakeClient([{"processing": "VALID", "internal": "MISSING_EXPORT_COMPLIANCE"}]))
        self.assertEqual((result.status, result.reason), ("unknown", "missing_export_compliance"))
        self.assertLess(clock.now, 10 * 60)

    def test_failed_assignment_is_not_retried(self):
        client = FakeClient([{"processing": "VALID", "internal": "READY_FOR_BETA_TESTING"}],
                            assign_error=asc.ApiError(409, "conflict"))
        result, _ = run(client, deadline=15 * 60)
        self.assertEqual(result.status, "unknown")
        self.assertEqual(len(client.posts), 1)


class HelpersTest(unittest.TestCase):
    def test_next_build_number(self):
        self.assertEqual(asc.next_build_number(0, 0), 1)
        self.assertEqual(asc.next_build_number(12, 5), 13)
        self.assertEqual(asc.next_build_number(3, 9), 9)

    def test_project_files_match_release_config(self):
        self.assertRegex(asc.read_pubspec_version(), r"^\d+\.\d+\.\d+$")
        self.assertEqual(asc.read_app_bundle_ids(), {asc.CONFIG["bundle_id"]})


class ClientTest(unittest.TestCase):
    def client(self):
        client = asc.AscClient("issuer", "key", "-----BEGIN PRIVATE KEY-----", sleep=lambda s: None)
        client._bearer = lambda: "token"
        return client

    @staticmethod
    def http_error(code):
        return urllib.error.HTTPError("https://api.appstoreconnect.apple.com/v1/apps", code, "err", {},
                                      io.BytesIO(b'{"errors":[{"code":"X","detail":"nope"}]}'))

    def test_refuses_to_send_token_elsewhere(self):
        with self.assertRaises(asc.ApiError):
            self.client().get("https://evil.example.com/v1/apps")

    def test_401_is_not_retried(self):
        with mock.patch("urllib.request.urlopen", side_effect=self.http_error(401)) as urlopen:
            with self.assertRaises(asc.AuthError):
                self.client().get("/v1/apps")
        self.assertEqual(urlopen.call_count, 1)

    def test_503_is_retried_then_succeeds(self):
        ok = mock.MagicMock()
        ok.__enter__.return_value.read.return_value = b'{"data": []}'
        with mock.patch("urllib.request.urlopen", side_effect=[self.http_error(503), ok]) as urlopen:
            self.assertEqual(self.client().get("/v1/apps"), {"data": []})
        self.assertEqual(urlopen.call_count, 2)

    def test_503_retries_are_bounded(self):
        with mock.patch("urllib.request.urlopen", side_effect=lambda *a, **k: (_ for _ in ()).throw(
                self.http_error(503))) as urlopen:
            with self.assertRaises(asc.ApiError):
                self.client().get("/v1/apps")
        self.assertEqual(urlopen.call_count, asc.MAX_ATTEMPTS)


class ReportTest(unittest.TestCase):
    ENV = {"VERSION": "1.0.0", "BUILD_NUMBER": "7", "SOURCE_COMMIT": "abcdef1234567", "SOURCE_REF": "v1.0.0",
           "GITHUB_REPOSITORY": "o/r", "GITHUB_REPOSITORY_OWNER": "o", "GITHUB_RUN_ID": "1"}

    def test_ready_only_from_api_result(self):
        _, body = report.compose({**self.ENV, "OUTCOME": "uploaded"}, {"status": "ready", "phase": "testflight",
                                                                      "reason": "in_beta_testing"})
        self.assertIn("✅ TestFlight 內測可用：1.0.0 (7)", body)
        self.assertEqual(report.final_status("uploaded", None), "unknown")

    def test_ci_failure_is_not_reported_as_apple_failure(self):
        _, body = report.compose({**self.ENV, "OUTCOME": "ci_failed", "FAILED_PHASE": "gates"}, None)
        self.assertIn("CI 失敗：品質檢查", body)
        self.assertNotIn("Apple 處理失敗", body)

    def test_dedupe_key_differs_per_result(self):
        k1, _ = report.compose({**self.ENV, "OUTCOME": "uploaded"}, {"status": "unknown"})
        k2, _ = report.compose({**self.ENV, "OUTCOME": "uploaded"}, {"status": "ready"})
        self.assertNotEqual(k1, k2)
        self.assertIn(f"key={k2}", report.compose({**self.ENV, "OUTCOME": "uploaded"}, {"status": "ready"})[1])


if __name__ == "__main__":
    unittest.main()
