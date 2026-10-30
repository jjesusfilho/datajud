from typing import Any

import httpx
import pytest

import datajud
from datajud import api_request, slices


def fake_response(n_hits: int, total: int | None = None, timed_out: bool = False,
                  failed: int = 0, relation: str = "eq") -> dict[str, Any]:
    return {
        "timed_out": timed_out,
        "_shards": {"total": 20, "successful": 20 - failed, "failed": failed},
        "hits": {
            "total": {"value": n_hits if total is None else total, "relation": relation},
            "hits": [{"_id": "x", "_source": {}} for _ in range(n_hits)],
        },
    }


@pytest.fixture(autouse=True)
def no_sleep(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("time.sleep", lambda s: None)


def test_check_complete_accepts_complete_response() -> None:
    assert datajud.check_complete(fake_response(3))
    assert datajud.check_complete(fake_response(0, total=10), check_hits=False)


@pytest.mark.parametrize("response,check_hits", [
    (fake_response(3, timed_out=True), True),
    (fake_response(3, failed=18), True),
    (fake_response(2, total=3), True),
    (fake_response(0, total=10000, relation="gte"), False),
])
def test_check_complete_rejects_partial_responses(response: dict[str, Any], check_hits: bool) -> None:
    with pytest.raises(datajud.IncompleteResponseError):
        datajud.check_complete(response, check_hits=check_hits)


def test_parse_datajud_date_reads_both_formats() -> None:
    x = ["2021-07-22T15:41:21.000Z", "2021-07-22T15:41:21Z", "20231110002114",
         "20231110", "2020-01-31", None, "garbage"]
    out = datajud.parse_datajud_date(x)

    assert str(out.dtype) == "datetime64[ns, UTC]"
    assert out.dt.strftime("%Y-%m-%d %H:%M:%S").tolist()[:5] == [
        "2021-07-22 15:41:21", "2021-07-22 15:41:21", "2023-11-10 00:21:14",
        "2023-11-10 00:00:00", "2020-01-31 00:00:00",
    ]
    assert out[5:].isna().all()


def test_split_by_cnj_prefix_builds_ten_prefix_filters() -> None:
    query = {"term": {"classe.codigo": 49}}
    parts = datajud.split_by_cnj_prefix(query, "10")

    assert list(parts) == [f"10{d}" for d in range(10)]
    assert parts["105"]["bool"]["filter"][0] == query
    assert parts["105"]["bool"]["filter"][1] == {"prefix": {"numeroProcesso": "105"}}
    assert datajud.add_cnj_prefix(query, "") is query
    with pytest.raises(ValueError):
        datajud.add_cnj_prefix(query, "1a")


def test_search_slice_refuses_slices_larger_than_max_size(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(slices, "datajud_request", lambda *a, **k: fake_response(0, total=5000))

    with pytest.raises(datajud.SliceTooLargeError) as err:
        datajud.search_slice("tjsp", {}, max_size=2000)
    assert err.value.total == 5000


def test_search_slice_retries_incomplete_downloads(monkeypatch: pytest.MonkeyPatch) -> None:
    calls = 0

    def fake_request(*args: Any, size: int, **kwargs: Any) -> dict[str, Any]:
        nonlocal calls
        calls += 1
        if size == 0:
            return fake_response(0, total=3)
        if calls == 2:
            return fake_response(1, total=3)
        return fake_response(3)

    monkeypatch.setattr(slices, "datajud_request", fake_request)

    out = datajud.search_slice("tjsp", {}, parse=False)
    assert len(out["hits"]["hits"]) == 3
    assert datajud.hits_total(out) == 3
    assert calls == 3

    df = datajud.search_slice("tjsp", {})
    assert len(df) == 3
    assert df.attrs["total"] == 3


def test_datajud_request_retries_429_and_stops_on_400(monkeypatch: pytest.MonkeyPatch) -> None:
    statuses: list[int] = [429, 504, 200]
    calls = 0

    def fake_post(*args: Any) -> httpx.Response:
        nonlocal calls
        status = statuses[calls]
        calls += 1
        return httpx.Response(status, json={"hits": {"hits": []}})

    monkeypatch.setattr(api_request, "datajud_post", fake_post)

    out = datajud.datajud_request("tjsp", {}, api_key="k")
    assert calls == 3
    assert isinstance(out, dict)

    statuses, calls = [400], 0
    with pytest.raises(datajud.DataJudError, match="status 400"):
        datajud.datajud_request("tjsp", {}, api_key="k")
    assert calls == 1


def test_datajud_request_retries_connection_errors(monkeypatch: pytest.MonkeyPatch) -> None:
    calls = 0

    def fake_post(*args: Any) -> httpx.Response:
        nonlocal calls
        calls += 1
        raise httpx.ReadTimeout("timed out")

    monkeypatch.setattr(api_request, "datajud_post", fake_post)

    with pytest.raises(datajud.DataJudError, match="ReadTimeout"):
        datajud.datajud_request("tjsp", {}, api_key="k", max_tries=3)
    assert calls == 3


def test_parse_datajud_date_keeps_series_index() -> None:
    import pandas as pd

    x = pd.Series(["2020-01-31", "20231110"], index=[5, 9])
    assert datajud.parse_datajud_date(x).index.tolist() == [5, 9]


def test_split_date_range() -> None:
    import datetime as dt

    parts = datajud.split_date_range("2024-01-01", "2024-03-31", parts=4)
    assert parts[0][0] == dt.date(2024, 1, 1)
    assert parts[-1][1] == dt.date(2024, 3, 31)
    for (_, end), (start, _) in zip(parts, parts[1:]):
        assert start - end == dt.timedelta(days=1)
    assert len(datajud.split_date_range("2024-01-01", "2024-01-02", parts=10)) == 2
    with pytest.raises(ValueError):
        datajud.split_date_range("2024-01-01", "2024-01-01")
