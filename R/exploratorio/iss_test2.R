library(httr2)

BASE_MSC  <- "https://apidatalake.tesouro.gov.br/ords/siconfi/tt/msc_orcamentaria"
BASE_RREO <- "https://apidatalake.tesouro.gov.br/ords/siconfi/tt/rreo"
ID_BV <- 1400100  # Boa Vista

fazer_req <- function(url, ...) {
  args <- list(...)
  req <- request(url)
  for (nm in names(args)) {
    req <- req_url_query(req, .data = setNames(list(args[[nm]]), nm))
  }
  req |> req_timeout(30) |> req_perform() |> resp_body_json(simplifyVector = TRUE)
}

# --- MSC sem tipo ---
cat("=== MSC sem co_tipo_matriz ===\n")
Sys.sleep(0.5)
tryCatch({
  d  <- fazer_req(BASE_MSC, id_ente=ID_BV, an_exercicio=2023,
                  classe_conta=6, id_tv="period_change")
  df <- as.data.frame(d$items)
  cat("Linhas:", nrow(df), "\n")
  if (nrow(df) > 0) { cat("Cols:", paste(names(df), collapse=", "), "\n"); print(head(df,3)) }
}, error=function(e) cat("ERRO:", conditionMessage(e), "\n"))

# --- MSC MSCA ---
cat("\n=== MSC co_tipo_matriz=MSCA ===\n")
Sys.sleep(0.5)
tryCatch({
  d  <- fazer_req(BASE_MSC, id_ente=ID_BV, an_exercicio=2023,
                  co_tipo_matriz="MSCA", classe_conta=6, id_tv="period_change")
  df <- as.data.frame(d$items)
  cat("Linhas:", nrow(df), "\n")
  if (nrow(df) > 0) { cat("Cols:", paste(names(df), collapse=", "), "\n"); print(head(df,3)) }
}, error=function(e) cat("ERRO:", conditionMessage(e), "\n"))

# --- RREO ---
cat("\n=== RREO Boa Vista 2023 ===\n")
Sys.sleep(0.5)
tryCatch({
  d  <- fazer_req(BASE_RREO, id_ente=ID_BV, an_exercicio=2023)
  df <- as.data.frame(d$items)
  cat("Linhas:", nrow(df), "\n")
  if (nrow(df) > 0) { cat("Cols:", paste(names(df), collapse=", "), "\n"); print(head(df,5)) }
}, error=function(e) cat("ERRO:", conditionMessage(e), "\n"))

# --- RREO com periodo ---
cat("\n=== RREO Boa Vista 2023 bimestre 6 ===\n")
Sys.sleep(0.5)
tryCatch({
  d  <- fazer_req(BASE_RREO, id_ente=ID_BV, an_exercicio=2023, nr_periodo=6,
                  co_tipo_demonstrativo="RREO")
  df <- as.data.frame(d$items)
  cat("Linhas:", nrow(df), "\n")
  if (nrow(df) > 0) { cat("Cols:", paste(names(df), collapse=", "), "\n"); print(head(df,5)) }
}, error=function(e) cat("ERRO:", conditionMessage(e), "\n"))
