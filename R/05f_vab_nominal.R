# ============================================================
# Projeto : Indicador de Atividade Econômica Trimestral — RR
# Script  : 05f_vab_nominal.R
# Autor   : Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)
# Data    : 2026-04-13
# Fase    : 5.6 — VAB Nominal Trimestral (Ponto 2 da reforma)
# Descrição: Gera índice trimestral do VAB nominal de RR
#   (preços correntes, base 2020=100) combinando:
#     - Índice real trimestral (indice_geral_rr.csv)
#     - Deflator implícito anual (derivado de CR nominal / CR volume)
#     - IPCA mensal (BCB/IBGE) como proxy trimestral no Denton
#
#   Metodologia:
#     1. Deflator anual: P_t/P_2020 = (VAB_nom_t/VAB_nom_2020)/(Q_t/100)
#        onde Q_t = índice encadeado de volume (base 2020=100)
#     2. Deflator agregado: média ponderada Laspeyres (pesos VAB 2020)
#     3. Deflator trimestral: Denton-Cholette(deflator_anual, IPCA_trim)
#     4. VAB nominal trimestral = indice_real × deflator / 100
#
# Entrada : data/processed/contas_regionais_RR_serie.csv
#            data/processed/contas_regionais_RR_volume.csv
#            data/raw/ipca_mensal.csv
#            data/output/indice_geral_rr.csv
# Saída   : data/processed/contas_regionais_RR_deflator.csv  (E.1/E.2)
#            data/output/indice_nominal_rr.csv               (E.5)
#            data/output/IAET_RR_series.xlsx (aba atualizada) (E.6)
# Depende : dplyr, tidyr, readr, tempdisagg, openxlsx
# ============================================================

source("R/utils.R")

library(dplyr)
library(tidyr)
library(readr)
library(tempdisagg)
library(openxlsx)

# --- Caminhos -----------------------------------------------

dir_processed <- file.path("data", "processed")
dir_raw       <- file.path("data", "raw")
dir_output    <- file.path("data", "output")

arq_cr_serie  <- file.path(dir_processed, "contas_regionais_RR_serie.csv")
arq_vol_serie <- file.path(dir_processed, "contas_regionais_RR_volume.csv")
arq_deflator  <- file.path(dir_processed, "contas_regionais_RR_deflator.csv")
arq_ipca      <- file.path(dir_raw,       "ipca_mensal.csv")
arq_geral     <- file.path(dir_output,    "indice_geral_rr.csv")
arq_nominal   <- file.path(dir_output,    "indice_nominal_rr.csv")
arq_excel     <- file.path(dir_output,    "IAET_RR_series.xlsx")

# --- Parâmetros ---------------------------------------------

anos_cr    <- 2020:2023
ano_inicio <- 2020L
ano_atual  <- as.integer(format(Sys.Date(), "%Y"))


# ============================================================
# ETAPA E.1/E.2 — Deflator implícito anual por atividade
# deflator_t = (vab_nom_t / vab_nom_2020) / (vol_t / 100) × 100
# Resultado: índice de preços base 2020=100
# ============================================================

message("\n=== ETAPA E.1/E.2: Deflator implícito anual por atividade ===\n")

cr  <- read_csv(arq_cr_serie,  show_col_types = FALSE)
vol <- read_csv(arq_vol_serie, show_col_types = FALSE)

# VAB nominal de 2020 por atividade (denominador do deflator)
vab_nom_2020 <- cr |>
  filter(ano == 2020) |>
  select(atividade, vab_mi_2020 = vab_mi)

# Unir e calcular deflator
deflator <- cr |>
  filter(ano %in% 2002:2023) |>
  select(atividade, ano, vab_mi) |>
  left_join(vab_nom_2020, by = "atividade") |>
  left_join(vol |> select(atividade, ano, vab_volume_rebased), by = c("atividade", "ano")) |>
  mutate(
    # Índice nominal relativo a 2020 = (vab_t / vab_2020) × 100
    idx_nominal = vab_mi / vab_mi_2020 * 100,
    # Deflator: preço relativo = nominal / real
    deflator_rebased = idx_nominal / (vab_volume_rebased / 100)
  ) |>
  select(atividade, ano, vab_mi, vab_mi_2020, idx_nominal,
         vab_volume_rebased, deflator_rebased) |>
  arrange(atividade, ano)

# Validação: deflator em 2020 deve ser 100 para todas as atividades
desvio_2020 <- deflator |>
  filter(ano == 2020) |>
  summarise(max_dev = max(abs(deflator_rebased - 100), na.rm = TRUE)) |>
  pull(max_dev)

if (desvio_2020 < 0.1) {
  message(sprintf("✓ Validação 2020=100: desvio máximo = %.4f (OK)", desvio_2020))
} else {
  warning(sprintf("Deflator 2020≠100: desvio máximo = %.4f — verificar.", desvio_2020))
}

# Taxas anuais do deflator total (agregado Laspeyres com pesos 2020)
pesos_2020 <- cr |>
  filter(ano == 2020) |>
  select(atividade, vab_mi) |>
  mutate(peso = vab_mi / sum(vab_mi, na.rm = TRUE))

deflator_total <- deflator |>
  filter(ano %in% anos_cr) |>
  left_join(pesos_2020 |> select(atividade, peso), by = "atividade") |>
  group_by(ano) |>
  summarise(defl_total = sum(deflator_rebased * peso, na.rm = TRUE), .groups = "drop") |>
  arrange(ano) |>
  mutate(var_defl = (defl_total / lag(defl_total) - 1) * 100)

message("Deflator implícito total RR (Laspeyres, base 2020=100):")
for (i in seq_len(nrow(deflator_total))) {
  var_str <- if (!is.na(deflator_total$var_defl[i])) {
    sprintf(" [%+.1f%%]", deflator_total$var_defl[i])
  } else ""
  message(sprintf("  %d: %.2f%s", deflator_total$ano[i], deflator_total$defl_total[i], var_str))
}

# Salvar deflator por atividade
write_csv(deflator, arq_deflator)
message(sprintf("\n✓ Deflator salvo: %s (%d obs.)", arq_deflator, nrow(deflator)))


# ============================================================
# ETAPA E.3 — IPCA trimestral (proxy para Denton do deflator)
# ============================================================

message("\n=== ETAPA E.3: IPCA trimestral ===\n")

ipca_raw <- read_csv(arq_ipca, show_col_types = FALSE)

# Identificar coluna do código de mês e do valor
col_mes  <- names(ipca_raw)[grep("ês.*ódigo|ódigo.*ês|Mês.*Código|Código.*Mês",
                                  names(ipca_raw), ignore.case = TRUE)][1]
col_val  <- "Valor"

ipca_clean <- ipca_raw |>
  rename(mes_cod = all_of(col_mes), valor = all_of(col_val)) |>
  filter(!is.na(valor), valor > 0) |>
  mutate(
    mes_cod = as.character(mes_cod),
    ano     = as.integer(substr(mes_cod, 1, 4)),
    mes     = as.integer(substr(mes_cod, 5, 6)),
    trim    = ceiling(mes / 3)
  ) |>
  filter(ano >= ano_inicio)

# Média trimestral do IPCA (índice de nível)
ipca_trim <- ipca_clean |>
  group_by(ano, trim) |>
  summarise(ipca_trim = mean(valor, na.rm = TRUE), .groups = "drop") |>
  arrange(ano, trim)

# Rebasear para 2020=100
ipca_base_2020 <- ipca_trim |> filter(ano == 2020) |> pull(ipca_trim) |> mean()
ipca_trim <- ipca_trim |>
  mutate(ipca_rebased = ipca_trim / ipca_base_2020 * 100)

message(sprintf("IPCA trimestral: %d trimestres (%dT%d–%dT%d), base 2020=100",
                nrow(ipca_trim),
                min(ipca_trim$ano), min(ipca_trim$trim[ipca_trim$ano == min(ipca_trim$ano)]),
                max(ipca_trim$ano), max(ipca_trim$trim[ipca_trim$ano == max(ipca_trim$ano)])))
message(sprintf("  2020: %.1f | 2021: %.1f | 2022: %.1f | 2023: %.1f",
                mean(ipca_trim$ipca_rebased[ipca_trim$ano == 2020]),
                mean(ipca_trim$ipca_rebased[ipca_trim$ano == 2021]),
                mean(ipca_trim$ipca_rebased[ipca_trim$ano == 2022]),
                mean(ipca_trim$ipca_rebased[ipca_trim$ano == 2023])))


# ============================================================
# ETAPA E.4 — Denton-Cholette: deflator anual → trimestral
# ============================================================

message("\n=== ETAPA E.4: Denton-Cholette deflator anual → trimestral ===\n")

# Deflator anual disponível: 2020–2023 (anos com benchmark CR)
bench_defl <- deflator_total$defl_total  # base 2020=100

# Indicador trimestral: IPCA (já em base 2020=100)
# Restringir ao período com benchmark (2020–2023)
ipca_bench <- ipca_trim |>
  filter(ano %in% anos_cr) |>
  arrange(ano, trim) |>
  pull(ipca_rebased)

if (length(ipca_bench) != length(anos_cr) * 4) {
  warning(sprintf("IPCA bench: %d obs (esperado %d) — verificar cobertura.",
                  length(ipca_bench), length(anos_cr) * 4))
}

defl_trim_bench <- tryCatch(
  denton(ipca_bench, bench_defl,
         ano_inicio = min(anos_cr), metodo = "denton-cholette"),
  error = function(e) {
    message(sprintf("  Denton deflator falhou: %s — usando IPCA reescalado.", e$message))
    # Fallback: repetir benchmark anual 4x e normalizar
    rep(bench_defl, each = 4)
  }
)

# Verificar ancoragem: média anual do deflator trimestral vs. benchmark
message("Verificação de ancoragem do deflator (média anual vs. benchmark):")
for (j in seq_along(anos_cr)) {
  idx_j   <- ((j - 1) * 4 + 1):(j * 4)
  media_j <- mean(defl_trim_bench[idx_j], na.rm = TRUE)
  bench_j <- bench_defl[j]
  desvio  <- abs(media_j - bench_j)
  status  <- if (desvio < 0.01) "✓" else sprintf("⚠ desvio=%.4f", desvio)
  message(sprintf("  %d: média=%.3f | benchmark=%.3f %s",
                  anos_cr[j], media_j, bench_j, status))
}

# Extrapolação do deflator para 2024–2025 usando IPCA
# Tendência: taxa de crescimento anual média do deflator no último bieênio
n_bench <- length(bench_defl)
taxa_defl_anual <- (bench_defl[n_bench] / bench_defl[n_bench - 1]) - 1
message(sprintf("Taxa de crescimento do deflator 2022→2023: %+.1f%%",
                taxa_defl_anual * 100))

# Anos extras além do período com benchmark
anos_extras <- setdiff(ano_inicio:ano_atual, anos_cr)
n_extra_trim <- length(anos_extras) * 4

if (n_extra_trim > 0) {
  # Usar IPCA trimestral extra diretamente (reescalado para nível deflator)
  ipca_extra <- ipca_trim |>
    filter(ano %in% anos_extras) |>
    arrange(ano, trim) |>
    pull(ipca_rebased)

  # Ajustar nível: o deflator no último trimestre de 2023 é referência
  ultimo_defl <- tail(defl_trim_bench, 1)
  ultimo_ipca_bench <- tail(ipca_bench, 1)
  escala <- ultimo_defl / ultimo_ipca_bench

  defl_extra <- ipca_extra * escala

  message(sprintf("Deflator extrapolado (%d trimestres, escala=%.4f):",
                  n_extra_trim, escala))
  for (i in seq_along(anos_extras)) {
    idx_i <- ((i - 1) * 4 + 1):(i * 4)
    message(sprintf("  %d: %.2f–%.2f (var %.1f%% vs. 2023)",
                    anos_extras[i],
                    min(defl_extra[idx_i]), max(defl_extra[idx_i]),
                    (mean(defl_extra[idx_i]) / mean(defl_trim_bench[(n_bench-1)*4+1:(n_bench*4)]) - 1) * 100))
  }
} else {
  defl_extra <- numeric(0)
}

defl_trimestral <- c(as.numeric(defl_trim_bench), defl_extra)

# Grid de datas
grid_completo <- expand_grid(ano = ano_inicio:ano_atual, trimestre = 1:4) |>
  arrange(ano, trimestre)


# ============================================================
# ETAPA E.5 — VAB nominal trimestral = indice_real × deflator/100
# ============================================================

message("\n=== ETAPA E.5: Índice nominal trimestral ===\n")

# Carregar índice real
geral <- read_csv(arq_geral, show_col_types = FALSE) |>
  arrange(ano, trimestre)

# Alinhar deflator ao grid do índice real
if (length(defl_trimestral) != nrow(geral)) {
  warning(sprintf("Tamanho diferente: deflator=%d, geral=%d — truncando ao mínimo.",
                  length(defl_trimestral), nrow(geral)))
  n_min <- min(length(defl_trimestral), nrow(geral))
  defl_trimestral <- defl_trimestral[1:n_min]
  geral <- geral[1:n_min, ]
}

resultado_nominal <- geral |>
  mutate(
    deflator_trimestral = round(defl_trimestral, 6),
    indice_nominal      = round(indice_geral * deflator_trimestral / 100, 6)
  ) |>
  select(periodo, ano, trimestre, indice_geral, deflator_trimestral, indice_nominal)

# Variações anuais
medias_nom <- resultado_nominal |>
  group_by(ano) |>
  summarise(media_real   = mean(indice_geral, na.rm = TRUE),
            media_defl   = mean(deflator_trimestral, na.rm = TRUE),
            media_nom    = mean(indice_nominal, na.rm = TRUE),
            n_trim = n(), .groups = "drop")

message("Variações anuais — Real, Deflator e Nominal (base 2020=100):")
message(sprintf("  %-6s  %8s  %8s  %8s", "Ano", "Real(%)", "Defl.(%)", "Nom.(%)"))
for (i in 2:nrow(medias_nom)) {
  if (medias_nom$n_trim[i] == 4) {
    var_real <- (medias_nom$media_real[i] / medias_nom$media_real[i-1] - 1) * 100
    var_defl <- (medias_nom$media_defl[i] / medias_nom$media_defl[i-1] - 1) * 100
    var_nom  <- (medias_nom$media_nom[i]  / medias_nom$media_nom[i-1]  - 1) * 100
    message(sprintf("  %d  %+7.1f%%  %+7.1f%%  %+7.1f%%",
                    medias_nom$ano[i], var_real, var_defl, var_nom))
  }
}

write_csv(resultado_nominal, arq_nominal)
message(sprintf("\n✓ Índice nominal salvo: %s (%d obs.)", arq_nominal, nrow(resultado_nominal)))


# ============================================================
# ETAPA E.6 — Atualizar Excel com aba "VAB Nominal"
# ============================================================

message("\n=== ETAPA E.6: Atualizando IAET_RR_series.xlsx ===\n")

if (!file.exists(arq_excel)) {
  message("Excel não encontrado — pular E.6. Rodar 05e_exportacao.R primeiro.")
} else {
  wb <- loadWorkbook(arq_excel)

  # Remover aba anterior se existir
  if ("VAB Nominal" %in% names(wb)) removeWorksheet(wb, "VAB Nominal")

  # Cabeçalho e dados
  df_excel <- resultado_nominal |>
    select(
      Período        = periodo,
      Ano            = ano,
      Trimestre      = trimestre,
      `Índice Real (2020=100)`     = indice_geral,
      `Deflator Implícito (2020=100)` = deflator_trimestral,
      `Índice Nominal (2020=100)`  = indice_nominal
    )

  addWorksheet(wb, "VAB Nominal")
  writeData(wb, "VAB Nominal", df_excel)

  # Estilo de cabeçalho
  cab_style <- createStyle(fontColour = "#FFFFFF", fgFill = "#1F497D",
                           halign = "CENTER", fontName = "Calibri",
                           fontSize = 11, textDecoration = "bold",
                           border = "TopBottomLeftRight")
  addStyle(wb, "VAB Nominal", cab_style, rows = 1, cols = 1:6, gridExpand = TRUE)

  # Largura de colunas
  setColWidths(wb, "VAB Nominal", cols = 1:6,
               widths = c(10, 8, 12, 20, 25, 22))

  # Nota metodológica na linha após os dados
  nota_row <- nrow(df_excel) + 3
  nota_txt <- paste0(
    "NOTA: Índice Nominal = Índice Real × Deflator Implícito / 100. ",
    "Deflator derivado das Contas Regionais IBGE (VAB nominal / VAB volume, base 2020=100), ",
    "desagregado trimestralmente com IPCA (IBGE) via Denton-Cholette."
  )
  writeData(wb, "VAB Nominal", nota_txt, startRow = nota_row, startCol = 1)
  nota_style <- createStyle(fontName = "Calibri", fontSize = 9,
                            fontColour = "#595959", wrapText = TRUE)
  addStyle(wb, "VAB Nominal", nota_style, rows = nota_row, cols = 1)
  mergeCells(wb, "VAB Nominal", cols = 1:6, rows = nota_row)

  saveWorkbook(wb, arq_excel, overwrite = TRUE)
  message(sprintf("✓ Aba 'VAB Nominal' adicionada ao Excel (%d obs.).", nrow(df_excel)))
}

message("\n=== Fase 5.6 (VAB Nominal Trimestral) concluída ===")
message(sprintf("  Deflator:       %s", arq_deflator))
message(sprintf("  Índice nominal: %s", arq_nominal))
message(sprintf("  Excel:          %s (aba 'VAB Nominal')", arq_excel))
