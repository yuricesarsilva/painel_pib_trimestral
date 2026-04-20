source("R/utils.R")

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
  library(stringr)
  library(scales)
})

dir_raw_anm <- file.path("data", "raw", "anm")
dir_raw_caged <- file.path("data", "raw", "caged")
dir_processed <- file.path("data", "processed")
dir_output <- file.path("data", "output", "extrativas_cfem")
dir_notas <- file.path("notas", "metodologia")
arq_nota <- file.path(dir_notas, "cfem_extrativas_indice_composto.md")

dir.create(dir_output, recursive = TRUE, showWarnings = FALSE)

ano_inicio <- 2020L
ano_fim <- 2025L
anos_benchmark <- 2020:2023

normalizar_texto <- function(x) {
  x <- iconv(x, from = "Latin1", to = "ASCII//TRANSLIT")
  x <- tolower(x)
  x <- gsub("[^a-z0-9]+", "_", x)
  trimws(gsub("^_|_$", "", x))
}

ler_cfem <- function(path) {
  df <- read_csv(
    path,
    show_col_types = FALSE,
    locale = locale(encoding = "Latin1"),
    col_types = cols(.default = col_character())
  )
  names(df) <- normalizar_texto(names(df))
  df
}

parse_br_num <- function(x) {
  parse_number(as.character(x), locale = locale(decimal_mark = ",", grouping_mark = "."))
}

objetivo_denton <- function(indicador_trim, benchmark_anual) {
  serie_denton <- denton(
    indicador_trim = indicador_trim,
    benchmark_anual = benchmark_anual,
    ano_inicio = min(anos_benchmark),
    metodo = "denton-cholette"
  )
  razao <- serie_denton / pmax(indicador_trim, 1e-9)
  sum(diff(razao)^2, na.rm = TRUE)
}

salvar_grafico_trimestral <- function(df_long, titulo, nome_arquivo) {
  ordem_periodos <- df_long |>
    distinct(periodo) |>
    arrange(periodo) |>
    pull(periodo)

  g <- ggplot(
    df_long |> mutate(periodo = factor(periodo, levels = ordem_periodos)),
    aes(x = periodo, y = indice, color = serie, group = serie)
  ) +
    geom_line(linewidth = 0.8, alpha = 0.95) +
    labs(
      title = titulo,
      x = NULL,
      y = "Indice (media 2020 = 100)",
      color = NULL
    ) +
    theme_minimal(base_size = 11) +
    theme(
      legend.position = "bottom",
      axis.text.x = element_text(angle = 45, hjust = 1)
    )

  ggsave(file.path(dir_output, nome_arquivo), plot = g, width = 10, height = 5.5, dpi = 150)
}

texto_regras <- function(diag_row) {
  motivos <- c()
  if (!isTRUE(diag_row$regra_base_2020)) {
    motivos <- c(motivos, "base trimestral 2020 nao positiva")
  }
  if (!isTRUE(diag_row$regra_cobertura)) {
    motivos <- c(motivos, "menos de 8 trimestres ativos em 2020-2023")
  }
  if (!isTRUE(diag_row$regra_participacao)) {
    motivos <- c(motivos, "participacao no valor 2020-2023 abaixo de 1%")
  }
  if (!isTRUE(diag_row$regra_escala)) {
    motivos <- c(motivos, "p95 da quantidade trimestral acima de 20x a base 2020")
  }
  if (length(motivos) == 0) "incluida" else paste(motivos, collapse = "; ")
}

message("\n=== ETAPA 1: Ler e limpar CFEM ===\n")

cfem <- bind_rows(
  ler_cfem(file.path(dir_raw_anm, "CFEM_Arrecadacao_2017_2021.csv")),
  ler_cfem(file.path(dir_raw_anm, "CFEM_Arrecadacao_2022_2026.csv"))
)

col_ano <- names(cfem)[1]
col_mes <- names(cfem)[2]
col_subst <- names(cfem)[7]
col_uf <- names(cfem)[8]
col_municipio <- names(cfem)[10]
col_quantidade <- names(cfem)[11]
col_unidade <- names(cfem)[12]
col_valor <- names(cfem)[13]

cfem_rr <- cfem |>
  transmute(
    ano = as.integer(.data[[col_ano]]),
    mes = as.integer(.data[[col_mes]]),
    uf = .data[[col_uf]],
    substancia = str_squish(.data[[col_subst]]),
    municipio = str_squish(.data[[col_municipio]]),
    quantidade = parse_br_num(.data[[col_quantidade]]),
    unidade = str_trim(.data[[col_unidade]]),
    valor_recolhido = parse_br_num(.data[[col_valor]])
  ) |>
  filter(
    uf == "RR",
    !is.na(ano),
    !is.na(mes),
    ano >= ano_inicio,
    ano <= ano_fim
  ) |>
  mutate(
    periodo_mensal = sprintf("%04dM%02d", ano, mes),
    trimestre = ceiling(mes / 3),
    periodo_trimestral = sprintf("%04dT%d", ano, trimestre)
  )

write_csv(cfem_rr, file.path(dir_output, "cfem_rr_micro_2020_2025.csv"))

message(sprintf("CFEM RR: %d registros entre %dM%02d e %dM%02d.",
                nrow(cfem_rr),
                min(cfem_rr$ano), min(cfem_rr$mes[cfem_rr$ano == min(cfem_rr$ano)]),
                max(cfem_rr$ano), max(cfem_rr$mes[cfem_rr$ano == max(cfem_rr$ano)])))

message("\n=== ETAPA 2: Agregar por substancia e construir pesos ===\n")

subst_mensal <- cfem_rr |>
  group_by(ano, mes, trimestre, periodo_mensal, periodo_trimestral, substancia, unidade) |>
  summarise(
    quantidade = sum(quantidade, na.rm = TRUE),
    valor_recolhido = sum(valor_recolhido, na.rm = TRUE),
    .groups = "drop"
  )

resumo_subst <- subst_mensal |>
  group_by(substancia) |>
  summarise(
    unidade_principal = unidade[which.max(tabulate(match(unidade, unique(unidade))))][1],
    n_meses = n(),
    n_unidades = n_distinct(unidade),
    valor_total_2020_2025 = sum(valor_recolhido, na.rm = TRUE),
    valor_total_2020_2023 = sum(valor_recolhido[ano %in% anos_benchmark], na.rm = TRUE),
    quantidade_media_2020 = mean(quantidade[ano == 2020], na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(
    elegivel_indice = quantidade_media_2020 > 0 & valor_total_2020_2023 > 0,
    peso_valor_2020_2023 = if_else(
      elegivel_indice,
      valor_total_2020_2023 / sum(valor_total_2020_2023[elegivel_indice], na.rm = TRUE),
      0
    ),
    motivo_exclusao = case_when(
      elegivel_indice ~ NA_character_,
      quantidade_media_2020 <= 0 & valor_total_2020_2023 <= 0 ~ "sem base 2020 e sem valor 2020-2023",
      quantidade_media_2020 <= 0 ~ "sem base positiva em 2020",
      valor_total_2020_2023 <= 0 ~ "sem valor 2020-2023",
      TRUE ~ "outro"
    )
  ) |>
  arrange(desc(valor_total_2020_2023))

write_csv(resumo_subst, file.path(dir_output, "cfem_rr_resumo_substancias.csv"))

subst_incluidas <- resumo_subst |>
  filter(elegivel_indice) |>
  select(substancia, unidade_principal, peso_valor_2020_2023)

write_csv(subst_incluidas, file.path(dir_output, "cfem_rr_substancias_incluidas.csv"))

message("Substancias elegiveis e pesos fixos (valor recolhido medio 2020-2023):")
print(subst_incluidas, n = nrow(subst_incluidas))

message("\n=== ETAPA 3: Indices por substancia e indice CFEM composto ===\n")

grade_mensal <- expand_grid(
  ano = ano_inicio:ano_fim,
  mes = 1:12,
  substancia = subst_incluidas$substancia
) |>
  mutate(
    trimestre = ceiling(mes / 3),
    periodo_mensal = sprintf("%04dM%02d", ano, mes),
    periodo_trimestral = sprintf("%04dT%d", ano, trimestre)
  )

subst_mensal_comp <- grade_mensal |>
  left_join(
    subst_mensal |>
      filter(substancia %in% subst_incluidas$substancia) |>
      group_by(ano, mes, trimestre, periodo_mensal, periodo_trimestral, substancia) |>
      summarise(
        quantidade = sum(quantidade, na.rm = TRUE),
        valor_recolhido = sum(valor_recolhido, na.rm = TRUE),
        .groups = "drop"
      ),
    by = c("ano", "mes", "trimestre", "periodo_mensal", "periodo_trimestral", "substancia")
  ) |>
  mutate(
    quantidade = replace_na(quantidade, 0),
    valor_recolhido = replace_na(valor_recolhido, 0)
  ) |>
  left_join(subst_incluidas, by = "substancia") |>
  group_by(substancia) |>
  mutate(
    base_mensal_2020 = mean(quantidade[ano == 2020], na.rm = TRUE),
    indice_quantidade_mensal = quantidade / base_mensal_2020 * 100
  ) |>
  ungroup()

write_csv(subst_mensal_comp, file.path(dir_output, "cfem_rr_mensal_substancias.csv"))

subst_trimestral <- subst_mensal_comp |>
  group_by(ano, trimestre, periodo_trimestral, substancia, peso_valor_2020_2023) |>
  summarise(
    quantidade_trimestre = sum(quantidade, na.rm = TRUE),
    valor_recolhido_trimestre = sum(valor_recolhido, na.rm = TRUE),
    .groups = "drop"
  ) |>
  group_by(substancia) |>
  mutate(
    base_trimestral_2020 = mean(quantidade_trimestre[ano == 2020], na.rm = TRUE),
    indice_quantidade_trimestral = quantidade_trimestre / base_trimestral_2020 * 100
  ) |>
  ungroup() |>
  left_join(select(subst_incluidas, substancia, unidade_principal), by = "substancia")

write_csv(subst_trimestral, file.path(dir_output, "cfem_rr_trimestral_substancias.csv"))

cfem_comp_trim <- subst_trimestral |>
  group_by(ano, trimestre, periodo_trimestral) |>
  summarise(
    indice_cfem_composto = sum(indice_quantidade_trimestral * peso_valor_2020_2023, na.rm = TRUE) /
      sum(peso_valor_2020_2023, na.rm = TRUE),
    .groups = "drop"
  )

write_csv(cfem_comp_trim, file.path(dir_output, "indice_cfem_extrativas_trimestral.csv"))

message("\n=== ETAPA 3B: Estrutura robusta da CFEM ===\n")

diag_robustez <- subst_trimestral |>
  group_by(substancia) |>
  summarise(
    unidade_principal = first(na.omit(unidade_principal)),
    valor_total_2020_2023 = sum(valor_recolhido_trimestre[ano %in% anos_benchmark], na.rm = TRUE),
    peso_valor_bruto = first(peso_valor_2020_2023),
    base_trimestral_2020 = mean(quantidade_trimestre[ano == 2020], na.rm = TRUE),
    n_trimestres_ativos_2020_2023 = sum(quantidade_trimestre[ano %in% anos_benchmark] > 0, na.rm = TRUE),
    mediana_qtd_2021_2023 = median(quantidade_trimestre[ano %in% 2021:2023 & quantidade_trimestre > 0], na.rm = TRUE),
    p95_qtd_2021_2025 = quantile(
      quantidade_trimestre[ano %in% 2021:ano_fim],
      probs = 0.95,
      na.rm = TRUE,
      names = FALSE
    ),
    indice_medio_2021_2023 = mean(
      indice_quantidade_trimestral[ano %in% 2021:2023],
      na.rm = TRUE
    ),
    indice_max_2021_2025 = max(
      indice_quantidade_trimestral[ano %in% 2021:ano_fim],
      na.rm = TRUE
    ),
    .groups = "drop"
  ) |>
  mutate(
    razao_mediana_base = mediana_qtd_2021_2023 / base_trimestral_2020,
    razao_p95_base = p95_qtd_2021_2025 / base_trimestral_2020,
    regra_base_2020 = is.finite(base_trimestral_2020) & base_trimestral_2020 > 0,
    regra_cobertura = n_trimestres_ativos_2020_2023 >= 8,
    regra_participacao = peso_valor_bruto >= 0.01,
    regra_escala = is.finite(razao_p95_base) & razao_p95_base <= 20,
    elegivel_robusto = regra_base_2020 & regra_cobertura & regra_participacao & regra_escala
  )

diag_robustez$motivo_regra <- purrr::map_chr(seq_len(nrow(diag_robustez)), \(i) {
  texto_regras(diag_robustez[i, ])
})

write_csv(diag_robustez, file.path(dir_output, "cfem_rr_diagnostico_robustez.csv"))

subst_robustas <- diag_robustez |>
  filter(elegivel_robusto) |>
  transmute(
    substancia,
    unidade_principal,
    valor_total_2020_2023,
    peso_valor_robusto = valor_total_2020_2023 / sum(valor_total_2020_2023, na.rm = TRUE),
    n_trimestres_ativos_2020_2023,
    base_trimestral_2020,
    razao_p95_base
  ) |>
  arrange(desc(peso_valor_robusto))

subst_excluidas_robustas <- diag_robustez |>
  filter(!elegivel_robusto) |>
  select(
    substancia, unidade_principal, peso_valor_bruto, n_trimestres_ativos_2020_2023,
    base_trimestral_2020, razao_p95_base, motivo_regra
  ) |>
  arrange(desc(peso_valor_bruto))

write_csv(subst_robustas, file.path(dir_output, "cfem_rr_substancias_robustas.csv"))
write_csv(subst_excluidas_robustas, file.path(dir_output, "cfem_rr_substancias_excluidas_robustas.csv"))

message("Substancias robustas mantidas no composto:")
print(subst_robustas, n = nrow(subst_robustas))

message("Substancias excluidas e motivo da exclusao robusta:")
print(subst_excluidas_robustas, n = nrow(subst_excluidas_robustas))

subst_trimestral_robusto <- subst_trimestral |>
  inner_join(select(subst_robustas, substancia, peso_valor_robusto), by = "substancia")

write_csv(
  subst_trimestral_robusto,
  file.path(dir_output, "cfem_rr_trimestral_substancias_robustas.csv")
)

cfem_robusto_trim <- subst_trimestral_robusto |>
  group_by(ano, trimestre, periodo_trimestral) |>
  summarise(
    indice_cfem_robusto = sum(indice_quantidade_trimestral * peso_valor_robusto, na.rm = TRUE) /
      sum(peso_valor_robusto, na.rm = TRUE),
    .groups = "drop"
  )

write_csv(
  cfem_robusto_trim,
  file.path(dir_output, "indice_cfem_extrativas_robusto_trimestral.csv")
)

message("\n=== ETAPA 4: CAGED B setorial ===\n")

caged_b <- read_csv(file.path(dir_raw_caged, "caged_rr_mensal.csv"), show_col_types = FALSE) |>
  filter(secao == "B") |>
  transmute(ano, mes, saldo)

grade_caged <- expand_grid(ano = ano_inicio:ano_fim, mes = 1:12)

caged_b_mensal <- grade_caged |>
  left_join(caged_b, by = c("ano", "mes")) |>
  mutate(
    saldo = replace_na(saldo, 0),
    estoque = cumsum(saldo) + 1000L,
    trimestre = ceiling(mes / 3),
    periodo_mensal = sprintf("%04dM%02d", ano, mes),
    periodo_trimestral = sprintf("%04dT%d", ano, trimestre)
  )

caged_b_trim <- caged_b_mensal |>
  group_by(ano, trimestre, periodo_trimestral) |>
  summarise(estoque_medio = mean(estoque, na.rm = TRUE), .groups = "drop") |>
  mutate(
    indice_caged_b = estoque_medio / mean(estoque_medio[ano == 2020], na.rm = TRUE) * 100
  )

write_csv(caged_b_mensal, file.path(dir_output, "caged_b_extrativas_mensal.csv"))
write_csv(caged_b_trim, file.path(dir_output, "caged_b_extrativas_trimestral.csv"))

message("\n=== ETAPA 5: Benchmark anual e otimizacao CFEM + CAGED B ===\n")

bench_extr <- read_csv(file.path(dir_processed, "contas_regionais_RR_volume.csv"), show_col_types = FALSE) |>
  filter(grepl("extrativ", atividade, ignore.case = TRUE), ano %in% anos_benchmark) |>
  arrange(ano)

if (nrow(bench_extr) != length(anos_benchmark)) {
  stop("Benchmark anual de extrativas incompleto nas Contas Regionais.")
}

base_otim <- cfem_comp_trim |>
  select(ano, trimestre, periodo_trimestral, indice_cfem_composto) |>
  left_join(select(caged_b_trim, ano, trimestre, indice_caged_b), by = c("ano", "trimestre"))

base_otim_robusta <- cfem_robusto_trim |>
  select(ano, trimestre, periodo_trimestral, indice_cfem_robusto) |>
  left_join(select(caged_b_trim, ano, trimestre, indice_caged_b), by = c("ano", "trimestre"))

grid_pesos <- tibble(peso_cfem = seq(0, 1, by = 0.05)) |>
  mutate(
    peso_caged_b = 1 - peso_cfem,
    objetivo = purrr::map_dbl(
      peso_cfem,
      \(w) {
        indicador <- base_otim |>
          filter(ano %in% anos_benchmark) |>
          mutate(indice_raw = w * indice_cfem_composto + (1 - w) * indice_caged_b) |>
          pull(indice_raw)
        objetivo_denton(indicador, bench_extr$vab_volume_rebased)
      }
    )
  ) |>
  arrange(objetivo)

write_csv(grid_pesos, file.path(dir_output, "otimizacao_cfem_caged_b.csv"))

grid_pesos_robusto <- tibble(peso_cfem_robusto = seq(0, 1, by = 0.05)) |>
  mutate(
    peso_caged_b = 1 - peso_cfem_robusto,
    objetivo = purrr::map_dbl(
      peso_cfem_robusto,
      \(w) {
        indicador <- base_otim_robusta |>
          filter(ano %in% anos_benchmark) |>
          mutate(indice_raw = w * indice_cfem_robusto + (1 - w) * indice_caged_b) |>
          pull(indice_raw)
        objetivo_denton(indicador, bench_extr$vab_volume_rebased)
      }
    )
  ) |>
  arrange(objetivo)

write_csv(grid_pesos_robusto, file.path(dir_output, "otimizacao_cfem_robusto_caged_b.csv"))

melhor <- grid_pesos |> slice(1)
melhor_robusto <- grid_pesos_robusto |> slice(1)

indice_extrativas_exploratorio <- base_otim |>
  mutate(
    peso_cfem = melhor$peso_cfem,
    peso_caged_b = melhor$peso_caged_b,
    indice_extrativas_raw = peso_cfem * indice_cfem_composto + peso_caged_b * indice_caged_b
  )

bench_ext <- estender_benchmark(
  bench_ano = bench_extr$ano,
  bench_val = bench_extr$vab_volume_rebased,
  ano_max = max(indice_extrativas_exploratorio$ano),
  n_ref = 2
)

indice_denton <- denton(
  indicador_trim = indice_extrativas_exploratorio$indice_extrativas_raw,
  benchmark_anual = bench_ext$bench,
  ano_inicio = min(bench_ext$ano),
  metodo = "denton-cholette"
)

indice_extrativas_exploratorio <- indice_extrativas_exploratorio |>
  mutate(
    indice_extrativas_denton = indice_denton,
    indice_extrativas_denton = indice_extrativas_denton /
      mean(indice_extrativas_denton[ano == 2020], na.rm = TRUE) * 100
  )

write_csv(indice_extrativas_exploratorio, file.path(dir_output, "indice_extrativas_exploratorio_trimestral.csv"))

indice_extrativas_robusto <- base_otim_robusta |>
  mutate(
    peso_cfem_robusto = melhor_robusto$peso_cfem_robusto,
    peso_caged_b = melhor_robusto$peso_caged_b,
    indice_extrativas_raw = peso_cfem_robusto * indice_cfem_robusto + peso_caged_b * indice_caged_b
  )

indice_denton_robusto <- denton(
  indicador_trim = indice_extrativas_robusto$indice_extrativas_raw,
  benchmark_anual = bench_ext$bench,
  ano_inicio = min(bench_ext$ano),
  metodo = "denton-cholette"
)

indice_extrativas_robusto <- indice_extrativas_robusto |>
  mutate(
    indice_extrativas_denton = indice_denton_robusto,
    indice_extrativas_denton = indice_extrativas_denton /
      mean(indice_extrativas_denton[ano == 2020], na.rm = TRUE) * 100
  )

write_csv(
  indice_extrativas_robusto,
  file.path(dir_output, "indice_extrativas_robusto_trimestral.csv")
)

comparacao_anual <- indice_extrativas_exploratorio |>
  group_by(ano) |>
  summarise(
    cfem = mean(indice_cfem_composto, na.rm = TRUE),
    caged_b = mean(indice_caged_b, na.rm = TRUE),
    combinado = mean(indice_extrativas_denton, na.rm = TRUE),
    .groups = "drop"
  ) |>
  left_join(
    bench_extr |>
      transmute(ano, benchmark_cr = vab_volume_rebased),
    by = "ano"
  )

write_csv(comparacao_anual, file.path(dir_output, "comparacao_anual_cfem_caged_benchmark.csv"))

comparacao_anual_robusta <- indice_extrativas_robusto |>
  group_by(ano) |>
  summarise(
    cfem_robusto = mean(indice_cfem_robusto, na.rm = TRUE),
    caged_b = mean(indice_caged_b, na.rm = TRUE),
    combinado_robusto = mean(indice_extrativas_denton, na.rm = TRUE),
    .groups = "drop"
  ) |>
  left_join(
    bench_extr |>
      transmute(ano, benchmark_cr = vab_volume_rebased),
    by = "ano"
  )

write_csv(
  comparacao_anual_robusta,
  file.path(dir_output, "comparacao_anual_cfem_robusto_caged_benchmark.csv")
)

message(sprintf("Peso otimo na grade: CFEM = %.0f%% | CAGED B = %.0f%%",
                melhor$peso_cfem * 100, melhor$peso_caged_b * 100))
message(sprintf("Peso otimo robusto: CFEM robusto = %.0f%% | CAGED B = %.0f%%",
                melhor_robusto$peso_cfem_robusto * 100, melhor_robusto$peso_caged_b * 100))

message("\n=== ETAPA 6: Graficos ===\n")

top_subst <- subst_incluidas |>
  arrange(desc(peso_valor_2020_2023)) |>
  slice_head(n = 5) |>
  pull(substancia)

graf_top_subst <- subst_trimestral |>
  filter(substancia %in% top_subst) |>
  transmute(
    periodo = periodo_trimestral,
    serie = substancia,
    indice = indice_quantidade_trimestral
  )

salvar_grafico_trimestral(graf_top_subst, "CFEM RR: indices trimestrais das principais substancias", "cfem_top_substancias.png")

top_subst_robustas <- subst_robustas |>
  arrange(desc(peso_valor_robusto)) |>
  slice_head(n = 5) |>
  pull(substancia)

graf_top_subst_robustas <- subst_trimestral_robusto |>
  filter(substancia %in% top_subst_robustas) |>
  transmute(
    periodo = periodo_trimestral,
    serie = substancia,
    indice = indice_quantidade_trimestral
  )

salvar_grafico_trimestral(
  graf_top_subst_robustas,
  "CFEM RR robusta: indices trimestrais das substancias mantidas",
  "cfem_top_substancias_robustas.png"
)

graf_proxy <- indice_extrativas_exploratorio |>
  transmute(
    periodo = periodo_trimestral,
    `CFEM composto` = indice_cfem_composto,
    `CAGED B` = indice_caged_b,
    `Indice exploratorio` = indice_extrativas_denton
  ) |>
  pivot_longer(-periodo, names_to = "serie", values_to = "indice")

salvar_grafico_trimestral(graf_proxy, "Extrativas: CFEM composto, CAGED B e indice exploratorio", "cfem_caged_indice_exploratorio.png")

graf_proxy_robusta <- indice_extrativas_robusto |>
  transmute(
    periodo = periodo_trimestral,
    `CFEM robusto` = indice_cfem_robusto,
    `CAGED B` = indice_caged_b,
    `Indice robusto` = indice_extrativas_denton
  ) |>
  pivot_longer(-periodo, names_to = "serie", values_to = "indice")

salvar_grafico_trimestral(
  graf_proxy_robusta,
  "Extrativas: CFEM robusto, CAGED B e indice robusto",
  "cfem_caged_indice_robusto.png"
)

graf_otim <- ggplot(grid_pesos, aes(x = peso_cfem, y = objetivo)) +
  geom_line(linewidth = 0.8, color = "#2c7fb8") +
  geom_point(data = melhor, color = "#d95f0e", size = 2) +
  scale_x_continuous(labels = percent_format(accuracy = 1)) +
  labs(
    title = "Extrativas: grade de otimizacao CFEM x CAGED B",
    x = "Peso da CFEM no indicador bruto",
    y = "Objetivo de variancia do Denton"
  ) +
  theme_minimal(base_size = 11)

ggsave(file.path(dir_output, "cfem_caged_otimizacao.png"), graf_otim, width = 8.5, height = 5, dpi = 150)

graf_otim_robusto <- ggplot(grid_pesos_robusto, aes(x = peso_cfem_robusto, y = objetivo)) +
  geom_line(linewidth = 0.8, color = "#2c7fb8") +
  geom_point(data = melhor_robusto, color = "#d95f0e", size = 2) +
  scale_x_continuous(labels = percent_format(accuracy = 1)) +
  labs(
    title = "Extrativas: grade de otimizacao CFEM robusto x CAGED B",
    x = "Peso da CFEM robusta no indicador bruto",
    y = "Objetivo de variancia do Denton"
  ) +
  theme_minimal(base_size = 11)

ggsave(file.path(dir_output, "cfem_caged_otimizacao_robusta.png"), graf_otim_robusto, width = 8.5, height = 5, dpi = 150)

message("\n=== ETAPA 7: Nota metodologica ===\n")

linhas_nota <- c(
  "# CFEM e Extrativas: indice composto exploratorio e versao robusta",
  "",
  sprintf("Gerado em %s pelo script `R/99_explora_cfem_extrativas.R`.", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  "",
  "## O que foi feito",
  "",
  "1. Baixada e consolidada a base da CFEM da ANM para Roraima.",
  "2. Agregacao mensal por substancia mineral.",
  "3. Construcao de um indice de quantidade por substancia, sempre comparando cada substancia com sua propria base de 2020.",
  "4. Combinacao das substancias por pesos fixos de valor recolhido medio em 2020-2023.",
  "5. Montagem de uma proxy complementar com CAGED secao B.",
  "6. Otimizacao da combinacao CFEM + CAGED B por grade, minimizando a variancia do ajuste Denton no benchmark anual 2020-2023.",
  "7. Criado um diagnostico de robustez por substancia para isolar bases fisicas muito pequenas e series desproporcionais.",
  "8. Construida uma versao robusta da CFEM para comparacao com a versao exploratoria.",
  "",
  "## Formula do indice por substancia",
  "",
  "Para cada substancia s e periodo t:",
  "",
  "`indice_s,t = quantidade_s,t / media_2020_s * 100`",
  "",
  "A quantidade nao e somada entre substancias. Cada serie e normalizada dentro da propria unidade fisica.",
  "",
  "## Formula do indice composto CFEM",
  "",
  "Com pesos fixos `w_s` obtidos da participacao media do `ValorRecolhido` em 2020-2023:",
  "",
  "`indice_cfem_t = soma( w_s * indice_s,t )`",
  "",
  sprintf("## Peso otimo encontrado na grade exploratoria\n\n- CFEM: %.0f%%\n- CAGED B: %.0f%%", melhor$peso_cfem * 100, melhor$peso_caged_b * 100),
  "",
  "## Regras da versao robusta",
  "",
  "A versao robusta manteve apenas as substancias que passaram simultaneamente nestes filtros:",
  "",
  "1. base trimestral positiva em 2020;",
  "2. pelo menos 8 trimestres com quantidade positiva entre 2020T1 e 2023T4;",
  "3. participacao minima de 1% no valor recolhido total de 2020-2023;",
  "4. razao entre o percentil 95 da quantidade trimestral (2021-2025) e a base trimestral de 2020 menor ou igual a 20.",
  "",
  "A quarta regra foi criada para evitar o problema de series com base 2020 muito pequena e explosao artificial do indice composto.",
  "",
  sprintf("## Peso otimo encontrado na grade robusta\n\n- CFEM robusto: %.0f%%\n- CAGED B: %.0f%%",
          melhor_robusto$peso_cfem_robusto * 100, melhor_robusto$peso_caged_b * 100),
  "",
  "## Arquivos para enxergar o processo por dentro",
  "",
  "- `data/output/extrativas_cfem/cfem_rr_diagnostico_robustez.csv`",
  "- `data/output/extrativas_cfem/cfem_rr_substancias_robustas.csv`",
  "- `data/output/extrativas_cfem/cfem_rr_substancias_excluidas_robustas.csv`",
  "- `data/output/extrativas_cfem/cfem_rr_trimestral_substancias_robustas.csv`",
  "- `data/output/extrativas_cfem/indice_cfem_extrativas_robusto_trimestral.csv`",
  "- `data/output/extrativas_cfem/otimizacao_cfem_robusto_caged_b.csv`",
  "- `data/output/extrativas_cfem/indice_extrativas_robusto_trimestral.csv`",
  "- `data/output/extrativas_cfem/comparacao_anual_cfem_robusto_caged_benchmark.csv`",
  "- `data/output/extrativas_cfem/cfem_top_substancias_robustas.png`",
  "- `data/output/extrativas_cfem/cfem_caged_indice_robusto.png`",
  "- `data/output/extrativas_cfem/cfem_caged_otimizacao_robusta.png`",
  "",
  "## Arquivos gerados",
  "",
  "- `data/output/extrativas_cfem/cfem_rr_resumo_substancias.csv`",
  "- `data/output/extrativas_cfem/cfem_rr_substancias_incluidas.csv`",
  "- `data/output/extrativas_cfem/cfem_rr_mensal_substancias.csv`",
  "- `data/output/extrativas_cfem/cfem_rr_trimestral_substancias.csv`",
  "- `data/output/extrativas_cfem/indice_cfem_extrativas_trimestral.csv`",
  "- `data/output/extrativas_cfem/caged_b_extrativas_trimestral.csv`",
  "- `data/output/extrativas_cfem/otimizacao_cfem_caged_b.csv`",
  "- `data/output/extrativas_cfem/indice_extrativas_exploratorio_trimestral.csv`",
  "- `data/output/extrativas_cfem/comparacao_anual_cfem_caged_benchmark.csv`",
  "- `data/output/extrativas_cfem/cfem_top_substancias.png`",
  "- `data/output/extrativas_cfem/cfem_caged_indice_exploratorio.png`",
  "- `data/output/extrativas_cfem/cfem_caged_otimizacao.png`",
  "- `data/output/extrativas_cfem/cfem_top_substancias_robustas.png`",
  "- `data/output/extrativas_cfem/cfem_caged_indice_robusto.png`",
  "- `data/output/extrativas_cfem/cfem_caged_otimizacao_robusta.png`"
)

writeLines(linhas_nota, arq_nota, useBytes = TRUE)

message(sprintf("Nota salva em: %s", arq_nota))
message(sprintf("Arquivos auxiliares em: %s", dir_output))
