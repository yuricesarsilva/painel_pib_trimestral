# ============================================================
# Projeto : Indicador de Atividade Econômica Trimestral — RR
# Script  : 05h_vab_nominal_setorial.R
# Autor   : Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)
# Data    : 2026-04-14
# Fase    : 5.9 — VAB Nominal Setorial Trimestral
# Descrição: Gera séries trimestrais do VAB nominal dos quatro
#            blocos do projeto (Agropecuária, AAPP, Indústria
#            e Serviços) para os anos com benchmark das Contas
#            Regionais do IBGE (2020–2023).
#
#   Metodologia:
#     1. VAB nominal anual por bloco = soma das atividades
#        correspondentes nas Contas Regionais (R$ milhões)
#     2. Índice anual de volume por bloco = agregação Laspeyres
#        base 2020 dos índices de volume das atividades do bloco
#     3. Deflator anual por bloco = índice nominal / índice real
#     4. Deflator trimestral = Denton-Cholette(deflator_anual, IPCA_trim)
#     5. Indicador nominal trimestral = índice real trimestral ×
#        deflator trimestral / 100
#     6. VAB nominal trimestral = Denton-Cholette(
#        VAB_nominal_anual ~ indicador_nominal_trimestral,
#        conversion = "sum")
#
# Entrada : data/processed/contas_regionais_RR_serie.csv
#            data/processed/contas_regionais_RR_volume.csv
#            data/raw/ipca_mensal.csv
#            data/output/indice_agropecuaria.csv
#            data/output/indice_adm_publica.csv
#            data/output/indice_industria.csv
#            data/output/indice_servicos.csv
# Saída   : data/output/vab_nominal_setorial_rr.csv
#            data/output/vab_nominal_setorial_anual_rr.csv
# Depende : dplyr, tidyr, readr, tempdisagg
# ============================================================

source("R/utils.R")

library(dplyr)
library(tidyr)
library(readr)
library(tempdisagg)

# --- Caminhos -----------------------------------------------

dir_processed <- file.path("data", "processed")
dir_raw       <- file.path("data", "raw")
dir_output    <- file.path("data", "output")

arq_cr_serie  <- file.path(dir_processed, "contas_regionais_RR_serie.csv")
arq_cr_volume <- file.path(dir_processed, "contas_regionais_RR_volume.csv")
arq_ipca      <- file.path(dir_raw,       "ipca_mensal.csv")
arq_agro      <- file.path(dir_output,    "indice_agropecuaria.csv")
arq_aapp      <- file.path(dir_output,    "indice_adm_publica.csv")
arq_ind       <- file.path(dir_output,    "indice_industria.csv")
arq_serv      <- file.path(dir_output,    "indice_servicos.csv")
arq_saida     <- file.path(dir_output,    "vab_nominal_setorial_rr.csv")
arq_saida_an  <- file.path(dir_output,    "vab_nominal_setorial_anual_rr.csv")

# --- Parâmetros ---------------------------------------------

ano_inicio <- 2020L
anos_cr    <- 2020:2023

ativ_agro <- c("Agropecuária")
ativ_aapp <- c("Adm., defesa, educação e saúde públicas e seguridade social")
ativ_ind  <- c(
  "Eletricidade, gás, água, esgoto e resíduos (SIUP)",
  "Construção",
  "Indústrias de transformação"
)
ativ_serv <- c(
  "Comércio e reparação de veículos automotores",
  "Transporte, armazenagem e correio",
  "Atividades financeiras, de seguros e serviços relacionados",
  "Atividades imobiliárias",
  "Outros serviços",
  "Informação e comunicação",
  "Indústrias extrativas"
)

mapa_blocos <- tibble(
  setor = c("Agropecuária", "AAPP", "Indústria", "Serviços"),
  atividade = list(ativ_agro, ativ_aapp, ativ_ind, ativ_serv)
) |>
  tidyr::unnest(atividade)


# ============================================================
# ETAPA 5.9.1 — Carregar insumos
# ============================================================

message("\n=== ETAPA 5.9.1: Carregando insumos ===\n")

cr_nom <- read_csv(arq_cr_serie, show_col_types = FALSE)
cr_vol <- read_csv(arq_cr_volume, show_col_types = FALSE)
ipca_raw <- read_csv(arq_ipca, show_col_types = FALSE)

agro_trim <- read_csv(arq_agro, show_col_types = FALSE) |>
  filter(ano %in% anos_cr) |>
  transmute(ano, trimestre, setor = "Agropecuária", indice_real = indice_agropecuaria)

aapp_trim <- read_csv(arq_aapp, show_col_types = FALSE) |>
  filter(ano %in% anos_cr) |>
  transmute(ano, trimestre, setor = "AAPP", indice_real = indice_adm_publica)

ind_trim <- read_csv(arq_ind, show_col_types = FALSE) |>
  filter(ano %in% anos_cr) |>
  transmute(ano, trimestre, setor = "Indústria", indice_real = indice_industria)

serv_trim <- read_csv(arq_serv, show_col_types = FALSE) |>
  filter(ano %in% anos_cr) |>
  transmute(ano, trimestre, setor = "Serviços", indice_real = indice_servicos)

indices_trim <- bind_rows(agro_trim, aapp_trim, ind_trim, serv_trim) |>
  mutate(periodo = sprintf("%dT%d", ano, trimestre)) |>
  arrange(setor, ano, trimestre)

if (any(is.na(indices_trim$indice_real))) {
  stop("Há lacunas nas séries trimestrais reais por bloco.", call. = FALSE)
}


# ============================================================
# ETAPA 5.9.2 — Benchmarks anuais nominais e reais por bloco
# ============================================================

message("\n=== ETAPA 5.9.2: Benchmarks anuais por bloco ===\n")

pesos_2020 <- cr_nom |>
  filter(ano == 2020) |>
  inner_join(mapa_blocos, by = "atividade") |>
  group_by(setor) |>
  mutate(peso_2020 = vab_mi / sum(vab_mi, na.rm = TRUE)) |>
  ungroup() |>
  select(setor, atividade, peso_2020, vab_mi_2020 = vab_mi)

nominal_anual_bloco <- cr_nom |>
  filter(ano %in% anos_cr) |>
  inner_join(mapa_blocos, by = "atividade") |>
  group_by(setor, ano) |>
  summarise(vab_nominal_mi_benchmark = sum(vab_mi, na.rm = TRUE), .groups = "drop")

volume_anual_bloco <- cr_vol |>
  filter(ano %in% anos_cr) |>
  inner_join(pesos_2020 |> select(setor, atividade, peso_2020), by = "atividade") |>
  group_by(setor, ano) |>
  summarise(indice_real_anual = sum(vab_volume_rebased * peso_2020, na.rm = TRUE), .groups = "drop")

benchmark_bloco <- nominal_anual_bloco |>
  left_join(volume_anual_bloco, by = c("setor", "ano")) |>
  group_by(setor) |>
  mutate(
    vab_nominal_2020 = vab_nominal_mi_benchmark[ano == 2020][1],
    indice_nominal_anual = vab_nominal_mi_benchmark / vab_nominal_2020 * 100,
    deflator_anual = indice_nominal_anual / (indice_real_anual / 100)
  ) |>
  ungroup() |>
  arrange(setor, ano)

if (any(is.na(benchmark_bloco$deflator_anual))) {
  stop("Falha ao calcular deflator anual por bloco.", call. = FALSE)
}

message("Benchmarks anuais por bloco montados com sucesso.")


# ============================================================
# ETAPA 5.9.3 — IPCA trimestral para Denton do deflator
# ============================================================

message("\n=== ETAPA 5.9.3: IPCA trimestral ===\n")

col_mes <- names(ipca_raw)[grep("ês.*ódigo|ódigo.*ês|Mês.*Código|Código.*Mês",
                                names(ipca_raw), ignore.case = TRUE)][1]

ipca_trim <- ipca_raw |>
  rename(mes_cod = all_of(col_mes), valor = Valor) |>
  filter(!is.na(valor), valor > 0) |>
  mutate(
    mes_cod = as.character(mes_cod),
    ano = as.integer(substr(mes_cod, 1, 4)),
    mes = as.integer(substr(mes_cod, 5, 6)),
    trimestre = ceiling(mes / 3)
  ) |>
  filter(ano %in% anos_cr) |>
  group_by(ano, trimestre) |>
  summarise(ipca_trim = mean(valor, na.rm = TRUE), .groups = "drop") |>
  arrange(ano, trimestre)

media_ipca_2020 <- ipca_trim |>
  filter(ano == 2020) |>
  summarise(media = mean(ipca_trim, na.rm = TRUE)) |>
  pull(media)

ipca_trim <- ipca_trim |>
  mutate(ipca_rebased = ipca_trim / media_ipca_2020 * 100)

if (nrow(ipca_trim) != length(anos_cr) * 4) {
  stop("IPCA trimestral incompleto para 2020–2023.", call. = FALSE)
}


# ============================================================
# ETAPA 5.9.4 — Trimestralizar deflator e gerar nominal setorial
# ============================================================

message("\n=== ETAPA 5.9.4: Deflator trimestral e VAB nominal setorial ===\n")

setores <- unique(benchmark_bloco$setor)

resultado_setorial <- lapply(setores, function(setor_atual) {
  bench_setor <- benchmark_bloco |>
    filter(setor == setor_atual) |>
    arrange(ano)

  real_trim_setor <- indices_trim |>
    filter(setor == setor_atual) |>
    arrange(ano, trimestre)

  serie_deflator <- ts(
    bench_setor$deflator_anual,
    start = min(anos_cr),
    frequency = 1
  )
  indicador_ipca <- ts(
    ipca_trim$ipca_rebased,
    start = c(min(anos_cr), 1),
    frequency = 4
  )

  deflator_trim <- tryCatch({
    mod <- tempdisagg::td(
      serie_deflator ~ 0 + indicador_ipca,
      method = "denton-cholette",
      conversion = "mean"
    )
    as.numeric(predict(mod))
  }, error = function(e) {
    stop(sprintf("Falha ao trimestralizar o deflator de %s: %s", setor_atual, e$message),
         call. = FALSE)
  })

  indicador_nominal_trim <- real_trim_setor$indice_real * deflator_trim / 100

  serie_benchmark_nominal <- ts(
    bench_setor$vab_nominal_mi_benchmark,
    start = min(anos_cr),
    frequency = 1
  )
  serie_indicador_nominal <- ts(
    indicador_nominal_trim,
    start = c(min(anos_cr), 1),
    frequency = 4
  )

  vab_nominal_trim <- tryCatch({
    mod <- tempdisagg::td(
      serie_benchmark_nominal ~ 0 + serie_indicador_nominal,
      method = "denton-cholette",
      conversion = "sum"
    )
    as.numeric(predict(mod))
  }, error = function(e) {
    stop(sprintf("Falha ao trimestralizar o VAB nominal de %s: %s", setor_atual, e$message),
         call. = FALSE)
  })

  saida_setor <- real_trim_setor |>
    mutate(
      periodo = sprintf("%dT%d", ano, trimestre),
      deflator_trim = deflator_trim,
      indice_nominal_indicador = indicador_nominal_trim,
      vab_nominal_mi = vab_nominal_trim
    )

  validar_serie(saida_setor$vab_nominal_mi, paste("VAB nominal setorial", setor_atual))
  saida_setor
}) |>
  bind_rows() |>
  arrange(setor, ano, trimestre)


# ============================================================
# ETAPA 5.9.5 — Validação anual e salvamento
# ============================================================

message("\n=== ETAPA 5.9.5: Validação anual e salvamento ===\n")

resumo_anual <- resultado_setorial |>
  group_by(setor, ano) |>
  summarise(
    vab_nominal_mi_trimestralizado = sum(vab_nominal_mi, na.rm = TRUE),
    indice_real_anual_projeto = mean(indice_real, na.rm = TRUE),
    .groups = "drop"
  ) |>
  left_join(
    benchmark_bloco |>
      select(setor, ano, vab_nominal_mi_benchmark, indice_real_anual, deflator_anual),
    by = c("setor", "ano")
  ) |>
  mutate(
    diferenca_mi = vab_nominal_mi_trimestralizado - vab_nominal_mi_benchmark,
    diferenca_pct = ifelse(vab_nominal_mi_benchmark == 0, NA_real_,
                           diferenca_mi / vab_nominal_mi_benchmark * 100)
  ) |>
  arrange(setor, ano)

desvio_max <- max(abs(resumo_anual$diferenca_mi), na.rm = TRUE)
if (desvio_max > 1e-4) {
  warning(sprintf("Fechamento anual setorial com desvio máximo de %.6f mi.", desvio_max), call. = FALSE)
} else {
  message(sprintf("✓ Fechamento anual setorial OK (desvio máximo = %.8f mi)", desvio_max))
}

write_csv(resultado_setorial, arq_saida)
write_csv(resumo_anual, arq_saida_an)

message(sprintf("✓ Série trimestral salva em: %s", arq_saida))
message(sprintf("✓ Resumo anual salvo em: %s", arq_saida_an))
message("\n=== Fase 5.9 — script concluído com sucesso ===")
