#' Set DataJud API Key
#'
#' @description
#' Sets the API key for accessing the DataJud API. The key can be set
#' as an environment variable or stored in the R session.
#'
#' @param api_key Character string with the DataJud API key. If NULL,
#'   the function will look for the key in the environment variable
#'   DATAJUD_API_KEY.
#'
#' @return Invisibly returns the API key if successfully set.
#' @export
#'
#' @examples
#' \dontrun{
#' # Set API key directly
#' set_api_key("cDZHYzlZa0JadVREZDJCendQbXY6SkJlTzNjLV9TRENyQk1RdnFKZGRQdw==")
#'
#' # Or set via environment variable
#' Sys.setenv(DATAJUD_API_KEY = "your_api_key_here")
#' set_api_key()
#' }
set_api_key <- function(api_key = NULL) {
  if (is.null(api_key)) {
    api_key <- Sys.getenv("DATAJUD_API_KEY")
    if (api_key == "") {
      stop("API key not found. Please provide an api_key or set DATAJUD_API_KEY environment variable.")
    }
  }

  options(datajud_api_key = api_key)
  invisible(api_key)
}

#' Get DataJud API Key
#'
#' @description
#' Retrieves the DataJud API key from R options or environment variables.
#'
#' @return Character string with the API key.
#' @keywords internal
get_api_key <- function() {
  api_key <- getOption("datajud_api_key")

  if (is.null(api_key)) {
    api_key <- Sys.getenv("DATAJUD_API_KEY")
    if (api_key == "") {
      stop(
        "API key not set. Use set_api_key() or set the DATAJUD_API_KEY environment variable.\n",
        "The default public key is: cDZHYzlZa0JadVREZDJCendQbXY6SkJlTzNjLV9TRENyQk1RdnFKZGRQdw=="
      )
    }
  }

  api_key
}

#' Get Default DataJud API Key
#'
#' @description
#' Returns the default public API key provided by CNJ. This key may change
#' at any time, so check the official documentation for the current key.
#'
#' @return Character string with the default public API key.
#' @export
#'
#' @examples
#' get_default_api_key()
get_default_api_key <- function() {
  "cDZHYzlZa0JadVREZDJCendQbXY6SkJlTzNjLV9TRENyQk1RdnFKZGRQdw=="
}
