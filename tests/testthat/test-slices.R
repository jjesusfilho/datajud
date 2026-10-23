fake_response <- function(n_hits, total = n_hits, timed_out = FALSE,
                          failed = 0, relation = "eq") {
  list(
    timed_out = timed_out,
    `_shards` = list(total = 20, successful = 20 - failed, failed = failed),
    hits = list(
      total = list(value = total, relation = relation),
      hits = rep(list(list(`_id` = "x", `_source` = list())), n_hits)
    )
  )
}

test_that("check_complete accepts a complete response", {
  expect_true(check_complete(fake_response(3)))
  expect_true(check_complete(fake_response(0, total = 10), check_hits = FALSE))
})

test_that("check_complete rejects partial responses", {
  expect_error(check_complete(fake_response(3, timed_out = TRUE)), class = "datajud_incomplete")
  expect_error(check_complete(fake_response(3, failed = 18)), class = "datajud_incomplete")
  expect_error(check_complete(fake_response(2, total = 3)), class = "datajud_incomplete")
  expect_error(
    check_complete(fake_response(0, total = 10000, relation = "gte"), check_hits = FALSE),
    class = "datajud_incomplete"
  )
})

test_that("parse_datajud_date reads both formats", {
  x <- c("2021-07-22T15:41:21.000Z", "2021-07-22T15:41:21Z", "20231110002114",
         "20231110", "2020-01-31", NA, "garbage")
  out <- parse_datajud_date(x)

  expect_s3_class(out, "POSIXct")
  expect_equal(
    format(out, "%Y-%m-%d %H:%M:%S", tz = "UTC"),
    c("2021-07-22 15:41:21", "2021-07-22 15:41:21", "2023-11-10 00:21:14",
      "2023-11-10 00:00:00", "2020-01-31 00:00:00", NA, NA)
  )
})

test_that("split_by_cnj_prefix builds ten prefix filters", {
  query <- list(term = list(classe.codigo = 49))
  parts <- split_by_cnj_prefix(query, "10")

  expect_named(parts, paste0("10", 0:9))
  expect_equal(parts[["105"]]$bool$filter[[1]], query)
  expect_equal(parts[["105"]]$bool$filter[[2]], list(prefix = list(numeroProcesso = "105")))
  expect_identical(add_cnj_prefix(query, ""), query)
  expect_error(add_cnj_prefix(query, "1a"))
})

test_that("search_slice refuses slices larger than max_size", {
  local_mocked_bindings(datajud_request = function(...) fake_response(0, total = 5000))

  err <- expect_error(search_slice("tjsp", list(), max_size = 2000), class = "datajud_slice_too_large")
  expect_equal(err$total, 5000)
})

test_that("search_slice retries incomplete downloads", {
  calls <- 0
  local_mocked_bindings(
    datajud_request = function(..., size) {
      calls <<- calls + 1
      if (size == 0) return(fake_response(0, total = 3))
      if (calls == 2) return(fake_response(1, total = 3))
      fake_response(3)
    },
    backoff_seconds = function(...) 0
  )

  out <- suppressMessages(search_slice("tjsp", list(), parse = FALSE))
  expect_length(out$hits$hits, 3)
  expect_equal(attr(out, "total"), 3)
  expect_equal(calls, 3)
})

test_that("datajud_request retries 429 and stops on 400", {
  statuses <- c(429, 504, 200)
  i <- 0
  local_mocked_bindings(
    datajud_post = function(...) {
      i <<- i + 1
      structure(
        list(status_code = statuses[i], content = charToRaw('{"hits":{"hits":[]}}'),
             url = "http://localhost", headers = list(`Content-Type` = "application/json")),
        class = "response"
      )
    },
    backoff_seconds = function(...) 0
  )
  out <- suppressMessages(datajud_request("tjsp", list(), api_key = "k"))
  expect_equal(i, 3)
  expect_type(out, "list")

  statuses <- 400
  i <- 0
  expect_error(datajud_request("tjsp", list(), api_key = "k"), "status 400")
  expect_equal(i, 1)
})
