source("R/utils.R")

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
})

dir_output <- file.path("data", "output", "extrativas_cfem")
dir.create(dir_output, recursive = TRUE, showWarnings = FALSE)

anos_benchmark <- 2020:2023

cfem_ingenua <- read_csv(
  file.path(dir_output, "indice_cfem_extrativas_trimestral.csv"),
  show_col_types = FALSE
)

cfem_robusta <- read_csv(
  file.path(dir_output, "indice_cfem_extrativas_robusto_trimestral.csv"),
  show_col_types = FALSE
)

caged_b <- read_csv(
  file.path(dir_output, "caged_b_extrativas_trimestral.csv"),
  show_col_types = FALSE
)

bench_extr <- read_csv(
  file.path("data", "processed", "contas_regionais_RR_volume.csv"),
  show_col_types = FALSE
) |>
  filter(grepl("extrativ", atividade, ignore.case = TRUE), ano %in% anos_benchmark) |>
  arrange(ano)

base <- cfem_ingenua |>
  select(ano, trimestre, periodo_trimestral, indice_cfem_composto) |>
  left_join(
    select(cfem_robusta, ano, trimestre, indice_cfem_robusto),
    by = c("ano", "trimestre")
  ) |>
  left_join(
    select(caged_b, ano, trimestre, indice_caged_b),
    by = c("ano", "trimestre")
  ) |>
  arrange(ano, trimestre)

detectar_spike_isolado <- function(x, fator = 10) {
  n <- length(x)
  out <- rep(FALSE, n)
  for (i in 2:(n - 1)) {
    viz_max <- max(x[i - 1], x[i + 1], na.rm = TRUE)
    out[i] <- is.finite(x[i]) && is.finite(viz_max) && viz_max > 0 && x[i] > fator * viz_max
  }
  out
}

tratar_spike_por_interpolacao <- function(x, flag) {
  y <- x
  idx <- which(flag)
  for (i in idx) {
    y[i] <- mean(c(x[i - 1], x[i + 1]), na.rm = TRUE)
  }
  y
}

flag_spike_ingenuo <- detectar_spike_isolado(base$indice_cfem_composto, fator = 10)
indice_cfem_composto_tratado <- tratar_spike_por_interpolacao(base$indice_cfem_composto, flag_spike_ingenuo)

relatorio_outlier <- base |>
  transmute(
    ano,
    trimestre,
    periodo_trimestral,
    indice_cfem_composto_original = indice_cfem_composto,
    spike_isolado = flag_spike_ingenuo,
    indice_cfem_composto_tratado = indice_cfem_composto_tratado
  )

write_csv(
  relatorio_outlier,
  file.path(dir_output, "outliers_cfem_ingenua.csv")
)

bench_ext <- estender_benchmark(
  bench_ano = bench_extr$ano,
  bench_val = bench_extr$vab_volume_rebased,
  ano_max = max(base$ano),
  n_ref = 2
)

rodar_denton <- function(indicador_trim) {
  serie <- denton(
    indicador_trim = indicador_trim,
    benchmark_anual = bench_ext$bench,
    ano_inicio = min(bench_ext$ano),
    metodo = "denton-cholette"
  )
  serie / mean(serie[base$ano == 2020], na.rm = TRUE) * 100
}

base <- base |>
  mutate(
    indice_cfem_composto_tratado = indice_cfem_composto_tratado,
    indicador_100_caged = indice_caged_b,
    indicador_50_ingenuo = 0.5 * indice_caged_b + 0.5 * indice_cfem_composto,
    indicador_50_ingenuo_tratado = 0.5 * indice_caged_b + 0.5 * indice_cfem_composto_tratado,
    indicador_50_robusto = 0.5 * indice_caged_b + 0.5 * indice_cfem_robusto,
    denton_100_caged = rodar_denton(indicador_100_caged),
    denton_50_ingenuo = rodar_denton(indicador_50_ingenuo),
    denton_50_ingenuo_tratado = rodar_denton(indicador_50_ingenuo_tratado),
    denton_50_robusto = rodar_denton(indicador_50_robusto)
  )

write_csv(
  base,
  file.path(dir_output, "comparacao_cenarios_cfem_extrativas.csv")
)

df_plot <- base |>
  transmute(
    periodo = periodo_trimestral,
    `CAGED B` = indice_caged_b,
    `CFEM ingenua tratada` = indice_cfem_composto_tratado,
    `CFEM robusta` = indice_cfem_robusto,
    `Denton 100% CAGED` = denton_100_caged,
    `Denton 50/50 ingenuo tratado` = denton_50_ingenuo_tratado,
    `Denton 50/50 robusto` = denton_50_robusto
  ) |>
  pivot_longer(-periodo, names_to = "serie", values_to = "indice")

ordem_periodos <- base$periodo_trimestral

g <- ggplot(
  df_plot |> mutate(periodo = factor(periodo, levels = ordem_periodos)),
  aes(x = periodo, y = indice, color = serie, group = serie)
) +
  geom_line(linewidth = 0.9, alpha = 0.95) +
  labs(
    title = "Extrativas: CAGED, CFEM ingenua, CFEM robusta e cenarios Denton",
    x = NULL,
    y = "Indice (media 2020 = 100)",
    color = NULL
  ) +
  theme_minimal(base_size = 11) +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

ggsave(
  file.path(dir_output, "comparacao_cenarios_cfem_extrativas.png"),
  plot = g,
  width = 11,
  height = 6.2,
  dpi = 150
)

message("Arquivo CSV salvo em data/output/extrativas_cfem/comparacao_cenarios_cfem_extrativas.csv")
message("Grafico salvo em data/output/extrativas_cfem/comparacao_cenarios_cfem_extrativas.png")
