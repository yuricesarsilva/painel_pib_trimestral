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
  if (!file.exists(arq_anac_raw)) {
    message("ANAC: baixando Dados_Estatisticos.csv (~353 MB)...")
    ret_anac <- tryCatch(
      request(url_anac_est) |>
        req_timeout(600) |>
        req_error(is_error = function(r) FALSE) |>
        req_perform(),
      error = function(e) {
        message(sprintf("  Erro de rede ANAC: %s", e$message))
        NULL
      }
    )
    if (!is.null(ret_anac) && httr2::resp_status(ret_anac) == 200) {
      writeBin(httr2::resp_body_raw(ret_anac), arq_anac_raw)
      message(sprintf("  ANAC: arquivo salvo (%.1f MB).",
                      file.size(arq_anac_raw) / 1e6))
    } else {
      message(sprintf("  ANAC: HTTP %s — sem dados.",
                      if (is.null(ret_anac)) "?" else httr2::resp_status(ret_anac)))
    }
  } else {
    message("ANAC: arquivo bruto em cache — processando.")
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
  # ANP publica Excel com todas as UFs e anos em arquivo único.
  # URL do Portal de Dados Abertos ANP (verificar atualização anual):
  # https://www.anp.gov.br/dados-abertos (seção "Combustíveis")
  url_anp <- paste0(
    "https://www.anp.gov.br/images/dadosabertos/",
    "venda-derivados-petroleo/VendaDerivadosCombustiveis_m.xlsx"
  )

  tmp_anp <- file.path(dir_anp, "VendaDerivadosCombustiveis_m.xlsx")

  message("ANP: baixando Excel de vendas de combustíveis...")
  ret_anp <- tryCatch(
    request(url_anp) |>
      req_timeout(300) |>
      req_error(is_error = function(r) FALSE) |>
      req_perform(),
    error = function(e) {
      message(sprintf("  Erro de rede ANP: %s", e$message))
      NULL
    }
  )

  anp_mensal <- NULL

  if (!is.null(ret_anp) && httr2::resp_status(ret_anp) == 200) {
    writeBin(httr2::resp_body_raw(ret_anp), tmp_anp)
    message("ANP: arquivo baixado. Lendo Excel...")

    anp_raw <- tryCatch(
      read_excel(tmp_anp, sheet = 1),
      error = function(e) {
        message(sprintf("  Erro leitura ANP Excel: %s", e$message))
        NULL
      }
    )

    if (!is.null(anp_raw)) {
      # Detectar colunas (ANP usa nomes em português, variáveis ao longo do tempo)
      nomes_anp <- toupper(names(anp_raw))
      col_uf    <- grep("^UF$|ESTADO|SIGLA", nomes_anp, value = TRUE)[1]
      col_prod  <- grep("PRODUTO|DERIVADO|COMBUSTIVEL", nomes_anp, value = TRUE)[1]
      col_ano   <- grep("^ANO$|^YEAR$", nomes_anp, value = TRUE)[1]
      col_mes   <- grep("^MES$|^MONTH$|^M[EÊ]S", nomes_anp, value = TRUE)[1]
      col_vol   <- grep("VOLUME|VENDAS|M3|QUANT", nomes_anp, value = TRUE)[1]

      if (!is.na(col_uf) && !is.na(col_prod) && !is.na(col_vol)) {
        names(anp_raw)[match(col_uf,   nomes_anp)] <- "uf"
        names(anp_raw)[match(col_prod, nomes_anp)] <- "produto"
        names(anp_raw)[match(col_vol,  nomes_anp)] <- "volume_m3"
        if (!is.na(col_ano)) names(anp_raw)[match(col_ano, nomes_anp)] <- "ano"
        if (!is.na(col_mes)) names(anp_raw)[match(col_mes, nomes_anp)] <- "mes"

        # Filtrar RR e diesel (óleo diesel total ou diesel S10/S500/B)
        anp_filtrado <- anp_raw |>
          filter(
            toupper(trimws(uf)) == "RR",
            grepl("DIESEL|DIESEL S|ÓL.*DIESEL|OLEO.*DIESEL", toupper(produto))
          )

        if ("ano" %in% names(anp_filtrado) && "mes" %in% names(anp_filtrado)) {
          anp_mensal <- anp_filtrado |>
            mutate(
              ano       = as.integer(ano),
              mes       = as.integer(mes),
              volume_m3 = suppressWarnings(as.numeric(gsub(",", ".", volume_m3)))
            ) |>
            filter(!is.na(ano), !is.na(mes), ano >= ano_inicio) |>
            group_by(ano, mes) |>
            summarise(diesel_m3 = sum(volume_m3, na.rm = TRUE), .groups = "drop") |>
            arrange(ano, mes)

          write_csv(anp_mensal, arq_anp_out)
          message(sprintf("ANP — %d meses de diesel RR salvos.", nrow(anp_mensal)))
        } else {
          message("ANP: colunas ano/mes não detectadas. Inspecionar arquivo manualmente.")
          message("  Colunas disponíveis: ", paste(names(anp_raw), collapse = ", "))
        }
      } else {
        message("ANP: estrutura do Excel não reconhecida. Colunas: ",
                paste(nomes_anp, collapse = ", "))
      }
    }
    unlink(tmp_anp)
  } else {
    message(sprintf("ANP: download falhou (HTTP %s).",
                    if (is.null(ret_anp)) "?" else httr2::resp_status(ret_anp)))
    message("  URL tentada: ", url_anp)
    message("  AÇÃO: baixar manualmente de https://www.anp.gov.br/dados-abertos")
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
# OData: RecursosMensalEstban, CODUF=14, CODVERBETE=160
# Verbete 160 = Depósitos totais (saldos)
# Tipo: estoque (valor nominal) | Qualidade: fraca mas necessária
# ============================================================

message("\n=== ETAPA 4.6: BCB Estban — depósitos RR ===\n")

if (file.exists(arq_estban_out)) {
  message("Estban: cache local encontrado.")
  estban_mensal <- read_csv(arq_estban_out, show_col_types = FALSE)
} else {
  message("Estban: consultando OData BCB...")

  url_estban_base <- paste0(
    "https://olinda.bcb.gov.br/olinda/servico/Estban/versao/v1/odata/",
    "RecursosMensalEstban"
  )

  estban_paginas <- list()
  top    <- 500L
  skip   <- 0L
  total  <- Inf

  while (skip < total) {
    resp_est <- tryCatch(
      request(url_estban_base) |>
        req_url_query(
          `$filter`  = "CODUF eq '14' and CODVERBETE eq '160'",
          `$select`  = "ANOMES,SALDO",
          `$top`     = top,
          `$skip`    = skip,
          `$count`   = "true",
          `$format`  = "json"
        ) |>
        req_timeout(60) |>
        req_perform(),
      error = function(e) {
        message(sprintf("  Estban erro (skip=%d): %s", skip, e$message))
        NULL
      }
    )
    if (is.null(resp_est)) break

    dados_est <- fromJSON(resp_body_string(resp_est))
    if (is.null(dados_est$value) || length(dados_est$value) == 0) break

    if (is.infinite(total) && !is.null(dados_est$`@odata.count`))
      total <- as.integer(dados_est$`@odata.count`)

    est_bloco <- as.data.frame(dados_est$value)
    estban_paginas <- c(estban_paginas, list(est_bloco))
    message(sprintf("  Estban: %d/%s registros", min(skip + nrow(est_bloco), total), total))

    if (nrow(est_bloco) < top) break
    skip <- skip + top
  }

  if (length(estban_paginas) > 0) {
    estban_raw <- bind_rows(estban_paginas) |>
      mutate(
        ano   = as.integer(substr(as.character(ANOMES), 1, 4)),
        mes   = as.integer(substr(as.character(ANOMES), 5, 6)),
        saldo = as.numeric(gsub(",", ".", as.character(SALDO)))
      ) |>
      filter(!is.na(ano), !is.na(mes)) |>
      group_by(ano, mes) |>
      summarise(depositos = sum(saldo, na.rm = TRUE), .groups = "drop") |>
      arrange(ano, mes)

    write_csv(estban_raw, arq_estban_out)
    estban_mensal <- estban_raw
    message(sprintf("Estban — %d obs. salvas.", nrow(estban_mensal)))
  } else {
    warning("Estban: nenhum dado coletado. Financeiro usará apenas concessões (ou será excluído).")
    estban_mensal <- data.frame(ano = integer(), mes = integer(), depositos = numeric())
  }
}

if (nrow(estban_mensal) > 0) {
  estban_mensal <- estban_mensal |> filter(ano >= ano_inicio)
  message(sprintf("Estban — %d obs. (%.0f–%.0f)",
                  nrow(estban_mensal),
                  min(estban_mensal$ano), max(estban_mensal$ano)))
}


# ============================================================
# ETAPA 4.7 — BCB: concessões de crédito por UF (Roraima)
# OData NotaCredito — CreditoConcedidoUFDestinatarioRecurso
# UF = 14 (Roraima). Fluxo mensal de novos créditos concedidos.
# Tipo: fluxo (valor nominal) | Qualidade: aceitável
# ============================================================

message("\n=== ETAPA 4.7: BCB — concessões de crédito (RR) ===\n")

bcb_concessoes_ok <- FALSE

if (file.exists(arq_concessoes_out)) {
  message("Concessões BCB: cache local encontrado.")
  concessoes_mensal <- read_csv(arq_concessoes_out, show_col_types = FALSE)
  bcb_concessoes_ok <- nrow(concessoes_mensal) > 0
} else {
  message("Concessões BCB: consultando OData...")

  url_nota_base <- paste0(
    "https://olinda.bcb.gov.br/olinda/servico/NotaCredito/versao/v1/odata/",
    "CreditoConcedidoUFDestinatarioRecurso"
  )

  conc_paginas <- list()
  top_c  <- 500L
  skip_c <- 0L
  total_c <- Inf

  while (skip_c < total_c) {
    resp_c <- tryCatch(
      request(url_nota_base) |>
        req_url_query(
          `$filter`  = "codUF eq '14'",
          `$select`  = "dataBase,concessoes",
          `$top`     = top_c,
          `$skip`    = skip_c,
          `$count`   = "true",
          `$format`  = "json"
        ) |>
        req_timeout(60) |>
        req_error(is_error = function(r) FALSE) |>
        req_perform(),
      error = function(e) {
        message(sprintf("  Concessões BCB erro: %s", e$message))
        NULL
      }
    )
    if (is.null(resp_c)) break
    if (httr2::resp_status(resp_c) != 200) {
      message(sprintf("  Concessões BCB: HTTP %d. Endpoint pode ter nome diferente.",
                      httr2::resp_status(resp_c)))
      break
    }

    dados_c <- tryCatch(fromJSON(resp_body_string(resp_c)), error = function(e) NULL)
    if (is.null(dados_c) || is.null(dados_c$value) || length(dados_c$value) == 0) break

    if (is.infinite(total_c) && !is.null(dados_c$`@odata.count`))
      total_c <- as.integer(dados_c$`@odata.count`)

    bloco_c <- as.data.frame(dados_c$value)
    conc_paginas <- c(conc_paginas, list(bloco_c))
    message(sprintf("  Concessões: %d/%s registros",
                    min(skip_c + nrow(bloco_c), total_c), total_c))

    if (nrow(bloco_c) < top_c) break
    skip_c <- skip_c + top_c
  }

  if (length(conc_paginas) > 0) {
    concessoes_raw <- bind_rows(conc_paginas)

    # Detectar colunas de data e valor
    nomes_c   <- names(concessoes_raw)
    col_data  <- grep("data|date|periodo|mes|anomes", tolower(nomes_c), value = TRUE)[1]
    col_valor <- grep("concess|valor|amount|credito", tolower(nomes_c), value = TRUE)[1]

    if (!is.na(col_data) && !is.na(col_valor)) {
      data_raw_c <- as.character(concessoes_raw[[col_data]])
      # Formato pode ser YYYY-MM-DD, YYYYMM, ou YYYY-MM
      ano_c <- as.integer(substr(gsub("[^0-9]", "", data_raw_c), 1, 4))
      mes_c <- as.integer(substr(gsub("[^0-9]", "", data_raw_c), 5, 6))

      concessoes_mensal <- data.frame(
        ano         = ano_c,
        mes         = mes_c,
        concessoes  = suppressWarnings(as.numeric(
          gsub(",", ".", as.character(concessoes_raw[[col_valor]]))))
      ) |>
        filter(!is.na(ano), !is.na(mes), !is.na(concessoes)) |>
        group_by(ano, mes) |>
        summarise(concessoes = sum(concessoes, na.rm = TRUE), .groups = "drop") |>
        arrange(ano, mes)

      write_csv(concessoes_mensal, arq_concessoes_out)
      bcb_concessoes_ok <- TRUE
      message(sprintf("Concessões BCB — %d obs. salvas.", nrow(concessoes_mensal)))
    } else {
      message("  Concessões BCB: colunas não identificadas.")
      message("  Colunas disponíveis: ", paste(nomes_c, collapse = ", "))
      concessoes_mensal <- data.frame(ano = integer(), mes = integer(), concessoes = numeric())
    }
  } else {
    message("Concessões BCB: dados não obtidos via OData.")
    message("  Alternativa: Financeiro usará apenas depósitos BCB Estban.")
    concessoes_mensal <- data.frame(ano = integer(), mes = integer(), concessoes = numeric())
  }
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
