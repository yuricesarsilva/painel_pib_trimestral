# Testa tipos de matriz MSC e endpoint RREO para municípios de RR
library(httr2)
library(dplyr)

BASE_MSC  <- "https://apidatalake.tesouro.gov.br/ords/siconfi/tt/msc_orcamentaria"
BASE_RREO <- "https://apidatalake.tesouro.gov.br/ords/siconfi/tt/rreo"
ID_BV <- 1400100  # Boa Vista

consultar <- function(url, params, descricao) {
  cat(sprintf("\n=== %s ===\n", descricao))
  Sys.sleep(0.5)
  tryCatch({
    req <- request(url)
    for (nm in names(params)) req <- req |> req_url_query(.data = setNames(list(params[[nm]]), nm))
    resp <- req |> req_timeout(30) |> req_perform()
    d    <- resp |> resp_body_json(simplifyVector = TRUE)
    df   <- as.data.frame(d$items)
    cat("Linhas:", nrow(df), "\n")
    if (nrow(df) > 0) {
      cat("Colunas:", paste(names(df), collapse = ", "), "\n")
      print(head(df, 4))
    }
    invisible(df)
  }, error = function(e) { cat("ERRO:", conditionMessage(e), "\n"); invisible(NULL) })
}

# Teste 1: MSC sem tipo de matriz
consultar(BASE_MSC,
  list(id_ente=ID_BV, an_exercicio=2023, classe_conta=6, id_tv="period_change"),
  "MSC sem co_tipo_matriz — Boa Vista 2023")

# Teste 2: MSC tipo MSCA
consultar(BASE_MSC,
  list(id_ente=ID_BV, an_exercicio=2023, co_tipo_matriz="MSCA",
       classe_conta=6, id_tv="period_change"),
  "MSC MSCA — Boa Vista 2023")

# Teste 3: RREO sem parâmetros adicionais
consultar(BASE_RREO,
  list(id_ente=ID_BV, an_exercicio=2023),
  "RREO base — Boa Vista 2023")
