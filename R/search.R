#' Search by CNJ Process Number
#'
#' @description
#' Search for judicial processes by their CNJ identification number.
#' The CNJ number follows the format NNNNNNN-DD.AAAA.J.TR.OOOO.
#'
#' @param cnj_number Character string or vector with one or more CNJ process numbers.
#' @param tribunal Character string with the tribunal (e.g., "trf1", "tjsp", "trt2").
#'   Use list_tribunals() to see available options. If NULL, will try to infer from the CNJ number.
#' @param size Integer indicating the maximum number of results per CNJ number
#'   (default: 10).
#' @param parse Logical indicating whether to parse the results into a data frame
#'   (default: TRUE).
#' @param api_key Character string with the API key. If NULL, uses the key set
#'   with set_api_key() or the DATAJUD_API_KEY environment variable.
#'
#' @return If parse = TRUE, returns a tibble with the search results. If parse = FALSE,
#'   returns the raw API response as a list. If multiple CNJ numbers are provided,
#'   returns a list with one element per CNJ number.
#' @export
#'
#' @examples
#' \dontrun{
#' # Set API key first
#' set_api_key(get_default_api_key())
#'
#' # Search by CNJ number (using short tribunal name)
#' results <- search_cnj("00001234520204036100", tribunal = "trf1")
#'
#' # Search multiple CNJ numbers
#' cnj_numbers <- c("00001234520204036100", "00005678920204036100")
#' results <- search_cnj(cnj_numbers, tribunal = "trf1")
#' }
search_cnj <- function(cnj_number, tribunal, size = 10, parse = TRUE, api_key = NULL) {

  # Clean CNJ numbers (remove formatting)
  cnj_clean <- gsub("[^0-9]", "", cnj_number)

  # If single CNJ number
  if (length(cnj_clean) == 1) {
    query <- list(
      match = list(
        numeroProcesso = cnj_clean
      )
    )

    return(search_datajud(tribunal, query, size, parse, api_key))
  }

  # Multiple CNJ numbers
  results <- lapply(cnj_clean, function(cnj) {
    query <- list(
      match = list(
        numeroProcesso = cnj
      )
    )

    search_datajud(tribunal, query, size, parse, api_key)
  })

  names(results) <- cnj_number
  results
}

#' Search by Date Range
#'
#' @description
#' Search for judicial processes within a date range.
#'
#' @param tribunal Character string with the tribunal (e.g., "trf1", "tjsp").
#' @param date_field Character string with the date field to search
#'   (default: "dataAjuizamento"). Options: "dataAjuizamento",
#'   "dataHoraUltimaAtualizacao".
#' @param start_date Character string or Date object with the start date
#'   (format: "YYYY-MM-DD").
#' @param end_date Character string or Date object with the end date
#'   (format: "YYYY-MM-DD").
#' @param size Integer indicating the maximum number of results (default: 10).
#' @param parse Logical indicating whether to parse the results into a data frame
#'   (default: TRUE).
#' @param api_key Character string with the API key.
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
#' # Search by filing date
#' results <- search_by_date(
#'   tribunal = "trf1",
#'   start_date = "2020-01-01",
#'   end_date = "2020-12-31"
#' )
#' }
search_by_date <- function(tribunal, date_field = "dataAjuizamento",
                           start_date = NULL, end_date = NULL,
                           size = 10, parse = TRUE, api_key = NULL) {

  if (is.null(start_date) && is.null(end_date)) {
    stop("At least one of start_date or end_date must be provided.")
  }

  # Build range query
  range_params <- list()
  if (!is.null(start_date)) {
    range_params$gte <- as.character(start_date)
  }
  if (!is.null(end_date)) {
    range_params$lte <- as.character(end_date)
  }

  query <- list(
    range = structure(
      list(range_params),
      names = date_field
    )
  )

  search_datajud(tribunal, query, size, parse, api_key)
}

#' Advanced Search with Custom Query
#'
#' @description
#' Perform an advanced search using a custom Elasticsearch query.
#' This function provides full flexibility to construct complex queries.
#'
#' @param tribunal Character string with the tribunal (e.g., "trf1", "tjsp").
#' @param query_string Character string with a query string search.
#' @param fields Character vector with the fields to search in.
#' @param size Integer indicating the maximum number of results (default: 10).
#' @param parse Logical indicating whether to parse the results into a data frame
#'   (default: TRUE).
#' @param api_key Character string with the API key.
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
#' # Search using query string
#' results <- search_advanced(
#'   tribunal = "trf1",
#'   query_string = "ação civil pública",
#'   fields = c("classe.nome", "assuntos.nome")
#' )
#' }
search_advanced <- function(tribunal, query_string, fields = c("*"),
                            size = 10, parse = TRUE, api_key = NULL) {

  query <- list(
    query_string = list(
      query = query_string,
      fields = fields
    )
  )

  search_datajud(tribunal, query, size, parse, api_key)
}

#' Search Processes with All Available Parameters
#'
#' @description
#' Comprehensive search function that supports all documented DataJud API parameters.
#' Build complex queries using any combination of available search criteria.
#'
#' @param tribunal Character string with the tribunal (e.g., "trf1", "tjsp", "trt2").
#'   Use list_tribunals() to see available options.
#' @param id Character string with the process identifier.
#' @param numeroProcesso Character string with the CNJ process number (without formatting).
#' @param grau Character string with the court level/instance identifier.
#' @param nivelSigilo Integer with the confidentiality level.
#' @param dataAjuizamento_start Character string or Date for filing date range start (format: "YYYY-MM-DD").
#' @param dataAjuizamento_end Character string or Date for filing date range end (format: "YYYY-MM-DD").
#' @param dataHoraUltimaAtualizacao_start Character string or POSIXct for last update range start.
#' @param dataHoraUltimaAtualizacao_end Character string or POSIXct for last update range end.
#' @param formato_codigo Character string with the process type code.
#' @param formato_nome Character string with the process type name.
#' @param sistema_codigo Character string with the court system code.
#' @param sistema_nome Character string with the court system name.
#' @param classe_codigo Character string with the case classification code.
#' @param classe_nome Character string with the case classification name.
#' @param assuntos_codigo Character string with the case subject code.
#' @param assuntos_nome Character string with the case subject name.
#' @param orgaoJulgador_codigo Character string with the court body code.
#' @param orgaoJulgador_nome Character string with the court body name.
#' @param orgaoJulgador_codigoMunicipioIBGE Character string with the IBGE municipality code.
#' @param movimentos_codigo Character string with the movement code.
#' @param movimentos_nome Character string with the movement name.
#' @param movimentos_dataHora_start Character string or POSIXct for movement date range start.
#' @param movimentos_dataHora_end Character string or POSIXct for movement date range end.
#' @param size Integer indicating the maximum number of results (default: 10, maximum: 10000).
#' @param parse Logical indicating whether to parse the results into a data frame (default: TRUE).
#' @param api_key Character string with the API key.
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
#' # Search by grau and date range
#' results <- search_processes(
#'   tribunal = "trf1",
#'   grau = "2",
#'   dataAjuizamento_start = "2020-01-01",
#'   dataAjuizamento_end = "2020-12-31"
#' )
#'
#' # Search by subject and court body
#' results <- search_processes(
#'   tribunal = "trf1",
#'   assuntos_codigo = "10596",
#'   orgaoJulgador_nome = "1ª Turma"
#' )
#'
#' # Search by class code and court body
#' results <- search_processes(
#'   tribunal = "trf1",
#'   classe_codigo = "1199",
#'   orgaoJulgador_nome = "1ª Turma"
#' )
#'
#' # Complex search with multiple criteria
#' results <- search_processes(
#'   tribunal = "tjsp",
#'   classe_codigo = "1199",
#'   grau = "2",
#'   sistema_nome = "PJe",
#'   nivelSigilo = 0
#' )
#' }
search_processes <- function(tribunal,
                            id = NULL,
                            numeroProcesso = NULL,
                            grau = NULL,
                            nivelSigilo = NULL,
                            dataAjuizamento_start = NULL,
                            dataAjuizamento_end = NULL,
                            dataHoraUltimaAtualizacao_start = NULL,
                            dataHoraUltimaAtualizacao_end = NULL,
                            formato_codigo = NULL,
                            formato_nome = NULL,
                            sistema_codigo = NULL,
                            sistema_nome = NULL,
                            classe_codigo = NULL,
                            classe_nome = NULL,
                            assuntos_codigo = NULL,
                            assuntos_nome = NULL,
                            orgaoJulgador_codigo = NULL,
                            orgaoJulgador_nome = NULL,
                            orgaoJulgador_codigoMunicipioIBGE = NULL,
                            movimentos_codigo = NULL,
                            movimentos_nome = NULL,
                            movimentos_dataHora_start = NULL,
                            movimentos_dataHora_end = NULL,
                            size = 10,
                            parse = TRUE,
                            api_key = NULL) {

  # Build list of match conditions
  must_conditions <- list()

  # Simple match parameters
  if (!is.null(id)) {
    must_conditions <- append(must_conditions, list(list(match = list(id = id))))
  }

  if (!is.null(numeroProcesso)) {
    # Clean CNJ number (remove formatting)
    numeroProcesso_clean <- gsub("[^0-9]", "", numeroProcesso)
    must_conditions <- append(must_conditions, list(list(match = list(numeroProcesso = numeroProcesso_clean))))
  }

  if (!is.null(grau)) {
    must_conditions <- append(must_conditions, list(list(match = list(grau = grau))))
  }

  if (!is.null(nivelSigilo)) {
    must_conditions <- append(must_conditions, list(list(match = list(nivelSigilo = nivelSigilo))))
  }

  # Nested object parameters - formato
  if (!is.null(formato_codigo)) {
    must_conditions <- append(must_conditions, list(list(match = list(formato.codigo = formato_codigo))))
  }

  if (!is.null(formato_nome)) {
    must_conditions <- append(must_conditions, list(list(match = list(formato.nome = formato_nome))))
  }

  # Nested object parameters - sistema
  if (!is.null(sistema_codigo)) {
    must_conditions <- append(must_conditions, list(list(match = list(sistema.codigo = sistema_codigo))))
  }

  if (!is.null(sistema_nome)) {
    must_conditions <- append(must_conditions, list(list(match = list(sistema.nome = sistema_nome))))
  }

  # Nested object parameters - classe
  if (!is.null(classe_codigo)) {
    must_conditions <- append(must_conditions, list(list(match = list(classe.codigo = classe_codigo))))
  }

  if (!is.null(classe_nome)) {
    must_conditions <- append(must_conditions, list(list(match = list(classe.nome = classe_nome))))
  }

  # Nested object parameters - assuntos
  if (!is.null(assuntos_codigo)) {
    must_conditions <- append(must_conditions, list(list(match = list(assuntos.codigo = assuntos_codigo))))
  }

  if (!is.null(assuntos_nome)) {
    must_conditions <- append(must_conditions, list(list(match = list(assuntos.nome = assuntos_nome))))
  }

  # Nested object parameters - orgaoJulgador
  if (!is.null(orgaoJulgador_codigo)) {
    must_conditions <- append(must_conditions, list(list(match = list(orgaoJulgador.codigo = orgaoJulgador_codigo))))
  }

  if (!is.null(orgaoJulgador_nome)) {
    must_conditions <- append(must_conditions, list(list(match = list(orgaoJulgador.nome = orgaoJulgador_nome))))
  }

  if (!is.null(orgaoJulgador_codigoMunicipioIBGE)) {
    must_conditions <- append(must_conditions, list(list(match = list(orgaoJulgador.codigoMunicipioIBGE = orgaoJulgador_codigoMunicipioIBGE))))
  }

  # Nested object parameters - movimentos
  if (!is.null(movimentos_codigo)) {
    must_conditions <- append(must_conditions, list(list(match = list(movimentos.codigo = movimentos_codigo))))
  }

  if (!is.null(movimentos_nome)) {
    must_conditions <- append(must_conditions, list(list(match = list(movimentos.nome = movimentos_nome))))
  }

  # Date range parameters - dataAjuizamento
  if (!is.null(dataAjuizamento_start) || !is.null(dataAjuizamento_end)) {
    range_params <- list()
    if (!is.null(dataAjuizamento_start)) {
      range_params$gte <- as.character(dataAjuizamento_start)
    }
    if (!is.null(dataAjuizamento_end)) {
      range_params$lte <- as.character(dataAjuizamento_end)
    }
    must_conditions <- append(must_conditions, list(list(range = list(dataAjuizamento = range_params))))
  }

  # Date range parameters - dataHoraUltimaAtualizacao
  if (!is.null(dataHoraUltimaAtualizacao_start) || !is.null(dataHoraUltimaAtualizacao_end)) {
    range_params <- list()
    if (!is.null(dataHoraUltimaAtualizacao_start)) {
      range_params$gte <- as.character(dataHoraUltimaAtualizacao_start)
    }
    if (!is.null(dataHoraUltimaAtualizacao_end)) {
      range_params$lte <- as.character(dataHoraUltimaAtualizacao_end)
    }
    must_conditions <- append(must_conditions, list(list(range = list(dataHoraUltimaAtualizacao = range_params))))
  }

  # Date range parameters - movimentos.dataHora
  if (!is.null(movimentos_dataHora_start) || !is.null(movimentos_dataHora_end)) {
    range_params <- list()
    if (!is.null(movimentos_dataHora_start)) {
      range_params$gte <- as.character(movimentos_dataHora_start)
    }
    if (!is.null(movimentos_dataHora_end)) {
      range_params$lte <- as.character(movimentos_dataHora_end)
    }
    must_conditions <- append(must_conditions, list(list(range = list(movimentos.dataHora = range_params))))
  }

  # Check that at least one search parameter was provided
  if (length(must_conditions) == 0) {
    stop("At least one search parameter must be provided.")
  }

  # Build the query
  query <- list(
    bool = list(
      must = must_conditions
    )
  )

  # Execute search
  search_datajud(tribunal, query, size, parse, api_key)
}

#' Search Processes with Pagination
#'
#' @description
#' Comprehensive search function that supports pagination and saving results.
#' Allows fetching multiple pages of results and optionally saving each page to disk.
#'
#' @param tribunal Character string with the tribunal (e.g., "trf1", "tjsp").
#' @param page_size Integer indicating the number of results per page (default: 100, maximum: 10000).
#' @param max_pages Integer indicating the maximum number of pages to fetch (default: NULL for all available).
#' @param save_pages Logical indicating whether to save each page to disk (default: FALSE).
#' @param output_dir Character string with the directory to save pages (default: "datajud_pages").
#' @param output_format Character string with the output format: "rds", "csv", or "json" (default: "rds").
#' @param ... Additional search parameters passed to search_processes (numeroProcesso, grau, classe_codigo, etc.).
#' @param api_key Character string with the API key.
#'
#' @return A list with:
#'   - data: Combined tibble with all results from all pages (if parse = TRUE)
#'   - pages: List of individual page results
#'   - total_hits: Total number of available results
#'   - pages_fetched: Number of pages actually fetched
#'   - files_saved: Vector of file paths if save_pages = TRUE
#' @export
#' @importFrom utils write.csv
#'
#' @examples
#' \dontrun{
#' # Set API key first
#' set_api_key(get_default_api_key())
#'
#' # Search with pagination
#' results <- search_processes_paginated(
#'   tribunal = "trf1",
#'   grau = "2",
#'   page_size = 100,
#'   max_pages = 5
#' )
#'
#' # Search and save each page
#' results <- search_processes_paginated(
#'   tribunal = "trf1",
#'   classe_codigo = "1199",
#'   page_size = 100,
#'   max_pages = 10,
#'   save_pages = TRUE,
#'   output_dir = "meus_dados",
#'   output_format = "csv"
#' )
#' }
search_processes_paginated <- function(tribunal,
                                       page_size = 100,
                                       max_pages = NULL,
                                       save_pages = FALSE,
                                       output_dir = "datajud_pages",
                                       output_format = "rds",
                                       ...,
                                       api_key = NULL) {

  # Validate output format
  output_format <- match.arg(output_format, c("rds", "csv", "json"))

  # Create output directory if needed
  if (save_pages && !dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
    message("Created output directory: ", output_dir)
  }

  # Get additional search parameters
  search_params <- list(...)

  # Build query using search_processes logic
  must_conditions <- list()

  # Extract and build conditions from search_params
  param_mapping <- list(
    id = "id",
    numeroProcesso = "numeroProcesso",
    grau = "grau",
    nivelSigilo = "nivelSigilo",
    formato_codigo = "formato.codigo",
    formato_nome = "formato.nome",
    sistema_codigo = "sistema.codigo",
    sistema_nome = "sistema.nome",
    classe_codigo = "classe.codigo",
    classe_nome = "classe.nome",
    assuntos_codigo = "assuntos.codigo",
    assuntos_nome = "assuntos.nome",
    orgaoJulgador_codigo = "orgaoJulgador.codigo",
    orgaoJulgador_nome = "orgaoJulgador.nome",
    orgaoJulgador_codigoMunicipioIBGE = "orgaoJulgador.codigoMunicipioIBGE",
    movimentos_codigo = "movimentos.codigo",
    movimentos_nome = "movimentos.nome"
  )

  for (param_name in names(param_mapping)) {
    if (!is.null(search_params[[param_name]])) {
      field_name <- param_mapping[[param_name]]
      value <- search_params[[param_name]]

      # Clean numeroProcesso if needed
      if (param_name == "numeroProcesso") {
        value <- gsub("[^0-9]", "", value)
      }

      match_condition <- list()
      match_condition[[field_name]] <- value
      must_conditions <- append(must_conditions, list(list(match = match_condition)))
    }
  }

  # Date range parameters
  date_ranges <- list(
    dataAjuizamento = c("dataAjuizamento_start", "dataAjuizamento_end"),
    dataHoraUltimaAtualizacao = c("dataHoraUltimaAtualizacao_start", "dataHoraUltimaAtualizacao_end"),
    movimentos.dataHora = c("movimentos_dataHora_start", "movimentos_dataHora_end")
  )

  for (field in names(date_ranges)) {
    start_param <- date_ranges[[field]][1]
    end_param <- date_ranges[[field]][2]

    if (!is.null(search_params[[start_param]]) || !is.null(search_params[[end_param]])) {
      range_params <- list()
      if (!is.null(search_params[[start_param]])) {
        range_params$gte <- as.character(search_params[[start_param]])
      }
      if (!is.null(search_params[[end_param]])) {
        range_params$lte <- as.character(search_params[[end_param]])
      }
      range_condition <- list()
      range_condition[[field]] <- range_params
      must_conditions <- append(must_conditions, list(list(range = range_condition)))
    }
  }

  # Check that at least one search parameter was provided
  if (length(must_conditions) == 0) {
    stop("At least one search parameter must be provided.")
  }

  # Build the query
  query <- list(
    bool = list(
      must = must_conditions
    )
  )

  # Initialize pagination variables
  pages <- list()
  files_saved <- character()
  current_page <- 0
  total_hits <- NULL

  # Fetch pages
  repeat {
    current_page <- current_page + 1

    # Calculate from parameter
    from <- (current_page - 1) * page_size

    # Make request
    message("Fetching page ", current_page, "...")
    response <- datajud_request(tribunal, query, size = page_size, api_key = api_key, from = from)

    # Get total hits on first page
    if (is.null(total_hits)) {
      if (!is.null(response$hits$total$value)) {
        total_hits <- response$hits$total$value
      } else {
        total_hits <- response$hits$total
      }
      message("Total results available: ", total_hits)
    }

    # Check if we have results
    if (is.null(response$hits$hits) || length(response$hits$hits) == 0) {
      message("No more results. Stopping at page ", current_page - 1)
      break
    }

    # Parse response
    page_data <- parse_response(response)
    pages[[current_page]] <- page_data

    # Save page if requested
    if (save_pages) {
      timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
      base_filename <- sprintf("page_%03d_%s", current_page, timestamp)

      if (output_format == "rds") {
        filepath <- file.path(output_dir, paste0(base_filename, ".rds"))
        saveRDS(page_data, filepath)
      } else if (output_format == "csv") {
        filepath <- file.path(output_dir, paste0(base_filename, ".csv"))
        write.csv(page_data, filepath, row.names = FALSE)
      } else if (output_format == "json") {
        filepath <- file.path(output_dir, paste0(base_filename, ".json"))
        writeLines(jsonlite::toJSON(page_data, pretty = TRUE), filepath)
      }

      files_saved <- c(files_saved, filepath)
      message("Saved page ", current_page, " to: ", filepath)
    }

    # Check stopping conditions
    if (!is.null(max_pages) && current_page >= max_pages) {
      message("Reached max_pages limit (", max_pages, "). Stopping.")
      break
    }

    # Check if we've fetched all available results
    if (from + page_size >= total_hits) {
      message("Fetched all available results. Stopping at page ", current_page)
      break
    }

    # Small delay to avoid overwhelming the API
    Sys.sleep(0.5)
  }

  # Combine all pages into single tibble
  combined_data <- NULL
  if (length(pages) > 0) {
    combined_data <- do.call(rbind, pages)
  }

  # Return results
  result <- list(
    data = combined_data,
    pages = pages,
    total_hits = total_hits,
    pages_fetched = length(pages)
  )

  if (save_pages) {
    result$files_saved <- files_saved
  }

  message("\nSummary:")
  message("- Total hits: ", total_hits)
  message("- Pages fetched: ", length(pages))
  message("- Rows retrieved: ", ifelse(is.null(combined_data), 0, nrow(combined_data)))
  if (save_pages) {
    message("- Files saved: ", length(files_saved))
  }

  result
}
