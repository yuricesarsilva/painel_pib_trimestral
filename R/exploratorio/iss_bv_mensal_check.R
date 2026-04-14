library(httr2)
library(dplyr)

# Verifica breakdown mensal ISS Boa Vista 2023 — mês a mês
ID_BV <- 1400100

resultados <- list()
for (mes in 1:12) {
  Sys.sleep(0.3)
  resp <- request("https://apidatalake.tesouro.gov.br/ords/siconfi/tt/msc_orcamentaria") |>
    req_url_query(
      id_ente        = ID_BV,
      an_referencia  = 2023,
      me_referencia  = mes,
      co_tipo_matriz = "MSCC",
      classe_conta   = 6,
      id_tv          = "period_change"
    ) |>
    req_timeout(30) |>
    req_error(is_error = function(r) FALSE) |>
    req_perform()

  d <- resp |> resp_body_json(simplifyVector = TRUE)
  df <- as.data.frame(d$items)

  # ISS: natureza 1112x, crédito
  iss <- df |> filter(grepl("^1112", natureza_receita), natureza_conta == "C")

  # ISS só principal (11125001)
  iss_princ <- iss |> filter(natureza_receita == "11125001")

  cat(sprintf("Mês %2d | ISS total = R$ %10.0f | ISS 11125001 = R$ %10.0f | linhas iss=%d\n",
              mes, sum(iss$valor), sum(iss_princ$valor), nrow(iss)))

  resultados[[mes]] <- data.frame(
    mes        = mes,
    iss_total  = sum(iss$valor),
    iss_princ  = sum(iss_princ$valor),
    n_linhas   = nrow(iss)
  )
}

df_bv <- bind_rows(resultados)
cat("\n--- Boa Vista 2023: ISS mensal (R$ mi) ---\n")
df_bv$iss_total_mi <- df_bv$iss_total / 1e6
df_bv$iss_princ_mi <- df_bv$iss_princ / 1e6
print(df_bv)
cat(sprintf("\nTotal anual ISS (todos):      R$ %.1f mi\n", sum(df_bv$iss_total_mi)))
cat(sprintf("Total anual ISS (11125001):   R$ %.1f mi\n", sum(df_bv$iss_princ_mi)))
