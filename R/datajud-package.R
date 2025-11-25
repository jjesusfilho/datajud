#' datajud: Access and Download Data from the DataJud API
#'
#' @description
#' The datajud package provides functions to access and download judicial process
#' metadata from the DataJud Public API, maintained by the Brazilian National
#' Council of Justice (CNJ).
#'
#' @section Authentication:
#' Before using the package, you need to set an API key using \code{set_api_key()}.
#' You can use the default public key provided by CNJ with \code{get_default_api_key()},
#' or set your own key.
#'
#' @section Main functions:
#' \itemize{
#'   \item \code{set_api_key()}: Set the API key for authentication
#'   \item \code{list_tribunals()}: List all available tribunals
#'   \item \code{search_cnj()}: Search by CNJ process number
#'   \item \code{search_by_class()}: Search by process class and court body
#'   \item \code{search_by_date()}: Search by date range
#'   \item \code{search_advanced()}: Advanced search with query strings
#'   \item \code{search_datajud()}: General purpose search with custom queries
#' }
#'
#' @section API Documentation:
#' For more information about the DataJud API, visit:
#' \url{https://datajud-wiki.cnj.jus.br/api-publica/}
#'
#' @docType package
#' @name datajud-package
#' @aliases datajud
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
## usethis namespace: end
NULL
