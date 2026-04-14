# ============================================================
# Projeto : Indicador de Atividade Econômica Trimestral — RR
# Script  : 05_agregacao.R
# Autor   : Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)
# Data    : 2026-04-12
# Fase    : 5.1 — Índice Geral Agregado
# Descrição: Combina os quatro índices setoriais (Agropecuária,
#   AAPP, Indústria, Serviços Privados) num índice geral de
#   atividade econômica trimestral de Roraima (base 2020 = 100).
#
#   Metodologia:
#   1. Pesos: participação % no VAB total de RR (CR IBGE 2023).
#   2. Composição: média ponderada dos subíndices setoriais.
#   3. Ancoragem: Denton-Cholette contra VAB total anual (CR 2020–2023).
#   4. Extrapolação AAPP e Agropecuária: tendência linear 2022→2023
#      para 2024–2025 (provisional — revisar quando CR 2024 for
#      publicado, previsão IBGE: out/2026).
#
# Entrada : data/output/indice_agropecuaria.csv
#            data/output/indice_adm_publica.csv
#            data/output/indice_industria.csv
#            data/output/indice_servicos.csv
#            data/processed/contas_regionais_RR_serie.csv
# Saída   : data/output/indice_geral_rr.csv
# Depende : dplyr, tidyr, readr, tempdisagg
#            R/utils.R
# ============================================================

source("R/utils.R")

library(dplyr)
library(tidyr)
library(readr)
library(tempdisagg)

# --- Caminhos -----------------------------------------------

dir_output    <- file.path("data", "output")
dir_processed <- file.path("data", "processed")

arq_agro      <- file.path(dir_output,    "indice_agropecuaria.csv")
arq_aapp      <- file.path(dir_output,    "indice_adm_publica.csv")
arq_ind       <- file.path(dir_output,    "indice_industria.csv")
arq_serv      <- file.path(dir_output,    "indice_servicos.csv")
arq_cr        <- file.path(dir_processed, "contas_regionais_RR_serie.csv")
arq_vol       <- file.path(dir_processed, "contas_regionais_RR_volume.csv")
arq_saida     <- file.path(dir_output,    "indice_geral_rr.csv")

# --- Parâmetros ---------------------------------------------

ano_inicio <- 2020L
ano_atual  <- as.integer(format(Sys.Date(), "%Y"))
anos_cr    <- 2020:2023   # anos com benchmark CR publicado

# Pesos setoriais base 2020 (Laspeyres, participação % no VAB total — CR IBGE 2020)
# Calculados dinamicamente a partir de contas_regionais_RR_serie.csv para garantir
# consistência com o ano base do índice (2020=100).
nom_cr_pesos <- read_csv(arq_cr, show_col_types = FALSE) |>
  filter(ano == 2020,
         !grepl("^Total", atividade, ignore.case = TRUE))  # exclui linha "Total das Atividades"
tot_vab_2020 <- sum(nom_cr_pesos$vab_mi, na.rm = TRUE)

peso_agro_2020 <- sum(
  nom_cr_pesos$vab_mi[grepl("Agropecu", nom_cr_pesos$atividade, ignore.case = TRUE)],
  na.rm = TRUE) / tot_vab_2020 * 100

peso_aapp_2020 <- sum(
  nom_cr_pesos$vab_mi[grepl("Adm\\..*def|Adm.*educa", nom_cr_pesos$atividade, ignore.case = TRUE)],
  na.rm = TRUE) / tot_vab_2020 * 100

peso_ind_2020 <- sum(
  nom_cr_pesos$vab_mi[grepl("transforma|Constru|Eletricidade", nom_cr_pesos$atividade,
                             ignore.case = TRUE)],
  na.rm = TRUE) / tot_vab_2020 * 100

peso_serv_2020 <- 100 - peso_agro_2020 - peso_aapp_2020 - peso_ind_2020

pesos_blocos <- c(
  agropecuaria = peso_agro_2020,
  aapp         = peso_aapp_2020,
  industria    = peso_ind_2020,
  servicos     = peso_serv_2020
)

message(sprintf(
  "Pesos 2020 (Laspeyres): Agro=%.2f%% AAPP=%.2f%% Ind=%.2f%% Serv=%.2f%%",
  pesos_blocos["agropecuaria"], pesos_blocos["aapp"],
  pesos_blocos["industria"],    pesos_blocos["servicos"]))

# Verificação: soma deve ser 100%
stopifnot(abs(sum(pesos_blocos) - 100) < 0.5)


# ============================================================
# ETAPA 5.1.1 — Carregar índices setoriais
# ============================================================

message("\n=== ETAPA 5.1.1: Carregando índices setoriais ===\n")

# Agropecuária — filtrar a partir de 2020
agro_raw <- read_csv(arq_agro, show_col_types = FALSE) |>
  filter(ano >= ano_inicio) |>
  select(ano, trimestre, indice_agropecuaria) |>
  arrange(ano, trimestre)

message(sprintf("Agropecuária — %d obs. (%dT%d–%dT%d)",
                nrow(agro_raw),
                min(agro_raw$ano), min(agro_raw$trimestre[agro_raw$ano == min(agro_raw$ano)]),
                max(agro_raw$ano), max(agro_raw$trimestre[agro_raw$ano == max(agro_raw$ano)])))

# AAPP
aapp_raw <- read_csv(arq_aapp, show_col_types = FALSE) |>
  filter(ano >= ano_inicio) |>
  select(ano, trimestre, indice_adm_publica) |>
  arrange(ano, trimestre)

message(sprintf("AAPP — %d obs. (%dT%d–%dT%d)",
                nrow(aapp_raw),
                min(aapp_raw$ano), min(aapp_raw$trimestre[aapp_raw$ano == min(aapp_raw$ano)]),
                max(aapp_raw$ano), max(aapp_raw$trimestre[aapp_raw$ano == max(aapp_raw$ano)])))

# Indústria
ind_raw <- read_csv(arq_ind, show_col_types = FALSE) |>
  filter(ano >= ano_inicio) |>
  select(ano, trimestre, indice_industria) |>
  arrange(ano, trimestre)

message(sprintf("Indústria — %d obs. (%dT%d–%dT%d)",
                nrow(ind_raw),
                min(ind_raw$ano), min(ind_raw$trimestre[ind_raw$ano == min(ind_raw$ano)]),
                max(ind_raw$ano), max(ind_raw$trimestre[ind_raw$ano == max(ind_raw$ano)])))

# Serviços Privados
serv_raw <- read_csv(arq_serv, show_col_types = FALSE) |>
  filter(ano >= ano_inicio) |>
  select(ano, trimestre, indice_servicos) |>
  arrange(ano, trimestre)

message(sprintf("Serviços Privados — %d obs. (%dT%d–%dT%d)",
                nrow(serv_raw),
                min(serv_raw$ano), min(serv_raw$trimestre[serv_raw$ano == min(serv_raw$ano)]),
                max(serv_raw$ano), max(serv_raw$trimestre[serv_raw$ano == max(serv_raw$ano)])))


# ============================================================
# ETAPA 5.1.2 — Grid completo e extrapolação de AAPP e Agropecuária
# Indústria e Serviços têm 2020T1–2025T4 (24 obs.)
# AAPP e Agropecuária têm apenas 2020T1–2023T4 (16 obs.)
# → extrapolar 2024–2025 com tendência linear do último bieênio
# ============================================================

message("\n=== ETAPA 5.1.2: Grid e extrapolação 2024–2025 ===\n")

# Grid completo: 2020T1 até o último trimestre disponível em Indústria/Serviços
ano_fim    <- max(ind_raw$ano, serv_raw$ano)
trim_fim   <- max(ind_raw$trimestre[ind_raw$ano == ano_fim],
                  serv_raw$trimestre[serv_raw$ano == ano_fim])

grid_completo <- expand_grid(
  ano       = ano_inicio:ano_fim,
  trimestre = 1:4
) |>
  filter(ano < ano_fim | trimestre <= trim_fim) |>
  arrange(ano, trimestre)

n_total <- nrow(grid_completo)
message(sprintf("Grid: %dT%d–%dT%d (%d trimestres)",
                ano_inicio, 1, ano_fim, trim_fim, n_total))

#' Extrapola série usando crescimento pelo trimestre homólogo (preserva sazonalidade)
#' @param df      data.frame com colunas ano, trimestre, valor (nome da coluna em col_val)
#' @param grid    data.frame com colunas ano, trimestre (grid alvo)
#' @param col_val nome da coluna de valor
#' @return vetor numérico alinhado ao grid
extrapolar_tendencia <- function(df, grid, col_val) {

  df_alinhado <- grid |>
    left_join(df, by = c("ano", "trimestre"))

  vals <- df_alinhado[[col_val]]
  n    <- length(vals)

  if (all(!is.na(vals))) return(vals)  # nada a extrapolar

  # Índice do último valor disponível
  ultimo_idx <- max(which(!is.na(vals)))
  message(sprintf("  Extrapolando %s: %d trimestres após posição %d",
                  col_val, n - ultimo_idx, ultimo_idx))

  # Taxa anual: crescimento médio entre trimestres homólogos do último bieênio
  # (Q1_ano_t / Q1_ano_t-1, Q2_t / Q2_t-1, etc.) — preserva sazonalidade real
  n_bench <- 4L
  if (ultimo_idx >= 2L * n_bench) {
    bloco_atual    <- vals[(ultimo_idx - n_bench + 1L):ultimo_idx]
    bloco_anterior <- vals[(ultimo_idx - 2L * n_bench + 1L):(ultimo_idx - n_bench)]
    taxa_anual <- mean(bloco_atual / bloco_anterior, na.rm = TRUE) - 1
    message(sprintf("  Taxa de crescimento anual usada: %+.1f%%", taxa_anual * 100))
  } else {
    taxa_anual <- 0
    message("  Dados insuficientes para tendência — usando nível constante.")
  }

  # Crescimento por trimestre homólogo: val[i] = val[i-4] * (1 + taxa_anual)
  # Preserva o padrão sazonal (safra/entressafra, pico fiscal, etc.)
  # Fallback para val[i-1] * taxa_trim apenas se o homólogo não estiver disponível.
  taxa_trim <- (1 + taxa_anual)^(1/4) - 1

  for (i in (ultimo_idx + 1L):n) {
    base_homologa <- i - 4L
    if (base_homologa >= 1L && !is.na(vals[base_homologa])) {
      vals[i] <- vals[base_homologa] * (1 + taxa_anual)
    } else {
      vals[i] <- vals[i - 1L] * (1 + taxa_trim)  # fallback (só primeiros 4 trimestres extras)
    }
  }

  return(vals)
}

# Aplicar extrapolação
agro_vals  <- extrapolar_tendencia(agro_raw,  grid_completo, "indice_agropecuaria")
aapp_vals  <- extrapolar_tendencia(aapp_raw,  grid_completo, "indice_adm_publica")
ind_vals   <- extrapolar_tendencia(ind_raw,   grid_completo, "indice_industria")
serv_vals  <- extrapolar_tendencia(serv_raw,  grid_completo, "indice_servicos")

# Verificar que não restam NA (somente se houve extrapolação bem-sucedida)
for (nm in c("agro", "aapp", "ind", "serv")) {
  v <- get(paste0(nm, "_vals"))
  n_na <- sum(is.na(v))
  if (n_na > 0) warning(sprintf("%s: %d NAs restantes após extrapolação.", nm, n_na))
}

message(sprintf("\nSéries alinhadas ao grid %dT1–%dT%d (%d trimestres cada)",
                ano_inicio, ano_fim, trim_fim, n_total))


# ============================================================
# ETAPA 5.1.3 — Índice composto (média ponderada Laspeyres)
# Pesos: % VAB 2023 (CR IBGE) por bloco setorial
# ============================================================

message("\n=== ETAPA 5.1.3: Índice composto ponderado ===\n")

w <- pesos_blocos / sum(pesos_blocos)  # normalizar para soma = 1

# Substituir NA por NA ponderado (não imputa — preserva transparência)
indices_matrix <- cbind(
  agropecuaria = agro_vals,
  aapp         = aapp_vals,
  industria    = ind_vals,
  servicos     = serv_vals
)

# Laspeyres: soma ponderada por linha (trimestre)
# Se algum bloco for NA, redistribui o peso entre os disponíveis
indice_composto_raw <- apply(indices_matrix, 1, function(row) {
  ok  <- !is.na(row)
  if (!any(ok)) return(NA_real_)
  sum(row[ok] * w[ok]) / sum(w[ok])
})

# Normalizar: base 2020 = 100
idx_2020 <- which(grid_completo$ano == 2020)
base_2020 <- mean(indice_composto_raw[idx_2020], na.rm = TRUE)
indice_composto_raw <- indice_composto_raw / base_2020 * 100

message(sprintf("Índice composto — %d trimestres calculados (base 2020 = 100)",
                sum(!is.na(indice_composto_raw))))
message(sprintf("  Pesos efetivos: Agro=%.1f%% AAPP=%.1f%% Ind=%.1f%% Serv=%.1f%%",
                w["agropecuaria"] * 100, w["aapp"] * 100,
                w["industria"] * 100,   w["servicos"] * 100))


# ============================================================
# ETAPA 5.1.4 — Benchmark: VAB total anual (CR IBGE 2020–2023)
# ============================================================

message("\n=== ETAPA 5.1.4: Benchmark — índice de volume total RR (Laspeyres, base 2020=100) ===\n")

# Reforma metodológica: o benchmark do segundo Denton é o índice de volume total de RR
# (Laspeyres com pesos do VAB nominal 2020), não o VAB nominal somado e normalizado.
# Motivação: o índice composto usa proxies de VOLUME → ancoragem deve ser em VOLUME.
nom_cr  <- read_csv(arq_cr,  show_col_types = FALSE)
vol_cr  <- read_csv(arq_vol, show_col_types = FALSE)

# Pesos Laspeyres: participação de cada atividade no VAB nominal total de 2020
pesos_ativ_2020 <- nom_cr |>
  filter(ano == 2020) |>
  select(atividade, vab_mi) |>
  mutate(peso = vab_mi / sum(vab_mi, na.rm = TRUE))

# Volume total RR por ano = média ponderada dos índices setoriais (base 2020=100)
# Resultado também é base 2020=100 por construção (pesos somam 1 e vol_2020=100 para todos)
vol_total <- vol_cr |>
  filter(ano %in% anos_cr) |>
  left_join(pesos_ativ_2020 |> select(atividade, peso), by = "atividade") |>
  group_by(ano) |>
  summarise(vol_total = sum(vab_volume_rebased * peso, na.rm = TRUE), .groups = "drop") |>
  arrange(ano)

message("Índice de volume total RR (Laspeyres, base 2020=100):")
for (i in seq_len(nrow(vol_total))) {
  message(sprintf("  %d: %.2f", vol_total$ano[i], vol_total$vol_total[i]))
}

bench_cr <- vol_total$vol_total

message(sprintf("\nBenchmark volume total (base 2020=100): %s",
                paste(sprintf("%.1f", bench_cr), collapse = " | ")))


# ============================================================
# ETAPA 5.1.5 — Denton-Cholette: ancorar ao VAB total CR
# ============================================================

message("\n=== ETAPA 5.1.5: Denton-Cholette — ancoragem ao VAB total ===\n")

# Restringir série do indicador ao período com benchmark (2020–2023)
n_bench_trim <- length(anos_cr) * 4  # 16 trimestres para 4 anos
ind_para_denton <- indice_composto_raw[1:n_bench_trim]

indice_ancorado_bench <- tryCatch(
  denton(ind_para_denton, bench_cr,
         ano_inicio = min(anos_cr), metodo = "denton-cholette"),
  error = function(e) {
    message(sprintf("  Denton falhou: %s — usando índice composto sem ancoragem.", e$message))
    ind_para_denton
  }
)

# Calcular fator de ajuste médio no último ano de benchmark (2023)
# e aplicar para extrapolar além de 2023 com o mesmo fator
n_trim_2023 <- which(grid_completo$ano == 2023 & grid_completo$trimestre == 4)
fator_ajuste_ultimo <- indice_ancorado_bench[n_bench_trim] /
                       indice_composto_raw[n_bench_trim]
message(sprintf("  Fator de ajuste Denton no último benchmark (2023T4): %.4f", fator_ajuste_ultimo))

# Série completa: período com benchmark usa Denton; além de 2023 aplica fator proporcional
n_extra <- n_total - n_bench_trim
if (n_extra > 0) {
  # Extrapolação: mesma proporção de crescimento do índice bruto, mantendo nível Denton
  ratio_extra <- indice_composto_raw[(n_bench_trim + 1):n_total] /
                 indice_composto_raw[n_bench_trim]
  extra_vals  <- indice_ancorado_bench[n_bench_trim] * ratio_extra
} else {
  extra_vals <- numeric(0)
}

indice_final <- c(as.numeric(indice_ancorado_bench), extra_vals)

message(sprintf("Denton concluído — %d trimestres (%d ancorados, %d extrapolados)",
                length(indice_final), n_bench_trim, n_extra))


# ============================================================
# ETAPA 5.1.6 — Validação e variações anuais
# ============================================================

message("\n=== ETAPA 5.1.6: Validação ===\n")

# Variações anuais (média anual)
medias_anuais <- grid_completo |>
  mutate(indice = indice_final) |>
  group_by(ano) |>
  summarise(media = mean(indice, na.rm = TRUE), n_trim = n(), .groups = "drop")

message("Variações anuais do índice geral (média anual, base 2020=100):")
for (i in 2:nrow(medias_anuais)) {
  if (medias_anuais$n_trim[i] == 4) {
    variacao <- (medias_anuais$media[i] / medias_anuais$media[i - 1] - 1) * 100
    message(sprintf("  %d vs %d: %+.1f%%",
                    medias_anuais$ano[i], medias_anuais$ano[i - 1], variacao))
  }
}

# Verificar ancoragem: a média de cada ano com CR deve bater com benchmark
message("\nVerificação de ancoragem (média anual do índice vs. benchmark CR):")
for (j in seq_along(anos_cr)) {
  ano_j   <- anos_cr[j]
  idx_j   <- which(grid_completo$ano == ano_j)
  media_j <- mean(indice_final[idx_j], na.rm = TRUE)
  bench_j <- bench_cr[j]
  desvio  <- abs(media_j - bench_j)
  status  <- if (desvio < 0.01) "✓" else sprintf("⚠ desvio=%.4f", desvio)
  message(sprintf("  %d: média índice=%.3f | benchmark=%.3f %s",
                  ano_j, media_j, bench_j, status))
}

# Validação com utils.R (permite NA nos anos extrapolados)
validar_serie(indice_final[1:n_bench_trim], "índice geral (2020–2023)",
              permite_na = FALSE, variacao_max = 0.60)
if (n_extra > 0) {
  validar_serie(extra_vals, "índice geral (extrapolado 2024–2025)",
                permite_na = FALSE, variacao_max = 0.60)
}


# ============================================================
# ETAPA 5.1.7 — Exportar indice_geral_rr.csv
# ============================================================

message("\n=== ETAPA 5.1.7: Exportando indice_geral_rr.csv ===\n")

resultado <- grid_completo |>
  mutate(
    periodo             = sprintf("%dT%d", ano, trimestre),
    indice_geral        = round(indice_final, 6),
    indice_agropecuaria = round(agro_vals / mean(agro_vals[grid_completo$ano == 2020]) * 100, 6),
    indice_aapp         = round(aapp_vals / mean(aapp_vals[grid_completo$ano == 2020]) * 100, 6),
    indice_industria    = round(ind_vals  / mean(ind_vals[grid_completo$ano == 2020], na.rm=TRUE) * 100, 6),
    indice_servicos     = round(serv_vals / mean(serv_vals[grid_completo$ano == 2020]) * 100, 6)
  ) |>
  select(periodo, ano, trimestre,
         indice_geral, indice_agropecuaria, indice_aapp,
         indice_industria, indice_servicos)

dir.create(dir_output, recursive = TRUE, showWarnings = FALSE)
write_csv(resultado, arq_saida)

message(sprintf("✓ Fase 5.1 concluída — %d obs. salvas em %s", nrow(resultado), arq_saida))
message(sprintf("  Cobertura: %s – %s",
                resultado$periodo[1], resultado$periodo[nrow(resultado)]))

# Preview
print(resultado)

message("\n=== NOTAS PARA REVISÃO ===\n")
message("1. AAPP e Agropecuária: extrapolados com tendência geométrica 2022–2023.")
message("   Atualizar quando CR 2024 for publicado (previsão IBGE: out/2026).")
message("   Re-executar este script após atualizar os scripts setoriais (01 e 02).")
message("")
message("2. Financeiro (2,78%) e Transportes parcial (1,92%) com proxies incompletas.")
message("   Impacto no índice geral: pequeno (via bloco Serviços que representa 33,32%).")
message("")
message("3. Benchmark: VAB total CR (sem impostos líquidos sobre produtos).")
message("   Impostos líquidos representam ~10–12% do PIB — incluir em versão futura")
message("   quando a série de impostos por UF estiver disponível.")
