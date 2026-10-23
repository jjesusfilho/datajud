#' Make DataJud API Request
#'
#' @description
#' Internal function to make POST requests to the DataJud API.
#'
#' @param tribunal Character string with the tribunal alias (e.g., "api_publica_trf1").
#' @param query List containing the Elasticsearch query.
#' @param size Integer indicating the number of results to return (default: 10).
#' @param api_key Character string with the API key. If NULL, uses get_api_key().
#' @param base_url Character string with the base URL (default: "https://api-publica.datajud.cnj.jus.br").
#' @param from Integer with the offset of the first result (default: 0).
#' @param source Optional `_source` filter, e.g. `list(excludes = list("movimentos"))`.
#' @param aggs Optional list with Elasticsearch aggregations.
#' @param track_total_hits Logical. If TRUE, asks for the exact total instead of
#'   the default lower bound of 10,000.
#' @param max_tries Integer with the maximum number of attempts. Status 429, 5xx
#'   and connection errors are retried with exponential backoff.
#' @param timeout Numeric with the timeout of each attempt, in seconds.
#'
#' @return A list with the API response.
#' @keywords internal
#'
#' @importFrom httr POST add_headers content status_code timeout
#' @importFrom jsonlite toJSON fromJSON
datajud_request <- function(tribunal, query, size = 10, api_key = NULL, base_url = "https://api-publica.datajud.cnj.jus.br", from = 0,
                            source = NULL, aggs = NULL, track_total_hits = NULL,
                            max_tries = 5, timeout = 120) {

  # Normalize and validate tribunal
  tribunal <- normalize_tribunal(tribunal)

  # Get API key
  if (is.null(api_key)) {
    api_key <- get_api_key()
  }

  # Build URL
  url <- paste0(base_url, "/", tribunal, "/_search")

  # Build request body
  body <- list(
    query = query,
    size = size,
    from = from
  )
  body[["_source"]] <- source
  body$aggs <- aggs
  body$track_total_hits <- track_total_hits

  json_body <- jsonlite::toJSON(body, auto_unbox = TRUE)

  # Make request, retrying transient failures (the API often answers 429 and
  # 504 during business hours)
  for (attempt in seq_len(max_tries)) {
    response <- tryCatch(
      datajud_post(url, api_key, json_body, timeout),
      error = function(e) e
    )

    if (inherits(response, "error")) {
      problem <- conditionMessage(response)
      retry <- TRUE
    } else {
      status <- httr::status_code(response)
      if (status == 200) {
        break
      }
      problem <- sprintf(
        "API request failed with status %d: %s",
        status,
        httr::content(response, "text", encoding = "UTF-8")
      )
      retry <- status == 429 || status >= 500
    }

    if (!retry || attempt == max_tries) {
      stop(problem, call. = FALSE)
    }

    wait <- backoff_seconds(attempt)
    message(sprintf("Attempt %d failed (%s). Retrying in %.0f s.",
                    attempt, substr(problem, 1, 80), wait))
    Sys.sleep(wait)
  }

  # Parse response
  result <- httr::content(response, "text", encoding = "UTF-8")
  parsed <- jsonlite::fromJSON(result, simplifyVector = FALSE)

  parsed
}

#' Send a raw POST to the DataJud API
#'
#' @description
#' Internal wrapper around [httr::POST()], kept separate so the retry logic in
#' [datajud_request()] can be tested without network access.
#'
#' @keywords internal
datajud_post <- function(url, api_key, json_body, timeout) {
  httr::POST(
    url = url,
    httr::add_headers(
      Authorization = paste("APIKey", api_key),
      `Content-Type` = "application/json"
    ),
    body = json_body,
    encode = "raw",
    httr::timeout(timeout)
  )
}

#' Exponential backoff with jitter
#'
#' @param attempt Integer with the number of the failed attempt.
#' @param base Numeric with the base wait, in seconds.
#' @param cap Numeric with the maximum wait, in seconds.
#'
#' @return Numeric with the number of seconds to wait.
#' @keywords internal
backoff_seconds <- function(attempt, base = 5, cap = 120) {
  min(cap, base * 2^(attempt - 1)) + stats::runif(1, 0, base)
}

#' Check that a DataJud response is complete
#'
#' @description
#' The DataJud API may return partial results without an HTTP error, when some
#' shards time out. This function rejects a response that timed out, has failed
#' shards or brings fewer documents than the reported total.
#'
#' @param response List with the raw API response (as returned with
#'   `parse = FALSE`).
#' @param check_hits Logical. If FALSE, skips the comparison between the number
#'   of documents and the reported total (useful for count queries with
#'   `size = 0`).
#'
#' @return Invisibly returns TRUE. Signals an error of class
#'   `datajud_incomplete` otherwise.
#' @export
#'
#' @examples
#' response <- list(
#'   timed_out = FALSE,
#'   `_shards` = list(total = 20, failed = 0),
#'   hits = list(total = list(value = 1, relation = "eq"), hits = list(list()))
#' )
#' check_complete(response)
check_complete <- function(response, check_hits = TRUE) {
  problems <- character()

  if (isTRUE(response$timed_out)) {
    problems <- c(problems, "the search timed out")
  }

  failed <- response[["_shards"]]$failed %||% 0
  if (failed > 0) {
    problems <- c(problems, sprintf("%d shard(s) failed", failed))
  }

  relation <- response$hits$total$relation %||% "eq"
  if (relation != "eq") {
    problems <- c(problems, "the total is a lower bound (use track_total_hits)")
  }

  if (check_hits) {
    total <- hits_total(response)
    n <- length(response$hits$hits)
    if (n < total) {
      problems <- c(problems, sprintf("%d of %d documents returned", n, total))
    }
  }

  if (length(problems) > 0) {
    stop(structure(
      class = c("datajud_incomplete", "error", "condition"),
      list(
        message = paste("Incomplete DataJud response:", paste(problems, collapse = "; ")),
        call = NULL
      )
    ))
  }

  invisible(TRUE)
}

#' Total number of hits in a DataJud response
#'
#' @param response List with the raw API response.
#'
#' @return Numeric with the reported total.
#' @keywords internal
hits_total <- function(response) {
  total <- response$hits$total
  if (is.list(total)) {
    total <- total$value
  }
  total %||% 0
}

#' Search DataJud API
#'
#' @description
#' General purpose function to search the DataJud API with custom queries.
#'
#' @param tribunal Character string with the tribunal alias. Use list_tribunals()
#'   to see available options.
#' @param query List containing the Elasticsearch query. This should follow
#'   Elasticsearch Query DSL format.
#' @param size Integer indicating the number of results to return (default: 10,
#'   maximum: 10000).
#' @param parse Logical indicating whether to parse the results into a data frame
#'   (default: TRUE).
#' @param api_key Character string with the API key. If NULL, uses the key set
#'   with set_api_key() or the DATAJUD_API_KEY environment variable.
#' @param from Integer indicating the starting position for pagination (default: 0).
#'
#' @return If parse = TRUE, returns a tibble with the search results. If parse = FALSE,
#'   returns the raw API response as a list.
#' @export
#'
#' @examples
#' \dontrun{
#' # Set API key first
#' set_api_key(get_default_api_key())
#'
#' # Search with a simple match query
#' query <- list(
#'   match = list(
#'     numeroProcesso = "00001234520204036100"
#'   )
#' )
#' results <- search_datajud("api_publica_trf1", query)
#' }
search_datajud <- function(tribunal, query, size = 10, parse = TRUE, api_key = NULL, from = 0) {

  # Make request
  response <- datajud_request(tribunal, query, size, api_key, from = from)

  if (!parse) {
    return(response)
  }

  # Parse results
  parse_response(response)
}

#' Parse DataJud API Response
#'
#' @description
#' Parses the raw API response into a more user-friendly data frame.
#'
#' @param response List containing the raw API response.
#'
#' @return A tibble with the parsed results.
#' @keywords internal
#'
#' @importFrom tibble tibble
parse_response <- function(response) {

  # Check if there are hits
  if (is.null(response$hits$hits) || length(response$hits$hits) == 0) {
    message("No results found.")
    return(tibble::tibble())
  }

  # Extract hits
  hits <- response$hits$hits

  # Convert to data frame
  results <- lapply(hits, function(hit) {
    source <- hit[["_source"]]

    # Create a flat structure
    tibble::tibble(
      id = hit[["_id"]] %||% NA,
      score = hit[["_score"]] %||% NA,
      numeroProcesso = source$numeroProcesso %||% NA,
      classe = list(source$classe),
      sistema = list(source$sistema),
      formato = list(source$formato),
      tribunal = source$tribunal %||% NA,
      dataHoraUltimaAtualizacao = source$dataHoraUltimaAtualizacao %||% NA,
      grau = source$grau %||% NA,
      nivelSigilo = source$nivelSigilo %||% NA,
      dataAjuizamento = source$dataAjuizamento %||% NA,
      movimentos = list(source$movimentos),
      assuntos = list(source$assuntos),
      orgaoJulgador = list(source$orgaoJulgador)
    )
  })

  do.call(rbind, results)
}

#' Null coalescing operator
#' @keywords internal
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
