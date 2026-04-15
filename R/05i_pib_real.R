# ============================================================
# Projeto : Indicador de Atividade Economica Trimestral - RR
# Script  : 05i_pib_real.R
# Autor   : Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)
# Data    : 2026-04-15
# Fase    : 5.10 - PIB Real Trimestral
# Descricao: Gera a serie trimestral do PIB real de Roraima
#   em R$ milhoes de 2020 e como indice base 2020=100.
#   Parte de uma serie trimestral preliminar obtida por
#   deflacao do PIB nominal do projeto e, em seguida, ancora
#   as medias anuais de 2020-2023 ao benchmark oficial do
#   PIB real das Contas Regionais do IBGE.
#
#   Metodologia:
#     1. Ler o PIB nominal trimestral ja construido no projeto
#     2. Ler o deflator trimestral implicito do projeto
#        (indice_nominal_rr.csv)
#     3. PIB real preliminar trimestral = PIB nominal trimestral / (deflator / 100)
#     4. Indice preliminar = PIB real preliminar / media de 2020 x 100
#     5. Ancorar medias anuais de 2020-2023 ao benchmark oficial
#        do PIB real via Denton-Cholette (conversion = "mean")
#     6. Reescalar o indice ancorado para R$ milhoes de 2020
#
#   Justificativa:
#     Esta abordagem preserva a dinamica intra-anual da serie
#     trimestral do projeto, mas corrige o nivel anual do PIB real
#     nos anos com benchmark oficial das Contas Regionais.
#
# Entrada : data/output/pib_nominal_rr.csv
#            data/output/indice_nominal_rr.csv
# Saida   : data/output/pib_real_rr.csv
#            data/output/pib_real_anual_rr.csv
#            data/output/IAET_RR_series.xlsx (aba "PIB Real")
# Depende : dplyr, readr, openxlsx, tempdisagg
# ============================================================

source("R/utils.R")

library(dplyr)
library(readr)
library(openxlsx)

dir_output   <- file.path("data", "output")

arq_pib_nom  <- file.path(dir_output, "pib_nominal_rr.csv")
arq_deflator <- file.path(dir_output, "indice_nominal_rr.csv")
arq_pib_real <- file.path(dir_output, "pib_real_rr.csv")
arq_pib_an   <- file.path(dir_output, "pib_real_anual_rr.csv")
arq_excel    <- file.path(dir_output, "IAET_RR_series.xlsx")


# ============================================================
# ETAPA 5.10.1 - Carregar insumos
# ============================================================

message("\n=== ETAPA 5.10.1: Carregando insumos ===\n")

pib_nominal <- read_csv(arq_pib_nom, show_col_types = FALSE) |>
  arrange(ano, trimestre)

deflator_trim <- read_csv(arq_deflator, show_col_types = FALSE) |>
  select(periodo, ano, trimestre, indice_geral, deflator_trimestral, indice_nominal) |>
  arrange(ano, trimestre)

if (nrow(pib_nominal) == 0) {
  stop("Arquivo de PIB nominal trimestral vazio ou ausente.", call. = FALSE)
}

if (nrow(deflator_trim) == 0) {
  stop("Arquivo de deflator trimestral vazio ou ausente.", call. = FALSE)
}

# Benchmark anual oficial do PIB real de Roraima nas Contas Regionais
# (taxa de crescimento em volume)
bench_pib_real_cr <- tibble::tibble(
  ano = 2020:2023,
  crescimento_real_cr_pct = c(NA_real_, 8.4, 11.3, 4.2)
)


# ============================================================
# ETAPA 5.10.2 - Serie preliminar do PIB real
# ============================================================

message("\n=== ETAPA 5.10.2: Deflacionando o PIB nominal e montando serie preliminar ===\n")

pib_real <- pib_nominal |>
  left_join(
    deflator_trim,
    by = c("periodo", "ano", "trimestre")
  ) |>
  mutate(
    pib_real_prelim_mi = pib_nominal_mi / (deflator_trimestral / 100)
  )

if (any(is.na(pib_real$deflator_trimestral))) {
  stop("Falha ao juntar o deflator trimestral a serie de PIB nominal.", call. = FALSE)
}

media_2020 <- pib_real |>
  filter(ano == 2020) |>
  summarise(media = mean(pib_real_prelim_mi, na.rm = TRUE)) |>
  pull(media)

if (is.na(media_2020) || media_2020 <= 0) {
  stop("Nao foi possivel calcular a media de 2020 do PIB real.", call. = FALSE)
}

pib_real <- pib_real |>
  mutate(
    indice_pib_real_prelim = pib_real_prelim_mi / media_2020 * 100
  )

validar_serie(pib_real$pib_real_prelim_mi, "PIB real trimestral preliminar")
validar_serie(pib_real$indice_pib_real_prelim, "Indice do PIB real trimestral preliminar")


# ============================================================
# ETAPA 5.10.3 - Ancoragem anual do PIB real
# ============================================================

message("\n=== ETAPA 5.10.3: Ancorando o PIB real ao benchmark anual oficial ===\n")

pib_real_anual_prelim <- pib_real |>
  group_by(ano) |>
  summarise(
    indice_pib_real_prelim_anual = mean(indice_pib_real_prelim, na.rm = TRUE),
    .groups = "drop"
  )

bench_pib_real_cr <- bench_pib_real_cr |>
  mutate(
    indice_pib_real_cr = cumprod(1 + coalesce(crescimento_real_cr_pct, 0) / 100) * 100
  )

bench_pib_real_anual <- pib_real_anual_prelim |>
  left_join(bench_pib_real_cr |> select(ano, indice_pib_real_cr), by = "ano") |>
  mutate(
    indice_pib_real_benchmark = coalesce(indice_pib_real_cr, indice_pib_real_prelim_anual)
  )

indice_pib_real_ancorado <- denton(
  indicador_trim = pib_real$indice_pib_real_prelim,
  benchmark_anual = bench_pib_real_anual$indice_pib_real_benchmark,
  ano_inicio = min(pib_real$ano),
  trimestre_ini = min(pib_real$trimestre[pib_real$ano == min(pib_real$ano)]),
  metodo = "denton-cholette"
)

pib_real <- pib_real |>
  mutate(
    indice_pib_real = indice_pib_real_ancorado,
    pib_real_mi = indice_pib_real / 100 * media_2020,
    tipo_ancoragem = ifelse(
      ano <= max(bench_pib_real_cr$ano),
      "Ancorado ao PIB real CR",
      "Sem benchmark oficial do PIB real"
    ),
    tipo_benchmark = paste(tipo_benchmark, "-", tipo_ancoragem)
  ) |>
  select(
    periodo, ano, trimestre,
    indice_geral_vab = indice_geral,
    deflator_trimestral,
    indice_pib_real,
    pib_nominal_mi,
    pib_real_mi,
    tipo_benchmark
  )

validar_serie(pib_real$pib_real_mi, "PIB real trimestral")
validar_serie(pib_real$indice_pib_real, "Indice do PIB real trimestral")

message("Benchmark anual do PIB real (indice 2020=100):")
for (i in seq_len(nrow(bench_pib_real_anual))) {
  message(sprintf(
    "  %d: prelim=%.2f | benchmark=%.2f%s",
    bench_pib_real_anual$ano[i],
    bench_pib_real_anual$indice_pib_real_prelim_anual[i],
    bench_pib_real_anual$indice_pib_real_benchmark[i],
    if (!is.na(bench_pib_real_anual$indice_pib_real_cr[i])) " | CR oficial" else " | mantido pela serie preliminar"
  ))
}


# ============================================================
# ETAPA 5.10.4 - Resumo anual
# ============================================================

message("\n=== ETAPA 5.10.4: Resumo anual ===\n")

pib_real_anual <- pib_real |>
  group_by(ano) |>
  summarise(
    pib_nominal_anual_mi = sum(pib_nominal_mi, na.rm = TRUE),
    pib_real_anual_mi = sum(pib_real_mi, na.rm = TRUE),
    indice_pib_real_anual = mean(indice_pib_real, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(
    crescimento_real_pct = (indice_pib_real_anual / lag(indice_pib_real_anual) - 1) * 100
  )

message("PIB real anual (R$ milhoes de 2020 e indice base 2020=100):")
for (i in seq_len(nrow(pib_real_anual))) {
  tx <- if (!is.na(pib_real_anual$crescimento_real_pct[i])) {
    sprintf(" | var. real=%+.2f%%", pib_real_anual$crescimento_real_pct[i])
  } else {
    ""
  }
  message(sprintf(
    "  %d: PIB nominal=%.0f | PIB real=%.0f | indice=%.2f%s",
    pib_real_anual$ano[i],
    pib_real_anual$pib_nominal_anual_mi[i],
    pib_real_anual$pib_real_anual_mi[i],
    pib_real_anual$indice_pib_real_anual[i],
    tx
  ))
}


# ============================================================
# ETAPA 5.10.5 - Salvar CSVS
# ============================================================

message("\n=== ETAPA 5.10.5: Salvando saidas ===\n")

write_csv(pib_real, arq_pib_real)
write_csv(pib_real_anual, arq_pib_an)

message(sprintf("✓ PIB real trimestral salvo: %s", arq_pib_real))
message(sprintf("✓ PIB real anual salvo: %s", arq_pib_an))


# ============================================================
# ETAPA 5.10.6 - Atualizar Excel
# ============================================================

message("\n=== ETAPA 5.10.6: Atualizando Excel ===\n")

if (!file.exists(arq_excel)) {
  message("Excel nao encontrado - pular atualizacao da aba 'PIB Real'.")
} else {
  wb <- loadWorkbook(arq_excel)

  if ("PIB Real" %in% names(wb)) removeWorksheet(wb, "PIB Real")

  aba_pib_real <- pib_real |>
    transmute(
      `Periodo` = periodo,
      `Ano` = ano,
      `Trimestre` = trimestre,
      `Deflator Trimestral (2020=100)` = round(deflator_trimestral, 6),
      `Indice PIB Real (2020=100)` = round(indice_pib_real, 6),
      `PIB Nominal (R$ mi)` = round(pib_nominal_mi, 6),
      `PIB Real (R$ mi de 2020)` = round(pib_real_mi, 6),
      `Benchmark` = tipo_benchmark
    )

  addWorksheet(wb, "PIB Real")
  writeData(wb, "PIB Real", aba_pib_real)

  cab_style <- createStyle(
    fontColour = "#FFFFFF",
    fgFill = "#1F497D",
    halign = "CENTER",
    fontName = "Calibri",
    fontSize = 11,
    textDecoration = "bold",
    border = "TopBottomLeftRight"
  )
  addStyle(wb, "PIB Real", cab_style, rows = 1, cols = 1:ncol(aba_pib_real), gridExpand = TRUE)
  setColWidths(wb, "PIB Real", cols = 1:ncol(aba_pib_real), widths = "auto")

  nota_row <- nrow(aba_pib_real) + 3
  nota_txt <- paste0(
    "NOTA: O PIB real trimestral parte de uma serie preliminar obtida por deflacao do PIB nominal trimestral ",
    "do projeto e, em seguida, e ancorado via Denton-Cholette ao benchmark anual oficial do PIB real das ",
    "Contas Regionais em 2020-2023. Para anos sem benchmark oficial, a trajetoria anual da serie preliminar e mantida."
  )
  writeData(wb, "PIB Real", nota_txt, startRow = nota_row, startCol = 1)
  nota_style <- createStyle(fontName = "Calibri", fontSize = 9, fontColour = "#595959", wrapText = TRUE)
  addStyle(wb, "PIB Real", nota_style, rows = nota_row, cols = 1)
  mergeCells(wb, "PIB Real", cols = 1:ncol(aba_pib_real), rows = nota_row)

  saveWorkbook(wb, arq_excel, overwrite = TRUE)
  message(sprintf("✓ Aba 'PIB Real' adicionada ao Excel (%d obs.).", nrow(aba_pib_real)))
}

message("\n=== Fase 5.10 (PIB Real Trimestral) concluida ===")
message(sprintf("  PIB real trimestral: %s", arq_pib_real))
message(sprintf("  PIB real anual:      %s", arq_pib_an))
message(sprintf("  Excel:               %s (aba 'PIB Real')", arq_excel))
