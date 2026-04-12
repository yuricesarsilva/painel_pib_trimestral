# ============================================================
# Projeto : Indicador de Atividade Econômica Trimestral — RR
# Script  : 04_servicos.R
# Autor   : Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)
# Data    : 2026-04-11
# Descrição: Índice trimestral do bloco de Serviços Privados de RR:
#
#   Comércio (12,25%): energia comercial ANEEL (67%) + CAGED G (33%).
#     ICMS por atividade (SEFAZ-RR) excluído desta versão — não
#     disponível; será integrado quando obtido.
#   Transportes (1,92%): passageiros ANAC (40%) + carga ANAC (30%)
#     + diesel ANP (30%).
#   Financeiro (2,78%): concessões de crédito BCB (70%) +
#     depósitos BCB Estban (30%), ambos deflacionados pelo IPCA.
#   Imobiliário (7,68%): tendência linear interpolada entre
#     benchmarks anuais das Contas Regionais IBGE.
#   Outros serviços (7,63%): CAGED I (aloj./alim.) + M+N (prof./
#     admin.) + P+Q (educação/saúde privada), pesos dinâmicos.
#   Informação e comunicação (1,01%): CAGED J (TI/telecom).
#   Indústrias extrativas (0,05%): interpolação linear CR (peso
#     negligenciável, sem proxy específico).
#
#   Todos os subsetores com proxy de volume aplicam Denton-Cholette
#   contra VAB anual das Contas Regionais IBGE (2020–2023).
#   Base: média dos 4 trimestres de 2020 = 100.
#
# Entrada : data/raw/aneel/aneel_energia_rr.csv (Fase 3, Comercial)
#            data/raw/caged/caged_rr_mensal.csv (Fase 3)
#            ANAC VRA mensal — dadosabertos ANAC (baixado aqui)
#            ANP — Vendas de combustíveis por UF (baixado aqui)
#            BCB SGS/OData — IPCA, Estban, Concessões (baixado aqui)
#            data/processed/contas_regionais_RR_serie.csv
# Saída   : data/raw/anac/anac_bvb_mensal.csv
#            data/raw/anp/anp_diesel_rr_mensal.csv
#            data/raw/bcb/bcb_estban_rr_mensal.csv
#            data/raw/bcb/bcb_concessoes_rr_mensal.csv
#            data/output/indice_servicos.csv
# Depende : httr2, jsonlite, dplyr, tidyr, lubridate, readr,
#            readxl, data.table, tempdisagg, sidrar
#            R/utils.R
# Notas   :
#   - ANAC: baixa VRA mensais (~2–4 MB/mês). Total ~300 MB para
#     2020–2025. Arquivos ZIP removidos após processamento.
#   - ANP: único arquivo Excel com toda a série histórica.
#   - BCB Estban: OData, UF=14, verbete 160 (depósitos totais).
#   - BCB Concessões: OData NotaCredito. Se indisponível, fallback
#     para Estban com aviso.
#   - Comércio SEM ICMS: índice calculado com 2 componentes.
#     Quando ICMS for disponibilizado pela SEFAZ-RR, reprocessar
#     com pesos: energia 40%, ICMS 40%, CAGED 20%.
# ============================================================

source("R/utils.R")

library(httr2)
library(jsonlite)
library(dplyr)
library(tidyr)
library(lubridate)
library(readr)
library(readxl)
library(data.table)
library(tempdisagg)

# --- Caminhos -----------------------------------------------

dir_raw       <- file.path("data", "raw")
dir_processed <- file.path("data", "processed")
dir_output    <- file.path("data", "output")
dir_aneel     <- file.path(dir_raw, "aneel")
dir_caged     <- file.path(dir_raw, "caged")
dir_anac      <- file.path(dir_raw, "anac")
dir_anp       <- file.path(dir_raw, "anp")
dir_bcb       <- file.path(dir_raw, "bcb")

for (d in c(dir_raw, dir_processed, dir_output,
            dir_anac, dir_anp, dir_bcb)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

arq_aneel_cache    <- file.path(dir_aneel, "aneel_energia_rr.csv")
arq_caged_cache    <- file.path(dir_caged, "caged_rr_mensal.csv")
arq_anac_out       <- file.path(dir_anac,  "anac_bvb_mensal.csv")
arq_anp_out        <- file.path(dir_anp,   "anp_diesel_rr_mensal.csv")
arq_estban_out     <- file.path(dir_bcb,   "bcb_estban_rr_mensal.csv")
arq_concessoes_out <- file.path(dir_bcb,   "bcb_concessoes_rr_mensal.csv")
arq_ipca           <- file.path(dir_raw,   "ipca_mensal.csv")
arq_cr_serie       <- file.path(dir_processed, "contas_regionais_RR_serie.csv")
arq_indice         <- file.path(dir_output, "indice_servicos.csv")

# --- Parâmetros ---------------------------------------------

ano_inicio <- 2020L
ano_atual  <- as.integer(format(Sys.Date(), "%Y"))

# Pesos dos componentes — Comércio (sem ICMS: redistribuir entre 2)
# Plano original: energia 40%, ICMS 40%, CAGED 20%
# Versão atual (ICMS indisponível): energia 67%, CAGED 33%
peso_energia_comercio <- 0.67
peso_caged_g          <- 0.33

# Transportes
peso_pax_anac    <- 0.40
peso_carga_anac  <- 0.30
peso_diesel_anp  <- 0.30

# Financeiro
peso_concessoes  <- 0.70
peso_depositos   <- 0.30

# Pesos setoriais para o índice composto de serviços (% VAB 2023, CR IBGE)
# Fonte: Contas Regionais IBGE — RR 2023 (out/2025)
pesos_setoriais <- c(
  comercio     = 12.25,
  transportes  =  1.92,
  financeiro   =  2.78,
  imobiliario  =  7.68,
  outros_serv  =  7.63,
  info_com     =  1.01,
  extrativas   =  0.05
)

# Benchmark: anos com Contas Regionais disponíveis
anos_cr <- 2020:2023


# ============================================================
# ETAPA 4.1 — Carregar ANEEL Comercial (cache da Fase 3)
# Proxy de volume de atividade comercial: MWh distribuídos
# Tipo: volume físico | Qualidade: forte
# ============================================================

message("\n=== ETAPA 4.1: ANEEL — energia comercial (cache Fase 3) ===\n")

if (!file.exists(arq_aneel_cache)) {
  stop("Arquivo ANEEL não encontrado: ", arq_aneel_cache,
       "\n  Execute R/03_industria.R antes deste script.")
}

aneel_energia <- read_csv(arq_aneel_cache, show_col_types = FALSE)

energia_com_mensal <- aneel_energia |>
  filter(classe == "Comercial") |>
  mutate(
    ano       = year(data),
    mes       = month(data),
    trimestre = ceiling(mes / 3)
  ) |>
  arrange(data)

if (nrow(energia_com_mensal) == 0) {
  stop("ANEEL: nenhum registro para classe 'Comercial'. Verificar arquivo de cache.")
}

message(sprintf("ANEEL Comercial — %d obs. de %s a %s",
                nrow(energia_com_mensal),
                min(energia_com_mensal$data),
                max(energia_com_mensal$data)))


# ============================================================
# ETAPA 4.2 — Carregar CAGED (cache da Fase 3)
# Seções usadas: G, H, I, J, K, M, N, P, Q (e sub-agrupamentos)
# ============================================================

message("\n=== ETAPA 4.2: CAGED — seções de serviços (cache Fase 3) ===\n")

if (!file.exists(arq_caged_cache)) {
  stop("Arquivo CAGED não encontrado: ", arq_caged_cache,
       "\n  Execute R/03_industria.R antes deste script.")
}

caged_rr <- read_csv(arq_caged_cache, show_col_types = FALSE)

#' Calcula estoque acumulado de emprego (base 1000 + cumsum saldo)
#' e agrega para trimestral (média do estoque). Inclui grid completion
#' para meses sem movimentação (saldo=0 — estoque inalterado).
#'
#' @param caged_full  data.frame completo (caged_rr_mensal.csv)
#' @param secoes      Vetor de seções CNAE (ex: c("G"), c("M","N"))
#' @param nome        Nome da série para mensagens
#' @return data.frame com colunas ano, trimestre, estoque, indice_base100
agregar_caged_secoes <- function(caged_full, secoes, nome) {

  mensal <- caged_full |>
    filter(secao %in% secoes) |>
    group_by(ano, mes) |>
    summarise(saldo = sum(saldo, na.rm = TRUE), .groups = "drop") |>
    arrange(ano, mes)

  if (nrow(mensal) == 0) {
    warning(sprintf("CAGED %s: nenhum registro. Seções: %s",
                    nome, paste(secoes, collapse = "+")))
    return(NULL)
  }

  # Grid completion — meses sem movimentação têm saldo=0
  ano_min <- min(mensal$ano)
  mes_min <- min(mensal$mes[mensal$ano == ano_min])
  ano_max <- max(caged_full$ano)
  mes_max <- max(caged_full$mes[caged_full$ano == ano_max])

  grid <- expand_grid(ano = ano_min:ano_max, mes = 1:12) |>
    filter((ano > ano_min | mes >= mes_min) & (ano < ano_max | mes <= mes_max))

  n_antes <- nrow(mensal)
  mensal <- grid |>
    left_join(mensal, by = c("ano", "mes")) |>
    mutate(saldo = replace_na(saldo, 0L)) |>
    arrange(ano, mes)

  if (nrow(mensal) > n_antes)
    message(sprintf("  CAGED %s: %d meses completados com saldo=0.",
                    nome, nrow(mensal) - n_antes))

  # Estoque acumulado
  mensal <- mensal |> mutate(estoque = 1000 + cumsum(saldo))

  if (any(mensal$estoque <= 0)) {
    adj <- abs(min(mensal$estoque)) + 100
    mensal <- mensal |> mutate(estoque = estoque + adj)
    message(sprintf("  CAGED %s: base ajustada em +%d (estoque negativo).", nome, adj))
  }

  # Agregar trimestral (média — estoque é variável de nível)
  trim <- mensal |>
    mutate(trimestre = ceiling(mes / 3)) |>
    group_by(ano, trimestre) |>
    summarise(estoque = mean(estoque, na.rm = TRUE), n_meses = n(),
              .groups = "drop") |>
    filter(n_meses == 3) |>
    arrange(ano, trimestre)

  # Normalizar: média 2020 = 100
  base_2020 <- trim |> filter(ano == 2020) |> pull(estoque) |> mean(na.rm = TRUE)
  trim <- trim |> mutate(indice = estoque / base_2020 * 100)

  message(sprintf("  CAGED %s — %d trimestres completos (base 2020=100)", nome, nrow(trim)))
  return(trim)
}

caged_g   <- agregar_caged_secoes(caged_rr, "G",          "G (Comércio)")
caged_i   <- agregar_caged_secoes(caged_rr, "I",          "I (Alojamento/Alimentação)")
caged_j   <- agregar_caged_secoes(caged_rr, "J",          "J (Info/Com)")
caged_mn  <- agregar_caged_secoes(caged_rr, c("M", "N"),  "M+N (Prof/Admin)")
caged_pq  <- agregar_caged_secoes(caged_rr, c("P", "Q"),  "P+Q (Educ/Saúde)")

message(sprintf("\nCAGED — seções carregadas para serviços privados."))


# ============================================================
# ETAPA 4.3 — ANAC: passageiros e carga — Aeroporto de Boa Vista
# Fonte: Dados Estatísticos do Transporte Aéreo — CSV consolidado
# URL: sistemas.anac.gov.br/dadosabertos/
#        Voos e operações aéreas/
#        Dados Estatísticos do Transporte Aéreo/
#        Dados_Estatisticos.csv
# (~353 MB, série completa 2000–presente, atualização mensal)
# ICAO Boa Vista: SBBV
# Tipo: volume físico | Qualidade: forte (pax); aceitável (carga)
# ============================================================

message("\n=== ETAPA 4.3: ANAC — passageiros e carga BVB (SBBV) ===\n")

icao_bvb      <- "SBBV"
arq_anac_raw  <- file.path(dir_anac, "Dados_Estatisticos.csv")
url_anac_est  <- paste0(
  "https://sistemas.anac.gov.br/dadosabertos/",
  "Voos%20e%20opera%C3%A7%C3%B5es%20a%C3%A9reas/",
  "Dados%20Estat%C3%ADsticos%20do%20Transporte%20A%C3%A9reo/",
  "Dados_Estatisticos.csv"
)

if (file.exists(arq_anac_out)) {
  message("ANAC: cache agregado encontrado — carregando.")
  anac_mensal <- read_csv(arq_anac_out, show_col_types = FALSE)
} else {
  # Download do CSV consolidado (único arquivo, ~353 MB)
  # Usa PowerShell Invoke-WebRequest (melhor suporte a arquivos grandes no Windows)
  # Fallback: download.file com libcurl
  tamanho_esperado_anac <- 340e6  # ~340 MB mínimo esperado

  anac_arquivo_ok <- function(f) {
    file.exists(f) && file.size(f) >= tamanho_esperado_anac
  }

  if (!anac_arquivo_ok(arq_anac_raw)) {
    if (file.exists(arq_anac_raw)) {
      message(sprintf("ANAC: arquivo parcial (%.1f MB) — re-baixando.",
                      file.size(arq_anac_raw) / 1e6))
      unlink(arq_anac_raw)
    }
    message("ANAC: baixando Dados_Estatisticos.csv (~353 MB)...")

    # Método 1: PowerShell (sem limite de memória, streaming nativo no Windows)
    ps_cmd <- sprintf(
      'Invoke-WebRequest -Uri "%s" -OutFile "%s" -TimeoutSec 900',
      url_anac_est,
      normalizePath(arq_anac_raw, mustWork = FALSE)
    )
    anac_dl_ok <- tryCatch({
      ret <- system2("powershell", args = c("-NoProfile", "-Command", ps_cmd),
                     stdout = TRUE, stderr = TRUE)
      anac_arquivo_ok(arq_anac_raw)
    }, error = function(e) FALSE)

    # Método 2: download.file libcurl com verificação de tamanho
    if (!anac_dl_ok) {
      message("  PowerShell falhou, tentando libcurl...")
      options(timeout = 900)
      tryCatch({
        suppressWarnings(
          download.file(url_anac_est, destfile = arq_anac_raw,
                        method = "libcurl", mode = "wb", quiet = FALSE)
        )
        anac_dl_ok <- anac_arquivo_ok(arq_anac_raw)
      }, error = function(e) {
        message(sprintf("  libcurl falhou: %s", e$message))
      })
    }

    if (anac_dl_ok) {
      message(sprintf("  ANAC: arquivo completo (%.1f MB).",
                      file.size(arq_anac_raw) / 1e6))
    } else {
      sz <- if (file.exists(arq_anac_raw)) file.size(arq_anac_raw) / 1e6 else 0
      message(sprintf("  ANAC: download incompleto (%.1f MB de ~353 MB esperados).", sz))
      message("  AÇÃO MANUAL: baixar o arquivo em:")
      message("  ", url_anac_est)
      message("  e salvar em: ", arq_anac_raw)
      if (file.exists(arq_anac_raw)) unlink(arq_anac_raw)
    }
  } else {
    message(sprintf("ANAC: arquivo bruto em cache (%.1f MB) — processando.",
                    file.size(arq_anac_raw) / 1e6))
  }

  anac_mensal <- data.frame(ano = integer(), mes = integer(),
                             pax_total = integer(), carga_kg = integer())

  if (file.exists(arq_anac_raw)) {
    message("ANAC: lendo e filtrando SBBV...")
    # O arquivo tem 1 linha de metadados antes do cabeçalho real
    anac_raw <- tryCatch(
      fread(arq_anac_raw, sep = ";", skip = 1L,
            select = c("ANO", "MES",
                       "AEROPORTO_DE_ORIGEM_SIGLA",
                       "AEROPORTO_DE_DESTINO_SIGLA",
                       "PASSAGEIROS_PAGOS", "PASSAGEIROS_GRATIS",
                       "CARGA_PAGA_KG", "CARGA_GRATIS_KG"),
            encoding = "UTF-8",
            data.table = TRUE),
      error = function(e) {
        message(sprintf("  fread ANAC falhou: %s", e$message))
        NULL
      }
    )

    if (!is.null(anac_raw) && nrow(anac_raw) > 0) {
      # Filtrar: voos de/para SBBV, ano >= 2020
      anac_bvb <- anac_raw[
        (AEROPORTO_DE_ORIGEM_SIGLA == icao_bvb |
         AEROPORTO_DE_DESTINO_SIGLA == icao_bvb) &
        as.integer(ANO) >= ano_inicio
      ]

      if (nrow(anac_bvb) > 0) {
        anac_mensal <- anac_bvb[,
          .(
            pax_total = sum(as.integer(PASSAGEIROS_PAGOS)  +
                            as.integer(PASSAGEIROS_GRATIS), na.rm = TRUE),
            carga_kg  = sum(as.numeric(CARGA_PAGA_KG) +
                            as.numeric(CARGA_GRATIS_KG), na.rm = TRUE)
          ),
          by = .(ano = as.integer(ANO), mes = as.integer(MES))
        ] |>
          as.data.frame() |>
          arrange(ano, mes)

        write_csv(anac_mensal, arq_anac_out)
        message(sprintf("ANAC — %d meses SBBV (%d–%d), %s pax totais",
                        nrow(anac_mensal),
                        min(anac_mensal$ano), max(anac_mensal$ano),
                        format(sum(anac_mensal$pax_total), big.mark = ".")))
      } else {
        message("ANAC: nenhum voo SBBV encontrado no arquivo.")
      }
    }
    # Apagar bruto após processamento (libera ~353 MB)
    unlink(arq_anac_raw)
    message("ANAC: arquivo bruto removido após processamento.")
  }
}


# ============================================================
# ETAPA 4.4 — ANP: vendas de diesel por UF (Roraima)
# Fonte: ANP — Dados Abertos (Excel, série completa)
# UF Roraima = "RR" (abreviação estadual nos arquivos ANP)
# Tipo: volume físico (m³) | Qualidade: aceitável (proxy contaminada)
# ============================================================

message("\n=== ETAPA 4.4: ANP — vendas de diesel (RR) ===\n")

if (file.exists(arq_anp_out)) {
  message("ANP: cache local encontrado — carregando.")
  anp_mensal <- read_csv(arq_anp_out, show_col_types = FALSE)
} else {
  # ANP — Dados Abertos: CSV com vendas de derivados por UF (1990–presente)
  # URL atualizada em 2025: formato CSV semicolon-delimited, mês em texto PT
  # Colunas: ANO;MÊS;GRANDE REGIÃO;UNIDADE DA FEDERAÇÃO;PRODUTO;VENDAS
  # Meses: JAN, FEV, MAR, ABR, MAI, JUN, JUL, AGO, SET, OUT, NOV, DEZ
  url_anp <- paste0(
    "https://www.gov.br/anp/pt-br/centrais-de-conteudo/dados-abertos/",
    "arquivos/vdpb/vendas-derivados-petroleo-e-etanol/",
    "vendas-combustiveis-m3-1990-2025.csv"
  )

  tmp_anp <- file.path(dir_anp, "vendas-combustiveis-m3-1990-2025.csv")

  message("ANP: baixando CSV de vendas de combustíveis...")
  anp_dl_ok <- tryCatch({
    options(timeout = 300)
    download.file(url_anp, destfile = tmp_anp, method = "libcurl",
                  mode = "wb", quiet = TRUE)
    file.exists(tmp_anp) && file.size(tmp_anp) > 1e5
  }, error = function(e) {
    message(sprintf("  download.file ANP falhou: %s", e$message))
    FALSE
  })

  anp_mensal <- NULL

  if (isTRUE(anp_dl_ok)) {
    message(sprintf("ANP: arquivo baixado (%.1f MB). Processando...",
                    file.size(tmp_anp) / 1e6))

    # Meses em texto PT → inteiro
    meses_pt <- c(JAN=1, FEV=2, MAR=3, ABR=4, MAI=5, JUN=6,
                  JUL=7, AGO=8, SET=9, OUT=10, NOV=11, DEZ=12)

    # Tentar UTF-8 primeiro (padrão gov.br); fallback para latin1
    anp_raw <- tryCatch(
      read_delim(tmp_anp, delim = ";", locale = locale(encoding = "UTF-8"),
                 show_col_types = FALSE),
      error = function(e) {
        message(sprintf("  Leitura ANP CSV (UTF-8) falhou: %s — tentando latin1.", e$message))
        tryCatch(
          read_delim(tmp_anp, delim = ";", locale = locale(encoding = "latin1"),
                     show_col_types = FALSE),
          error = function(e2) {
            message(sprintf("  Leitura ANP CSV (latin1) falhou: %s", e2$message))
            NULL
          }
        )
      }
    )

    if (!is.null(anp_raw) && nrow(anp_raw) > 0) {
      # Normalizar nomes: remover acentos e converter para ASCII maiúsculo
      nomes_orig <- names(anp_raw)
      nomes_norm <- toupper(iconv(nomes_orig, from = "UTF-8", to = "ASCII//TRANSLIT"))
      # Se iconv retornar NA (encoding incorreto), usar gsub manual
      nomes_norm <- ifelse(is.na(nomes_norm),
                           toupper(gsub("[^A-Za-z0-9_ ]", "", nomes_orig)),
                           nomes_norm)
      names(anp_raw) <- nomes_norm

      col_ano  <- grep("^ANO$", nomes_norm, value = TRUE)[1]
      col_mes  <- grep("^M[E?]S$|^MES$", nomes_norm, value = TRUE)[1]
      if (is.na(col_mes)) col_mes <- nomes_norm[grepl("^M.S$", nomes_norm)][1]
      col_uf   <- nomes_norm[grepl("UNIDADE|ESTADO|^UF$", nomes_norm)][1]
      col_prod <- nomes_norm[grepl("PRODUTO|DERIVADO", nomes_norm)][1]
      col_vol  <- nomes_norm[grepl("VENDAS|VOLUME|M3", nomes_norm)][1]

      message(sprintf("  Colunas: %s", paste(nomes_norm, collapse = " | ")))
      message(sprintf("  Detectadas: ano=%s mes=%s uf=%s prod=%s vol=%s",
                      col_ano, col_mes, col_uf, col_prod, col_vol))

      if (!is.na(col_uf) && !is.na(col_prod) && !is.na(col_vol)) {
        # Normalizar valores da coluna UF para comparação sem acento
        uf_norm <- toupper(iconv(anp_raw[[col_uf]], from = "UTF-8", to = "ASCII//TRANSLIT"))
        anp_raw[["_uf_norm"]] <- ifelse(is.na(uf_norm),
                                         toupper(anp_raw[[col_uf]]),
                                         uf_norm)
        prod_norm <- toupper(iconv(anp_raw[[col_prod]], from = "UTF-8", to = "ASCII//TRANSLIT"))
        anp_raw[["_prod_norm"]] <- ifelse(is.na(prod_norm),
                                           toupper(anp_raw[[col_prod]]),
                                           prod_norm)
        anp_filtrado <- anp_raw |>
          filter(
            trimws(`_uf_norm`) == "RORAIMA",
            grepl("DIESEL|OLEO.*DIESEL|OL.*DIESEL", `_prod_norm`)
          )

        if (nrow(anp_filtrado) > 0 && !is.na(col_ano) && !is.na(col_mes)) {
          anp_mensal <- anp_filtrado |>
            mutate(
              ano  = as.integer(.data[[col_ano]]),
              mes  = suppressWarnings(
                       as.integer(meses_pt[toupper(trimws(.data[[col_mes]]))])
                     ),
              diesel_m3 = suppressWarnings(
                            as.numeric(gsub(",", ".", .data[[col_vol]]))
                          )
            ) |>
            filter(!is.na(ano), !is.na(mes), ano >= ano_inicio) |>
            group_by(ano, mes) |>
            summarise(diesel_m3 = sum(diesel_m3, na.rm = TRUE), .groups = "drop") |>
            arrange(ano, mes)

          write_csv(anp_mensal, arq_anp_out)
          message(sprintf("ANP — %d meses de diesel RR salvos (%.0f–%.0f).",
                          nrow(anp_mensal),
                          min(anp_mensal$ano), max(anp_mensal$ano)))
        } else {
          message("ANP: nenhum registro RR/diesel encontrado. Verificar filtros.")
          message("  Primeiras UFs: ", paste(unique(head(anp_raw[[col_uf]], 20)), collapse=", "))
        }
      } else {
        message("ANP: colunas não detectadas. Colunas do arquivo: ",
                paste(nomes_norm, collapse = ", "))
      }
    }
    unlink(tmp_anp)
  } else {
    message("ANP: download falhou.")
    message("  URL tentada: ", url_anp)
    message("  AÇÃO MANUAL: baixar CSV de https://www.gov.br/anp/pt-br/centrais-de-conteudo/dados-abertos")
    message("  e salvar em: ", arq_anp_out,
            " com colunas: ano, mes, diesel_m3")
  }

  if (is.null(anp_mensal)) {
    anp_mensal <- data.frame(ano = integer(), mes = integer(), diesel_m3 = numeric())
  }
}

if (nrow(anp_mensal) > 0) {
  message(sprintf("ANP — %d meses de diesel RR (%.0f–%.0f)",
                  nrow(anp_mensal),
                  min(anp_mensal$ano), max(anp_mensal$ano)))
}


# ============================================================
# ETAPA 4.5 — BCB: IPCA mensal (deflator)
# Reutiliza cache da Fase 2 (ipca_mensal.csv via SIDRA)
# Série IBGE SIDRA Tab. 1737 v2266 — IPCA variação % mensal
# ============================================================

message("\n=== ETAPA 4.5: IPCA (deflator BCB) ===\n")

if (file.exists(arq_ipca)) {
  message("IPCA: cache local encontrado — reutilizando.")
  ipca_raw <- read.csv(arq_ipca, check.names = FALSE, stringsAsFactors = FALSE)
} else {
  message("IPCA: coletando via SIDRA (Tab. 1737)...")
  ipca_raw <- tryCatch(
    sidrar::get_sidra(api = "/t/1737/n1/all/v/2266/p/all/d/v2266%2013"),
    error = function(e) {
      message(sprintf("  IPCA SIDRA falhou: %s", e$message))
      NULL
    }
  )
  if (!is.null(ipca_raw)) write.csv(ipca_raw, arq_ipca, row.names = FALSE)
}

# Processar IPCA
if (!is.null(ipca_raw) && nrow(ipca_raw) > 0) {
  nomes_ipca   <- names(ipca_raw)
  col_val      <- nomes_ipca[grepl("^Valor$", nomes_ipca)][1]
  col_mes_cod  <- nomes_ipca[grepl("Mês \\(Código\\)", nomes_ipca)][1]
  col_mes_txt  <- nomes_ipca[grepl("^Mês$|^Mês e Ano$", nomes_ipca)][1]

  parse_periodo_ipca <- function(cod, txt) {
    # Tenta código numérico AAAAMM
    if (length(cod) > 0 && !is.na(cod[1]) && grepl("^[0-9]{6}$", trimws(cod[1]))) {
      return(list(
        ano = as.integer(substr(trimws(cod), 1, 4)),
        mes = as.integer(substr(trimws(cod), 5, 6))
      ))
    }
    # Fallback: texto "janeiro 2020", "jan. 2020", etc.
    meses_pt <- c("jan"=1,"fev"=2,"mar"=3,"abr"=4,"mai"=5,"jun"=6,
                  "jul"=7,"ago"=8,"set"=9,"out"=10,"nov"=11,"dez"=12)
    m <- regmatches(tolower(txt), regexpr("[a-z]{3}", tolower(txt)))
    a <- regmatches(txt, regexpr("[0-9]{4}", txt))
    list(
      ano = as.integer(a),
      mes = as.integer(meses_pt[m])
    )
  }

  cod_vec <- if (!is.na(col_mes_cod)) as.character(ipca_raw[[col_mes_cod]]) else rep(NA_character_, nrow(ipca_raw))
  txt_vec <- if (!is.na(col_mes_txt)) as.character(ipca_raw[[col_mes_txt]]) else rep(NA_character_, nrow(ipca_raw))
  parsed  <- parse_periodo_ipca(cod_vec, txt_vec)

  ipca <- data.frame(
    ano     = parsed$ano,
    mes     = parsed$mes,
    var_pct = suppressWarnings(as.numeric(gsub(",", ".", ipca_raw[[col_val]])))
  ) |>
    filter(!is.na(ano), !is.na(mes), !is.na(var_pct)) |>
    arrange(ano, mes)

  # Índice de preços (base: jan/2020 = 1)
  idx_jan2020 <- which(ipca$ano == 2020 & ipca$mes == 1)
  if (length(idx_jan2020) == 0) idx_jan2020 <- 1

  ipca <- ipca |>
    mutate(
      indice_preco = cumprod(1 + var_pct / 100),
      indice_preco = indice_preco / indice_preco[idx_jan2020]
    )

  message(sprintf("IPCA — %d obs. de %d/%d a %d/%d",
                  nrow(ipca), min(ipca$mes), min(ipca$ano),
                  max(ipca$mes), max(ipca$ano)))
} else {
  warning("IPCA: não disponível. BCB Financeiro calculado sem deflação.")
  ipca <- NULL
}


# ============================================================
# ETAPA 4.6 — BCB Estban: depósitos totais em RR
# NOTA: endpoints OData BCB (Estban v1/v2/v3) retornam HTTP 404
# desde 2025. Setor Financeiro permanece NA nesta versão.
# Para reativar: colocar arquivo com colunas ano,mes,depositos em:
#   data/raw/bcb/bcb_estban_rr_mensal.csv
# ============================================================

message("\n=== ETAPA 4.6: BCB Estban — depósitos RR ===\n")

if (file.exists(arq_estban_out)) {
  message("Estban: cache local encontrado.")
  estban_mensal <- read_csv(arq_estban_out, show_col_types = FALSE)
  message(sprintf("Estban — %d obs. (%.0f–%.0f)",
                  nrow(estban_mensal),
                  min(estban_mensal$ano), max(estban_mensal$ano)))
} else {
  message("Estban: sem cache. API OData BCB indisponível (HTTP 404 em todas as versões).")
  message("  Setor Financeiro será excluído do índice composto nesta versão.")
  message("  Para incluir: salvar manualmente em ", arq_estban_out,
          " (colunas: ano, mes, depositos).")
  estban_mensal <- data.frame(ano = integer(), mes = integer(), depositos = numeric())
}


# ============================================================
# ETAPA 4.7 — BCB: concessões de crédito por UF (Roraima)
# NOTA: endpoint OData NotaCredito retorna HTTP 404.
# Para reativar: salvar arquivo com colunas ano,mes,concessoes em:
#   data/raw/bcb/bcb_concessoes_rr_mensal.csv
# ============================================================

message("\n=== ETAPA 4.7: BCB — concessões de crédito (RR) ===\n")

bcb_concessoes_ok <- FALSE

if (file.exists(arq_concessoes_out)) {
  message("Concessões BCB: cache local encontrado.")
  concessoes_mensal <- read_csv(arq_concessoes_out, show_col_types = FALSE)
  bcb_concessoes_ok <- nrow(concessoes_mensal) > 0
  if (bcb_concessoes_ok)
    message(sprintf("Concessões BCB — %d obs. (%.0f–%.0f)",
                    nrow(concessoes_mensal),
                    min(concessoes_mensal$ano), max(concessoes_mensal$ano)))
} else {
  message("Concessões BCB: sem cache. API OData BCB indisponível.")
  message("  Para incluir: salvar manualmente em ", arq_concessoes_out,
          " (colunas: ano, mes, concessoes).")
  concessoes_mensal <- data.frame(ano = integer(), mes = integer(), concessoes = numeric())
}

if (bcb_concessoes_ok) {
  concessoes_mensal <- concessoes_mensal |> filter(ano >= ano_inicio)
  message(sprintf("Concessões BCB — %d obs. (%.0f–%.0f)",
                  nrow(concessoes_mensal),
                  min(concessoes_mensal$ano), max(concessoes_mensal$ano)))
}


# ============================================================
# ETAPA 4.8 — COMÉRCIO (12,25% do VAB)
# Índice composto: energia comercial (67%) + CAGED G (33%)
# NOTA: ICMS SEFAZ-RR excluído. Ao integrar ICMS:
#   pesos = energia 40%, ICMS deflacionado 40%, CAGED G 20%
# Tipo medida: volume (energia) + insumo (emprego)
# Qualidade: aceitável (sem ICMS) — revisar quando disponível
# ============================================================

message("\n=== ETAPA 4.8: Comércio — energia comercial + CAGED G ===\n")

# Energia comercial trimestral
energia_com_trim <- energia_com_mensal |>
  group_by(ano, trimestre) |>
  summarise(energia_kwh = sum(energia_kwh, na.rm = TRUE), n_meses = n(),
            .groups = "drop") |>
  filter(n_meses == 3) |>
  arrange(ano, trimestre)

base_ecom_2020 <- energia_com_trim |> filter(ano == 2020) |>
  pull(energia_kwh) |> mean(na.rm = TRUE)
energia_com_trim <- energia_com_trim |>
  mutate(indice_energia_com = energia_kwh / base_ecom_2020 * 100)

# CAGED G já normalizado na função agregar_caged_secoes
if (is.null(caged_g) || nrow(caged_g) == 0) {
  warning("CAGED G: sem dados — Comércio usará apenas energia comercial.")
  peso_energia_comercio_ef <- 1.0
  peso_caged_g_ef           <- 0.0
} else {
  peso_energia_comercio_ef <- peso_energia_comercio
  peso_caged_g_ef           <- peso_caged_g
}

# Índice composto Comércio
comercio_base <- energia_com_trim |>
  select(ano, trimestre, indice_energia_com)

if (peso_caged_g_ef > 0) {
  comercio_trim <- comercio_base |>
    left_join(select(caged_g, ano, trimestre, indice_g = indice),
              by = c("ano", "trimestre")) |>
    mutate(
      indice_comercio_raw = case_when(
        !is.na(indice_energia_com) & !is.na(indice_g) ~
          peso_energia_comercio_ef * indice_energia_com +
          peso_caged_g_ef * indice_g,
        !is.na(indice_energia_com) ~ indice_energia_com,
        !is.na(indice_g)           ~ indice_g,
        TRUE ~ NA_real_
      )
    )
} else {
  comercio_trim <- comercio_base |>
    mutate(indice_comercio_raw = indice_energia_com)
}

message(sprintf("Comércio: %d trimestres (energia %.0f%% + CAGED G %.0f%% — sem ICMS)",
                sum(!is.na(comercio_trim$indice_comercio_raw)),
                peso_energia_comercio_ef * 100,
                peso_caged_g_ef * 100))

# Contas Regionais — VAB Comércio para benchmark Denton
cr_all <- read_csv(arq_cr_serie, show_col_types = FALSE)

bench_comercio <- cr_all |>
  filter(grepl("Com.rcio", atividade, ignore.case = TRUE),
         ano %in% anos_cr) |>
  arrange(ano) |>
  pull(vab_mi)

if (length(bench_comercio) != length(anos_cr)) {
  warning(sprintf("Benchmark Comércio: %d anos (esperado %d). Verificar CR.",
                  length(bench_comercio), length(anos_cr)))
}

ind_com_para_denton <- comercio_trim |>
  filter(ano >= min(anos_cr)) |>
  pull(indice_comercio_raw)

indice_comercio_denton <- tryCatch(
  denton(ind_com_para_denton, bench_comercio,
         ano_inicio = min(anos_cr), metodo = "denton-cholette"),
  error = function(e) {
    message(sprintf("  Denton Comércio falhou: %s — usando índice raw.", e$message))
    ind_com_para_denton
  }
)

# Normalizar 2020=100 após Denton
n_2020_com <- 4L  # 4 trimestres de 2020
base_com_denton <- mean(head(indice_comercio_denton, n_2020_com))
indice_comercio <- indice_comercio_denton / base_com_denton * 100

comercio_trim_completo <- comercio_trim |>
  filter(ano >= min(anos_cr)) |>
  mutate(indice_comercio = indice_comercio)

validar_serie(comercio_trim_completo$indice_comercio, "Comércio",
              variacao_max = 0.60)

message(sprintf("Comércio — %d trimestres Denton (base 2020=100)",
                nrow(comercio_trim_completo)))


# ============================================================
# ETAPA 4.9 — TRANSPORTES (1,92% do VAB)
# ANAC pax (40%) + ANAC carga (30%) + ANP diesel (30%)
# Tipo: volume (pax/carga/combustível) | Qualidade: média
# ============================================================

message("\n=== ETAPA 4.9: Transportes — ANAC + ANP diesel ===\n")

# Agregar ANAC para trimestral
tem_anac <- nrow(anac_mensal) > 0

if (tem_anac) {
  anac_trim <- anac_mensal |>
    mutate(trimestre = ceiling(mes / 3)) |>
    group_by(ano, trimestre) |>
    summarise(
      pax_total = sum(pax_total, na.rm = TRUE),
      carga_kg  = sum(carga_kg,  na.rm = TRUE),
      n_meses   = n(),
      .groups   = "drop"
    ) |>
    filter(n_meses == 3) |>
    arrange(ano, trimestre)

  base_pax_2020  <- anac_trim |> filter(ano == 2020) |> pull(pax_total) |> mean()
  base_carga_2020 <- anac_trim |> filter(ano == 2020) |> pull(carga_kg)  |> mean()

  # Evitar divisão por zero
  if (is.na(base_pax_2020) || base_pax_2020 == 0) base_pax_2020 <- 1
  if (is.na(base_carga_2020) || base_carga_2020 == 0) base_carga_2020 <- 1

  anac_trim <- anac_trim |>
    mutate(
      indice_pax   = pax_total  / base_pax_2020  * 100,
      indice_carga = carga_kg   / base_carga_2020 * 100
    )
}

# ANP diesel trimestral
tem_anp <- nrow(anp_mensal) > 0

if (tem_anp) {
  anp_trim <- anp_mensal |>
    mutate(trimestre = ceiling(mes / 3)) |>
    group_by(ano, trimestre) |>
    summarise(diesel_m3 = sum(diesel_m3, na.rm = TRUE), n_meses = n(),
              .groups = "drop") |>
    filter(n_meses == 3) |>
    arrange(ano, trimestre)

  base_diesel_2020 <- anp_trim |> filter(ano == 2020) |> pull(diesel_m3) |> mean()
  if (is.na(base_diesel_2020) || base_diesel_2020 == 0) base_diesel_2020 <- 1

  anp_trim <- anp_trim |> mutate(indice_diesel = diesel_m3 / base_diesel_2020 * 100)
}

# Pesos efetivos conforme disponibilidade
if (!tem_anac && !tem_anp) {
  warning("Transportes: ANAC e ANP indisponíveis. Setor sem índice.")
  transportes_trim_completo <- data.frame(
    ano = integer(), trimestre = integer(), indice_transportes = numeric()
  )
} else {
  # Normalizar pesos ao que está disponível
  p_pax   <- if (tem_anac) peso_pax_anac   else 0
  p_carga <- if (tem_anac) peso_carga_anac else 0
  p_dsl   <- if (tem_anp)  peso_diesel_anp else 0
  total_p <- p_pax + p_carga + p_dsl
  if (total_p == 0) total_p <- 1
  p_pax <- p_pax / total_p; p_carga <- p_carga / total_p; p_dsl <- p_dsl / total_p

  # Base: trimestres da série mais longa (geralmente ANAC)
  base_tr <- if (tem_anac) anac_trim |> select(ano, trimestre) else
    anp_trim |> select(ano, trimestre)

  transportes_trim <- base_tr
  if (tem_anac) {
    transportes_trim <- transportes_trim |>
      left_join(select(anac_trim, ano, trimestre, indice_pax, indice_carga),
                by = c("ano", "trimestre"))
  } else {
    transportes_trim <- transportes_trim |>
      mutate(indice_pax = NA_real_, indice_carga = NA_real_)
  }
  if (tem_anp) {
    transportes_trim <- transportes_trim |>
      left_join(select(anp_trim, ano, trimestre, indice_diesel),
                by = c("ano", "trimestre"))
  } else {
    transportes_trim <- transportes_trim |> mutate(indice_diesel = NA_real_)
  }

  transportes_trim <- transportes_trim |>
    rowwise() |>
    mutate(
      indice_transp_raw = {
        vals  <- c(indice_pax, indice_carga, indice_diesel)
        pesos <- c(p_pax, p_carga, p_dsl)
        ok    <- !is.na(vals)
        if (any(ok)) sum(vals[ok] * pesos[ok] / sum(pesos[ok])) else NA_real_
      }
    ) |>
    ungroup()

  bench_transp <- cr_all |>
    filter(grepl("Transporte", atividade, ignore.case = TRUE),
           ano %in% anos_cr) |>
    arrange(ano) |>
    pull(vab_mi)

  ind_tr_para_denton <- transportes_trim |>
    filter(ano >= min(anos_cr)) |>
    pull(indice_transp_raw)

  indice_transp_denton <- tryCatch(
    denton(ind_tr_para_denton, bench_transp, ano_inicio = min(anos_cr), metodo = "denton-cholette"),
    error = function(e) {
      message(sprintf("  Denton Transportes falhou: %s", e$message))
      ind_tr_para_denton
    }
  )

  base_tr_denton <- mean(head(indice_transp_denton, 4L))
  indice_transp  <- indice_transp_denton / base_tr_denton * 100

  transportes_trim_completo <- transportes_trim |>
    filter(ano >= min(anos_cr)) |>
    mutate(indice_transportes = indice_transp)

  message(sprintf("Transportes — %d trimestres (pax %.0f%% + carga %.0f%% + diesel %.0f%%)",
                  nrow(transportes_trim_completo),
                  p_pax * 100, p_carga * 100, p_dsl * 100))
}


# ============================================================
# ETAPA 4.10 — FINANCEIRO (2,78% do VAB)
# Concessões de crédito BCB (70%) + depósitos Estban (30%)
# Ambos deflacionados pelo IPCA antes do cálculo do índice
# Suavização: média móvel de 3 meses (alta volatilidade mensal)
# Tipo: fluxo deflacionado (concessões) + estoque deflacionado (dep.)
# Qualidade: aceitável (concessões) + fraca mas necessária (depósitos)
# ============================================================

message("\n=== ETAPA 4.10: Financeiro — BCB concessões + Estban ===\n")

#' Deflaciona série mensal e aplica média móvel de 3 meses
deflacionar_e_suavizar <- function(df_mensal, col_valor, ipca_df, mm3 = TRUE) {
  if (is.null(ipca_df)) return(df_mensal |> mutate(valor_real = .data[[col_valor]]))

  df <- df_mensal |>
    left_join(select(ipca_df, ano, mes, indice_preco), by = c("ano", "mes")) |>
    mutate(
      valor_real = .data[[col_valor]] / indice_preco
    )

  if (mm3 && nrow(df) >= 3) {
    df <- df |>
      arrange(ano, mes) |>
      mutate(
        valor_real = {
          x <- valor_real
          n <- length(x)
          r <- rep(NA_real_, n)
          for (i in 3:n) r[i] <- mean(x[(i-2):i], na.rm = FALSE)
          r
        }
      )
  }
  return(df)
}

tem_concessoes <- bcb_concessoes_ok && nrow(concessoes_mensal) > 0
tem_depositos  <- nrow(estban_mensal) > 0

if (!tem_concessoes && !tem_depositos) {
  warning("Financeiro: sem dados BCB. Setor sem índice — será excluído do composto.")
  financeiro_trim_completo <- data.frame(
    ano = integer(), trimestre = integer(), indice_financeiro = numeric()
  )
} else {
  p_conc <- if (tem_concessoes) peso_concessoes else 0
  p_dep  <- if (tem_depositos)  peso_depositos  else 0
  total_pf <- p_conc + p_dep
  if (total_pf == 0) total_pf <- 1
  p_conc <- p_conc / total_pf; p_dep <- p_dep / total_pf

  # Deflacionar e suavizar concessões
  if (tem_concessoes) {
    conc_real <- deflacionar_e_suavizar(concessoes_mensal, "concessoes", ipca, mm3 = TRUE)

    conc_trim <- conc_real |>
      filter(ano >= ano_inicio) |>
      mutate(trimestre = ceiling(mes / 3)) |>
      group_by(ano, trimestre) |>
      summarise(concessoes_real = mean(valor_real, na.rm = TRUE), n_meses = n(),
                .groups = "drop") |>
      filter(n_meses == 3) |>
      arrange(ano, trimestre)

    base_conc_2020 <- conc_trim |> filter(ano == 2020) |> pull(concessoes_real) |> mean()
    if (is.na(base_conc_2020) || base_conc_2020 == 0) base_conc_2020 <- 1
    conc_trim <- conc_trim |> mutate(indice_concessoes = concessoes_real / base_conc_2020 * 100)
  }

  # Deflacionar depósitos
  if (tem_depositos) {
    dep_real <- deflacionar_e_suavizar(estban_mensal, "depositos", ipca, mm3 = FALSE)

    dep_trim <- dep_real |>
      filter(ano >= ano_inicio) |>
      mutate(trimestre = ceiling(mes / 3)) |>
      group_by(ano, trimestre) |>
      summarise(depositos_real = mean(valor_real, na.rm = TRUE), n_meses = n(),
                .groups = "drop") |>
      filter(n_meses == 3) |>
      arrange(ano, trimestre)

    base_dep_2020 <- dep_trim |> filter(ano == 2020) |> pull(depositos_real) |> mean()
    if (is.na(base_dep_2020) || base_dep_2020 == 0) base_dep_2020 <- 1
    dep_trim <- dep_trim |> mutate(indice_depositos = depositos_real / base_dep_2020 * 100)
  }

  # Índice composto Financeiro
  base_fin <- if (tem_concessoes) conc_trim |> select(ano, trimestre) else
    dep_trim |> select(ano, trimestre)

  financeiro_trim <- base_fin
  if (tem_concessoes)
    financeiro_trim <- financeiro_trim |>
      left_join(select(conc_trim, ano, trimestre, indice_concessoes), by = c("ano", "trimestre"))
  else
    financeiro_trim <- financeiro_trim |> mutate(indice_concessoes = NA_real_)

  if (tem_depositos)
    financeiro_trim <- financeiro_trim |>
      left_join(select(dep_trim, ano, trimestre, indice_depositos), by = c("ano", "trimestre"))
  else
    financeiro_trim <- financeiro_trim |> mutate(indice_depositos = NA_real_)

  financeiro_trim <- financeiro_trim |>
    rowwise() |>
    mutate(
      indice_financeiro_raw = {
        vals  <- c(indice_concessoes, indice_depositos)
        pesos <- c(p_conc, p_dep)
        ok    <- !is.na(vals)
        if (any(ok)) sum(vals[ok] * pesos[ok] / sum(pesos[ok])) else NA_real_
      }
    ) |>
    ungroup()

  bench_financ <- cr_all |>
    filter(grepl("financeiras", atividade, ignore.case = TRUE),
           ano %in% anos_cr) |>
    arrange(ano) |>
    pull(vab_mi)

  ind_fin_para_denton <- financeiro_trim |>
    filter(ano >= min(anos_cr)) |>
    pull(indice_financeiro_raw)

  indice_financ_denton <- tryCatch(
    denton(ind_fin_para_denton, bench_financ, ano_inicio = min(anos_cr), metodo = "denton-cholette"),
    error = function(e) {
      message(sprintf("  Denton Financeiro falhou: %s", e$message))
      ind_fin_para_denton
    }
  )

  base_fin_denton <- mean(head(indice_financ_denton, 4L))
  indice_fin      <- indice_financ_denton / base_fin_denton * 100

  financeiro_trim_completo <- financeiro_trim |>
    filter(ano >= min(anos_cr)) |>
    mutate(indice_financeiro = indice_fin)

  message(sprintf("Financeiro — %d trimestres (conc. %.0f%% + dep. %.0f%%)",
                  nrow(financeiro_trim_completo),
                  p_conc * 100, p_dep * 100))
}


# ============================================================
# ETAPA 4.11 — IMOBILIÁRIO (7,68% do VAB)
# Tendência linear interpolada entre benchmarks anuais CR IBGE
# Sem proxy de mercado (aluguel imputado ≠ transações imobiliárias)
# Tipo: tendência | Qualidade: fraca mas necessária
# ============================================================

message("\n=== ETAPA 4.11: Imobiliário — interpolação linear CR ===\n")

bench_imob <- cr_all |>
  filter(grepl("imobili", atividade, ignore.case = TRUE),
         ano %in% anos_cr) |>
  arrange(ano) |>
  pull(vab_mi)

# Interpolar anualmente de 2020 a (ano_atual), extrapolando a tendência
# Tendência de longo prazo: inclinação média dos últimos 2 anos CR
n_bench <- length(bench_imob)
slope_imob <- if (n_bench >= 2) (bench_imob[n_bench] - bench_imob[n_bench - 1]) else 0

# Série anual completa (CR + extrapolação linear)
anos_completos <- ano_inicio:ano_atual
vab_imob_serie <- numeric(length(anos_completos))
for (i in seq_along(anos_completos)) {
  ano_i <- anos_completos[i]
  if (ano_i %in% anos_cr) {
    vab_imob_serie[i] <- bench_imob[which(anos_cr == ano_i)]
  } else {
    # Extrapolar: usar tendência linear do último benchmark
    anos_extra <- ano_i - max(anos_cr)
    vab_imob_serie[i] <- bench_imob[n_bench] + slope_imob * anos_extra
  }
}

# Distribuição intra-anual: linear entre anos adjacentes, média anual = benchmark
# Usar Denton com indicador constante (uniforme) = interpolação linear suave
ind_plano <- rep(1, length(anos_completos) * 4)
bench_imob_completo <- vab_imob_serie

imob_trim_vals <- tryCatch(
  denton(ind_plano, bench_imob_completo,
         ano_inicio = ano_inicio, metodo = "denton-cholette"),
  error = function(e) {
    message(sprintf("  Denton Imobiliário falhou: %s — usando tendência linear.", e$message))
    # Fallback: repetir cada valor anual 4 vezes e normalizar
    rep(bench_imob_completo, each = 4)
  }
)

# Criar data.frame estruturado
trimestres_grid <- expand_grid(ano = anos_completos, trimestre = 1:4) |>
  arrange(ano, trimestre)

imobiliario_trim_completo <- trimestres_grid |>
  mutate(valor_imob = imob_trim_vals) |>
  filter(ano >= ano_inicio)

# Normalizar 2020=100
base_imob_2020 <- imobiliario_trim_completo |> filter(ano == 2020) |>
  pull(valor_imob) |> mean()
imobiliario_trim_completo <- imobiliario_trim_completo |>
  mutate(indice_imobiliario = valor_imob / base_imob_2020 * 100)

message(sprintf("Imobiliário — %d trimestres (interpolação linear CR, extrapolado para %.0f)",
                nrow(imobiliario_trim_completo), ano_atual))


# ============================================================
# ETAPA 4.12 — OUTROS SERVIÇOS (7,63% do VAB)
# CAGED I (aloj./alim.) + M+N (prof./admin.) + P+Q (educ./saúde)
# Pesos: proporcionais ao estoque de emprego médio de 2020
# Tipo: insumo (emprego) | Qualidade: aceitável
# ============================================================

message("\n=== ETAPA 4.12: Outros Serviços — CAGED I + M+N + P+Q ===\n")

# Identificar quais subgrupos estão disponíveis
disponivel_i  <- !is.null(caged_i)  && nrow(caged_i)  > 0
disponivel_mn <- !is.null(caged_mn) && nrow(caged_mn) > 0
disponivel_pq <- !is.null(caged_pq) && nrow(caged_pq) > 0

if (!disponivel_i && !disponivel_mn && !disponivel_pq) {
  warning("Outros Serviços: todos os subgrupos CAGED ausentes.")
  outros_trim_completo <- data.frame(
    ano = integer(), trimestre = integer(), indice_outros = numeric()
  )
} else {
  # Calcular pesos proporcionais ao estoque médio de emprego em 2020
  get_estoque_2020 <- function(df_caged, disponivel) {
    if (!disponivel) return(0)
    df_caged |> filter(ano == 2020) |> pull(estoque) |> mean(na.rm = TRUE)
  }

  estoque_i_2020  <- get_estoque_2020(caged_i,  disponivel_i)
  estoque_mn_2020 <- get_estoque_2020(caged_mn, disponivel_mn)
  estoque_pq_2020 <- get_estoque_2020(caged_pq, disponivel_pq)
  total_estoque   <- estoque_i_2020 + estoque_mn_2020 + estoque_pq_2020

  if (total_estoque == 0) total_estoque <- 1
  peso_i  <- estoque_i_2020  / total_estoque
  peso_mn <- estoque_mn_2020 / total_estoque
  peso_pq <- estoque_pq_2020 / total_estoque

  message(sprintf("Outros Serviços — pesos dinâmicos (estoque 2020): I=%.1f%% M+N=%.1f%% P+Q=%.1f%%",
                  peso_i * 100, peso_mn * 100, peso_pq * 100))

  # Base de trimestres: união de todos os subgrupos disponíveis
  base_os <- bind_rows(
    if (disponivel_i)  caged_i  |> select(ano, trimestre) else NULL,
    if (disponivel_mn) caged_mn |> select(ano, trimestre) else NULL,
    if (disponivel_pq) caged_pq |> select(ano, trimestre) else NULL
  ) |> distinct() |> arrange(ano, trimestre)

  outros_trim <- base_os
  if (disponivel_i)
    outros_trim <- outros_trim |>
      left_join(select(caged_i, ano, trimestre, indice_i = indice), by = c("ano", "trimestre"))
  else
    outros_trim <- outros_trim |> mutate(indice_i = NA_real_)

  if (disponivel_mn)
    outros_trim <- outros_trim |>
      left_join(select(caged_mn, ano, trimestre, indice_mn = indice), by = c("ano", "trimestre"))
  else
    outros_trim <- outros_trim |> mutate(indice_mn = NA_real_)

  if (disponivel_pq)
    outros_trim <- outros_trim |>
      left_join(select(caged_pq, ano, trimestre, indice_pq = indice), by = c("ano", "trimestre"))
  else
    outros_trim <- outros_trim |> mutate(indice_pq = NA_real_)

  outros_trim <- outros_trim |>
    rowwise() |>
    mutate(
      indice_outros_raw = {
        vals  <- c(indice_i, indice_mn, indice_pq)
        pesos <- c(peso_i, peso_mn, peso_pq)
        ok    <- !is.na(vals)
        if (any(ok)) sum(vals[ok] * pesos[ok] / sum(pesos[ok])) else NA_real_
      }
    ) |>
    ungroup()

  bench_outros <- cr_all |>
    filter(grepl("Outros servi", atividade, ignore.case = TRUE),
           ano %in% anos_cr) |>
    arrange(ano) |>
    pull(vab_mi)

  ind_os_para_denton <- outros_trim |>
    filter(ano >= min(anos_cr)) |>
    pull(indice_outros_raw)

  indice_os_denton <- tryCatch(
    denton(ind_os_para_denton, bench_outros, ano_inicio = min(anos_cr), metodo = "denton-cholette"),
    error = function(e) {
      message(sprintf("  Denton Outros Serviços falhou: %s", e$message))
      ind_os_para_denton
    }
  )

  base_os_denton <- mean(head(indice_os_denton, 4L))
  indice_os      <- indice_os_denton / base_os_denton * 100

  outros_trim_completo <- outros_trim |>
    filter(ano >= min(anos_cr)) |>
    mutate(indice_outros = indice_os)

  message(sprintf("Outros Serviços — %d trimestres (base 2020=100)",
                  nrow(outros_trim_completo)))
}


# ============================================================
# ETAPA 4.13 — INFORMAÇÃO E COMUNICAÇÃO (1,01% do VAB)
# Proxy: estoque acumulado de emprego CNAE J (TI/telecom)
# Tipo: insumo (emprego) | Qualidade: fraca mas necessária
# ============================================================

message("\n=== ETAPA 4.13: Informação e Comunicação — CAGED J ===\n")

if (is.null(caged_j) || nrow(caged_j) == 0) {
  warning("CAGED J: sem dados. Info e Comunicação sem índice.")
  infocom_trim_completo <- data.frame(
    ano = integer(), trimestre = integer(), indice_infocom = numeric()
  )
} else {
  bench_info <- cr_all |>
    filter(grepl("Informa", atividade, ignore.case = TRUE),
           ano %in% anos_cr) |>
    arrange(ano) |>
    pull(vab_mi)

  ind_j_para_denton <- caged_j |>
    filter(ano >= min(anos_cr)) |>
    pull(indice)

  indice_j_denton <- tryCatch(
    denton(ind_j_para_denton, bench_info, ano_inicio = min(anos_cr), metodo = "denton-cholette"),
    error = function(e) {
      message(sprintf("  Denton Info/Com falhou: %s", e$message))
      ind_j_para_denton
    }
  )

  base_j_denton <- mean(head(indice_j_denton, 4L))
  indice_j      <- indice_j_denton / base_j_denton * 100

  infocom_trim_completo <- caged_j |>
    filter(ano >= min(anos_cr)) |>
    mutate(indice_infocom = indice_j)

  message(sprintf("Informação e Comunicação — %d trimestres (base 2020=100)",
                  nrow(infocom_trim_completo)))
}


# ============================================================
# ETAPA 4.14 — EXTRATIVAS (0,05% do VAB)
# Peso negligenciável — interpolação linear entre benchmarks CR
# Mesma lógica do Imobiliário, com tendência dos últimos 2 anos
# ============================================================

message("\n=== ETAPA 4.14: Extrativas — interpolação linear CR ===\n")

bench_extr <- cr_all |>
  filter(grepl("extrativ", atividade, ignore.case = TRUE),
         ano %in% anos_cr) |>
  arrange(ano) |>
  pull(vab_mi)

n_extr <- length(bench_extr)
# Para setores voláteis/pequenos, não extrapolar tendência negativa — usar último benchmark
slope_extr <- if (n_extr >= 2) max(0, bench_extr[n_extr] - bench_extr[n_extr - 1]) else 0

vab_extr_serie <- numeric(length(anos_completos))
for (i in seq_along(anos_completos)) {
  ano_i <- anos_completos[i]
  if (ano_i %in% anos_cr) {
    vab_extr_serie[i] <- bench_extr[which(anos_cr == ano_i)]
  } else {
    anos_extra <- ano_i - max(anos_cr)
    vab_extr_serie[i] <- max(bench_extr[n_extr] + slope_extr * anos_extra,
                             bench_extr[n_extr] * 0.5)  # piso: 50% do último benchmark
  }
}

ind_plano_extr <- rep(1, length(anos_completos) * 4)
extr_trim_vals <- tryCatch(
  denton(ind_plano_extr, vab_extr_serie,
         ano_inicio = ano_inicio, metodo = "denton-cholette"),
  error = function(e) {
    message(sprintf("  Denton Extrativas falhou: %s — usando tendência linear.", e$message))
    rep(vab_extr_serie, each = 4)
  }
)

extrativas_trim_completo <- trimestres_grid |>
  mutate(valor_extr = extr_trim_vals) |>
  filter(ano >= ano_inicio)

base_extr_2020 <- extrativas_trim_completo |> filter(ano == 2020) |>
  pull(valor_extr) |> mean()
extrativas_trim_completo <- extrativas_trim_completo |>
  mutate(indice_extrativas = valor_extr / base_extr_2020 * 100)

message(sprintf("Extrativas — %d trimestres (interpolação linear CR)", nrow(extrativas_trim_completo)))


# ============================================================
# ETAPA 4.15 — ÍNDICE COMPOSTO DE SERVIÇOS (Laspeyres setorial)
# Agrega os 7 subsetores com pesos % VAB 2023 (Contas Regionais)
# Trimestres disponíveis: 2020T1–(ano_atual)T4
# ============================================================

message("\n=== ETAPA 4.15: Índice composto de Serviços ===\n")

# Grade de todos os trimestres de 2020 a ano_atual
grade_trim <- expand_grid(
  ano       = ano_inicio:ano_atual,
  trimestre = 1:4
) |> arrange(ano, trimestre)

# Montar data.frame largo com todos os subíndices
indice_wide <- grade_trim |>
  left_join(select(comercio_trim_completo,     ano, trimestre, indice_comercio),
            by = c("ano", "trimestre")) |>
  left_join(
    if (nrow(transportes_trim_completo) > 0)
      select(transportes_trim_completo, ano, trimestre, indice_transportes)
    else
      data.frame(ano = integer(), trimestre = integer(), indice_transportes = numeric()),
    by = c("ano", "trimestre")
  ) |>
  left_join(
    if (nrow(financeiro_trim_completo) > 0)
      select(financeiro_trim_completo, ano, trimestre, indice_financeiro)
    else
      data.frame(ano = integer(), trimestre = integer(), indice_financeiro = numeric()),
    by = c("ano", "trimestre")
  ) |>
  left_join(select(imobiliario_trim_completo, ano, trimestre, indice_imobiliario),
            by = c("ano", "trimestre")) |>
  left_join(
    if (nrow(outros_trim_completo) > 0)
      select(outros_trim_completo, ano, trimestre, indice_outros)
    else
      data.frame(ano = integer(), trimestre = integer(), indice_outros = numeric()),
    by = c("ano", "trimestre")
  ) |>
  left_join(
    if (nrow(infocom_trim_completo) > 0)
      select(infocom_trim_completo, ano, trimestre, indice_infocom)
    else
      data.frame(ano = integer(), trimestre = integer(), indice_infocom = numeric()),
    by = c("ano", "trimestre")
  ) |>
  left_join(select(extrativas_trim_completo, ano, trimestre, indice_extrativas),
            by = c("ano", "trimestre"))

# Calcular índice composto ponderado (Laspeyres com pesos VAB 2023)
# Pesos normalizados apenas com o que está disponível em cada trimestre
indice_wide <- indice_wide |>
  rowwise() |>
  mutate(
    indice_servicos = {
      vals <- c(
        indice_comercio,
        indice_transportes,
        indice_financeiro,
        indice_imobiliario,
        indice_outros,
        indice_infocom,
        indice_extrativas
      )
      pesos <- pesos_setoriais  # c(comercio, transportes, financeiro, imobiliario, outros_serv, info_com, extrativas)
      ok    <- !is.na(vals)
      # Exigir que pelo menos um setor de proxy ativa (Comércio, Outros ou InfoCom)
      # tenha dado real — evitar composite baseado só em tendência extrapolada
      proxies_ativas <- c(indice_comercio, indice_outros, indice_infocom)
      tem_dado_ativo <- any(!is.na(proxies_ativas))
      if (any(ok) && tem_dado_ativo) sum(vals[ok] * pesos[ok] / sum(pesos[ok])) else NA_real_
    }
  ) |>
  ungroup()

# Validar número de trimestres completos
n_completos <- sum(!is.na(indice_wide$indice_servicos))
message(sprintf("\nÍndice composto de Serviços — %d trimestres calculados", n_completos))

if (n_completos < 8) {
  warning("Poucos trimestres disponíveis para o índice de serviços. Verificar fontes.")
}

# Mostrar resultado
print(indice_wide |>
        filter(!is.na(indice_servicos)) |>
        select(ano, trimestre, indice_servicos,
               indice_comercio, indice_imobiliario, indice_outros,
               indice_financeiro, indice_transportes))

# Variações anuais
message("\nVariações anuais do índice de serviços (média anual):")
anual_serv <- indice_wide |>
  filter(!is.na(indice_servicos)) |>
  group_by(ano) |>
  summarise(media_anual = mean(indice_servicos), n_trim = n(), .groups = "drop")

for (i in 2:nrow(anual_serv)) {
  var_pct <- (anual_serv$media_anual[i] / anual_serv$media_anual[i - 1] - 1) * 100
  message(sprintf("  %d vs %d: %.1f%%",
                  anual_serv$ano[i], anual_serv$ano[i - 1], var_pct))
}


# ============================================================
# ETAPA 4.16 — EXPORTAR RESULTADO
# Salva indice_servicos.csv em data/output/
# Colunas: ano, trimestre, indice_servicos, + subíndices setoriais
# ============================================================

message("\n=== ETAPA 4.16: Exportando indice_servicos.csv ===\n")

resultado_final <- indice_wide |>
  filter(!is.na(indice_servicos)) |>
  select(
    ano,
    trimestre,
    indice_servicos,
    indice_comercio,
    indice_transportes,
    indice_financeiro,
    indice_imobiliario,
    indice_outros_servicos  = indice_outros,
    indice_infocom,
    indice_extrativas
  )

# Validar série principal
validar_serie(resultado_final$indice_servicos, "indice_servicos",
              variacao_max = 0.60)

write_csv(resultado_final, arq_indice)

message(sprintf("\n✓ Fase 4 concluída — %d obs. salvas em %s",
                nrow(resultado_final), arq_indice))
message(sprintf("  Cobertura: %dT%d – %dT%d",
                min(resultado_final$ano), min(resultado_final$trimestre[resultado_final$ano == min(resultado_final$ano)]),
                max(resultado_final$ano), max(resultado_final$trimestre[resultado_final$ano == max(resultado_final$ano)])))

# ============================================================
# NOTAS FINAIS
# ============================================================

message("
=== NOTAS PARA REVISÃO ===

1. COMÉRCIO (sem ICMS): pesos atuais = energia 67% + CAGED G 33%.
   Ao integrar ICMS por atividade (SEFAZ-RR):
   → pesos = energia 40%, ICMS deflacionado 40%, CAGED G 20%
   → adicionar dummy para quebras tributárias (alterar alíquota)

2. ANAC: verificar cobertura dos dados. Se VRA indisponível para
   algum mês, conferir manualmente no portal ANAC e re-executar.

3. ANP diesel: URL pode mudar anualmente. Se download falhar,
   baixar manualmente em https://www.anp.gov.br/dados-abertos
   e salvar com colunas: ano, mes, diesel_m3

4. BCB Concessões: endpoint OData pode requerer ajuste de filtro
   ou nome de coluna. Se falhar, Financeiro usa apenas Estban.

5. Imobiliário e Extrativas: séries extrapoladas para além de 2023
   usando tendência linear. Atualizar quando CR 2024 for publicado
   (previsão IBGE: out/2026).
")
