# ============================================================
# Projeto : Indicador de Atividade Econômica Trimestral — RR
# Script  : inspecionar_siconfi_icms_rr.R
# Autor   : Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)
# Data    : 2026-04-13
# Descrição: Inspeciona e extrai a série mensal de ICMS do Estado
#            de Roraima via MSC orçamentária do Siconfi.
# Entrada : API Siconfi / MSC Orçamentária
# Saída   : data/raw/icms_rr_siconfi_mensal_detalhado.csv
#            data/raw/icms_rr_siconfi_mensal_total.csv
# Depende : httr2, dplyr, tidyr, readr, purrr, R/utils.R
# Nota    : A rota validada para arrecadação mensal observada usa:
#           id_ente = 14, co_tipo_matriz = MSCC, classe_conta = 6,
#           id_tv = "period_change", conta_contabil = 621200000
#           (receita realizada). Somar todas as contas contábeis da
#           classe 6 superestima janeiro, pois mistura previsão,
#           realização e ajustes/deduções orçamentárias.
# ============================================================

source("R/utils.R")

library(httr2)
library(dplyr)
library(tidyr)
library(readr)
library(purrr)

# --- Caminhos -----------------------------------------------

dir_raw <- file.path("data", "raw")
dir.create(dir_raw, recursive = TRUE, showWarnings = FALSE)

arq_icms_detalhado <- file.path(dir_raw, "icms_rr_siconfi_mensal_detalhado.csv")
arq_icms_total     <- file.path(dir_raw, "icms_rr_siconfi_mensal_total.csv")

# --- Parâmetros ---------------------------------------------

id_ente_rr <- 14L
ano_inicio <- 2020L
ano_fim    <- as.integer(format(Sys.Date(), "%Y"))
mes_fim    <- as.integer(format(Sys.Date(), "%m"))

codes_icms <- c(
  "11145011", # principal (classificador novo)
  "11145013", # dívida ativa (classificador novo)
  "11145015", # multas (classificador novo)
  "11145016", # juros de mora (classificador novo)
  "11145017", # dívida ativa - multas (classificador novo)
  "11145018", # dívida ativa - juros (classificador novo)
  "11180211", # principal (classificador anterior)
  "11180213", # dívida ativa (classificador anterior)
  "11180215", # multas (classificador anterior)
  "11180216", # juros de mora (classificador anterior)
  "11180217", # dívida ativa - multas (classificador anterior)
  "11180218"  # dívida ativa - juros (classificador anterior)
)

# --- Funções auxiliares -------------------------------------

siconfi_msc_get <- function(id_ente, ano, mes) {
  resp <- request("https://apidatalake.tesouro.gov.br/ords/siconfi/tt/msc_orcamentaria") |>
    req_url_query(
      id_ente         = id_ente,
      an_referencia   = ano,
      me_referencia   = mes,
      co_tipo_matriz  = "MSCC",
      classe_conta    = 6,
      id_tv           = "period_change"
    ) |>
    req_retry(max_tries = 3, backoff = ~ 2) |>
    req_error(is_error = function(resp) FALSE) |>
    req_perform()

  if (resp_status(resp) != 200) {
    warning(sprintf("Siconfi MSC retornou status %d para %d-%02d.",
                    resp_status(resp), ano, mes), call. = FALSE)
    return(NULL)
  }

  body <- resp_body_json(resp, simplifyVector = TRUE)
  if (is.null(body$items) || length(body$items) == 0) return(NULL)

  as_tibble(body$items)
}

grade_meses <- tidyr::crossing(
  ano = ano_inicio:ano_fim,
  mes = 1:12
) |>
  filter(!(ano == ano_fim & mes > mes_fim))

# --- Coleta --------------------------------------------------

log_msg("Iniciando inspeção do ICMS de RR no Siconfi / MSC.")

msc_bruta <- pmap_dfr(
  grade_meses,
  function(ano, mes) {
    log_msg(sprintf("Consultando MSC orçamentária: %d-%02d", ano, mes))
    dados <- siconfi_msc_get(id_ente_rr, ano, mes)
    if (is.null(dados)) return(tibble())
    dados
  }
)

if (nrow(msc_bruta) == 0) {
  stop("Nenhum dado retornado pela MSC para RR.", call. = FALSE)
}

# --- Filtro metodologicamente correto -----------------------

icms_detalhado <- msc_bruta |>
  filter(
    cod_ibge == id_ente_rr,
    conta_contabil == "621200000",
    natureza_receita %in% codes_icms
  ) |>
  transmute(
    ano                = as.integer(exercicio),
    mes                = as.integer(mes_referencia),
    data_referencia    = as.Date(substr(data_referencia, 1, 10)),
    natureza_receita,
    valor              = as.numeric(valor),
    complemento_fonte  = ifelse(is.na(complemento_fonte), "", complemento_fonte),
    fonte_recursos     = ifelse(is.na(fonte_recursos), "", fonte_recursos),
    poder_orgao        = ifelse(is.na(poder_orgao), "", poder_orgao),
    tipo_matriz,
    conta_contabil
  ) |>
  arrange(ano, mes, natureza_receita, complemento_fonte)

if (nrow(icms_detalhado) == 0) {
  stop("Nenhum registro de ICMS encontrado após os filtros metodológicos.", call. = FALSE)
}

icms_mensal <- icms_detalhado |>
  group_by(ano, mes) |>
  summarise(
    icms_principal          = sum(valor[natureza_receita == "11145011"], na.rm = TRUE),
    icms_divida_ativa       = sum(valor[natureza_receita == "11145013"], na.rm = TRUE),
    icms_multas             = sum(valor[natureza_receita == "11145015"], na.rm = TRUE),
    icms_juros              = sum(valor[natureza_receita == "11145016"], na.rm = TRUE),
    icms_divida_ativa_multa = sum(valor[natureza_receita == "11145017"], na.rm = TRUE),
    icms_divida_ativa_juros = sum(valor[natureza_receita == "11145018"], na.rm = TRUE),
    icms_principal_legacy          = sum(valor[natureza_receita == "11180211"], na.rm = TRUE),
    icms_divida_ativa_legacy       = sum(valor[natureza_receita == "11180213"], na.rm = TRUE),
    icms_multas_legacy             = sum(valor[natureza_receita == "11180215"], na.rm = TRUE),
    icms_juros_legacy              = sum(valor[natureza_receita == "11180216"], na.rm = TRUE),
    icms_divida_ativa_multa_legacy = sum(valor[natureza_receita == "11180217"], na.rm = TRUE),
    icms_divida_ativa_juros_legacy = sum(valor[natureza_receita == "11180218"], na.rm = TRUE),
    icms_total              = sum(valor, na.rm = TRUE),
    n_linhas                = n(),
    .groups = "drop"
  ) |>
  mutate(
    trimestre = ceiling(mes / 3),
    data = as.Date(sprintf("%04d-%02d-01", ano, mes))
  ) |>
  arrange(ano, mes)

# --- QA ------------------------------------------------------

validar_serie(icms_mensal$icms_total, "icms_rr_siconfi_mensal", variacao_max = 1.50, n_min = 12)

# --- Saídas --------------------------------------------------

write_csv(icms_detalhado, arq_icms_detalhado)
write_csv(icms_mensal, arq_icms_total)

log_msg(sprintf("Arquivo detalhado salvo em: %s", arq_icms_detalhado))
log_msg(sprintf("Arquivo mensal consolidado salvo em: %s", arq_icms_total))

log_msg("Resumo metodológico da inspeção:")
log_msg("  - endpoint: /msc_orcamentaria")
log_msg("  - conta contábil usada: 621200000 (receita realizada)")
log_msg("  - códigos ICMS monitorados: 1114501x (novo) e 1118021x (legado)")
log_msg(sprintf("  - cobertura obtida: %d observações mensais", nrow(icms_mensal)))
