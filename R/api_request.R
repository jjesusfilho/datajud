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
#'
#' @return A list with the API response.
#' @keywords internal
#'
#' @importFrom httr POST add_headers content status_code
#' @importFrom jsonlite toJSON fromJSON
datajud_request <- function(tribunal, query, size = 10, api_key = NULL, base_url = "https://api-publica.datajud.cnj.jus.br", from = 0) {

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

  # Make request
  response <- httr::POST(
    url = url,
    httr::add_headers(
      Authorization = paste("APIKey", api_key),
      `Content-Type` = "application/json"
    ),
    body = jsonlite::toJSON(body, auto_unbox = TRUE),
    encode = "raw"
  )

  # Check status
  if (httr::status_code(response) != 200) {
    stop(
      sprintf(
        "API request failed with status %d: %s",
        httr::status_code(response),
        httr::content(response, "text", encoding = "UTF-8")
      )
    )
  }

  # Parse response
  result <- httr::content(response, "text", encoding = "UTF-8")
  parsed <- jsonlite::fromJSON(result, simplifyVector = FALSE)

  parsed
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
