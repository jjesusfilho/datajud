#' Download a Small Slice of Processes in One Request
#'
#' @description
#' Downloads every document matching `query` in a single request, without
#' sorting or pagination. Paging with `from`/`size` without a sort repeats and
#' skips documents in the DataJud API, and sorting tends to exceed the gateway
#' timeout, so large result sets should be split into slices small enough to
#' come in one request (for instance by court unit, filing year and the prefix
#' of the CNJ number; see [split_by_cnj_prefix()]).
#'
#' The function first counts the matches. If there are more than `max_size`, it
#' signals an error of class `datajud_slice_too_large`, whose `total` field
#' holds the count, so the caller can split the slice. Otherwise it downloads
#' the slice and accepts the response only if [check_complete()] passes,
#' retrying up to `max_tries` times.
#'
#' @param tribunal Character string with the tribunal alias.
#' @param query List containing the Elasticsearch query.
#' @param max_size Integer with the largest slice accepted (default: 2000).
#'   Smaller slices are faster and fail less; responses with movements are
#'   large, so values between 500 and 1000 work better when they are included.
#' @param source Optional `_source` filter, e.g.
#'   `list(excludes = list("movimentos"))`, which makes the response much
#'   smaller.
#' @param parse Logical indicating whether to parse the results into a tibble
#'   (default: TRUE). With FALSE, returns the raw response.
#' @param api_key Character string with the API key.
#' @param max_tries Integer with the maximum number of attempts to obtain a
#'   complete response.
#' @param ... Further arguments passed to the internal request function
#'   (e.g. `timeout`).
#'
#' @return A tibble (or the raw response) with every document in the slice. The
#'   attribute `total` holds the count reported by the API.
#' @export
#'
#' @examples
#' \dontrun{
#' query <- list(bool = list(filter = list(
#'   list(term = list(classe.codigo = 49)),
#'   list(term = list(orgaoJulgador.codigo = 12345))
#' )))
#' slice <- search_slice("tjsp", query, max_size = 1000)
#' }
search_slice <- function(tribunal, query, max_size = 2000, source = NULL,
                         parse = TRUE, api_key = NULL, max_tries = 5, ...) {

  count <- request_complete(
    tribunal, query,
    size = 0, track_total_hits = TRUE, api_key = api_key,
    check_hits = FALSE, max_tries = max_tries, ...
  )
  total <- hits_total(count)

  if (total > max_size) {
    stop(structure(
      class = c("datajud_slice_too_large", "error", "condition"),
      list(
        message = sprintf("Slice has %d documents, more than max_size = %d.", total, max_size),
        call = NULL,
        total = total
      )
    ))
  }

  response <- count
  if (total > 0) {
    response <- request_complete(
      tribunal, query,
      size = max_size, source = source, track_total_hits = TRUE,
      api_key = api_key, max_tries = max_tries, ...
    )
  }

  result <- if (parse) parse_response(response) else response
  attr(result, "total") <- total
  result
}

#' Request Until the Response Is Complete
#'
#' @description
#' Calls [datajud_request()] until [check_complete()] passes. The API answers
#' with status 200 even when most shards reject the search, so HTTP retries
#' alone are not enough.
#'
#' @param ... Arguments passed to [datajud_request()].
#' @param check_hits Logical passed to [check_complete()].
#' @param max_tries Integer with the maximum number of attempts.
#'
#' @return A list with the complete raw response.
#' @keywords internal
request_complete <- function(..., check_hits = TRUE, max_tries = 5) {
  for (attempt in seq_len(max_tries)) {
    response <- datajud_request(..., max_tries = max_tries)
    complete <- tryCatch(
      check_complete(response, check_hits = check_hits),
      datajud_incomplete = function(e) e
    )
    if (isTRUE(complete)) {
      return(response)
    }
    if (attempt == max_tries) {
      stop(complete)
    }
    wait <- backoff_seconds(attempt)
    message(sprintf("Attempt %d: %s Retrying in %.0f s.", attempt, conditionMessage(complete), wait))
    Sys.sleep(wait)
  }
}

#' Restrict a Query to a Prefix of the CNJ Number
#'
#' @description
#' Adds a filter on the first digits of `numeroProcesso` to a query. The first
#' seven digits of the CNJ number are a sequential number, so prefixes split a
#' slice into parts of similar size.
#'
#' @param query List containing the Elasticsearch query.
#' @param prefix Character string with the leading digits of the CNJ number.
#'
#' @return A list with the combined query.
#' @export
#'
#' @examples
#' query <- list(term = list(classe.codigo = 49))
#' add_cnj_prefix(query, "10")
add_cnj_prefix <- function(query, prefix) {
  if (!grepl("^[0-9]*$", prefix)) {
    stop("prefix must contain only digits.")
  }
  if (prefix == "") {
    return(query)
  }

  list(bool = list(filter = list(
    query,
    list(prefix = list(numeroProcesso = prefix))
  )))
}

#' Split a Query by the Next Digit of the CNJ Number
#'
#' @description
#' Returns ten queries, one for each digit following `prefix`. Use it to split a
#' slice that [search_slice()] refused as too large, descending one digit at a
#' time.
#'
#' @param query List containing the Elasticsearch query, without prefix
#'   filters.
#' @param prefix Character string with the leading digits already fixed
#'   (default: "").
#'
#' @return A named list of ten queries. The names are the new prefixes.
#' @export
#'
#' @examples
#' query <- list(term = list(classe.codigo = 49))
#' names(split_by_cnj_prefix(query, "1"))
split_by_cnj_prefix <- function(query, prefix = "") {
  prefixes <- paste0(prefix, 0:9)
  stats::setNames(lapply(prefixes, function(p) add_cnj_prefix(query, p)), prefixes)
}

#' Parse DataJud Dates
#'
#' @description
#' DataJud stores dates in two formats: ISO 8601 (`2021-07-22T15:41:21.000Z`)
#' and a compact one (`20231110002114`). The index misreads the compact format
#' in range queries, so read the dates on the client side with this function.
#'
#' Both formats are read as UTC. The compact format carries no time zone, so
#' times close to midnight may be off by one day.
#'
#' @param x Character vector with dates.
#'
#' @return A POSIXct vector in UTC. Unrecognized values become NA.
#' @export
#'
#' @examples
#' parse_datajud_date(c("2021-07-22T15:41:21.000Z", "20231110002114", "2020-01-31"))
parse_datajud_date <- function(x) {
  x <- as.character(x)
  out <- rep(as.POSIXct(NA_real_, tz = "UTC"), length(x))

  compact <- !is.na(x) & grepl("^[0-9]{8}([0-9]{6})?$", x)
  y <- x[compact]
  y <- ifelse(nchar(y) == 8, paste0(y, "000000"), y)
  out[compact] <- as.POSIXct(y, format = "%Y%m%d%H%M%S", tz = "UTC")

  iso <- !is.na(x) & grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}(T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?Z?)?$", x)
  y <- sub("Z$", "", x[iso])
  y <- sub("\\.[0-9]+$", "", y)
  y <- sub("T", " ", y)
  y <- ifelse(nchar(y) == 10, paste(y, "00:00:00"), y)
  out[iso] <- as.POSIXct(y, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")

  out
}
