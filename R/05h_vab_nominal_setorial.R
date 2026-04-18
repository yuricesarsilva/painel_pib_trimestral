# ============================================================
# Projeto : Indicador de Atividade Economica Trimestral - RR
# Script  : 05h_vab_nominal_setorial.R
# Autor   : Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)
# Data    : 2026-04-15
# Fase    : 5.9 - VAB Nominal Setorial Trimestral
# Descricao: Gera series trimestrais do VAB nominal dos quatro
#            setores do projeto (Agropecuaria, AAPP, Industria
#            e Servicos), preservando o benchmark oficial das
#            Contas Regionais do IBGE em 2020-2023 e
#            extrapolando 2024-2025 com base no indicador
#            nominal setorial do proprio projeto.
#
#   Metodologia:
#     1. VAB nominal anual oficial por setor = soma das atividades
#        correspondentes nas Contas Regionais (R$ milhoes)
#     2. Indice anual de volume oficial por setor = agregacao
#        Laspeyres base 2020 das atividades do setor
#     3. Deflator anual oficial por setor = indice nominal / indice real
#     4. Deflator anual e VAB nominal anual sao estendidos para os
#        anos sem benchmark oficial usando o indicador do projeto
#     5. Deflator trimestral = Denton-Cholette(deflator_anual, IPCA_trim),
#        com o IPCA servindo apenas de proxy temporal
#     6. Indicador nominal trimestral = indice_real * deflator_trim / 100
#     7. VAB nominal trimestral = Denton-Cholette(
#        VAB_nominal_anual ~ indicador_nominal_trimestral,
#        conversion = "sum")
#
# Entrada : data/processed/contas_regionais_RR_serie.csv
#           data/processed/contas_regionais_RR_volume.csv
#           data/raw/ipca_mensal.csv
#           data/output/indice_agropecuaria.csv
#           data/output/indice_adm_publica.csv
#           data/output/indice_industria.csv
#           data/output/indice_servicos.csv
# Saida   : data/output/vab_nominal_setorial_rr.csv
#           data/output/vab_nominal_setorial_anual_rr.csv
# Depende : dplyr, tidyr, readr, tempdisagg
# ============================================================

source("R/utils.R")

library(dplyr)
library(tidyr)
library(readr)
library(tempdisagg)

normalizar_texto <- function(x) {
  x <- iconv(x, from = "", to = "ASCII//TRANSLIT")
  x <- tolower(x)
  x <- gsub("[^a-z0-9]+", " ", x)
  trimws(x)
}

# --- Caminhos -----------------------------------------------

dir_processed <- file.path("data", "processed")
dir_raw <- file.path("data", "raw")
dir_output <- file.path("data", "output")

arq_cr_serie <- file.path(dir_processed, "contas_regionais_RR_serie.csv")
arq_cr_volume <- file.path(dir_processed, "contas_regionais_RR_volume.csv")
arq_ipca <- file.path(dir_raw, "ipca_mensal.csv")
arq_agro <- file.path(dir_output, "indice_agropecuaria.csv")
arq_aapp <- file.path(dir_output, "indice_adm_publica.csv")
arq_ind <- file.path(dir_output, "indice_industria.csv")
arq_serv <- file.path(dir_output, "indice_servicos.csv")
arq_saida <- file.path(dir_output, "vab_nominal_setorial_rr.csv")
arq_saida_an <- file.path(dir_output, "vab_nominal_setorial_anual_rr.csv")

# --- Parametros ---------------------------------------------

ano_inicio <- 2020L

ativ_agro <- c("Agropecuaria")
ativ_aapp <- c("Adm., defesa, educacao e saude publicas e seguridade social")
ativ_ind <- c(
  "Eletricidade, gas, agua, esgoto e residuos (SIUP)",
  "Construcao",
  "Industrias de transformacao"
)
ativ_serv <- c(
  "Comercio e reparacao de veiculos automotores",
  "Transporte, armazenagem e correio",
  "Atividades financeiras, de seguros e servicos relacionados",
  "Atividades imobiliarias",
  "Outros servicos",
  "Informacao e comunicacao",
  "Industrias extrativas"
)

mapa_setores <- tibble(
  setor = c("Agropecuaria", "AAPP", "Industria", "Servicos"),
  atividade = list(ativ_agro, ativ_aapp, ativ_ind, ativ_serv)
) |>
  tidyr::unnest(atividade) |>
  mutate(atividade_key = normalizar_texto(atividade))


# ============================================================
# ETAPA 5.9.1 - Carregar insumos
# ============================================================

message("\n=== ETAPA 5.9.1: Carregando insumos ===\n")

cr_nom <- read_csv(arq_cr_serie, show_col_types = FALSE)
cr_vol <- read_csv(arq_cr_volume, show_col_types = FALSE)
ipca_raw <- read_csv(arq_ipca, show_col_types = FALSE)

cr_nom_map <- cr_nom |>
  mutate(atividade_key = normalizar_texto(atividade))

cr_vol_map <- cr_vol |>
  mutate(atividade_key = normalizar_texto(atividade))

anos_cr <- intersect(sort(unique(cr_nom$ano)), sort(unique(cr_vol$ano)))
anos_cr <- anos_cr[anos_cr >= ano_inicio]

agro_trim <- read_csv(arq_agro, show_col_types = FALSE) |>
  filter(ano >= ano_inicio) |>
  transmute(ano, trimestre, setor = "Agropecuaria", indice_real = indice_agropecuaria)

aapp_trim <- read_csv(arq_aapp, show_col_types = FALSE) |>
  filter(ano >= ano_inicio) |>
  transmute(ano, trimestre, setor = "AAPP", indice_real = indice_adm_publica)

ind_trim <- read_csv(arq_ind, show_col_types = FALSE) |>
  filter(ano >= ano_inicio) |>
  transmute(ano, trimestre, setor = "Industria", indice_real = indice_industria)

serv_trim <- read_csv(arq_serv, show_col_types = FALSE) |>
  filter(ano >= ano_inicio) |>
  transmute(ano, trimestre, setor = "Servicos", indice_real = indice_servicos)

indices_trim <- bind_rows(agro_trim, aapp_trim, ind_trim, serv_trim) |>
  mutate(periodo = sprintf("%dT%d", ano, trimestre)) |>
  arrange(setor, ano, trimestre)

anos_saida <- sort(unique(indices_trim$ano))
ano_fim <- max(anos_saida)

if (any(is.na(indices_trim$indice_real))) {
  stop("Ha lacunas nas series trimestrais reais por setor.", call. = FALSE)
}

contagem_setores <- indices_trim |>
  count(setor, ano)

if (any(contagem_setores$n != 4)) {
  stop("As series trimestrais reais setoriais nao possuem 4 trimestres em todos os anos.", call. = FALSE)
}


# ============================================================
# ETAPA 5.9.2 - Benchmarks anuais oficiais por setor
# ============================================================

message("\n=== ETAPA 5.9.2: Benchmarks anuais oficiais por setor ===\n")

pesos_2020 <- cr_nom_map |>
  filter(ano == ano_inicio) |>
  inner_join(mapa_setores, by = "atividade_key") |>
  group_by(setor) |>
  mutate(peso_2020 = vab_mi / sum(vab_mi, na.rm = TRUE)) |>
  ungroup() |>
  select(setor, atividade_key, peso_2020)

nominal_anual_setor <- cr_nom_map |>
  filter(ano %in% anos_cr) |>
  inner_join(mapa_setores, by = "atividade_key") |>
  group_by(setor, ano) |>
  summarise(vab_nominal_mi_benchmark = sum(vab_mi, na.rm = TRUE), .groups = "drop")

volume_anual_setor <- cr_vol_map |>
  filter(ano %in% anos_cr) |>
  inner_join(pesos_2020, by = "atividade_key") |>
  group_by(setor, ano) |>
  summarise(indice_real_anual = sum(vab_volume_rebased * peso_2020, na.rm = TRUE), .groups = "drop")

benchmark_oficial <- nominal_anual_setor |>
  left_join(volume_anual_setor, by = c("setor", "ano")) |>
  group_by(setor) |>
  mutate(
    vab_nominal_2020 = vab_nominal_mi_benchmark[ano == ano_inicio][1],
    indice_nominal_anual = vab_nominal_mi_benchmark / vab_nominal_2020 * 100,
    deflator_anual = indice_nominal_anual / (indice_real_anual / 100)
  ) |>
  ungroup() |>
  arrange(setor, ano)

if (any(is.na(benchmark_oficial$deflator_anual))) {
  stop("Falha ao calcular o deflator anual oficial por setor.", call. = FALSE)
}

message("Benchmarks anuais oficiais por setor montados com sucesso.")


# ============================================================
# ETAPA 5.9.3 - IPCA trimestral para Denton do deflator
# ============================================================

message("\n=== ETAPA 5.9.3: IPCA trimestral ===\n")

col_mes <- names(ipca_raw)[names(ipca_raw) == "Mês (Código)"][1]
if (is.na(col_mes)) {
  col_mes <- names(ipca_raw)[grep("es.*odigo|odigo.*es|Mes.*Codigo|Codigo.*Mes",
                                  names(ipca_raw), ignore.case = TRUE)][1]
}
if (is.na(col_mes)) {
  stop("Nao foi possivel identificar a coluna de codigo do mes no IPCA.", call. = FALSE)
}

ipca_trim <- ipca_raw |>
  rename(mes_cod = all_of(col_mes), valor = Valor) |>
  filter(!is.na(valor), valor > 0) |>
  mutate(
    mes_cod = as.character(mes_cod),
    ano = as.integer(substr(mes_cod, 1, 4)),
    mes = as.integer(substr(mes_cod, 5, 6)),
    trimestre = ceiling(mes / 3)
  ) |>
  filter(ano >= ano_inicio, ano <= ano_fim) |>
  group_by(ano, trimestre) |>
  summarise(ipca_trim = mean(valor, na.rm = TRUE), .groups = "drop") |>
  arrange(ano, trimestre)

media_ipca_2020 <- ipca_trim |>
  filter(ano == ano_inicio) |>
  summarise(media = mean(ipca_trim, na.rm = TRUE)) |>
  pull(media)

ipca_trim <- ipca_trim |>
  mutate(ipca_rebased = ipca_trim / media_ipca_2020 * 100)

if (nrow(ipca_trim) != length(anos_saida) * 4) {
  stop("IPCA trimestral incompleto para o horizonte do projeto.", call. = FALSE)
}


# ============================================================
# ETAPA 5.9.4 - Estender benchmark anual e gerar trimestral
# ============================================================

message("\n=== ETAPA 5.9.4: Estendendo benchmark anual e gerando trimestral ===\n")

setores <- unique(benchmark_oficial$setor)
resultado_setorial <- vector("list", length(setores))
resumo_benchmark <- vector("list", length(setores))

for (i in seq_along(setores)) {
  setor_atual <- setores[i]

  bench_setor <- benchmark_oficial |>
    filter(setor == setor_atual) |>
    arrange(ano)

  real_trim_setor <- indices_trim |>
    filter(setor == setor_atual) |>
    arrange(ano, trimestre)

  ext_deflator <- estender_benchmark(
    bench_ano = bench_setor$ano,
    bench_val = bench_setor$deflator_anual,
    ano_max = ano_fim
  )

  serie_deflator_anual <- ts(
    ext_deflator$bench,
    start = min(ext_deflator$ano),
    frequency = 1
  )
  indicador_ipca <- ts(
    ipca_trim$ipca_rebased,
    start = c(min(anos_saida), 1),
    frequency = 4
  )

  deflator_trim <- tryCatch({
    mod <- tempdisagg::td(
      serie_deflator_anual ~ 0 + indicador_ipca,
      method = "denton-cholette",
      conversion = "mean"
    )
    as.numeric(predict(mod))
  }, error = function(e) {
    stop(sprintf("Falha ao trimestralizar o deflator de %s: %s", setor_atual, e$message),
         call. = FALSE)
  })

  indicador_nominal_trim <- real_trim_setor$indice_real * deflator_trim / 100

  indicador_nominal_anual <- tibble(
    ano = anos_saida,
    indicador_nominal_anual = as.numeric(tapply(indicador_nominal_trim, real_trim_setor$ano, sum))
  )

  benchmark_nominal_ext <- tibble(ano = anos_saida) |>
    left_join(bench_setor |> select(ano, vab_nominal_mi_benchmark), by = "ano") |>
    left_join(indicador_nominal_anual, by = "ano") |>
    arrange(ano)

  ultimo_ano_oficial <- max(bench_setor$ano)
  for (j in seq_len(nrow(benchmark_nominal_ext))) {
    ano_atual <- benchmark_nominal_ext$ano[j]
    if (ano_atual > ultimo_ano_oficial) {
      valor_anterior <- benchmark_nominal_ext$vab_nominal_mi_benchmark[j - 1]
      indicador_anterior <- benchmark_nominal_ext$indicador_nominal_anual[j - 1]
      indicador_atual <- benchmark_nominal_ext$indicador_nominal_anual[j]
      benchmark_nominal_ext$vab_nominal_mi_benchmark[j] <- valor_anterior * (indicador_atual / indicador_anterior)
    }
  }

  serie_benchmark_nominal <- ts(
    benchmark_nominal_ext$vab_nominal_mi_benchmark,
    start = min(anos_saida),
    frequency = 1
  )
  serie_indicador_nominal <- ts(
    indicador_nominal_trim,
    start = c(min(anos_saida), 1),
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

  benchmark_utilizado <- benchmark_nominal_ext |>
    mutate(
      setor = setor_atual,
      deflator_anual_utilizado = ext_deflator$bench,
      tipo_benchmark = if_else(
        ano <= ultimo_ano_oficial,
        "Benchmark CR IBGE",
        "Extrapolado pelo indicador nominal setorial"
      )
    ) |>
    left_join(
      bench_setor |> select(ano, indice_real_anual, deflator_anual),
      by = "ano"
    ) |>
    rename(
      vab_nominal_mi_benchmark_utilizado = vab_nominal_mi_benchmark,
      indice_real_anual_oficial = indice_real_anual,
      deflator_anual_oficial = deflator_anual
    )

  saida_setor <- real_trim_setor |>
    mutate(
      periodo = sprintf("%dT%d", ano, trimestre),
      deflator_trim = deflator_trim,
      indice_nominal_indicador = indicador_nominal_trim,
      vab_nominal_mi = vab_nominal_trim,
      tipo_benchmark = if_else(
        ano <= ultimo_ano_oficial,
        "Benchmark CR IBGE",
        "Extrapolado pelo indicador nominal setorial"
      )
    )

  validar_serie(saida_setor$vab_nominal_mi, paste("VAB nominal setorial", setor_atual))

  resultado_setorial[[i]] <- saida_setor
  resumo_benchmark[[i]] <- benchmark_utilizado
}

resultado_setorial <- bind_rows(resultado_setorial) |>
  arrange(setor, ano, trimestre)

benchmark_utilizado_anual <- bind_rows(resumo_benchmark) |>
  arrange(setor, ano)


# ============================================================
# ETAPA 5.9.5 - Validacao anual e salvamento
# ============================================================

message("\n=== ETAPA 5.9.5: Validacao anual e salvamento ===\n")

resumo_anual <- resultado_setorial |>
  group_by(setor, ano) |>
  summarise(
    vab_nominal_mi_trimestralizado = sum(vab_nominal_mi, na.rm = TRUE),
    indice_real_anual_projeto = mean(indice_real, na.rm = TRUE),
    tipo_benchmark = first(tipo_benchmark),
    .groups = "drop"
  ) |>
  left_join(benchmark_utilizado_anual, by = c("setor", "ano", "tipo_benchmark")) |>
  mutate(
    diferenca_mi = vab_nominal_mi_trimestralizado - vab_nominal_mi_benchmark_utilizado,
    diferenca_pct = if_else(
      vab_nominal_mi_benchmark_utilizado == 0,
      NA_real_,
      diferenca_mi / vab_nominal_mi_benchmark_utilizado * 100
    )
  ) |>
  arrange(setor, ano)

desvio_max <- max(abs(resumo_anual$diferenca_mi), na.rm = TRUE)
if (desvio_max > 1e-4) {
  warning(sprintf("Fechamento anual setorial com desvio maximo de %.6f mi.", desvio_max), call. = FALSE)
} else {
  message(sprintf("Fechamento anual setorial OK (desvio maximo = %.8f mi)", desvio_max))
}

write_csv(resultado_setorial, arq_saida)
write_csv(resumo_anual, arq_saida_an)

message(sprintf("Serie trimestral salva em: %s", arq_saida))
message(sprintf("Resumo anual salvo em: %s", arq_saida_an))
message("\n=== Fase 5.9 - script concluido com sucesso ===")
