# R/exploratorio/iss_siconfi_municipios_rr.R
#
# Exploração: ISS mensal dos municípios de Roraima via Siconfi/MSC
#
# Estratégia: consultar o endpoint MSC para cada município de RR (15 entes),
# filtrar pela conta contábil de ISS (receita realizada) e agregar.
#
# Referência metodológica: análoga ao ICMS estadual, mas com id_ente = código
# de cada município. A conta de ISS nas Contas de Receita é a 6212200000 ou
# similar — a identificar nesta exploração.
#
# Municípios de Roraima (IBGE 7 dígitos → Siconfi usa os mesmos códigos):
#   1400027 Alto Alegre     1400050 Amajari       1400100 Boa Vista
#   1400159 Bonfim          1400175 Cantá          1400209 Caracaraí
#   1400233 Caroebe         1400282 Iracema        1400308 Mucajaí
#   1400407 Normandia       1400456 Pacaraima      1400472 Rorainópolis
#   1400506 São João da Baliza  1400605 São Luiz  1400704 Uiramutã

library(httr2)
library(dplyr)
library(readr)

BASE_URL <- "https://apidatalake.tesouro.gov.br/ords/siconfi/tt/msc_orcamentaria"

municipios_rr <- c(
  "Alto Alegre"       = 1400027,
  "Amajari"           = 1400050,
  "Boa Vista"         = 1400100,
  "Bonfim"            = 1400159,
  "Cantá"             = 1400175,
  "Caracaraí"         = 1400209,
  "Caroebe"           = 1400233,
  "Iracema"           = 1400282,
  "Mucajaí"           = 1400308,
  "Normandia"         = 1400407,
  "Pacaraima"         = 1400456,
  "Rorainópolis"      = 1400472,
  "São João da Baliza"= 1400506,
  "São Luiz"          = 1400605,
  "Uiramutã"          = 1400704
)

# Período de teste inicial: 2023 (ano com benchmark CR disponível)
ANOS_TESTE <- c(2023)

# Parâmetros MSC — mesma lógica usada para o ICMS estadual
# co_tipo_matriz = MSCC (balancete mensal)
# classe_conta   = 6    (receitas)
# id_tv          = period_change (realizações do período)
# conta_contabil = ?    → a identificar; candidatos:
#   6212100000 (ISS — serviços de qualquer natureza)
#   6212200000 (alternativa)
#   621200000  (nível mais alto, receita tributária municipal)

buscar_iss <- function(id_ente, ano, nome_municipio) {
  Sys.sleep(0.4)  # respeita rate limit
  tryCatch({
    resp <- request(BASE_URL) |>
      req_url_query(
        id_ente       = id_ente,
        an_exercicio  = ano,
        co_tipo_matriz = "MSCC",
        classe_conta  = 6,
        id_tv         = "period_change"
      ) |>
      req_timeout(30) |>
      req_perform()

    dados <- resp |> resp_body_json(simplifyVector = TRUE)
    df    <- as.data.frame(dados$items)

    if (nrow(df) == 0) {
      cat(sprintf("  [%s] %d — sem dados\n", nome_municipio, ano))
      return(NULL)
    }

    # Mostra contas únicas disponíveis para inspecionar onde ISS aparece
    cat(sprintf("\n=== %s (%d) — %d linhas ===\n", nome_municipio, ano, nrow(df)))
    cat("Colunas:", paste(names(df), collapse=", "), "\n")

    # Filtra contas com "ISS" ou "serviço" no nome (case-insensitive)
    if ("no_conta" %in% names(df)) {
      iss_rows <- df[grepl("iss|servi", df$no_conta, ignore.case=TRUE), ]
      if (nrow(iss_rows) > 0) {
        cat("Contas com ISS/serviço:\n")
        print(iss_rows[, intersect(c("no_conta","co_conta","vl_periodo","no_mes"), names(iss_rows))])
      }
    }

    if ("conta_contabil" %in% names(df)) {
      iss_cc <- df[grepl("^6212", df$conta_contabil), ]
      if (nrow(iss_cc) > 0) {
        cat("Contas 6212x:\n")
        print(iss_cc[, intersect(c("conta_contabil","no_conta","vl_periodo","no_mes"), names(iss_cc))])
      }
    }

    df$municipio <- nome_municipio
    df$id_ente   <- id_ente
    df

  }, error = function(e) {
    cat(sprintf("  ERRO [%s]: %s\n", nome_municipio, conditionMessage(e)))
    NULL
  })
}

# --- teste com 3 municípios primeiro para ver a estrutura -------------------
cat("=== Fase 1: inspecionar estrutura para 3 municípios ===\n\n")
municipios_teste <- municipios_rr[c("Boa Vista", "Caracaraí", "Rorainópolis")]

resultados <- list()
for (i in seq_along(municipios_teste)) {
  nome <- names(municipios_teste)[i]
  id   <- municipios_teste[[i]]
  cat(sprintf("[%d/%d] Consultando %s (id_ente=%d)...\n", i, length(municipios_teste), nome, id))
  r <- buscar_iss(id, ANOS_TESTE[1], nome)
  if (!is.null(r)) resultados[[nome]] <- r
}

cat("\n=== Resumo da inspeção ===\n")
if (length(resultados) > 0) {
  todos <- bind_rows(resultados)
  cat("Total de linhas retornadas:", nrow(todos), "\n")
  cat("Colunas disponíveis:", paste(names(todos), collapse=", "), "\n")

  # Tenta identificar a conta de ISS
  if ("conta_contabil" %in% names(todos)) {
    contas_6 <- todos[grepl("^6", todos$conta_contabil), ]
    contas_unicas <- unique(contas_6[, c("conta_contabil",
      if("no_conta" %in% names(todos)) "no_conta" else NULL)])
    cat("\nContas de receita (classe 6) disponíveis:\n")
    print(contas_unicas)
  }
} else {
  cat("Nenhum resultado obtido.\n")
}
