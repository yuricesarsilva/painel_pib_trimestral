# ============================================================
# Projeto : Indicador de Atividade Econômica Trimestral — RR
# Script  : 05g_pib_nominal.R
# Autor   : Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)
# Data    : 2026-04-14
# Fase    : 5.8 — PIB Nominal Trimestral
# Descrição: Gera a série trimestral do PIB nominal de Roraima
#   em R$ milhões a partir de:
#     - VAB nominal trimestral já escalado em reais
#     - ILP anual = PIB anual - VAB anual
#     - ICMS estadual mensal (SEFAZ-RR) como proxy trimestral do ILP
#
#   Metodologia:
#     1. ILP anual benchmark = PIB anual (SIDRA 5938) - VAB anual (CR IBGE)
#     2. ILP 2024–2025 extrapolado pela taxa anual do ICMS
#     3. ICMS mensal agregado a trimestre (fluxo, soma)
#     4. Denton-Cholette com conversion = "sum": ILP_anual ~ ICMS_trim
#     5. PIB nominal trimestral = VAB nominal trimestral + ILP trimestral
#
# Entrada : data/output/vab_nominal_rr_reais.csv
#            data/processed/icms_sefaz_rr_mensal.csv
#            data/processed/contas_regionais_RR_serie.csv
# Saída   : data/output/pib_nominal_rr.csv
#            data/output/ilp_rr_trimestral.csv
#            data/output/IAET_RR_series.xlsx (aba "PIB Nominal")
# Depende : dplyr, tidyr, readr, sidrar, tempdisagg, openxlsx
# ============================================================

source("R/utils.R")

library(dplyr)
library(tidyr)
library(readr)
library(sidrar)
library(tempdisagg)
library(openxlsx)

# --- Caminhos -----------------------------------------------

dir_processed <- file.path("data", "processed")
dir_output    <- file.path("data", "output")

arq_icms      <- file.path(dir_processed, "icms_sefaz_rr_mensal.csv")
arq_cr_serie  <- file.path(dir_processed, "contas_regionais_RR_serie.csv")
arq_vab_reais <- file.path(dir_output,    "vab_nominal_rr_reais.csv")
arq_ilp_trim  <- file.path(dir_output,    "ilp_rr_trimestral.csv")
arq_pib_trim  <- file.path(dir_output,    "pib_nominal_rr.csv")
arq_excel     <- file.path(dir_output,    "IAET_RR_series.xlsx")

# --- Parâmetros ---------------------------------------------

ano_inicio <- 2020L
ano_atual  <- as.integer(format(Sys.Date(), "%Y"))
anos_saida <- ano_inicio:(ano_atual - 1L)


# ============================================================
# ETAPA 5.8.1 — Carregar insumos
# ============================================================

message("\n=== ETAPA 5.8.1: Carregando insumos ===\n")

icms_mensal <- read_csv(arq_icms, show_col_types = FALSE) |>
  arrange(ano, mes)

vab_trim <- read_csv(arq_vab_reais, show_col_types = FALSE) |>
  arrange(ano, trimestre)

cr <- read_csv(arq_cr_serie, show_col_types = FALSE)

if (nrow(vab_trim) == 0) {
  stop("Arquivo de VAB nominal trimestral vazio ou ausente.", call. = FALSE)
}

message(sprintf("ICMS mensal: %d observações (%d-%02d a %d-%02d)",
                nrow(icms_mensal),
                min(icms_mensal$ano), min(icms_mensal$mes[icms_mensal$ano == min(icms_mensal$ano)]),
                max(icms_mensal$ano), max(icms_mensal$mes[icms_mensal$ano == max(icms_mensal$ano)])))
message(sprintf("VAB nominal trimestral: %d trimestres (%s a %s)",
                nrow(vab_trim), vab_trim$periodo[1], tail(vab_trim$periodo, 1)))


# ============================================================
# ETAPA 5.8.2 — PIB anual e ILP anual benchmark
# ============================================================

message("\n=== ETAPA 5.8.2: PIB anual e ILP anual ===\n")

pib_sidra <- sidrar::get_sidra(
  x = 5938,
  variable = 37,
  period = "2010-2023",
  geo = "State",
  geo.filter = list("State" = 14)
)

col_ano <- names(pib_sidra)[grep("^Ano$|^ano$|^Trimestre", names(pib_sidra), ignore.case = TRUE)][1]
col_val <- names(pib_sidra)[grep("^Valor$|^valor$", names(pib_sidra), ignore.case = TRUE)][1]

pib_anual <- pib_sidra |>
  transmute(
    ano = as.integer(.data[[col_ano]]),
    pib_mi = as.numeric(.data[[col_val]]) / 1000
  ) |>
  filter(ano >= ano_inicio, ano <= 2023) |>
  arrange(ano)

vab_anual <- cr |>
  filter(atividade == "Total das Atividades", ano >= ano_inicio, ano <= 2023) |>
  select(ano, vab_mi) |>
  arrange(ano)

ilp_anual <- vab_anual |>
  left_join(pib_anual, by = "ano") |>
  mutate(
    ilp_mi = pib_mi - vab_mi,
    razao_icms_ilp = NA_real_
  )

if (any(is.na(ilp_anual$ilp_mi))) {
  stop("Falha ao montar ILP anual benchmark: PIB anual com lacunas.", call. = FALSE)
}

message("ILP anual benchmark (R$ milhões):")
for (i in seq_len(nrow(ilp_anual))) {
  message(sprintf("  %d: PIB=%.0f | VAB=%.0f | ILP=%.0f",
                  ilp_anual$ano[i], ilp_anual$pib_mi[i], ilp_anual$vab_mi[i], ilp_anual$ilp_mi[i]))
}


# ============================================================
# ETAPA 5.8.3 — ICMS trimestral e extrapolação do ILP anual
# ============================================================

message("\n=== ETAPA 5.8.3: ICMS trimestral e ILP extrapolado ===\n")

icms_trim <- icms_mensal |>
  mutate(
    trimestre = ceiling(mes / 3),
    periodo   = sprintf("%dT%d", ano, trimestre)
  ) |>
  group_by(ano, trimestre, periodo) |>
  summarise(icms_mi = sum(icms_mi, na.rm = TRUE), .groups = "drop") |>
  arrange(ano, trimestre)

icms_anual <- icms_trim |>
  group_by(ano) |>
  summarise(icms_mi = sum(icms_mi, na.rm = TRUE), n_trim = n(), .groups = "drop") |>
  arrange(ano)

ilp_anual <- ilp_anual |>
  left_join(icms_anual |> select(ano, icms_mi), by = "ano") |>
  mutate(razao_icms_ilp = icms_mi / ilp_mi)

message("Cobertura anual do ICMS sobre o ILP benchmark:")
for (i in seq_len(nrow(ilp_anual))) {
  message(sprintf("  %d: ICMS=%.0f | ILP=%.0f | ICMS/ILP=%.1f%%",
                  ilp_anual$ano[i], ilp_anual$icms_mi[i], ilp_anual$ilp_mi[i],
                  ilp_anual$razao_icms_ilp[i] * 100))
}

# Extrapolar ILP anual para anos sem benchmark via crescimento do ICMS anual
anos_extras <- setdiff(sort(unique(vab_trim$ano)), ilp_anual$ano)
if (length(anos_extras) > 0) {
  ultimo_ilp <- tail(ilp_anual$ilp_mi, 1)
  ano_base   <- tail(ilp_anual$ano, 1)

  extras <- lapply(anos_extras, function(ano_x) {
    icms_atual <- icms_anual |> filter(ano == ano_x) |> pull(icms_mi)
    icms_prev  <- icms_anual |> filter(ano == ano_x - 1L) |> pull(icms_mi)

    if (length(icms_atual) == 0 || length(icms_prev) == 0 || is.na(icms_prev) || icms_prev == 0) {
      stop(sprintf("Não foi possível extrapolar ILP para %d: ICMS anual incompleto.", ano_x),
           call. = FALSE)
    }

    if (ano_x == ano_base + 1L) {
      ilp_prev <- ultimo_ilp
    } else {
      ilp_prev <- tail(ilp_anual$ilp_mi[ilp_anual$ano < ano_x], 1)
    }

    taxa_icms <- icms_atual / icms_prev

    tibble(
      ano = ano_x,
      vab_mi = NA_real_,
      pib_mi = NA_real_,
      ilp_mi = ilp_prev * taxa_icms,
      icms_mi = icms_atual,
      razao_icms_ilp = icms_atual / (ilp_prev * taxa_icms),
      tipo = "Extrapolado por ICMS anual"
    )
  }) |>
    bind_rows()

  ilp_anual <- ilp_anual |>
    mutate(tipo = "Benchmark CR IBGE") |>
    bind_rows(extras) |>
    arrange(ano)
} else {
  ilp_anual <- ilp_anual |>
    mutate(tipo = "Benchmark CR IBGE")
}

message("ILP anual final usado no Denton:")
for (i in seq_len(nrow(ilp_anual))) {
  message(sprintf("  %d: %.0f (%s)", ilp_anual$ano[i], ilp_anual$ilp_mi[i], ilp_anual$tipo[i]))
}


# ============================================================
# ETAPA 5.8.4 — Denton-Cholette: ILP anual → trimestral
# ============================================================

message("\n=== ETAPA 5.8.4: Denton-Cholette ILP anual → trimestral ===\n")

grade_trim <- expand_grid(
  ano = sort(unique(vab_trim$ano)),
  trimestre = 1:4
) |>
  mutate(periodo = sprintf("%dT%d", ano, trimestre)) |>
  semi_join(vab_trim, by = c("ano", "trimestre", "periodo")) |>
  arrange(ano, trimestre)

icms_trim_denton <- grade_trim |>
  left_join(icms_trim, by = c("ano", "trimestre", "periodo")) |>
  mutate(icms_mi = ifelse(is.na(icms_mi), 0, icms_mi))

bench_ilp <- ilp_anual |>
  filter(ano %in% sort(unique(grade_trim$ano))) |>
  arrange(ano) |>
  pull(ilp_mi)

indicador_trim <- icms_trim_denton$icms_mi
serie_benchmark <- ts(
  as.numeric(bench_ilp),
  start = min(grade_trim$ano),
  frequency = 1
)
serie_indicador <- ts(
  as.numeric(indicador_trim),
  start = c(min(grade_trim$ano), 1),
  frequency = 4
)

ilp_trim_vals <- tryCatch({
  mod <- tempdisagg::td(
    serie_benchmark ~ 0 + serie_indicador,
    method = "denton-cholette",
    conversion = "sum"
  )
  as.numeric(predict(mod))
}, error = function(e) {
  stop(sprintf("Falha no Denton do ILP: %s", e$message), call. = FALSE)
})

if (length(ilp_trim_vals) != nrow(grade_trim)) {
  stop("Comprimento do ILP trimestral diferente da grade de saída.", call. = FALSE)
}

message("Verificação de ancoragem anual do ILP trimestral:")
for (ano_x in sort(unique(grade_trim$ano))) {
  soma_trim <- sum(ilp_trim_vals[grade_trim$ano == ano_x], na.rm = TRUE)
  bench_x   <- ilp_anual |> filter(ano == ano_x) |> pull(ilp_mi)
  desvio    <- abs(soma_trim - bench_x)
  status    <- if (desvio < 0.01) "✓" else sprintf("⚠ desvio=%.4f", desvio)
  message(sprintf("  %d: soma=%.3f | benchmark=%.3f %s", ano_x, soma_trim, bench_x, status))
}


# ============================================================
# ETAPA 5.8.5 — PIB nominal trimestral
# ============================================================

message("\n=== ETAPA 5.8.5: PIB nominal trimestral ===\n")

ilp_trim <- grade_trim |>
  mutate(
    ilp_nominal_mi = round(ilp_trim_vals, 6)
  ) |>
  left_join(
    ilp_anual |> select(ano, ilp_anual_mi = ilp_mi, tipo_benchmark = tipo),
    by = "ano"
  ) |>
  left_join(
    icms_trim |> select(ano, trimestre, icms_mi),
    by = c("ano", "trimestre")
  )

resultado_pib <- vab_trim |>
  left_join(ilp_trim |> select(periodo, ano, trimestre, ilp_nominal_mi, icms_mi, tipo_benchmark),
            by = c("periodo", "ano", "trimestre")) |>
  mutate(
    pib_nominal_mi = round(vab_nominal_mi + ilp_nominal_mi, 6)
  ) |>
  select(periodo, ano, trimestre, indice_nominal, vab_nominal_mi,
         icms_mi, ilp_nominal_mi, pib_nominal_mi, tipo_benchmark)

write_csv(ilp_trim, arq_ilp_trim)
write_csv(resultado_pib, arq_pib_trim)

message(sprintf("✓ ILP trimestral salvo: %s", arq_ilp_trim))
message(sprintf("✓ PIB nominal trimestral salvo: %s", arq_pib_trim))

message("PIB nominal anual (soma dos trimestres, R$ milhões):")
pib_anual_check <- resultado_pib |>
  group_by(ano) |>
  summarise(
    vab_anual_mi = sum(vab_nominal_mi, na.rm = TRUE),
    ilp_anual_mi = sum(ilp_nominal_mi, na.rm = TRUE),
    pib_anual_mi = sum(pib_nominal_mi, na.rm = TRUE),
    .groups = "drop"
  )
for (i in seq_len(nrow(pib_anual_check))) {
  message(sprintf("  %d: VAB=%.0f | ILP=%.0f | PIB=%.0f",
                  pib_anual_check$ano[i], pib_anual_check$vab_anual_mi[i],
                  pib_anual_check$ilp_anual_mi[i], pib_anual_check$pib_anual_mi[i]))
}


# ============================================================
# ETAPA 5.8.6 — Atualizar Excel com aba "PIB Nominal"
# ============================================================

message("\n=== ETAPA 5.8.6: Atualizando Excel ===\n")

if (!file.exists(arq_excel)) {
  message("Excel não encontrado — pular atualização da aba 'PIB Nominal'.")
} else {
  wb <- loadWorkbook(arq_excel)

  if ("PIB Nominal" %in% names(wb)) removeWorksheet(wb, "PIB Nominal")

  aba_pib <- resultado_pib |>
    transmute(
      Período = periodo,
      Ano = ano,
      Trimestre = trimestre,
      `VAB Nominal (R$ mi)` = vab_nominal_mi,
      `ICMS Proxy (R$ mi)` = round(icms_mi, 1),
      `ILP Trimestral (R$ mi)` = ilp_nominal_mi,
      `PIB Nominal (R$ mi)` = pib_nominal_mi,
      Benchmark = tipo_benchmark
    )

  addWorksheet(wb, "PIB Nominal")
  writeData(wb, "PIB Nominal", aba_pib)

  cab_style <- createStyle(
    fontColour = "#FFFFFF",
    fgFill = "#1F497D",
    halign = "CENTER",
    fontName = "Calibri",
    fontSize = 11,
    textDecoration = "bold",
    border = "TopBottomLeftRight"
  )
  addStyle(wb, "PIB Nominal", cab_style, rows = 1, cols = 1:ncol(aba_pib), gridExpand = TRUE)
  setColWidths(wb, "PIB Nominal", cols = 1:ncol(aba_pib), widths = "auto")

  nota_row <- nrow(aba_pib) + 3
  nota_txt <- paste0(
    "NOTA: ILP trimestral = Denton-Cholette(ILP anual, ICMS trimestral). ",
    "Benchmark anual: PIB (SIDRA 5938) - VAB nominal (Contas Regionais IBGE). ",
    "Para 2024–2025, o ILP anual foi extrapolado pela taxa anual do ICMS da SEFAZ-RR. ",
    "Proxy adotada: ICMS estadual exclusivamente; ISS e bloco federal foram descartados por limitações documentadas em plano_reforma_impostos.md."
  )
  writeData(wb, "PIB Nominal", nota_txt, startRow = nota_row, startCol = 1)
  nota_style <- createStyle(fontName = "Calibri", fontSize = 9, fontColour = "#595959", wrapText = TRUE)
  addStyle(wb, "PIB Nominal", nota_style, rows = nota_row, cols = 1)
  mergeCells(wb, "PIB Nominal", cols = 1:ncol(aba_pib), rows = nota_row)

  saveWorkbook(wb, arq_excel, overwrite = TRUE)
  message(sprintf("✓ Aba 'PIB Nominal' adicionada ao Excel (%d obs.).", nrow(aba_pib)))
}

message("\n=== Fase 5.8 (PIB Nominal Trimestral) concluída ===")
message(sprintf("  ILP trimestral: %s", arq_ilp_trim))
message(sprintf("  PIB nominal:    %s", arq_pib_trim))
message(sprintf("  Excel:          %s (aba 'PIB Nominal')", arq_excel))
