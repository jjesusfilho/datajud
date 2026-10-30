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
* New `date_range_query()` filters dates in both formats stored in the index.
  The index reads compact dates as milliseconds since 1970, so a `range` in
  one format only finds documents stored in that format. `search_processes()`,
  `search_by_date()` and `search_processes_paginated()` now use it; before,
  they missed every document stored in ISO format.
* New `split_date_range()` splits a slice by dates. Short CNJ prefixes match
  almost every number in the index and tend to exceed the gateway timeout.
* `search_processes_paginated()` and `search_with_pagination()` now warn that
  they do not return every document reliably.
