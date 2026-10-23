# datajud 0.2.0.9000

* `datajud_request()` retries status 429, 5xx and connection errors with
  exponential backoff, and accepts `source`, `aggs`, `track_total_hits` and
  `timeout`.
* New `check_complete()` rejects partial responses (timed out search, failed
  shards or fewer documents than the reported total), which the API returns
  with status 200.
* New `search_slice()` downloads a small slice in one request, without sorting
  or pagination, and signals `datajud_slice_too_large` with the count when the
  slice must be split.
* New `add_cnj_prefix()` and `split_by_cnj_prefix()` split a slice by the
  leading digits of the CNJ number.
* New `parse_datajud_date()` reads the ISO and compact date formats.
* `search_processes_paginated()` and `search_with_pagination()` now warn that
  they do not return every document reliably.
