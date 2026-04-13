# ============================================================
# Projeto : Indicador de Atividade Econômica Trimestral — RR
# Script  : 05b_sensibilidade_calendario.R
# Autor   : Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)
# Data    : 2026-04-12
# Fase    : 5.2 — Teste de sensibilidade: calendário agrícola
#
# Descrição:
#   Compara três versões do calendário de colheita:
#     A (produção) : Calendário SEADI-RR
#     B (candidata): Censo Agropecuário 2006 — ponderação por área colhida
#     C (candidata): Censo Agropecuário 2006 — ponderação por nº de estabelecimentos
#
#   Para cada versão, roda 01_agropecuaria.R (dados já em cache — sem chamadas SIDRA)
#   e salva o índice em data/output/sensibilidade/.
#
#   Resultado: tabela de divergências trimestrais e avaliação do impacto no índice
#   geral (peso da agropecuária = 8,87% do VAB de RR).
#
# NOTA METODOLÓGICA:
#   Como o Denton-Cholette ancora cada versão ao mesmo VAB agropecuário anual (CR
#   IBGE), as médias anuais são idênticas nas três versões. A sensibilidade é
#   exclusivamente no perfil sazonal intra-anual (distribuição entre trimestres
#   dentro de cada ano).
#
# Entrada : data/output/indice_agropecuaria.csv (versão A — já computada)
#            R/01_agropecuaria.R (roda com versoes B e C em modo não-destrutivo)
#            data/output/indice_*.csv (para impacto no índice geral)
# Saída   : data/output/sensibilidade/agropecuaria_versao_B.csv
#            data/output/sensibilidade/agropecuaria_versao_C.csv
#            data/output/sensibilidade/comparacao_calendarios.csv
# Depende : dplyr, readr + dependências de 01_agropecuaria.R
# ============================================================

library(dplyr)
library(readr)
library(tidyr)

dir_output        <- file.path("data", "output")
dir_sensibilidade <- file.path("data", "output", "sensibilidade")
dir.create(dir_sensibilidade, recursive = TRUE, showWarnings = FALSE)

peso_agro <- 8.87 / 100  # participação da agropecuária no VAB total RR

# ============================================================
# ETAPA 5.2.1 — Carregar versão A (já computada em produção)
# ============================================================

message("\n=== ETAPA 5.2.1: Versão A (SEADI-RR) — carregando resultado de produção ===\n")

agro_A <- read_csv(file.path(dir_output, "indice_agropecuaria.csv"),
                   show_col_types = FALSE) |>
  filter(ano >= 2020) |>
  select(periodo, ano, trimestre, indice_agropecuaria) |>
  rename(versao_A = indice_agropecuaria) |>
  arrange(ano, trimestre)

message(sprintf("Versão A: %d trimestres (%s a %s)",
                nrow(agro_A), agro_A$periodo[1], agro_A$periodo[nrow(agro_A)]))


# ============================================================
# ETAPA 5.2.2 — Rodar versão B (Censo 2006 — área colhida)
# ============================================================

message("\n=== ETAPA 5.2.2: Versão B (Censo 2006 — área colhida) ===\n")

arq_saida_B <- file.path(dir_sensibilidade, "agropecuaria_versao_B.csv")

versao_calendario <- "censo2006_area"
arq_indice        <- arq_saida_B

source("R/01_agropecuaria.R")

# Limpar variáveis de controle (restaurar comportamento padrão de 01_ para próxima chamada)
rm(versao_calendario, arq_indice)

agro_B <- read_csv(arq_saida_B, show_col_types = FALSE) |>
  filter(ano >= 2020) |>
  select(periodo, ano, trimestre, indice_agropecuaria) |>
  rename(versao_B = indice_agropecuaria) |>
  arrange(ano, trimestre)

message(sprintf("Versão B: %d trimestres (%s a %s)",
                nrow(agro_B), agro_B$periodo[1], agro_B$periodo[nrow(agro_B)]))


# ============================================================
# ETAPA 5.2.3 — Rodar versão C (Censo 2006 — estabelecimentos)
# ============================================================

message("\n=== ETAPA 5.2.3: Versão C (Censo 2006 — nº estabelecimentos) ===\n")

arq_saida_C <- file.path(dir_sensibilidade, "agropecuaria_versao_C.csv")

versao_calendario <- "censo2006_estab"
arq_indice        <- arq_saida_C

source("R/01_agropecuaria.R")

rm(versao_calendario, arq_indice)

agro_C <- read_csv(arq_saida_C, show_col_types = FALSE) |>
  filter(ano >= 2020) |>
  select(periodo, ano, trimestre, indice_agropecuaria) |>
  rename(versao_C = indice_agropecuaria) |>
  arrange(ano, trimestre)

message(sprintf("Versão C: %d trimestres (%s a %s)",
                nrow(agro_C), agro_C$periodo[1], agro_C$periodo[nrow(agro_C)]))


# ============================================================
# ETAPA 5.2.4 — Tabela comparativa trimestral
# ============================================================

message("\n=== ETAPA 5.2.4: Comparação A vs. B vs. C ===\n")

comp <- agro_A |>
  left_join(agro_B, by = c("periodo", "ano", "trimestre")) |>
  left_join(agro_C, by = c("periodo", "ano", "trimestre")) |>
  mutate(
    # Divergências absolutas em pontos de índice
    dif_B_menos_A   = round(versao_B - versao_A, 4),
    dif_C_menos_A   = round(versao_C - versao_A, 4),
    # Divergências relativas (%)
    dif_B_pct       = round((versao_B / versao_A - 1) * 100, 3),
    dif_C_pct       = round((versao_C / versao_A - 1) * 100, 3),
    # Impacto no índice geral (agro = 8,87% do VAB)
    impacto_B_geral = round(dif_B_menos_A * peso_agro, 4),
    impacto_C_geral = round(dif_C_menos_A * peso_agro, 4)
  )

arq_comp <- file.path(dir_sensibilidade, "comparacao_calendarios.csv")
write_csv(comp, arq_comp)
message(sprintf("Tabela comparativa salva: %s", arq_comp))


# ============================================================
# ETAPA 5.2.5 — Sumário: divergências máximas e RMSE
# ============================================================

message("\n=== ETAPA 5.2.5: Sumário de divergências ===\n")

rmse <- function(x) sqrt(mean(x^2, na.rm = TRUE))
mae  <- function(x) mean(abs(x), na.rm = TRUE)

cat(sprintf("\n%s\n", strrep("=", 65)))
cat("SUMÁRIO — Sensibilidade do índice agropecuário ao calendário\n")
cat(sprintf("%s\n\n", strrep("=", 65)))

for (versao in c("B", "C")) {
  col_abs <- paste0("dif_", versao, "_menos_A")
  col_pct <- paste0("dif_", versao, "_pct")
  col_imp <- paste0("impacto_", versao, "_geral")

  d_abs <- comp[[col_abs]]
  d_pct <- comp[[col_pct]]
  d_imp <- comp[[col_imp]]

  nome_versao <- if (versao == "B") "Censo 2006 — área colhida" else "Censo 2006 — nº estabelecimentos"

  cat(sprintf("Versão %s (%s) vs. A (SEADI-RR):\n", versao, nome_versao))
  cat(sprintf("  Divergência absoluta (pontos de índice):\n"))
  cat(sprintf("    Máx. positiva: %+.3f  |  Máx. negativa: %+.3f\n",
              max(d_abs, na.rm = TRUE), min(d_abs, na.rm = TRUE)))
  cat(sprintf("    RMSE: %.4f  |  MAE: %.4f\n", rmse(d_abs), mae(d_abs)))
  cat(sprintf("  Divergência relativa (%%):\n"))
  cat(sprintf("    Máx. positiva: %+.2f%%  |  Máx. negativa: %+.2f%%\n",
              max(d_pct, na.rm = TRUE), min(d_pct, na.rm = TRUE)))
  cat(sprintf("  Impacto no índice geral (peso agro = %.2f%%):\n", peso_agro * 100))
  cat(sprintf("    Máx. desvio absoluto no índice geral: %+.4f pontos\n",
              max(abs(d_imp), na.rm = TRUE)))
  cat("\n")
}


# ============================================================
# ETAPA 5.2.6 — Verificação de identidade anual (Denton)
# ============================================================

message("=== ETAPA 5.2.6: Verificação — médias anuais devem ser idênticas (Denton) ===\n")

medias <- comp |>
  group_by(ano) |>
  summarise(
    media_A = mean(versao_A, na.rm = TRUE),
    media_B = mean(versao_B, na.rm = TRUE),
    media_C = mean(versao_C, na.rm = TRUE),
    n_trim  = n(),
    .groups = "drop"
  ) |>
  filter(n_trim == 4) |>  # apenas anos completos (Denton válido)
  mutate(
    dif_B_A = round(media_B - media_A, 6),
    dif_C_A = round(media_C - media_A, 6)
  )

cat("\nMédias anuais por versão de calendário (devem ser iguais para 2020–2023):\n\n")
cat(sprintf("%-6s  %10s  %10s  %10s  %12s  %12s\n",
            "Ano", "Versão A", "Versão B", "Versão C", "Dif B−A", "Dif C−A"))
cat(strrep("-", 68), "\n")

for (i in seq_len(nrow(medias))) {
  status <- if (abs(medias$dif_B_A[i]) < 0.01 && abs(medias$dif_C_A[i]) < 0.01) "✓" else "⚠"
  cat(sprintf("%-6d  %10.4f  %10.4f  %10.4f  %+12.6f  %+12.6f  %s\n",
              medias$ano[i], medias$media_A[i], medias$media_B[i], medias$media_C[i],
              medias$dif_B_A[i], medias$dif_C_A[i], status))
}

cat("\n")
cat("✓ = diferença < 0.01 pontos (Denton funcionando corretamente)\n")
cat("⚠ = diferença detectada (verificar ancoragem)\n\n")


# ============================================================
# ETAPA 5.2.7 — Perfil sazonal por versão (média trimestral 2020–2023)
# ============================================================

message("=== ETAPA 5.2.7: Perfil sazonal médio (2020–2023) ===\n")

sazonal <- comp |>
  filter(ano %in% 2020:2023) |>
  group_by(trimestre) |>
  summarise(
    media_A = mean(versao_A, na.rm = TRUE),
    media_B = mean(versao_B, na.rm = TRUE),
    media_C = mean(versao_C, na.rm = TRUE),
    .groups = "drop"
  )

cat("\nMédia por trimestre (2020–2023) — perfil sazonal por versão:\n\n")
cat(sprintf("%-10s  %10s  %10s  %10s\n", "Trimestre", "A (SEADI)", "B (Área)", "C (Estab)"))
cat(strrep("-", 45), "\n")
for (i in seq_len(nrow(sazonal))) {
  cat(sprintf("T%-9d  %10.2f  %10.2f  %10.2f\n",
              sazonal$trimestre[i],
              sazonal$media_A[i], sazonal$media_B[i], sazonal$media_C[i]))
}

# Razão pico/vale (amplitude sazonal)
for (versao in c("A", "B", "C")) {
  col <- paste0("media_", versao)
  nome <- switch(versao, A = "SEADI", B = "Área", C = "Estab")
  razao <- max(sazonal[[col]]) / min(sazonal[[col]])
  cat(sprintf("  Amplitude sazonal versão %s (%s): %.2fx\n", versao, nome, razao))
}

cat("\n")

# ============================================================

message(sprintf("\n=== Fase 5.2 concluída ==="))
message(sprintf("  Resultados salvos em: %s", dir_sensibilidade))
message(sprintf("  Arquivos gerados:"))
message(sprintf("    agropecuaria_versao_B.csv"))
message(sprintf("    agropecuaria_versao_C.csv"))
message(sprintf("    comparacao_calendarios.csv"))
message(sprintf("\n  Conclusão metodológica esperada:"))
message(sprintf("  - Médias anuais idênticas (Denton ancora ao mesmo VAB CR IBGE)"))
message(sprintf("  - Diferença exclusivamente no perfil sazonal intra-anual"))
message(sprintf("  - Impacto no índice geral pequeno (agro = 8,87%% do VAB)")
)
