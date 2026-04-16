# ============================================================
# Projeto : Indicador de Atividade Econômica Trimestral — RR
# Script  : 03_industria.R
# Autor   : Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)
# Data    : 2026-04-11
# Descrição: Índice trimestral do setor industrial de RR:
#   SIUP (5,51% do VAB em 2020): consumo de energia elétrica por classe
#   de consumidor (ANEEL/SAMP) — residencial, comercial,
#   industrial, público. O total de energia distribuída é o
#   proxy de volume da produção do setor.
#   Construção (4,98% do VAB em 2020): vínculos formais CNAE F via
#   CAGED microdata (FTP/MTE). SNIC cimento requer download
#   manual — usado como componente adicional se arquivo presente.
#   Indústria de Transformação (1,15% do VAB em 2020): energia
#   industrial ANEEL (peso 0,55) + emprego CAGED C (peso 0,45).
#   Pesos otimizados por minimização da variância do Denton (2026-04-15).
#   Todos os subsetores aplicam Denton-Cholette contra VAB
#   anual das Contas Regionais IBGE (benchmarks 2020–2023).
#   A coleta ANEEL é compartilhada: energia comercial e
#   industrial ficam disponíveis para a Fase 4 (Comércio e
#   Transformação não precisam de coleta adicional).
# Entrada : API CKAN ANEEL (dadosabertos.aneel.gov.br) —
#             sem autenticação, filtro pré-aplicado
#            CAGED microdata 7z (FTP ftp.mtps.gov.br)
#            data/raw/snic_cimento_rr.csv (download manual SNIC
#             — opcional; instruções ao final do script)
#            data/processed/contas_regionais_RR_serie.csv
# Saída   : data/raw/aneel/aneel_energia_rr.csv
#            data/raw/caged/caged_rr_mensal.csv
#            data/output/indice_industria.csv
# Depende : httr2, jsonlite, dplyr, lubridate, data.table,
#            readr, tempdisagg
#            R/utils.R
# Nota    : CAGED — 1ª execução baixa ~2,5 GB (72 meses × 35 MB).
#           Arquivos grandes apagados após processamento; apenas
#           o agregado RR (~1 KB/mês) é mantido localmente.
#           SNIC: indisponível via API. Instruções de download
#           manual ao final do script. Se ausente, Construção
#           usa apenas CAGED F.
# ============================================================

source("R/utils.R")

library(httr2)
library(jsonlite)
library(dplyr)
library(tidyr)
library(lubridate)
library(data.table)
library(readr)

# --- Caminhos -----------------------------------------------

dir_raw       <- file.path("data", "raw")
dir_processed <- file.path("data", "processed")
dir_output    <- file.path("data", "output")
dir_aneel     <- file.path(dir_raw, "aneel")
dir_caged     <- file.path(dir_raw, "caged")

for (d in c(dir_raw, dir_processed, dir_output, dir_aneel, dir_caged)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

arq_aneel_out  <- file.path(dir_aneel, "aneel_energia_rr.csv")
arq_caged_out  <- file.path(dir_caged, "caged_rr_mensal.csv")
arq_snic       <- file.path(dir_raw,   "snic_cimento_rr.csv")
arq_cr_serie   <- file.path(dir_processed, "contas_regionais_RR_serie.csv")
arq_vol_serie  <- file.path(dir_processed, "contas_regionais_RR_volume.csv")
arq_indice     <- file.path(dir_output, "indice_industria.csv")

# --- Parâmetros ---------------------------------------------

# 7-Zip (necessário para extrair CAGED .7z no Windows)
caminho_7zip <- "C:/Program Files/7-Zip/7z.exe"
if (!file.exists(caminho_7zip)) {
  stop("7-Zip não encontrado em '", caminho_7zip, "'. Instalar em https://7-zip.org/")
}

# ANEEL SAMP: dataset_id e resource_ids por ano
# Fonte: https://dadosabertos.aneel.gov.br/
aneel_dataset_id <- "3e153db4-a503-4093-88be-75d31b002dcf"
aneel_resource_ids <- list(
  "2020" = "29f9fec9-34dd-454b-8f3c-6b4ca5b22f2c",
  "2021" = "84906f77-0bb4-4527-b9a0-cb6c2b525661",
  "2022" = "7e097631-46ad-4051-8954-9ef8fb594fdc",
  "2023" = "b9ad890b-d500-4294-bd36-1108acc54832",
  "2024" = "ff80dd21-eade-4eb5-9ca8-d802c883940e",
  "2025" = "6fac5605-5df0-469d-be08-04ee22934f60",
  "2026" = "56f1c242-5017-4cef-a365-0a96fffb0f2b"
)

# Distribuidor de RR na ANEEL SAMP
aneel_distribuidora <- "BOA VISTA"
aneel_tipo_mercado  <- "Sistema Isolado - Regular"
aneel_detalhe       <- "Energia TE (kWh)"

# CAGED: intervalo de coleta
caged_ano_inicio <- 2020
caged_ano_fim    <- 2025

# Pesos do índice composto de Transformação
# Otimizados por 05b_sensibilidade_pesos.R (critério: variância Denton)
# Ad hoc anterior: 70%/30% | Ótimo estimado: 55%/45% | Melhoria: 59,9%
peso_energia_transf <- 0.55
peso_emprego_transf <- 0.45

# ============================================================
# ETAPA 3.1 — ANEEL SAMP via API CKAN
# Coleta energia por classe para RR (BOA VISTA, Sistema Isolado)
# Cobertura: todos os anos disponíveis (2020–2026)
# Compartilhado com Fase 4 (Comércio usa classe Comercial)
# ============================================================

message("\n=== ETAPA 3.1: ANEEL SAMP — energia por classe (RR) ===\n")

#' Baixa registros da ANEEL para um ano via API CKAN com paginação
#'
#' Filtra diretamente na API: BOA VISTA + Sistema Isolado + Energia TE.
#' Cada chamada retorna até 500 registros; pagina até esgotar os resultados.
baixar_aneel_api <- function(resource_id, ano) {
  arq_cache <- file.path(dir_aneel, sprintf("aneel_energia_rr_%d.csv", ano))

  if (file.exists(arq_cache)) {
    message(sprintf("  ANEEL %d: cache local encontrado — pulando download.", ano))
    return(read_csv(arq_cache, show_col_types = FALSE))
  }

  message(sprintf("  ANEEL %d: consultando API CKAN...", ano))

  base_url <- "https://dadosabertos.aneel.gov.br/api/3/action/datastore_search"
  campos   <- "DatCompetencia,DscClasseConsumoMercado,VlrMercado"
  filtros  <- list(
    SigAgenteDistribuidora = aneel_distribuidora,
    NomTipoMercado         = aneel_tipo_mercado,
    DscDetalheMercado      = aneel_detalhe
  )
  filtros_json <- jsonlite::toJSON(filtros, auto_unbox = TRUE)

  limit   <- 500
  offset  <- 0
  paginas <- list()

  repeat {
    resp <- tryCatch(
      request(base_url) |>
        req_url_query(
          resource_id = resource_id,
          filters     = filtros_json,
          fields      = campos,
          limit       = limit,
          offset      = offset
        ) |>
        req_timeout(60) |>
        req_perform(),
      error = function(e) {
        message(sprintf("    Erro na API ANEEL %d (offset=%d): %s", ano, offset, e$message))
        NULL
      }
    )
    if (is.null(resp)) break

    dados <- fromJSON(resp_body_string(resp))
    registros <- dados$result$records

    if (is.null(registros) || nrow(registros) == 0) break

    paginas <- c(paginas, list(registros))
    message(sprintf("    %d/%d registros baixados...",
                    min(offset + nrow(registros), dados$result$total),
                    dados$result$total))

    if (nrow(registros) < limit) break
    offset <- offset + limit
  }

  if (length(paginas) == 0) {
    message(sprintf("  AVISO: Nenhum registro retornado para %d.", ano))
    return(NULL)
  }

  df <- bind_rows(paginas) |>
    mutate(
      data      = as.Date(DatCompetencia),
      classe    = DscClasseConsumoMercado,
      # VlrMercado vem como string com decimal vírgula (formato brasileiro)
      energia_kwh = as.numeric(gsub(",", ".", VlrMercado))
    ) |>
    group_by(data, classe) |>
    summarise(energia_kwh = sum(energia_kwh, na.rm = TRUE), .groups = "drop") |>
    arrange(data, classe)

  write_csv(df, arq_cache)
  message(sprintf("  ANEEL %d: %d registros salvos em %s", ano, nrow(df), arq_cache))
  return(df)
}

# Executar para todos os anos disponíveis
lista_aneel <- lapply(names(aneel_resource_ids), function(ano_str) {
  res <- tryCatch(
    baixar_aneel_api(aneel_resource_ids[[ano_str]], as.integer(ano_str)),
    error = function(e) {
      message(sprintf("  ERRO em ANEEL %s: %s", ano_str, e$message))
      NULL
    }
  )
  if (!is.null(res)) mutate(res, ano = as.integer(ano_str))
  else NULL
})

aneel_energia <- bind_rows(Filter(Negate(is.null), lista_aneel)) |>
  arrange(data, classe)

if (nrow(aneel_energia) == 0) stop("ANEEL: nenhum dado coletado. Verificar conexão ou IDs dos recursos.")

write_csv(aneel_energia, arq_aneel_out)
message(sprintf("\nANEEL — total: %d obs. de %s a %s",
                nrow(aneel_energia),
                min(aneel_energia$data), max(aneel_energia$data)))

# ============================================================
# ETAPA 3.2 — CAGED Microdata (FTP/MTE)
# Coleta emprego formal por seção CNAE para RR (UF=14)
# Salva saldo mensal de TODAS as seções — reaproveitado na Fase 4
# ============================================================

message("\n=== ETAPA 3.2: CAGED — emprego formal por seção CNAE (RR) ===\n")
message("NOTA: 1ª execução baixa ~2,5 GB (um arquivo de 35 MB por mês).")
message("      Arquivos grandes são apagados após processamento.")
message("      Arquivos já processados são pulados (idempotente).\n")

#' Baixa, extrai e agrega CAGED de um mês para UF=14 (Roraima)
baixar_caged_mes <- function(ano, mes) {
  yearmonth <- sprintf("%d%02d", ano, mes)
  arq_rr    <- file.path(dir_caged, sprintf("caged_rr_%s.csv", yearmonth))

  if (file.exists(arq_rr)) return(invisible(NULL))

  url_ftp <- sprintf(
    "ftp://ftp.mtps.gov.br/pdet/microdados/NOVO%%20CAGED/%d/%s/CAGEDMOV%s.7z",
    ano, yearmonth, yearmonth
  )
  tmp_7z  <- file.path(dir_caged, sprintf("CAGEDMOV%s.7z",  yearmonth))
  tmp_txt <- file.path(dir_caged, sprintf("CAGEDMOV%s.txt", yearmonth))

  tryCatch({
    message(sprintf("  [%s] Baixando (~35 MB)...", yearmonth))
    # Usar curl via sistema — mais confiável para FTP no Windows que download.file()
    ret_dl <- system(
      sprintf('curl -s --ftp-pasv --retry 3 --retry-delay 5 -o "%s" "%s"',
              normalizePath(tmp_7z, winslash = "/", mustWork = FALSE),
              url_ftp),
      wait = TRUE, intern = FALSE
    )
    if (ret_dl != 0 || !file.exists(tmp_7z) || file.size(tmp_7z) < 1000) {
      stop("curl falhou no download (código ", ret_dl, ")")
    }
    Sys.sleep(3)  # pausa para não sobrecarregar o servidor FTP

    message(sprintf("  [%s] Extraindo...", yearmonth))
    ret <- system(
      sprintf('"%s" e "%s" -o"%s" -y -bd',
              caminho_7zip,
              normalizePath(tmp_7z, winslash = "/"),
              normalizePath(dir_caged, winslash = "/")),
      wait = TRUE, intern = FALSE
    )
    if (ret != 0) stop("7-Zip retornou código de erro ", ret)

    message(sprintf("  [%s] Processando para RR (UF=14)...", yearmonth))

    # Ler apenas as colunas necessárias (posições 3=uf, 5=seção, 7=saldo)
    # fread é rápido mesmo em arquivos de 276 MB descomprimidos
    caged_br <- fread(
      tmp_txt,
      sep        = ";",
      select     = c(3L, 5L, 7L),
      colClasses = list(character = 1:2, integer = 3),
      encoding   = "Latin-1",
      data.table = FALSE
    )
    names(caged_br) <- c("uf", "secao", "saldo")

    caged_rr_mes <- caged_br |>
      filter(as.integer(uf) == 14L) |>
      group_by(secao) |>
      summarise(saldo = sum(saldo, na.rm = TRUE), .groups = "drop") |>
      mutate(yearmonth = yearmonth, ano = ano, mes = mes)

    write_csv(caged_rr_mes, arq_rr)
    message(sprintf("  [%s] OK — %d seções, saldo total = %d",
                    yearmonth, nrow(caged_rr_mes), sum(caged_rr_mes$saldo)))

  }, error = function(e) {
    message(sprintf("  [%s] AVISO: falha — %s", yearmonth, e$message))
  }, finally = {
    if (file.exists(tmp_7z))  unlink(tmp_7z)
    if (file.exists(tmp_txt)) unlink(tmp_txt)
  })
}

# Loop de download — 2020 a 2025, todos os meses
for (ano in caged_ano_inicio:caged_ano_fim) {
  for (mes in 1:12) {
    baixar_caged_mes(ano, mes)
  }
}

# Montar série completa a partir dos arquivos mensais
arqs_mensais <- list.files(dir_caged, pattern = "^caged_rr_[0-9]{6}\\.csv$",
                            full.names = TRUE)
if (length(arqs_mensais) == 0) {
  stop("Nenhum arquivo CAGED processado encontrado em ", dir_caged)
}

caged_rr <- bind_rows(lapply(arqs_mensais, read_csv, show_col_types = FALSE)) |>
  arrange(ano, mes, secao)

write_csv(caged_rr, arq_caged_out)
message(sprintf("\nCAGED — série consolidada: %d obs. (%d meses × seções)",
                nrow(caged_rr), length(arqs_mensais)))

# ============================================================
# ETAPA 3.3 — SIUP: índice de energia elétrica total (RR)
# Proxy: soma de todas as classes de consumo (energia distribuída)
# Tipo de medida: volume físico (kWh)
# Qualidade: forte — dado direto de consumo, sem deflação necessária
# ============================================================

message("\n=== ETAPA 3.3: SIUP — índice de energia distribuída ===\n")

# Energia mensal total (soma de todas as classes)
energia_mensal <- aneel_energia |>
  group_by(data) |>
  summarise(energia_kwh = sum(energia_kwh, na.rm = TRUE), .groups = "drop") |>
  mutate(
    ano      = year(data),
    mes      = month(data),
    trimestre = ceiling(mes / 3)
  ) |>
  arrange(data)

# Verificar cobertura
message(sprintf("SIUP — energia mensal: %d meses de %s a %s",
                nrow(energia_mensal),
                min(energia_mensal$data), max(energia_mensal$data)))

# Agregar para trimestral (soma dos meses do trimestre)
energia_trim <- energia_mensal |>
  group_by(ano, trimestre) |>
  summarise(energia_kwh = sum(energia_kwh, na.rm = TRUE), n_meses = n(),
            .groups = "drop") |>
  filter(n_meses == 3) |>  # só trimestres completos
  arrange(ano, trimestre)

# Normalizar: média de 2020 = 100
base_siup_2020 <- energia_trim |>
  filter(ano == 2020) |>
  pull(energia_kwh) |>
  mean(na.rm = TRUE)

energia_trim <- energia_trim |>
  mutate(indice_siup_raw = energia_kwh / base_siup_2020 * 100)

message(sprintf("SIUP — %d trimestres completos (base 2020=100)",
                nrow(energia_trim)))
print(energia_trim |> select(ano, trimestre, energia_kwh, indice_siup_raw))

# ============================================================
# ETAPA 3.4 — Construção: emprego formal CNAE F (CAGED)
# Proxy: estoque acumulado de vínculos formais na construção
# Tipo de medida: insumo (emprego)
# Qualidade: média-alta
# SNIC cimento: usado como componente adicional se arquivo presente
# ============================================================

message("\n=== ETAPA 3.4: Construção — emprego CAGED F (+ SNIC se disponível) ===\n")

# Saldo mensal para seção F (Construção)
caged_f_mensal <- caged_rr |>
  filter(secao == "F") |>
  arrange(ano, mes)

if (nrow(caged_f_mensal) == 0) {
  stop("CAGED: nenhum registro para seção F (Construção). Verificar dados.")
}

# Completar grid de meses: meses sem movimentação em RR têm saldo=0
# (estoque permanece inalterado). Evita que trimestres com mês "vazio"
# sejam descartados pelo filter(n_meses == 3) posterior.
{
  ano_min <- min(caged_f_mensal$ano); mes_min <- min(caged_f_mensal$mes[caged_f_mensal$ano == ano_min])
  ano_max <- max(caged_rr$ano);      mes_max <- max(caged_rr$mes[caged_rr$ano == ano_max])
  grid_f <- expand_grid(ano = ano_min:ano_max, mes = 1:12) |>
    filter((ano > ano_min | mes >= mes_min) & (ano < ano_max | mes <= mes_max))
  n_antes <- nrow(caged_f_mensal)
  caged_f_mensal <- grid_f |>
    left_join(select(caged_f_mensal, ano, mes, saldo), by = c("ano", "mes")) |>
    mutate(saldo = replace_na(saldo, 0L)) |>
    arrange(ano, mes)
  n_depois <- nrow(caged_f_mensal)
  if (n_depois > n_antes)
    message(sprintf("CAGED F: %d meses completados com saldo=0 (sem movimentação).",
                    n_depois - n_antes))
}

# Calcular estoque acumulado (base 1000 + saldos mensais)
# O nível inicial (1000) é arbitrário; o Denton calibra o nível correto.
caged_f_mensal <- caged_f_mensal |>
  mutate(estoque_f = 1000 + cumsum(saldo))

# Verificar se há estoque negativo (saldo acumulado extremo)
if (any(caged_f_mensal$estoque_f <= 0)) {
  n_neg <- sum(caged_f_mensal$estoque_f <= 0)
  message(sprintf("AVISO: %d meses com estoque acumulado <= 0 em CAGED F — ajustando base.", n_neg))
  base_adj <- abs(min(caged_f_mensal$estoque_f)) + 100
  caged_f_mensal <- caged_f_mensal |>
    mutate(estoque_f = estoque_f + base_adj)
}

# Agregar para trimestral (média do estoque — variável de nível)
caged_f_trim <- caged_f_mensal |>
  mutate(trimestre = ceiling(mes / 3)) |>
  group_by(ano, trimestre) |>
  summarise(estoque_f = mean(estoque_f, na.rm = TRUE), n_meses = n(),
            .groups = "drop") |>
  filter(n_meses == 3) |>
  arrange(ano, trimestre)

# Verificar SNIC — componente de cimento (download manual)
usar_snic <- file.exists(arq_snic)
if (usar_snic) {
  message("SNIC encontrado: incorporando cimento como componente adicional.")
  snic_raw <- tryCatch(
    read_csv(arq_snic, show_col_types = FALSE),
    error = function(e) {
      message("AVISO: falha ao ler SNIC — usando apenas CAGED F.")
      NULL
    }
  )
  # Formato esperado: colunas ano, mes, vendas_ton
  if (!is.null(snic_raw) && all(c("ano", "mes", "vendas_ton") %in% names(snic_raw))) {
    snic_trim <- snic_raw |>
      mutate(trimestre = ceiling(mes / 3)) |>
      group_by(ano, trimestre) |>
      summarise(cimento_ton = sum(vendas_ton, na.rm = TRUE), n_meses = n(),
                .groups = "drop") |>
      filter(n_meses == 3) |>
      arrange(ano, trimestre)

    # Normalizar cimento: média 2020 = 100
    base_snic_2020 <- snic_trim |>
      filter(ano == 2020) |>
      pull(cimento_ton) |>
      mean(na.rm = TRUE)
    snic_trim <- snic_trim |>
      mutate(indice_snic = cimento_ton / base_snic_2020 * 100)

    # Normalizar CAGED F: média 2020 = 100
    base_f_2020 <- caged_f_trim |>
      filter(ano == 2020) |>
      pull(estoque_f) |>
      mean(na.rm = TRUE)
    caged_f_trim <- caged_f_trim |>
      mutate(indice_f = estoque_f / base_f_2020 * 100)

    # Índice composto Construção: CAGED F 60% + SNIC 40%
    construcao_trim <- caged_f_trim |>
      left_join(select(snic_trim, ano, trimestre, indice_snic),
                by = c("ano", "trimestre")) |>
      filter(!is.na(indice_snic)) |>
      mutate(indice_construcao_raw = 0.6 * indice_f + 0.4 * indice_snic)
    message("Construção: índice composto CAGED F (60%) + SNIC cimento (40%).")
  } else {
    message("AVISO: SNIC sem colunas esperadas (ano, mes, vendas_ton) — usando apenas CAGED F.")
    usar_snic <- FALSE
  }
}

if (!usar_snic) {
  base_f_2020 <- caged_f_trim |>
    filter(ano == 2020) |>
    pull(estoque_f) |>
    mean(na.rm = TRUE)
  construcao_trim <- caged_f_trim |>
    mutate(
      indice_f              = estoque_f / base_f_2020 * 100,
      indice_construcao_raw = indice_f
    )
  message("Construção: proxy única — CAGED F (SNIC não disponível).")
}

message(sprintf("Construção — %d trimestres (base 2020=100)", nrow(construcao_trim)))
print(construcao_trim |> select(ano, trimestre, estoque_f, indice_construcao_raw))

# ============================================================
# ETAPA 3.5 — Indústria de Transformação: energia industrial + CAGED C
# Proxy composta: energia industrial ANEEL (70%) + emprego CNAE C (30%)
# Tipo de medida: volume físico (energia) + insumo (emprego)
# Qualidade: média (sem PIM-PF para RR; peso < 2% no total)
# ============================================================

message("\n=== ETAPA 3.5: Transformação — energia industrial + CAGED C ===\n")

# Energia industrial mensal (classe "Industrial" da ANEEL)
energia_ind_mensal <- aneel_energia |>
  filter(classe == "Industrial") |>
  mutate(
    ano       = year(data),
    mes       = month(data),
    trimestre = ceiling(mes / 3)
  ) |>
  arrange(data)

if (nrow(energia_ind_mensal) == 0) {
  message("AVISO: nenhuma observação para classe Industrial na ANEEL.")
  message("       Transformação usará apenas CAGED C.")
  peso_energia_transf_efetivo <- 0.0
  peso_emprego_transf_efetivo <- 1.0
} else {
  peso_energia_transf_efetivo <- peso_energia_transf
  peso_emprego_transf_efetivo <- peso_emprego_transf
}

# Agregar energia industrial para trimestral
energia_ind_trim <- energia_ind_mensal |>
  group_by(ano, trimestre) |>
  summarise(energia_kwh = sum(energia_kwh, na.rm = TRUE), n_meses = n(),
            .groups = "drop") |>
  filter(n_meses == 3) |>
  arrange(ano, trimestre)

# Normalizar: média 2020 = 100
if (nrow(energia_ind_trim) > 0) {
  base_ind_2020 <- energia_ind_trim |>
    filter(ano == 2020) |>
    pull(energia_kwh) |>
    mean(na.rm = TRUE)
  energia_ind_trim <- energia_ind_trim |>
    mutate(indice_energia_ind = energia_kwh / base_ind_2020 * 100)
}

# Emprego CAGED C (Ind. Transformação) — estoque acumulado
caged_c_mensal <- caged_rr |>
  filter(secao == "C") |>
  arrange(ano, mes)

if (nrow(caged_c_mensal) == 0) {
  message("AVISO: nenhum registro CAGED para seção C (Transformação). Usando apenas energia.")
  peso_energia_transf_efetivo <- 1.0
  peso_emprego_transf_efetivo <- 0.0
} else {
  # Completar grid de meses para seção C (mesma lógica da seção F)
  {
    ano_min_c <- min(caged_c_mensal$ano); mes_min_c <- min(caged_c_mensal$mes[caged_c_mensal$ano == ano_min_c])
    ano_max_c <- max(caged_rr$ano);       mes_max_c <- max(caged_rr$mes[caged_rr$ano == ano_max_c])
    grid_c <- expand_grid(ano = ano_min_c:ano_max_c, mes = 1:12) |>
      filter((ano > ano_min_c | mes >= mes_min_c) & (ano < ano_max_c | mes <= mes_max_c))
    n_antes_c <- nrow(caged_c_mensal)
    caged_c_mensal <- grid_c |>
      left_join(select(caged_c_mensal, ano, mes, saldo), by = c("ano", "mes")) |>
      mutate(saldo = replace_na(saldo, 0L)) |>
      arrange(ano, mes)
    if (nrow(caged_c_mensal) > n_antes_c)
      message(sprintf("CAGED C: %d meses completados com saldo=0.",
                      nrow(caged_c_mensal) - n_antes_c))
  }

  caged_c_mensal <- caged_c_mensal |>
    mutate(estoque_c = 1000 + cumsum(saldo))

  if (any(caged_c_mensal$estoque_c <= 0)) {
    base_adj_c <- abs(min(caged_c_mensal$estoque_c)) + 100
    caged_c_mensal <- caged_c_mensal |>
      mutate(estoque_c = estoque_c + base_adj_c)
  }

  caged_c_trim <- caged_c_mensal |>
    mutate(trimestre = ceiling(mes / 3)) |>
    group_by(ano, trimestre) |>
    summarise(estoque_c = mean(estoque_c, na.rm = TRUE), n_meses = n(),
              .groups = "drop") |>
    filter(n_meses == 3) |>
    arrange(ano, trimestre)

  base_c_2020 <- caged_c_trim |>
    filter(ano == 2020) |>
    pull(estoque_c) |>
    mean(na.rm = TRUE)
  caged_c_trim <- caged_c_trim |>
    mutate(indice_emprego_c = estoque_c / base_c_2020 * 100)
}

# Índice composto Transformação
transf_base <- energia_ind_trim |>
  select(ano, trimestre, indice_energia_ind)

if (peso_emprego_transf_efetivo > 0 && exists("caged_c_trim")) {
  transf_trim <- transf_base |>
    left_join(select(caged_c_trim, ano, trimestre, indice_emprego_c),
              by = c("ano", "trimestre")) |>
    mutate(
      indice_transf_raw = case_when(
        !is.na(indice_energia_ind) & !is.na(indice_emprego_c) ~
          peso_energia_transf_efetivo * indice_energia_ind +
          peso_emprego_transf_efetivo * indice_emprego_c,
        !is.na(indice_energia_ind) ~ indice_energia_ind,
        !is.na(indice_emprego_c)   ~ indice_emprego_c,
        TRUE ~ NA_real_
      )
    )
  message(sprintf("Transformação: %d trimestres, pesos energia=%.0f%% / emprego=%.0f%%",
                  sum(!is.na(transf_trim$indice_transf_raw)),
                  peso_energia_transf_efetivo * 100,
                  peso_emprego_transf_efetivo * 100))
} else {
  transf_trim <- transf_base |>
    mutate(indice_transf_raw = indice_energia_ind)
  message("Transformação: proxy única — energia industrial ANEEL.")
}

print(transf_trim |> select(ano, trimestre, indice_transf_raw))

# Salvar proxies brutas da Transformação para análise de sensibilidade
{
  dir_sens <- file.path(dir_output, "sensibilidade")
  dir.create(dir_sens, recursive = TRUE, showWarnings = FALSE)

  cols_transf <- intersect(c("ano", "trimestre", "indice_energia_ind", "indice_emprego_c"),
                           names(transf_trim))
  write_csv(transf_trim[, cols_transf], file.path(dir_sens, "proxies_transformacao.csv"))
  message("Proxies Transformação salvas para sensibilidade.")
}

# ============================================================
# ETAPA 3.6 — Denton-Cholette: cada subsetor × benchmark IBGE
# Benchmark: VAB anual das Contas Regionais (2020–2023)
# Denton garante que a média dos 4 trimestres reproduza o anual
# ============================================================

message("\n=== ETAPA 3.6: Denton-Cholette — benchmarks IBGE ===\n")

# Carregar benchmarks
if (!file.exists(arq_vol_serie)) {
  stop("Arquivo de volume não encontrado: ", arq_vol_serie,
       "\nExecutar R/00_dados_referencia.R primeiro.")
}
cr_serie  <- read.csv(arq_cr_serie,  stringsAsFactors = FALSE)  # mantido para pesos de agregação
vol_serie <- read.csv(arq_vol_serie, stringsAsFactors = FALSE)  # benchmark volume real

# Nomes das atividades conforme 00_dados_referencia.R
atividade_siup    <- "Eletricidade, gás, água, esgoto e resíduos (SIUP)"
atividade_const   <- "Construção"
atividade_transf  <- "Indústrias de transformação"

# Função auxiliar: aplicar Denton a um data frame trimestral
# vol_serie: contas_regionais_RR_volume.csv (vab_volume_rebased, base 2020=100)
aplicar_denton <- function(df_trim, col_indice, atividade_nome, vol_serie) {
  vol_ativ <- vol_serie |>
    filter(atividade == atividade_nome) |>
    select(ano, vab_volume_rebased) |>
    arrange(ano)

  if (nrow(vol_ativ) == 0) {
    message(sprintf("AVISO: benchmark '%s' não encontrado — pulando Denton.", atividade_nome))
    return(df_trim |> mutate(indice_denton = .data[[col_indice]]))
  }

  if (!any(vol_ativ$ano == 2020)) {
    message(sprintf("AVISO: volume 2020 ausente para '%s' — usando índice bruto.", atividade_nome))
    return(df_trim |> mutate(indice_denton = .data[[col_indice]]))
  }

  # vab_volume_rebased já está em base 2020=100 — sem normalização adicional
  bench <- vol_ativ |>
    rename(bench = vab_volume_rebased) |>
    select(ano, bench)

  # Anos com 4 trimestres completos na série de proxy
  contagem       <- df_trim |> count(ano)
  anos_completos <- contagem$ano[contagem$n == 4]

  if (length(anos_completos) < 2) {
    message(sprintf("AVISO: menos de 2 anos para Denton em '%s' — usando índice bruto.", atividade_nome))
    return(df_trim |> mutate(indice_denton = .data[[col_indice]]))
  }

  # Estender benchmark CR por tendência geométrica para cobrir todo o período da proxy.
  # Elimina a descontinuidade de nível que ocorria quando anos extras usavam proxy bruta.
  ano_max_proxy <- max(anos_completos)
  if (ano_max_proxy > max(bench$ano)) {
    bench_ext <- estender_benchmark(bench$ano, bench$bench,
                                    ano_max = ano_max_proxy, n_ref = 3)
    bench <- data.frame(ano = bench_ext$ano, bench = bench_ext$bench)
  }

  anos_todos <- intersect(anos_completos, bench$ano)

  message(sprintf("  '%s' — Denton %d–%d (%d anos, %d trimestres — %d CR IBGE, %d extrapol.)",
                  atividade_nome,
                  min(anos_todos), max(anos_todos),
                  length(anos_todos), length(anos_todos) * 4L,
                  sum(anos_todos %in% vol_ativ$ano),
                  sum(!anos_todos %in% vol_ativ$ano)))

  idx_d   <- df_trim |> filter(ano %in% anos_todos) |> arrange(ano, trimestre)
  bench_d <- bench   |> filter(ano %in% anos_todos) |> arrange(ano)

  serie_denton <- denton(
    indicador_trim  = idx_d[[col_indice]],
    benchmark_anual = bench_d$bench,
    ano_inicio      = min(anos_todos),
    metodo          = "denton-cholette"
  )

  idx_d |> mutate(indice_denton = serie_denton)
}

# Aplicar Denton aos três subsetores
message("\n--- SIUP ---")
siup_trim <- aplicar_denton(energia_trim, "indice_siup_raw",
                             atividade_siup, vol_serie) |>
  rename(indice_siup = indice_denton)

message("\n--- Construção ---")
const_trim <- aplicar_denton(construcao_trim, "indice_construcao_raw",
                              atividade_const, vol_serie) |>
  rename(indice_construcao = indice_denton)

message("\n--- Transformação ---")
transf_trim_d <- aplicar_denton(transf_trim, "indice_transf_raw",
                                 atividade_transf, vol_serie) |>
  rename(indice_transformacao = indice_denton)

# ============================================================
# ETAPA 3.7 — Índice composto da Indústria
# Pesos: participação no VAB total de RR (Contas Regionais 2020)
# SIUP 5,51% + Construção 4,98% + Transformação 1,15% = 11,64%
# ============================================================

message("\n=== ETAPA 3.7: Índice composto da Indústria ===\n")

# Pesos relativos dentro do bloco industrial (normalizam para 100%)
# Fonte: Contas Regionais IBGE — participação no VAB de RR
vab_siup    <- cr_serie |> filter(atividade == atividade_siup,  ano == 2020) |> pull(vab_mi)
vab_const   <- cr_serie |> filter(atividade == atividade_const, ano == 2020) |> pull(vab_mi)
vab_transf  <- cr_serie |> filter(atividade == atividade_transf, ano == 2020) |> pull(vab_mi)

vab_industria <- sum(c(vab_siup, vab_const, vab_transf), na.rm = TRUE)
if (vab_industria == 0) stop("VAB industrial total = 0. Verificar Contas Regionais.")

peso_siup   <- vab_siup   / vab_industria
peso_const  <- vab_const  / vab_industria
peso_transf <- vab_transf / vab_industria

message(sprintf("Pesos internos (Contas Regionais 2020):"))
message(sprintf("  SIUP:          %.1f%%", peso_siup   * 100))
message(sprintf("  Construção:    %.1f%%", peso_const  * 100))
message(sprintf("  Transformação: %.1f%%", peso_transf * 100))

# Juntar os três índices por trimestre
industria_trim <- siup_trim |>
  select(ano, trimestre, indice_siup) |>
  left_join(select(const_trim,     ano, trimestre, indice_construcao),  by = c("ano", "trimestre")) |>
  left_join(select(transf_trim_d,  ano, trimestre, indice_transformacao), by = c("ano", "trimestre")) |>
  filter(!is.na(indice_siup) & !is.na(indice_construcao) & !is.na(indice_transformacao)) |>
  mutate(
    indice_industria = peso_siup   * indice_siup          +
                       peso_const  * indice_construcao    +
                       peso_transf * indice_transformacao
  ) |>
  arrange(ano, trimestre)

message(sprintf("\nÍndice Industrial — %d trimestres (base 2020=100)",
                nrow(industria_trim)))
print(industria_trim)

# ============================================================
# ETAPA 3.8 — Validação e exportação
# ============================================================

message("\n=== ETAPA 3.8: Validação e exportação ===\n")

# Validar cada componente
validar_serie(siup_trim$indice_siup,          "indice_siup",     n_min = 4)
validar_serie(const_trim$indice_construcao,   "indice_construcao", n_min = 4)
validar_serie(transf_trim_d$indice_transformacao, "indice_transformacao", n_min = 4)
validar_serie(industria_trim$indice_industria, "indice_industria", n_min = 4)

# Calcular variações anuais (média das 4 médias trimestrais por ano)
var_anual <- industria_trim |>
  group_by(ano) |>
  summarise(media_anual = mean(indice_industria, na.rm = TRUE), .groups = "drop") |>
  mutate(var_pct = (media_anual / lag(media_anual) - 1) * 100)

message("\nVariações anuais do índice industrial (para validação manual vs. IBGE):")
print(var_anual)

# Montar saída final
saida <- industria_trim |>
  select(ano, trimestre, indice_industria,
         indice_siup, indice_construcao, indice_transformacao)

write.csv(saida, arq_indice, row.names = FALSE)
message(sprintf("\nÍndice salvo em: %s (%d observações)", arq_indice, nrow(saida)))

# ============================================================
# INSTRUÇÕES — SNIC cimento (download manual)
# ============================================================

if (!usar_snic) {
  message("\n")
  message("=================================================================")
  message("INSTRUÇÃO — SNIC cimento (componente opcional para Construção):")
  message("-----------------------------------------------------------------")
  message("O SNIC (Sindicato Nacional da Indústria do Cimento) publica")
  message("vendas de cimento por estado em frequência mensal, mas não")
  message("disponibiliza API pública para download automatizado.")
  message("")
  message("Para incorporar cimento como proxy adicional de Construção:")
  message("  1. Acessar snic.org.br → Estatísticas → Dados por Estado")
  message("  2. Baixar série mensal para Roraima (2020 em diante)")
  message("  3. Salvar como: data/raw/snic_cimento_rr.csv")
  message("     Colunas obrigatórias: ano, mes, vendas_ton")
  message("  4. Re-executar este script")
  message("  Sem o arquivo, Construção usa apenas CAGED F (válido).")
  message("=================================================================")
}

message("\n=== Fase 3 concluída ===")
