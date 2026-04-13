# ============================================================
# Projeto : Indicador de Atividade Econômica Trimestral — RR
# Script  : 02_adm_publica.R
# Autor   : Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)
# Data    : 2026-04-10
# Descrição: Índice trimestral de Administração Pública de RR.
#   Etapa 2.1 — Folha federal (SIAPE): INDISPONÍVEL via API.
#               O endpoint /remuneracao-servidores-ativos do Portal da
#               Transparência retorna HTTP 403 para o cadastro padrão.
#               O componente federal é implicitamente incluído via
#               Denton-Cholette (benchmark IBGE já engloba federal).
#   Etapa 2.2 — Folha estadual (elemento 31 — pessoal ativo):
#               SICONFI/STN — RREO Anexo 06, governo do estado de RR.
#   Etapa 2.3 — Folha municipal: SICONFI/STN — RREO Anexo 06,
#               todos os 15 municípios de RR, elemento pessoal.
#   Etapa 2.4 — Série de volume, Denton-Cholette e validação.
# Entrada : API SICONFI/STN (pública, sem autenticação)
#            data/processed/contas_regionais_RR_serie.csv
# Saída   : data/raw/folha_estadual_rr_mensal.csv
#            data/raw/folha_municipal_rr.csv
#            data/output/indice_adm_publica.csv
# Depende : httr2, jsonlite, dplyr, tidyr, lubridate, tempdisagg
#            R/utils.R
# Nota    : RREO Anexo 06 é bimestral (acumulado). Diferença entre
#           bimestres fornece o valor incremental por bimestre.
#           Bimestres são convertidos para trimestres por agregação.
#           Elemento 31 (Pessoal Ativo) alinhado com metodologia
#           do IBGE para cálculo do VAB de AAPP.
# ============================================================

source("R/utils.R")

library(httr2)
library(jsonlite)
library(dplyr)
library(tidyr)
library(lubridate)
library(data.table)

# --- Caminhos -----------------------------------------------

dir_raw       <- file.path("data", "raw")
dir_processed <- file.path("data", "processed")
dir_output    <- file.path("data", "output")

dir.create(dir_raw,       recursive = TRUE, showWarnings = FALSE)
dir.create(dir_processed, recursive = TRUE, showWarnings = FALSE)
dir.create(dir_output,    recursive = TRUE, showWarnings = FALSE)

arq_siape     <- file.path(dir_raw, "siape_rr_mensal.csv")
arq_estadual  <- file.path(dir_raw, "folha_estadual_rr_mensal.csv")
arq_municipal <- file.path(dir_raw, "folha_municipal_rr.csv")
arq_ipca      <- file.path(dir_raw, "ipca_mensal.csv")
arq_indice    <- file.path(dir_output, "indice_adm_publica.csv")
arq_cr_serie  <- file.path(dir_processed, "contas_regionais_RR_serie.csv")

# --- Parâmetros ---------------------------------------------

# Período de interesse (a partir de 2020 — início do CAGED novo)
ano_inicio  <- 2020L
ano_atual   <- as.integer(format(Sys.Date(), "%Y"))
anos_serie  <- ano_inicio:ano_atual

# SICONFI: id_ente estado de RR = 14 (código IBGE UF)
ID_ENTE_RR_ESTADO <- 14L

# SICONFI: cod_ibge dos 15 municípios de RR
municipios_rr <- c(
  "Amajari"             = 1400027L,
  "Alto Alegre"         = 1400050L,
  "Boa Vista"           = 1400100L,
  "Bonfim"              = 1400159L,
  "Cantá"               = 1400175L,
  "Caracaraí"           = 1400209L,
  "Caroebe"             = 1400233L,
  "Iracema"             = 1400282L,
  "Mucajaí"             = 1400308L,
  "Normandia"           = 1400407L,
  "Pacaraima"           = 1400456L,
  "Rorainópolis"        = 1400472L,
  "São João da Baliza"  = 1400506L,
  "São Luiz"            = 1400605L,
  "Uiramutã"            = 1400704L
)

anos_peso <- 2018:2022

# --- Funções auxiliares -------------------------------------

# Ler .env sem dependência do pacote dotenv
carregar_env <- function(caminho = ".env") {
  if (!file.exists(caminho)) return(invisible(NULL))
  lines <- readLines(caminho, warn = FALSE)
  for (l in lines) {
    l <- trimws(l)
    if (nchar(l) == 0 || startsWith(l, "#")) next
    if (grepl("^[A-Za-z_][A-Za-z0-9_]*=", l)) {
      partes <- strsplit(l, "=", fixed = TRUE)[[1]]
      do.call(Sys.setenv, setNames(list(paste(partes[-1], collapse = "=")), partes[1]))
    }
  }
}

# Chamada genérica à API SICONFI com retry simples
siconfi_get <- function(...) {
  r <- request("https://apidatalake.tesouro.gov.br/ords/siconfi/tt/rreo") |>
    req_url_query(...) |>
    req_retry(max_tries = 3, backoff = ~ 5) |>
    req_error(is_error = function(resp) FALSE) |>
    req_perform()

  if (resp_status(r) != 200) {
    warning(sprintf("SICONFI retornou status %d para params: %s",
                    resp_status(r), paste(list(...), collapse = ",")))
    return(NULL)
  }
  b <- resp_body_json(r)
  if (length(b$items) == 0) return(NULL)

  do.call(rbind, lapply(b$items, function(x)
    as.data.frame(lapply(x, function(v) if (is.null(v)) NA else v),
                  stringsAsFactors = FALSE)
  ))
}

# Extrair "Pessoal e Encargos Sociais" liquidado acumulado de um data.frame RREO A06
extrair_pessoal <- function(df) {
  if (is.null(df)) return(NULL)
  df |>
    filter(cod_conta == "RREO6PessoalEEncargosSociais",
           grepl("LIQUIDAD", coluna, ignore.case = TRUE),
           !grepl("INTRA|RESTOS|PAGOS|PROCESSAD", coluna, ignore.case = TRUE)) |>
    slice(1) |>   # pegar apenas "DESPESAS LIQUIDADAS" (acumulado bimestral)
    pull(valor)
}

# Converter bimestres acumulados → valor incremental por bimestre
# Entrada: data.frame com colunas ano, bimestre, valor_acum
acumulado_para_incremental <- function(df) {
  df |>
    arrange(ano, bimestre) |>
    group_by(ano) |>
    mutate(valor_bim = valor_acum - lag(valor_acum, default = 0)) |>
    ungroup()
}

# Converter bimestres (1–6) → trimestres (1–4)
# Bimestre 1 (jan-fev) → Q1 (parcial); Bim 2 (mar-abr) → Q1+Q2; etc.
# Mapeamento: jan-fev (bim1), mar-abr (bim2), mai-jun (bim3),
#             jul-ago (bim4), set-out (bim5), nov-dez (bim6)
# Trimestres: Q1=jan-mar, Q2=abr-jun, Q3=jul-set, Q4=out-dez
# Como cada bimestre cruza trimestres, dividimos igualmente os 2 meses:
bimestral_para_trimestral <- function(df) {
  # Distribuir cada bimestre por meses (2 meses por bimestre), depois agregar por trim
  df |>
    rowwise() |>
    mutate(
      mes_inicio = (bimestre - 1) * 2 + 1,
      mes_fim    = bimestre * 2,
      valor_mes  = valor_bim / 2   # distribuição uniforme intra-bimestre
    ) |>
    ungroup() |>
    # Expandir: uma linha por mês
    rowwise() |>
    mutate(mes = list(mes_inicio:mes_fim)) |>
    unnest(mes) |>
    mutate(trimestre = ceiling(mes / 3L)) |>
    group_by(ano, trimestre) |>
    summarise(valor_trim = sum(valor_mes, na.rm = TRUE), .groups = "drop")
}

# ============================================================
# ETAPA 2.1 — Folha Federal (SIAPE — arquivos manuais do Portal da Transparência)
# ============================================================
#
# Estratégia de identificação de UF (critério OR — qualquer indicativo vale):
#   1. UF_EXERCICIO == "RR"   (quando preenchido — nem sempre disponível)
#   2. grepl("RORAIMA", ORG_LOTACAO | UORG_LOTACAO) após normalização de acentos
#      (iconv Latin-1 → ASCII//TRANSLIT) — cobre UFRR, IFRR, órgãos federais
#      em RR e servidores do Ex-Território Federal de Roraima.
#   As duas estratégias se complementam: meses com UF_EXERCICIO preenchido
#   ganham cobertura extra; meses com -1 dependem dos nomes de órgão.
#
# Resultado: ~6.100+ servidores/mês identificados em RR (jan/2020).
# "Governo do Ex-Território Federal de Roraima" (≈3.400 obs.) = ATIVO PERMANENTE.
#
# Colunas do cache salvo (arq_siape):
#   ano, mes, n_servidores, folha_bruta  (folha_bruta em R$)
# ============================================================

message("\n=== ETAPA 2.1: Folha Federal (SIAPE) — arquivos manuais ===\n")

dir_siape_bulk <- file.path("bases_baixadas_manualmente",
                            "dados_siape_portal_transparencia")

if (file.exists(arq_siape)) {
  message("SIAPE: cache encontrado — reutilizando (", arq_siape, ").")
  folha_federal <- read.csv(arq_siape, stringsAsFactors = FALSE)
  message(sprintf("  %d meses carregados (%dM01–%dM%02d)",
                  nrow(folha_federal),
                  min(folha_federal$ano), max(folha_federal$ano),
                  max(folha_federal$mes[folha_federal$ano == max(folha_federal$ano)])))

} else if (dir.exists(dir_siape_bulk)) {

  zips <- sort(list.files(dir_siape_bulk, pattern = "\\.zip$",
                           full.names = TRUE, ignore.case = TRUE))
  message(sprintf("SIAPE: processando %d ZIPs de %s ...", length(zips), dir_siape_bulk))
  message("  Critério RR (OR): UF_EXERCICIO=='RR'  OU  'RORAIMA' em ORG/UORG_LOTACAO")
  message("  (UF_EXERCICIO pode ser -1 em alguns meses — as duas estratégias se complementam)")

  tmp_dir  <- tempdir()
  norm_col <- function(x) toupper(iconv(x, from = "latin1", to = "ASCII//TRANSLIT"))
  resultados <- vector("list", length(zips))
  idx_res  <- 0L

  for (zip_path in zips) {
    zip_nome <- basename(zip_path)
    aaaamm   <- regmatches(zip_nome, regexpr("^[0-9]{6}", zip_nome))
    if (length(aaaamm) == 0) next

    ano_zip <- as.integer(substr(aaaamm, 1, 4))
    mes_zip  <- as.integer(substr(aaaamm, 5, 6))
    if (ano_zip < ano_inicio) next

    # Listar arquivos internos
    arqs_zip <- tryCatch(unzip(zip_path, list = TRUE)$Name, error = function(e) character(0))
    if (length(arqs_zip) == 0) {
      message(sprintf("  %s: ZIP vazio ou corrompido — ignorado.", zip_nome)); next
    }
    arq_cad <- arqs_zip[grepl("Cadastro", arqs_zip, ignore.case = TRUE)][1]
    arq_rem <- arqs_zip[grepl("Remuner",  arqs_zip, ignore.case = TRUE)][1]
    if (is.na(arq_cad) || is.na(arq_rem)) {
      message(sprintf("  %s: Cadastro ou Remuneracao ausente — ignorado.", zip_nome)); next
    }

    # --- Cadastro: filtrar servidores em RR -----------------
    tryCatch(unzip(zip_path, files = arq_cad, exdir = tmp_dir, overwrite = TRUE),
             error = function(e) NULL)
    cad_path <- file.path(tmp_dir, arq_cad)

    cad <- tryCatch(
      data.table::fread(cad_path, sep = ";", encoding = "Latin-1",
                        select = c("Id_SERVIDOR_PORTAL", "UF_EXERCICIO",
                                   "ORG_LOTACAO", "UORG_LOTACAO"),
                        showProgress = FALSE, data.table = TRUE),
      error = function(e) {
        message(sprintf("  %s: erro no Cadastro — %s", zip_nome, e$message)); NULL
      }
    )
    unlink(cad_path)
    if (is.null(cad) || nrow(cad) == 0) next

    # Critério combinado (OR): qualquer indicativo de RR é válido
    cad[, `:=`(org_norm  = norm_col(ORG_LOTACAO),
               uorg_norm = norm_col(UORG_LOTACAO),
               uf_e_rr   = trimws(toupper(as.character(UF_EXERCICIO))) == "RR")]
    cad_rr <- cad[uf_e_rr == TRUE |
                  grepl("RORAIMA", org_norm,  fixed = TRUE) |
                  grepl("RORAIMA", uorg_norm, fixed = TRUE)]

    # Diagnóstico por critério (para acompanhamento da qualidade)
    n_uf  <- cad[uf_e_rr == TRUE, .N]
    n_org <- cad[(grepl("RORAIMA", org_norm, fixed = TRUE) |
                  grepl("RORAIMA", uorg_norm, fixed = TRUE)), .N]
    message(sprintf("  %s: %d servidores RR  [UF_EXERCICIO=%d | ORG/UORG=%d | único=%d]",
                    aaaamm, nrow(cad_rr), n_uf, n_org, nrow(cad_rr)))

    if (nrow(cad_rr) < 50)
      message(sprintf("  AVISO %s: total muito baixo (%d) — verificar base.",
                      zip_nome, nrow(cad_rr)))

    ids_rr <- unique(cad_rr$Id_SERVIDOR_PORTAL)
    rm(cad, cad_rr); gc(verbose = FALSE)   # liberar memória do Cadastro (~40MB)

    # --- Remuneracao: ler 2 colunas por posição → filtrar RR ----------------
    # Estrutura padrão SIAPE Remuneracao (Portal da Transparência):
    #   col 1=ANO, 2=MES, 3=Id_SERVIDOR_PORTAL, 4=CPF, 5=NOME,
    #   col 6=REMUNERAÇÃO BÁSICA BRUTA (R$)  ← o que queremos
    # Usamos posições inteiras para evitar problemas de encoding no Windows
    # (fread com nrows=0 pode retornar nomes incorretos em alguns ambientes).
    tryCatch(unzip(zip_path, files = arq_rem, exdir = tmp_dir, overwrite = TRUE),
             error = function(e) NULL)
    rem_path <- file.path(tmp_dir, arq_rem)
    if (!file.exists(rem_path)) next

    # Validar posições lendo 1 linha (barato: < 1 KB)
    rem1 <- tryCatch(
      data.table::fread(rem_path, sep = ";", encoding = "Latin-1",
                        nrows = 1L, showProgress = FALSE, data.table = FALSE),
      error = function(e) NULL
    )
    if (is.null(rem1) || ncol(rem1) < 6) { unlink(rem_path); next }

    nomes <- names(rem1)
    # Buscar por substring sem acento (robusto em qualquer plataforma)
    pos_id    <- which(grepl("SERVIDOR_PORTAL", nomes, ignore.case = TRUE))[1]
    pos_bruta <- which(grepl("BRUTA", nomes, ignore.case = TRUE) &
                       grepl("R\\$",  nomes, fixed = TRUE) &
                       !grepl("U\\$", nomes, fixed = TRUE))[1]
    # Fallback para posições fixas do padrão SIAPE
    if (is.na(pos_id))    pos_id    <- 3L
    if (is.na(pos_bruta)) pos_bruta <- 6L

    # Ler apenas as 2 colunas necessárias (~10 MB vs ~171 MB)
    rem <- tryCatch(
      data.table::fread(rem_path, sep = ";", encoding = "Latin-1",
                        select = c(pos_id, pos_bruta),
                        showProgress = FALSE, data.table = TRUE),
      error = function(e) {
        message(sprintf("  %s: erro na Remuneracao — %s", zip_nome, e$message)); NULL
      }
    )
    unlink(rem_path)
    if (is.null(rem) || nrow(rem) == 0) next

    # Renomear para nomes simples (sem acento, sem espaço)
    data.table::setnames(rem, c("id_portal", "sal_bruto"))

    rem_rr <- rem[id_portal %in% ids_rr]
    rm(rem); gc(verbose = FALSE)
    if (nrow(rem_rr) == 0) {
      message(sprintf("  %s: 0 servidores RR na Remuneracao.", zip_nome)); next
    }

    # Converter formato BR ("14.249,03") → numérico R$
    vals <- suppressWarnings(
      as.numeric(gsub(",", ".", gsub("\\.", "", as.character(rem_rr$sal_bruto))))
    )
    folha_rr <- sum(vals, na.rm = TRUE)

    idx_res <- idx_res + 1L
    resultados[[idx_res]] <- data.frame(
      ano          = ano_zip,
      mes          = mes_zip,
      n_servidores = nrow(rem_rr),
      folha_bruta  = folha_rr,
      stringsAsFactors = FALSE
    )
    message(sprintf("  %s: %d servidores RR — R$ %.1f mi",
                    aaaamm, nrow(rem_rr), folha_rr / 1e6))
    rm(rem_rr, vals); gc(verbose = FALSE)
  }

  if (idx_res > 0) {
    folha_federal <- do.call(rbind, resultados[seq_len(idx_res)]) |>
      dplyr::arrange(ano, mes)
    write.csv(folha_federal, arq_siape, row.names = FALSE)
    message(sprintf("\nSIAPE: %d meses processados — cache salvo em %s",
                    nrow(folha_federal), arq_siape))
  } else {
    message("SIAPE: nenhum resultado. Folha federal = NULL.")
    folha_federal <- NULL
  }

} else {
  message(sprintf("SIAPE: pasta %s não encontrada.", dir_siape_bulk))
  message("  Índice calculado com estado + municípios; Denton ancora ao total IBGE (inclui federal).")
  folha_federal <- NULL
}

# ============================================================
# ETAPA 2.2 — Folha Estadual (SICONFI — RREO Anexo 06)
# ============================================================

message("\n=== ETAPA 2.2: Folha Estadual — SICONFI/STN ===\n")

if (!file.exists(arq_estadual)) {
  message("Coletando RREO Anexo 06 para o Estado de RR (id_ente=14)...")

  folha_est_lista <- list()

  for (ano in anos_serie) {
    for (bim in 1:6) {
      df_bim <- siconfi_get(
        an_exercicio          = ano,
        nr_periodo            = bim,
        co_tipo_demonstrativo = "RREO",
        no_anexo              = "RREO-Anexo 06",
        co_esfera             = "E",
        co_uf                 = "RR",
        id_ente               = ID_ENTE_RR_ESTADO
      )

      val <- extrair_pessoal(df_bim)
      if (length(val) > 0 && !is.na(val)) {
        folha_est_lista[[length(folha_est_lista) + 1]] <- data.frame(
          ano        = ano,
          bimestre   = bim,
          valor_acum = as.numeric(val),
          stringsAsFactors = FALSE
        )
        log_msg(sprintf("Estado RR — %d bim%d: R$ %.0f mi", ano, bim, as.numeric(val)/1e6))
      } else {
        message(sprintf("  Estado RR — %d bim%d: sem dado", ano, bim))
      }
      Sys.sleep(0.2)   # respeitar rate limit SICONFI
    }
  }

  folha_estadual_acum <- do.call(rbind, folha_est_lista)

  if (nrow(folha_estadual_acum) > 0) {
    # Converter acumulado → incremental → trimestral
    folha_estadual_bim <- acumulado_para_incremental(folha_estadual_acum)
    write.csv(folha_estadual_bim, arq_estadual, row.names = FALSE)
    message(sprintf("Folha estadual salva: %s (%d bimestres)", arq_estadual, nrow(folha_estadual_bim)))
  } else {
    message("AVISO: nenhum dado da folha estadual obtido do SICONFI.")
    folha_estadual_bim <- NULL
  }
} else {
  message("Folha estadual: usando cache (", arq_estadual, ")")
  folha_estadual_bim <- read.csv(arq_estadual, stringsAsFactors = FALSE)
}

# ============================================================
# ETAPA 2.3 — Folha Municipal (SICONFI — RREO Anexo 06)
# ============================================================

message("\n=== ETAPA 2.3: Folha Municipal — SICONFI/STN (15 municípios de RR) ===\n")

if (!file.exists(arq_municipal)) {
  message("Coletando RREO Anexo 06 para os 15 municípios de RR...")

  folha_mun_lista <- list()

  for (nm_mun in names(municipios_rr)) {
    cod_ibge_mun <- municipios_rr[[nm_mun]]
    mun_acum <- list()

    for (ano in anos_serie) {
      for (bim in 1:6) {
        df_bim <- siconfi_get(
          an_exercicio          = ano,
          nr_periodo            = bim,
          co_tipo_demonstrativo = "RREO",
          no_anexo              = "RREO-Anexo 06",
          co_esfera             = "M",
          id_ente               = cod_ibge_mun
        )

        val <- extrair_pessoal(df_bim)
        if (length(val) > 0 && !is.na(val)) {
          mun_acum[[length(mun_acum) + 1]] <- data.frame(
            municipio  = nm_mun,
            cod_ibge   = cod_ibge_mun,
            ano        = ano,
            bimestre   = bim,
            valor_acum = as.numeric(val),
            stringsAsFactors = FALSE
          )
        }
        Sys.sleep(0.2)
      }
    }

    n_bim <- length(mun_acum)
    if (n_bim > 0) {
      folha_mun_lista <- c(folha_mun_lista, mun_acum)
      message(sprintf("  %-22s: %d bimestres coletados", nm_mun, n_bim))
    } else {
      message(sprintf("  %-22s: sem dados no SICONFI", nm_mun))
    }
  }

  if (length(folha_mun_lista) > 0) {
    folha_mun_acum <- do.call(rbind, folha_mun_lista)
    # Converter acumulado → incremental por município, depois somar
    folha_mun_bim <- folha_mun_acum |>
      group_by(municipio, cod_ibge) |>
      group_modify(~ acumulado_para_incremental(.x)) |>
      ungroup()
    write.csv(folha_mun_bim, arq_municipal, row.names = FALSE)
    message(sprintf("Folha municipal salva: %s", arq_municipal))
  } else {
    message("AVISO: nenhum dado municipal obtido do SICONFI.")
    folha_mun_bim <- NULL
  }
} else {
  message("Folha municipal: usando cache (", arq_municipal, ")")
  folha_mun_bim <- read.csv(arq_municipal, stringsAsFactors = FALSE)
}

# ============================================================
# ETAPA 2.4 — Série de volume + Denton-Cholette
# ============================================================

message("\n=== ETAPA 2.4: Série de volume e benchmarking ===\n")

# --- Verificar disponibilidade dos componentes --------------

if (is.null(folha_estadual_bim) || nrow(folha_estadual_bim) == 0) {
  stop("Folha estadual indisponível — não é possível calcular o índice de AAPP.")
}

# Componente estadual (principal): bimestral → trimestral
folha_est_trim <- bimestral_para_trimestral(folha_estadual_bim) |>
  rename(estadual = valor_trim)

# Componente municipal: agregar municípios, depois bimestral → trimestral
if (!is.null(folha_mun_bim) && nrow(folha_mun_bim) > 0) {
  folha_mun_total_bim <- folha_mun_bim |>
    group_by(ano, bimestre) |>
    summarise(valor_bim = sum(valor_bim, na.rm = TRUE), .groups = "drop")

  folha_mun_trim <- bimestral_para_trimestral(
    folha_mun_total_bim |> mutate(valor_acum = cumsum(valor_bim))
    # Já está incremental, bimestral_para_trimestral espera valor_bim
  ) |> rename(municipal = valor_trim)
} else {
  message("Componente municipal indisponível — usando zero (apenas estadual + federal).")
  folha_mun_trim <- data.frame(ano = integer(), trimestre = integer(), municipal = numeric())
}

# Componente federal: mensal → trimestral (se disponível)
# folha_federal: colunas ano, mes, n_servidores, folha_bruta (R$)
if (!is.null(folha_federal) && nrow(folha_federal) > 0) {
  folha_fed_trim <- folha_federal |>
    filter(!is.na(folha_bruta)) |>
    mutate(trimestre = ceiling(mes / 3L)) |>
    group_by(ano, trimestre) |>
    summarise(federal = sum(folha_bruta, na.rm = TRUE), .groups = "drop")
  message(sprintf("Componente federal (SIAPE): %d trimestres disponíveis.", nrow(folha_fed_trim)))
} else {
  message("Componente federal (SIAPE) indisponível — índice baseado em estadual + municipal.")
  folha_fed_trim <- data.frame(ano = integer(), trimestre = integer(), federal = numeric())
}

# --- Combinar todos os componentes --------------------------

folha_total <- folha_est_trim |>
  full_join(folha_mun_trim, by = c("ano", "trimestre")) |>
  full_join(folha_fed_trim, by = c("ano", "trimestre")) |>
  mutate(
    estadual  = replace_na(estadual,  0),
    municipal = replace_na(municipal, 0),
    federal   = replace_na(federal,   0),
    folha_total = estadual + municipal + federal
  ) |>
  filter(ano >= ano_inicio, folha_total > 0) |>
  arrange(ano, trimestre)

cat(sprintf("Componentes da folha — cobertura: %dT%d a %dT%d\n\n",
            min(folha_total$ano), min(folha_total$trimestre[folha_total$ano==min(folha_total$ano)]),
            max(folha_total$ano), max(folha_total$trimestre[folha_total$ano==max(folha_total$ano)])))

# Diagnóstico da composição
for (i in seq_len(nrow(folha_total))) {
  r <- folha_total[i, ]
  cat(sprintf("  %dT%d  estadual=%6.0fmi  municipal=%5.0fmi  federal=%6.0fmi  total=%6.0fmi\n",
              r$ano, r$trimestre,
              r$estadual/1e6, r$municipal/1e6, r$federal/1e6, r$folha_total/1e6))
}

# --- Deflacionar pelo IPCA nacional -------------------------
# Baixar IPCA via SIDRA (tabela 1737, variação mensal)

if (!file.exists(arq_ipca)) {
  message("\nBaixando IPCA mensal via SIDRA (tab 1737)...")
  ipca_raw <- sidrar::get_sidra(api = "/t/1737/n1/all/v/2266/p/all/d/v2266%2013")
  write.csv(ipca_raw, arq_ipca, row.names = FALSE)
  message("IPCA salvo.")
} else {
  message("\nIPCA: usando cache.")
  ipca_raw <- read.csv(arq_ipca, check.names = FALSE, stringsAsFactors = FALSE)
}

col_val_ipca  <- names(ipca_raw)[grepl("^Valor$", names(ipca_raw))][1]
# "Mês (Código)" = "YYYYMM" (e.g. "202001"); "Mês" = text (e.g. "janeiro 2020")
col_mes_cod   <- names(ipca_raw)[grepl("Mês \\(Código\\)", names(ipca_raw))][1]
col_mes_texto <- names(ipca_raw)[grepl("^Mês$|^Mês e Ano$", names(ipca_raw))][1]

parse_ipca_periodo <- function(cod_vec, txt_vec) {
  # Prefer YYYYMM code column (no ambiguity); fallback to text
  use_cod <- !is.na(cod_vec) & grepl("^[0-9]{6}$", cod_vec)
  ano <- ifelse(use_cod,
                as.integer(substr(cod_vec, 1, 4)),
                suppressWarnings(as.integer(
                  vapply(txt_vec, function(s) {
                    m <- regexpr("[12][0-9]{3}", s); if (m < 0) NA_character_ else regmatches(s, m)
                  }, character(1))
                )))
  mes <- ifelse(use_cod,
                as.integer(substr(cod_vec, 5, 6)),
                NA_integer_)
  list(ano = ano, mes = mes)
}

ipca_cols <- list(
  cod = if (!is.na(col_mes_cod))   as.character(ipca_raw[[col_mes_cod]])   else rep(NA_character_, nrow(ipca_raw)),
  txt = if (!is.na(col_mes_texto)) as.character(ipca_raw[[col_mes_texto]]) else rep(NA_character_, nrow(ipca_raw)),
  val = suppressWarnings(as.numeric(gsub(",", ".", ipca_raw[[col_val_ipca]])))
)
parsed <- parse_ipca_periodo(ipca_cols$cod, ipca_cols$txt)

ipca <- data.frame(
  ano     = parsed$ano,
  mes     = parsed$mes,
  var_pct = ipca_cols$val,
  stringsAsFactors = FALSE
) |>
  filter(!is.na(var_pct), !is.na(ano), !is.na(mes)) |>
  arrange(ano, mes)

# Índice de preços encadeado, base jan/2020 = 1
idx_jan2020 <- which(ipca$ano == 2020 & ipca$mes == 1)
if (length(idx_jan2020) == 0) stop("IPCA: janeiro de 2020 não encontrado na série.")
ipca <- ipca |>
  mutate(
    fator     = 1 + var_pct / 100,
    idx_preco = cumprod(fator),
    idx_preco = idx_preco / idx_preco[idx_jan2020]
  )

# Deflator trimestral: média dos 3 meses
deflator_trim <- ipca |>
  filter(ano >= ano_inicio) |>
  mutate(trimestre = ceiling(mes / 3L)) |>
  group_by(ano, trimestre) |>
  summarise(deflator = mean(idx_preco, na.rm = TRUE), .groups = "drop")

folha_real <- folha_total |>
  left_join(deflator_trim, by = c("ano", "trimestre")) |>
  mutate(
    folha_real = if_else(!is.na(deflator) & deflator > 0,
                         folha_total / deflator,
                         folha_total)   # sem deflação se IPCA não disponível para o período
  ) |>
  select(ano, trimestre, estadual, municipal, federal, folha_total, deflator, folha_real)

# --- Índice de volume (base 2020 = 100) ---------------------

base_2020 <- mean(folha_real$folha_real[folha_real$ano == 2020], na.rm = TRUE)
if (is.na(base_2020) || base_2020 == 0) {
  stop("Sem dados de folha em 2020 — impossível normalizar o índice.")
}

folha_real <- folha_real |>
  mutate(indice_aapp_raw = folha_real / base_2020 * 100)

# --- Denton-Cholette contra VAB AAPP anual ------------------

cr_serie <- read.csv(arq_cr_serie, stringsAsFactors = FALSE)
vab_aapp <- cr_serie |>
  filter(atividade == "Adm., defesa, educação e saúde públicas e seguridade social") |>
  select(ano, vab_mi) |>
  arrange(ano)

vab_base2020 <- vab_aapp$vab_mi[vab_aapp$ano == 2020]
if (length(vab_base2020) == 0) stop("VAB AAPP de 2020 não encontrado.")

benchmark <- vab_aapp |>
  mutate(bench = vab_mi / vab_base2020 * 100)

# Interseção de anos com exatamente 4 trimestres
anos_comuns <- intersect(unique(folha_real$ano), benchmark$ano)
contagem <- folha_real |> filter(ano %in% anos_comuns) |> count(ano)
anos_completos <- contagem$ano[contagem$n == 4]
if (length(anos_completos) < length(anos_comuns)) {
  excluidos <- setdiff(anos_comuns, anos_completos)
  message("AVISO: Anos com < 4 trimestres excluídos do Denton: ", paste(excluidos, collapse=", "))
}
anos_comuns <- anos_completos

message(sprintf("\nDenton: %d–%d (%d anos, %d trimestres)",
                min(anos_comuns), max(anos_comuns),
                length(anos_comuns), length(anos_comuns) * 4))

idx_d   <- folha_real  |> filter(ano %in% anos_comuns) |> arrange(ano, trimestre)
bench_d <- benchmark   |> filter(ano %in% anos_comuns) |> arrange(ano)

serie_denton <- denton(
  indicador_trim  = idx_d$indice_aapp_raw,
  benchmark_anual = bench_d$bench,
  ano_inicio      = min(anos_comuns),
  trimestre_ini   = 1,
  metodo          = "denton-cholette"
)

idx_aapp_final <- idx_d |>
  mutate(
    indice_adm_publica = serie_denton,
    periodo            = sprintf("%dT%d", ano, trimestre)
  ) |>
  select(periodo, ano, trimestre, estadual, municipal, federal,
         folha_total, folha_real, indice_aapp_raw, indice_adm_publica)

validar_serie(idx_aapp_final$indice_adm_publica, "indice_adm_publica")

# --- Validação: variação anual índice vs. VAB IBGE ----------

cat("\nValidação — variação anual do índice vs. VAB AAPP (Contas Regionais):\n\n")
cat(sprintf("%-6s %16s %16s\n", "Ano", "Var. índice (%)", "Var. VAB nom. (%)"))
cat(strrep("-", 42), "\n")

medias_anuais <- idx_aapp_final |>
  group_by(ano) |>
  summarise(media = mean(indice_adm_publica, na.rm = TRUE), .groups = "drop") |>
  arrange(ano)

for (i in 2:nrow(medias_anuais)) {
  ano_i   <- medias_anuais$ano[i]
  var_idx <- (medias_anuais$media[i] / medias_anuais$media[i-1] - 1) * 100
  vab_i   <- vab_aapp$vab_mi[vab_aapp$ano == ano_i]
  vab_im1 <- vab_aapp$vab_mi[vab_aapp$ano == medias_anuais$ano[i-1]]
  var_vab <- if (length(vab_i)==1 && length(vab_im1)==1)
               (vab_i / vab_im1 - 1) * 100 else NA_real_
  cat(sprintf("%-6d %15.1f%% %15.1f%%\n", ano_i, var_idx, var_vab))
}

write.csv(idx_aapp_final, arq_indice, row.names = FALSE)
message(sprintf(
  "\nÍndice AAPP salvo: %s\n  Período: %s a %s | Observações: %d",
  arq_indice,
  head(idx_aapp_final$periodo, 1),
  tail(idx_aapp_final$periodo, 1),
  nrow(idx_aapp_final)
))

message("\n=== Fase 2 — Administração Pública: script concluído ===")
