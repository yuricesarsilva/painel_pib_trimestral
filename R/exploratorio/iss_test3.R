library(httr2)

BASE_MSC  <- "https://apidatalake.tesouro.gov.br/ords/siconfi/tt/msc_orcamentaria"
BASE_RREO <- "https://apidatalake.tesouro.gov.br/ords/siconfi/tt/rreo"

# Boa Vista — código IBGE = 1400100
# Siconfi pode usar o mesmo ou um código diferente
ID_BV_IBGE <- 1400100

# --- MSC para Boa Vista: jan/2023, MSCC ---
cat("=== MSC MSCC Boa Vista jan/2023 ===\n")
Sys.sleep(0.5)
tryCatch({
  resp <- request(BASE_MSC) |>
    req_url_query(
      id_ente        = ID_BV_IBGE,
      an_referencia  = 2023,
      me_referencia  = 1,
      co_tipo_matriz = "MSCC",
      classe_conta   = 6,
      id_tv          = "period_change"
    ) |>
    req_timeout(30) |>
    req_error(is_error = function(r) FALSE) |>
    req_perform()
  cat("Status:", resp_status(resp), "\n")
  d <- resp |> resp_body_json(simplifyVector = TRUE)
  df <- as.data.frame(d$items)
  cat("Linhas:", nrow(df), "\n")
  if (nrow(df) > 0) { cat("Cols:", paste(names(df), collapse=", "), "\n"); print(head(df,3)) }
}, error=function(e) cat("ERRO:", conditionMessage(e), "\n"))

# --- MSC sem tipo de matriz ---
cat("\n=== MSC sem co_tipo_matriz Boa Vista jan/2023 ===\n")
Sys.sleep(0.5)
tryCatch({
  resp <- request(BASE_MSC) |>
    req_url_query(
      id_ente        = ID_BV_IBGE,
      an_referencia  = 2023,
      me_referencia  = 1,
      classe_conta   = 6,
      id_tv          = "period_change"
    ) |>
    req_timeout(30) |>
    req_error(is_error = function(r) FALSE) |>
    req_perform()
  cat("Status:", resp_status(resp), "\n")
  d <- resp |> resp_body_json(simplifyVector = TRUE)
  df <- as.data.frame(d$items)
  cat("Linhas:", nrow(df), "\n")
  if (nrow(df) > 0) { cat("Cols:", paste(names(df), collapse=", "), "\n"); print(head(df,3)) }
}, error=function(e) cat("ERRO:", conditionMessage(e), "\n"))

# --- MSC MSCA ---
cat("\n=== MSC MSCA Boa Vista jan/2023 ===\n")
Sys.sleep(0.5)
tryCatch({
  resp <- request(BASE_MSC) |>
    req_url_query(
      id_ente        = ID_BV_IBGE,
      an_referencia  = 2023,
      me_referencia  = 1,
      co_tipo_matriz = "MSCA",
      classe_conta   = 6,
      id_tv          = "period_change"
    ) |>
    req_timeout(30) |>
    req_error(is_error = function(r) FALSE) |>
    req_perform()
  cat("Status:", resp_status(resp), "\n")
  d <- resp |> resp_body_json(simplifyVector = TRUE)
  df <- as.data.frame(d$items)
  cat("Linhas:", nrow(df), "\n")
  if (nrow(df) > 0) { cat("Cols:", paste(names(df), collapse=", "), "\n"); print(head(df,3)) }
}, error=function(e) cat("ERRO:", conditionMessage(e), "\n"))

# --- RREO bimestre 2 de 2023 ---
cat("\n=== RREO Boa Vista bimestre 2/2023 ===\n")
Sys.sleep(0.5)
tryCatch({
  resp <- request(BASE_RREO) |>
    req_url_query(
      id_ente              = ID_BV_IBGE,
      an_exercicio         = 2023,
      nr_periodo           = 2,
      co_tipo_demonstrativo = "RREO"
    ) |>
    req_timeout(30) |>
    req_error(is_error = function(r) FALSE) |>
    req_perform()
  cat("Status:", resp_status(resp), "\n")
  d <- resp |> resp_body_json(simplifyVector = TRUE)
  df <- as.data.frame(d$items)
  cat("Linhas:", nrow(df), "\n")
  if (nrow(df) > 0) {
    cat("Cols:", paste(names(df), collapse=", "), "\n")
    # Busca ISS
    for (col in names(df)) {
      if (any(grepl("ISS|servi", df[[col]], ignore.case=TRUE))) {
        cat(sprintf("Coluna '%s' tem ISS:\n", col))
        print(df[grepl("ISS|servi", df[[col]], ignore.case=TRUE), ])
      }
    }
    print(head(df, 5))
  }
}, error=function(e) cat("ERRO:", conditionMessage(e), "\n"))
