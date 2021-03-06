mlflow_rest_path <- function(version) {
  switch(
    version,
    "2.0" = "api/2.0/preview/mlflow"
  )
}

#' @importFrom httr timeout
mlflow_rest_timeout <- function() {
  timeout(getOption("mlflow.rest.timeout", 60))
}

#' @importFrom base64enc base64encode
get_rest_config <- function(config) {
  headers <- list()
  auth_header <- if (!is.na(config$username) && !is.na(config$password)) {
    basic_auth_str <- paste(config$username, config$password, sep = ":")
    paste("Basic", base64encode(basic_auth_str), sep = " ")
  } else if (!is.na(config$token)) {
    paste("Bearer", config$token, sep = " ")
  } else {
    NA
  }
  if (!is.na(auth_header)) {
    headers$Authorization <- auth_header
  }
  verify_peer <- list(true = 0, false = 1)[[tolower(config$insecure)]]
  list(headers = headers, verify_peer = verify_peer)
}

mlflow_rest <- function( ..., client, query = NULL, data = NULL, verb = "GET", version = "2.0") {
  host_creds <- client$get_host_creds()
  rest_config <- get_rest_config(host_creds)
  args <- list(...)
  api_url <- file.path(
    host_creds$host,
    mlflow_rest_path(version),
    paste(args, collapse = "/")
  )
  config <- config(config(ssl_verifypeer = rest_config$verify_peer))
  headers <- rest_config$headers
  response <- switch(
    verb,
    GET = GET(
      api_url,
      query = query,
      mlflow_rest_timeout(),
      config = config,
      do.call(add_headers, headers)),
    POST = POST(
      api_url,
      body = if (is.null(data)) NULL else rapply(data, as.character, how = "replace"),
      encode = "json",
      mlflow_rest_timeout(),
      config = config,
      do.call(add_headers, headers)
    ),
    stop("Verb '", verb, "' is unsupported.")
  )
  if (identical(response$status_code, 500L)) {
    stop(xml2::as_list(content(response))$html$body$p[[1]])
  }
  text <- content(response, "text", encoding = "UTF-8")
  jsonlite::fromJSON(text)
}
