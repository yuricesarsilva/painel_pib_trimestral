# R/exploratorio/icms_sefaz_rr.R
#
# Lê os arquivos Excel de arrecadação menssal da SEFAZ-RR e exporta
# série limpa de ICMS estadual de Roraima.
#
# Fonte: SEFAZ-RR / Portal de Arrecadação Mensal
#   https://www.sefaz.rr.gov.br/m-arrecadacao-mensal
# Arquivos baixados manualmente em:
#   bases_baixadas_manualmente/dados_arrecadacao_rr_2020.1_2026.3/
#
# Cobertura: jan/2020 – mar/2026 (75 observações mensais, sem lacunas)
# Saída:     data/processed/icms_sefaz_rr_mensal.csv

library(readxl)
library(dplyr)
library(readr)

# --- configuração -----------------------------------------------------------
PASTA  <- "bases_baixadas_manualmente/dados_arrecadacao_rr_2020.1_2026.3"
SAIDA  <- "data/processed/icms_sefaz_rr_mensal.csv"

meses_pt <- c(
  "Janeiro" = 1, "Fevereiro" = 2, "Março" = 3, "Marco" = 3,
  "Abril"   = 4, "Maio"      = 5, "Junho"  = 6,
  "Julho"   = 7, "Agosto"    = 8, "Setembro" = 9,
  "Outubro" = 10, "Novembro" = 11, "Dezembro" = 12
)

# --- leitura ----------------------------------------------------------------
arqs <- sort(Sys.glob(file.path(PASTA, "*.xlsx")))
cat(sprintf("Arquivos encontrados: %d\n", length(arqs)))

serie <- lapply(arqs, function(f) {
  # Estrutura dos arquivos:
  #   L1  : título
  #   L4  : linha com o ano
  #   L6  : cabeçalho  → Mês | Ano | ICMS | IPVA | ITCD | IRRF | Taxas | Outras | Total
  #   L7+ : dados mensais
  df <- read_excel(f, skip = 5, col_names = TRUE)

  # Renomeia colunas de forma robusta (posição, não nome, pois encoding pode variar)
  names(df)[1] <- "mes_nome"
  names(df)[2] <- "ano"
  names(df)[3] <- "icms"
  names(df)[4] <- "ipva"
  names(df)[5] <- "itcd"
  names(df)[6] <- "irrf"
  names(df)[7] <- "taxas"
  names(df)[8] <- "outras"
  names(df)[9] <- "total"

  # Filtra apenas linhas de mês válido
  df <- df[df$mes_nome %in% names(meses_pt) & !is.na(df$icms), ]

  df$mes <- meses_pt[df$mes_nome]
  df$ano <- as.integer(df$ano)

  df[, c("ano", "mes", "mes_nome", "icms", "ipva", "itcd", "irrf", "taxas", "outras", "total")]
})

icms_df <- bind_rows(serie) |>
  arrange(ano, mes)

# --- validação básica -------------------------------------------------------
n_obs    <- nrow(icms_df)
ano_min  <- min(icms_df$ano);  mes_min  <- min(icms_df$mes[icms_df$ano == ano_min])
ano_max  <- max(icms_df$ano);  mes_max  <- max(icms_df$mes[icms_df$ano == ano_max])

cat(sprintf("Observações carregadas: %d\n", n_obs))
cat(sprintf("Cobertura: %d-%02d a %d-%02d\n", ano_min, mes_min, ano_max, mes_max))

# Verifica lacunas
grade <- data.frame(
  t_idx = seq((ano_min - 1L) * 12L + mes_min,
              (ano_max - 1L) * 12L + mes_max)
)
grade$ano <- ((grade$t_idx - 1L) %/% 12L) + 1L
grade$mes <- ((grade$t_idx - 1L) %% 12L) + 1L
icms_df$t_idx <- (icms_df$ano - 1L) * 12L + icms_df$mes
faltantes <- grade[!grade$t_idx %in% icms_df$t_idx, ]
if (nrow(faltantes) == 0) {
  cat("Série contínua — sem lacunas.\n")
} else {
  cat(sprintf("ATENÇÃO: %d mês(es) faltando:\n", nrow(faltantes)))
  print(faltantes[, c("ano", "mes")])
}

# --- resumo anual -----------------------------------------------------------
cat("\nTotais anuais de ICMS (R$ milhões):\n")
resumo <- icms_df |>
  group_by(ano) |>
  summarise(
    n_meses      = n(),
    icms_mi      = sum(icms) / 1e6,
    .groups = "drop"
  )
print(resumo, n = 20)

# --- outliers ---------------------------------------------------------------
# Detecta meses com ICMS > 3 dp da média anual (pode indicar ajustes atípicos)
icms_df <- icms_df |>
  group_by(ano) |>
  mutate(
    media_ano = mean(icms),
    dp_ano    = sd(icms),
    z_score   = (icms - media_ano) / dp_ano
  ) |>
  ungroup()

outliers <- icms_df[abs(icms_df$z_score) > 2.5, c("ano", "mes", "mes_nome", "icms", "z_score")]
if (nrow(outliers) > 0) {
  cat("\nMeses com ICMS atípico (z > 2.5):\n")
  print(outliers)
} else {
  cat("\nNenhum outlier de ICMS detectado (z > 2.5).\n")
}

# --- exportação -------------------------------------------------------------
saida_df <- icms_df |>
  mutate(icms_mi = icms / 1e6) |>
  select(ano, mes, mes_nome, icms_reais = icms, icms_mi)

dir.create(dirname(SAIDA), showWarnings = FALSE, recursive = TRUE)
write_csv(saida_df, SAIDA)
cat(sprintf("\nSérie exportada para: %s\n", SAIDA))
cat("Colunas: ano, mes, mes_nome, icms_reais, icms_mi\n")
