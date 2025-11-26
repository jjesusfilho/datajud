#' List Available Tribunals
#'
#' @description
#' Returns a data frame with information about all available Brazilian
#' tribunals in the DataJud API.
#'
#' @return A tibble with columns: alias (tribunal code), name (tribunal name),
#'   and type (tribunal category).
#' @export
#'
#' @examples
#' list_tribunals()
#'
#' # Filter by type
#' tribunals <- list_tribunals()
#' tribunals[tribunals$type == "TRF", ]
list_tribunals <- function() {
  tribunals_data <- list(
    # Superior Courts
    list(alias = "api_publica_tst", name = "Tribunal Superior do Trabalho", type = "Superior"),
    list(alias = "api_publica_tse", name = "Tribunal Superior Eleitoral", type = "Superior"),
    list(alias = "api_publica_stj", name = "Superior Tribunal de Justi\u00e7a", type = "Superior"),
    list(alias = "api_publica_stm", name = "Superior Tribunal Militar", type = "Superior"),

    # Regional Electoral Courts (TRE)
    list(alias = "api_publica_tre-ac", name = "Tribunal Regional Eleitoral do Acre", type = "TRE"),
    list(alias = "api_publica_tre-al", name = "Tribunal Regional Eleitoral de Alagoas", type = "TRE"),
    list(alias = "api_publica_tre-ap", name = "Tribunal Regional Eleitoral do Amapá", type = "TRE"),
    list(alias = "api_publica_tre-am", name = "Tribunal Regional Eleitoral do Amazonas", type = "TRE"),
    list(alias = "api_publica_tre-ba", name = "Tribunal Regional Eleitoral da Bahia", type = "TRE"),
    list(alias = "api_publica_tre-ce", name = "Tribunal Regional Eleitoral do Ceará", type = "TRE"),
    list(alias = "api_publica_tre-dft", name = "Tribunal Regional Eleitoral do Distrito Federal", type = "TRE"),
    list(alias = "api_publica_tre-es", name = "Tribunal Regional Eleitoral do Espírito Santo", type = "TRE"),
    list(alias = "api_publica_tre-go", name = "Tribunal Regional Eleitoral de Goiás", type = "TRE"),
    list(alias = "api_publica_tre-ma", name = "Tribunal Regional Eleitoral do Maranhão", type = "TRE"),
    list(alias = "api_publica_tre-mt", name = "Tribunal Regional Eleitoral de Mato Grosso", type = "TRE"),
    list(alias = "api_publica_tre-ms", name = "Tribunal Regional Eleitoral de Mato Grosso do Sul", type = "TRE"),
    list(alias = "api_publica_tre-mg", name = "Tribunal Regional Eleitoral de Minas Gerais", type = "TRE"),
    list(alias = "api_publica_tre-pa", name = "Tribunal Regional Eleitoral do Pará", type = "TRE"),
    list(alias = "api_publica_tre-pb", name = "Tribunal Regional Eleitoral da Paraíba", type = "TRE"),
    list(alias = "api_publica_tre-pr", name = "Tribunal Regional Eleitoral do Paraná", type = "TRE"),
    list(alias = "api_publica_tre-pe", name = "Tribunal Regional Eleitoral de Pernambuco", type = "TRE"),
    list(alias = "api_publica_tre-pi", name = "Tribunal Regional Eleitoral do Piauí", type = "TRE"),
    list(alias = "api_publica_tre-rj", name = "Tribunal Regional Eleitoral do Rio de Janeiro", type = "TRE"),
    list(alias = "api_publica_tre-rn", name = "Tribunal Regional Eleitoral do Rio Grande do Norte", type = "TRE"),
    list(alias = "api_publica_tre-rs", name = "Tribunal Regional Eleitoral do Rio Grande do Sul", type = "TRE"),
    list(alias = "api_publica_tre-ro", name = "Tribunal Regional Eleitoral de Rondônia", type = "TRE"),
    list(alias = "api_publica_tre-rr", name = "Tribunal Regional Eleitoral de Roraima", type = "TRE"),
    list(alias = "api_publica_tre-sc", name = "Tribunal Regional Eleitoral de Santa Catarina", type = "TRE"),
    list(alias = "api_publica_tre-sp", name = "Tribunal Regional Eleitoral de São Paulo", type = "TRE"),
    list(alias = "api_publica_tre-se", name = "Tribunal Regional Eleitoral de Sergipe", type = "TRE"),
    list(alias = "api_publica_tre-to", name = "Tribunal Regional Eleitoral do Tocantins", type = "TRE"),

    # Federal Regional Courts (TRF)
    list(alias = "api_publica_trf1", name = "Tribunal Regional Federal da 1\u00aa Regi\u00e3o", type = "TRF"),
    list(alias = "api_publica_trf2", name = "Tribunal Regional Federal da 2\u00aa Regi\u00e3o", type = "TRF"),
    list(alias = "api_publica_trf3", name = "Tribunal Regional Federal da 3\u00aa Regi\u00e3o", type = "TRF"),
    list(alias = "api_publica_trf4", name = "Tribunal Regional Federal da 4\u00aa Regi\u00e3o", type = "TRF"),
    list(alias = "api_publica_trf5", name = "Tribunal Regional Federal da 5\u00aa Regi\u00e3o", type = "TRF"),
    list(alias = "api_publica_trf6", name = "Tribunal Regional Federal da 6\u00aa Regi\u00e3o", type = "TRF"),

    # State Courts (TJSP, TJRJ, etc.)
    list(alias = "api_publica_tjac", name = "Tribunal de Justi\u00e7a do Acre", type = "TJ"),
    list(alias = "api_publica_tjal", name = "Tribunal de Justi\u00e7a de Alagoas", type = "TJ"),
    list(alias = "api_publica_tjap", name = "Tribunal de Justi\u00e7a do Amap\u00e1", type = "TJ"),
    list(alias = "api_publica_tjam", name = "Tribunal de Justi\u00e7a do Amazonas", type = "TJ"),
    list(alias = "api_publica_tjba", name = "Tribunal de Justi\u00e7a da Bahia", type = "TJ"),
    list(alias = "api_publica_tjce", name = "Tribunal de Justi\u00e7a do Cear\u00e1", type = "TJ"),
    list(alias = "api_publica_tjdft", name = "Tribunal de Justi\u00e7a do Distrito Federal e Territ\u00f3rios", type = "TJ"),
    list(alias = "api_publica_tjes", name = "Tribunal de Justi\u00e7a do Esp\u00edrito Santo", type = "TJ"),
    list(alias = "api_publica_tjgo", name = "Tribunal de Justi\u00e7a de Goi\u00e1s", type = "TJ"),
    list(alias = "api_publica_tjma", name = "Tribunal de Justi\u00e7a do Maranh\u00e3o", type = "TJ"),
    list(alias = "api_publica_tjmt", name = "Tribunal de Justi\u00e7a de Mato Grosso", type = "TJ"),
    list(alias = "api_publica_tjms", name = "Tribunal de Justi\u00e7a de Mato Grosso do Sul", type = "TJ"),
    list(alias = "api_publica_tjmg", name = "Tribunal de Justi\u00e7a de Minas Gerais", type = "TJ"),
    list(alias = "api_publica_tjpa", name = "Tribunal de Justi\u00e7a do Par\u00e1", type = "TJ"),
    list(alias = "api_publica_tjpb", name = "Tribunal de Justi\u00e7a da Para\u00edba", type = "TJ"),
    list(alias = "api_publica_tjpr", name = "Tribunal de Justi\u00e7a do Paran\u00e1", type = "TJ"),
    list(alias = "api_publica_tjpe", name = "Tribunal de Justi\u00e7a de Pernambuco", type = "TJ"),
    list(alias = "api_publica_tjpi", name = "Tribunal de Justi\u00e7a do Piau\u00ed", type = "TJ"),
    list(alias = "api_publica_tjrj", name = "Tribunal de Justi\u00e7a do Rio de Janeiro", type = "TJ"),
    list(alias = "api_publica_tjrn", name = "Tribunal de Justi\u00e7a do Rio Grande do Norte", type = "TJ"),
    list(alias = "api_publica_tjrs", name = "Tribunal de Justi\u00e7a do Rio Grande do Sul", type = "TJ"),
    list(alias = "api_publica_tjro", name = "Tribunal de Justi\u00e7a de Rond\u00f4nia", type = "TJ"),
    list(alias = "api_publica_tjrr", name = "Tribunal de Justi\u00e7a de Roraima", type = "TJ"),
    list(alias = "api_publica_tjsc", name = "Tribunal de Justi\u00e7a de Santa Catarina", type = "TJ"),
    list(alias = "api_publica_tjsp", name = "Tribunal de Justi\u00e7a de S\u00e3o Paulo", type = "TJ"),
    list(alias = "api_publica_tjse", name = "Tribunal de Justi\u00e7a de Sergipe", type = "TJ"),
    list(alias = "api_publica_tjto", name = "Tribunal de Justi\u00e7a do Tocantins", type = "TJ"),

    # Labor Courts (TRT)
    list(alias = "api_publica_trt1", name = "Tribunal Regional do Trabalho da 1\u00aa Regi\u00e3o", type = "TRT"),
    list(alias = "api_publica_trt2", name = "Tribunal Regional do Trabalho da 2\u00aa Regi\u00e3o", type = "TRT"),
    list(alias = "api_publica_trt3", name = "Tribunal Regional do Trabalho da 3\u00aa Regi\u00e3o", type = "TRT"),
    list(alias = "api_publica_trt4", name = "Tribunal Regional do Trabalho da 4\u00aa Regi\u00e3o", type = "TRT"),
    list(alias = "api_publica_trt5", name = "Tribunal Regional do Trabalho da 5\u00aa Regi\u00e3o", type = "TRT"),
    list(alias = "api_publica_trt6", name = "Tribunal Regional do Trabalho da 6\u00aa Regi\u00e3o", type = "TRT"),
    list(alias = "api_publica_trt7", name = "Tribunal Regional do Trabalho da 7\u00aa Regi\u00e3o", type = "TRT"),
    list(alias = "api_publica_trt8", name = "Tribunal Regional do Trabalho da 8\u00aa Regi\u00e3o", type = "TRT"),
    list(alias = "api_publica_trt9", name = "Tribunal Regional do Trabalho da 9\u00aa Regi\u00e3o", type = "TRT"),
    list(alias = "api_publica_trt10", name = "Tribunal Regional do Trabalho da 10\u00aa Regi\u00e3o", type = "TRT"),
    list(alias = "api_publica_trt11", name = "Tribunal Regional do Trabalho da 11\u00aa Regi\u00e3o", type = "TRT"),
    list(alias = "api_publica_trt12", name = "Tribunal Regional do Trabalho da 12\u00aa Regi\u00e3o", type = "TRT"),
    list(alias = "api_publica_trt13", name = "Tribunal Regional do Trabalho da 13\u00aa Regi\u00e3o", type = "TRT"),
    list(alias = "api_publica_trt14", name = "Tribunal Regional do Trabalho da 14\u00aa Regi\u00e3o", type = "TRT"),
    list(alias = "api_publica_trt15", name = "Tribunal Regional do Trabalho da 15\u00aa Regi\u00e3o", type = "TRT"),
    list(alias = "api_publica_trt16", name = "Tribunal Regional do Trabalho da 16\u00aa Regi\u00e3o", type = "TRT"),
    list(alias = "api_publica_trt17", name = "Tribunal Regional do Trabalho da 17\u00aa Regi\u00e3o", type = "TRT"),
    list(alias = "api_publica_trt18", name = "Tribunal Regional do Trabalho da 18\u00aa Regi\u00e3o", type = "TRT"),
    list(alias = "api_publica_trt19", name = "Tribunal Regional do Trabalho da 19\u00aa Regi\u00e3o", type = "TRT"),
    list(alias = "api_publica_trt20", name = "Tribunal Regional do Trabalho da 20\u00aa Regi\u00e3o", type = "TRT"),
    list(alias = "api_publica_trt21", name = "Tribunal Regional do Trabalho da 21\u00aa Regi\u00e3o", type = "TRT"),
    list(alias = "api_publica_trt22", name = "Tribunal Regional do Trabalho da 22\u00aa Regi\u00e3o", type = "TRT"),
    list(alias = "api_publica_trt23", name = "Tribunal Regional do Trabalho da 23\u00aa Regi\u00e3o", type = "TRT"),
    list(alias = "api_publica_trt24", name = "Tribunal Regional do Trabalho da 24\u00aa Regi\u00e3o", type = "TRT")
  )

  tibble::tibble(
    alias = sapply(tribunals_data, function(x) x$alias),
    name = sapply(tribunals_data, function(x) x$name),
    type = sapply(tribunals_data, function(x) x$type)
  )
}

#' Normalize Tribunal Name
#'
#' @description
#' Converts short tribunal names to the full API alias format.
#' Accepts both short forms (e.g., "trf1", "tjsp") and full forms (e.g., "api_publica_trf1").
#'
#' @param tribunal Character string with the tribunal name (short or full).
#'
#' @return Character string with the normalized tribunal alias (api_publica_XXX format).
#' @export
#'
#' @examples
#' normalize_tribunal("trf1")  # Returns "api_publica_trf1"
#' normalize_tribunal("api_publica_trf1")  # Returns "api_publica_trf1"
#' normalize_tribunal("tjsp")  # Returns "api_publica_tjsp"
normalize_tribunal <- function(tribunal) {
  # If already in correct format, return as is
  if (grepl("^api_publica_", tribunal)) {
    if (!validate_tribunal(tribunal)) {
      stop("Invalid tribunal alias: ", tribunal, ". Use list_tribunals() to see available options.")
    }
    return(tribunal)
  }

  # Convert short name to full format
  full_name <- paste0("api_publica_", tolower(tribunal))

  # Validate
  if (!validate_tribunal(full_name)) {
    stop("Invalid tribunal: ", tribunal, ". Use list_tribunals() to see available options.")
  }

  full_name
}

#' Validate Tribunal Alias
#'
#' @description
#' Checks if a tribunal alias is valid.
#'
#' @param tribunal Character string with the tribunal alias.
#'
#' @return TRUE if valid, FALSE otherwise.
#' @keywords internal
validate_tribunal <- function(tribunal) {
  valid_tribunals <- list_tribunals()$alias
  tribunal %in% valid_tribunals
}
