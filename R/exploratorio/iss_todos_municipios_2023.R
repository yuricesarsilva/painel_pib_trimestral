# Extrai ISS mensal de todos os 15 municípios de RR via Siconfi MSC (2023)
# Objetivo: validar totais contra o ILP anual e confirmar a rota de extração
library(httr2)
library(dplyr)
library(readr)

municipios_rr <- c(
  "Alto Alegre"        = 1400027,
  "Amajari"            = 1400050,
  "Boa Vista"          = 1400100,
  "Bonfim"             = 1400159,
  "Cantá"              = 1400175,
  "Caracaraí"          = 1400209,
  "Caroebe"            = 1400233,
  "Iracema"            = 1400282,
  "Mucajaí"            = 1400308,
  "Normandia"          = 1400407,
  "Pacaraima"          = 1400456,
  "Rorainópolis"       = 1400472,
  "São João da Baliza" = 1400506,
  "São Luiz"           = 1400605,
  "Uiramutã"           = 1400704
)

buscar_iss_mes <- function(id_ente, nome, ano, mes) {
  Sys.sleep(0.3)
  tryCatch({
    resp <- request("https://apidatalake.tesouro.gov.br/ords/siconfi/tt/msc_orcamentaria") |>
      req_url_query(
        id_ente        = id_ente,
        an_referencia  = ano,
        me_referencia  = mes,
        co_tipo_matriz = "MSCC",
        classe_conta   = 6,
        id_tv          = "period_change"
      ) |>
      req_timeout(30) |>
      req_error(is_error = function(r) FALSE) |>
      req_perform()

    if (resp_status(resp) != 200) return(NULL)
    d <- resp |> resp_body_json(simplifyVector = TRUE)
    df <- as.data.frame(d$items)
    if (nrow(df) == 0) return(NULL)

    # Filtra ISS: natureza 1112xxxx, crédito (realização positiva)
    iss <- df |>
      filter(grepl("^1112", natureza_receita),
             natureza_conta == "C")

    if (nrow(iss) == 0) return(data.frame(municipio=nome, id_ente=id_ente,
                                           ano=ano, mes=mes, iss_reais=0))
    data.frame(
      municipio = nome,
      id_ente   = id_ente,
      ano       = ano,
      mes       = mes,
      iss_reais = sum(iss$valor, na.rm = TRUE)
    )
  }, error = function(e) {
    cat(sprintf("  ERRO %s %d-%02d: %s\n", nome, ano, mes, conditionMessage(e)))
    NULL
  })
}

# --- Extrai jan–dez/2023 para todos os municípios --------------------------
cat("Extraindo ISS 2023 para 15 municípios de RR...\n")
cat(sprintf("Total de requisições: %d × 12 = %d\n\n",
            length(municipios_rr), length(municipios_rr) * 12))

resultados <- list()
for (i in seq_along(municipios_rr)) {
  nome <- names(municipios_rr)[i]
  id   <- municipios_rr[[i]]
  cat(sprintf("[%2d/15] %s... ", i, nome))
  meses <- lapply(1:12, function(m) buscar_iss_mes(id, nome, 2023, m))
  meses <- Filter(Negate(is.null), meses)
  if (length(meses) > 0) {
    df_mun <- bind_rows(meses)
    anual  <- sum(df_mun$iss_reais) / 1e6
    cat(sprintf("ISS 2023 = R$ %.1f mi (%d meses)\n", anual, nrow(df_mun)))
    resultados[[nome]] <- df_mun
  } else {
    cat("sem dados\n")
  }
}

# --- Consolida e resume -----------------------------------------------------
if (length(resultados) > 0) {
  todos <- bind_rows(resultados)

  cat("\n=== Resumo anual ISS 2023 por município (R$ mi) ===\n")
  resumo_mun <- todos |>
    group_by(municipio) |>
    summarise(iss_mi = sum(iss_reais)/1e6, n_meses = n(), .groups="drop") |>
    arrange(desc(iss_mi))
  print(resumo_mun, n=20)

  total_iss_2023 <- sum(todos$iss_reais) / 1e6
  cat(sprintf("\nTOTAL ISS RR 2023: R$ %.1f mi\n", total_iss_2023))
  cat(sprintf("ICMS RR 2023:      R$ 1707.4 mi\n"))
  cat(sprintf("ILP RR 2023:       R$ 2122.0 mi\n"))
  cat(sprintf("ICMS+ISS / ILP:    %.1f%%\n", (1707.4 + total_iss_2023)/2122.0*100))

  cat("\n=== Resumo trimestral ISS 2023 (todos municípios) ===\n")
  resumo_trim <- todos |>
    mutate(trim = ceiling(mes/3)) |>
    group_by(trim) |>
    summarise(iss_mi = sum(iss_reais)/1e6, .groups="drop")
  print(resumo_trim)

  write_csv(todos, "data/processed/iss_municipios_rr_2023.csv")
  cat("\nSalvo em: data/processed/iss_municipios_rr_2023.csv\n")
}
