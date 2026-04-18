# ============================================================
# Projeto : Indicador de Atividade Econômica Trimestral — RR
# Script  : 02_adm_publica.R
# Autor   : Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)
# Data    : 2026-04-10
# Descrição: Índice trimestral de Administração Pública de RR.
#   Etapa 2.1 — Folha federal (SIAPE): obrigatória, via arquivos
#               manuais do Portal da Transparência processados localmente.
#   Etapa 2.2 — Folha estadual mensal do FIPLAN/SEPLAN-RR
#               (FIP 855), usada como proxy principal do estado.
#   Etapa 2.3 — Folha municipal via SICONFI/STN (RREO Anexo 06),
#               convertida de bimestral acumulada para trimestral.
#   Etapa 2.4 — Deflação pelo IPCA, série real, Denton-Cholette
#               e validação.
# Entrada : arquivos manuais FIPLAN/SEPLAN-RR (FIP 855)
#            API SICONFI/STN (pública, sem autenticação)
#            data/processed/contas_regionais_RR_volume.csv
# Saída   : data/raw/folha_estadual_rr_mensal.csv
#            data/raw/folha_municipal_rr.csv
#            data/output/indice_adm_publica.csv
# Depende : httr2, jsonlite, dplyr, tidyr, lubridate, tempdisagg
#            xml2, rvest
#            R/utils.R
# Nota    : A série estadual mensal é lida do FIP 855 do FIPLAN e
#           construída como a soma de `3190.1100` (Vencimentos e
#           Vantagens Fixas - Pessoal Civil), `3190.1200`
#           (Vencimentos e Vantagens Fixas - Pessoal Militar) e
#           `3190.1300` (Obrigações Patronais). A série federal
#           observada é obrigatória. A série municipal permanece
#           no RREO Anexo 06 do SICONFI (bimestral acumulado).
#           A folha nominal total é deflacionada com o IPCA mensal
#           reescalado para jan/2020 = 1. O benchmark anual do
#           Denton vem da série de volume das Contas Regionais.
# ============================================================

source("R/utils.R")

library(httr2)
library(jsonlite)
library(dplyr)
library(tidyr)
library(lubridate)
library(data.table)
library(xml2)
library(rvest)

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
arq_vol_serie <- file.path(dir_processed, "contas_regionais_RR_volume.csv")
dir_fiplan    <- file.path("bases_baixadas_manualmente", "dados_folha_rr_fip855")

# --- Parâmetros ---------------------------------------------

# Período de interesse (a partir de 2020 — início do CAGED novo)
ano_inicio  <- 2020L
ano_atual   <- as.integer(format(Sys.Date(), "%Y"))
anos_serie  <- ano_inicio:ano_atual

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

rubricas_fiplan_proxy <- c("3190.1100", "3190.1200", "3190.1300")

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

numero_ptbr_para_numeric <- function(x) {
  x <- gsub("\\.", "", x)
  x <- gsub(",", ".", x, fixed = TRUE)
  suppressWarnings(as.numeric(x))
}

ler_fip855_ano <- function(caminho_xls) {
  tabela <- read_html(caminho_xls, encoding = "ISO-8859-1") |>
    html_element("table") |>
    html_table(fill = TRUE)

  idx_header <- which(trimws(tabela[[1]]) == "NATUREZA")[1]
  if (is.na(idx_header)) {
    stop("Cabeçalho 'NATUREZA' não encontrado em ", caminho_xls)
  }

  nomes <- trimws(as.character(unlist(tabela[idx_header, ], use.names = FALSE)))
  dados <- tabela[(idx_header + 1):nrow(tabela), , drop = FALSE]
  names(dados) <- nomes

  col_natureza  <- names(dados)[1]
  col_descricao <- names(dados)[2]
  cols_meses    <- grep("^[0-9]{2}/[0-9]{4}$", names(dados), value = TRUE)

  if (length(cols_meses) == 0) {
    stop("Nenhuma coluna mensal encontrada em ", caminho_xls)
  }

  dados |>
    mutate(
      natureza  = trimws(.data[[col_natureza]]),
      descricao = trimws(.data[[col_descricao]])
    ) |>
    filter(natureza %in% rubricas_fiplan_proxy) |>
    select(natureza, descricao, all_of(cols_meses)) |>
    pivot_longer(
      cols = all_of(cols_meses),
      names_to = "competencia",
      values_to = "valor_chr"
    ) |>
    mutate(
      mes = as.integer(substr(competencia, 1, 2)),
      ano = as.integer(substr(competencia, 4, 7)),
      valor = numero_ptbr_para_numeric(valor_chr)
    ) |>
    group_by(ano, mes) |>
    summarise(valor_mes = sum(valor, na.rm = TRUE), .groups = "drop") |>
    arrange(ano, mes)
}

ler_fiplan_estadual <- function(dir_fiplan) {
  if (!dir.exists(dir_fiplan)) {
    stop("Pasta do FIPLAN não encontrada: ", dir_fiplan)
  }

  arquivos <- list.files(dir_fiplan, pattern = "\\.xls$", full.names = TRUE, ignore.case = TRUE)
  if (length(arquivos) == 0) {
    stop("Nenhum arquivo .xls do FIP 855 encontrado em ", dir_fiplan)
  }

  arquivos <- arquivos[order(arquivos)]
  bind_rows(lapply(arquivos, ler_fip855_ano)) |>
    distinct(ano, mes, .keep_all = TRUE) |>
    arrange(ano, mes)
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
    stop(
      "SIAPE obrigatório: nenhum resultado processado a partir dos ZIPs em ",
      dir_siape_bulk,
      ". Verifique os arquivos manuais antes de rodar o índice de AAPP."
    )
  }

} else {
  stop(
    "SIAPE obrigatório: pasta não encontrada em ",
    dir_siape_bulk,
    ". Baixe/processse a base federal antes de rodar o índice de AAPP."
  )
}

# ============================================================
# ETAPA 2.2 — Folha Estadual (FIPLAN/SEPLAN-RR — FIP 855)
# ============================================================

message("\n=== ETAPA 2.2: Folha Estadual — FIPLAN/SEPLAN-RR (FIP 855) ===\n")

cache_estadual_valido <- FALSE

if (file.exists(arq_estadual)) {
  folha_estadual_mensal <- read.csv(arq_estadual, stringsAsFactors = FALSE)
  cache_estadual_valido <- all(c("ano", "mes", "valor_mes") %in% names(folha_estadual_mensal))

  if (!cache_estadual_valido) {
    message("Folha estadual: cache legado incompatível encontrado — reconstruindo a partir do FIPLAN.")
  }
}

if (!file.exists(arq_estadual) || !cache_estadual_valido) {
  message("Lendo FIP 855 da SEPLAN-RR em ", dir_fiplan, " ...")
  folha_estadual_mensal <- ler_fiplan_estadual(dir_fiplan) |>
    filter(ano >= ano_inicio)

  if (nrow(folha_estadual_mensal) > 0) {
    write.csv(folha_estadual_mensal, arq_estadual, row.names = FALSE)
    message(sprintf("Folha estadual salva: %s (%d meses)", arq_estadual, nrow(folha_estadual_mensal)))
  } else {
    message("AVISO: nenhum dado da folha estadual obtido do FIPLAN.")
    folha_estadual_mensal <- NULL
  }
} else {
  message("Folha estadual: usando cache (", arq_estadual, ")")
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

if (is.null(folha_estadual_mensal) || nrow(folha_estadual_mensal) == 0) {
  stop("Folha estadual indisponível — não é possível calcular o índice de AAPP.")
}

# Componente estadual (principal): mensal → trimestral
folha_est_trim <- folha_estadual_mensal |>
  mutate(trimestre = ceiling(mes / 3L)) |>
  group_by(ano, trimestre) |>
  summarise(estadual = sum(valor_mes, na.rm = TRUE), .groups = "drop")

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

  # Preencher meses ausentes por interpolação linear.
  # O Portal da Transparência publica ZIPs com Remuneracao.csv vazio para alguns meses
  # (ex: dez/2024 e fev/2025 tinham apenas cabeçalho). Sem preenchimento, a soma trimestral
  # ficaria com apenas 2 meses de folha federal, sub-estimando o trimestre em ~33%.
  folha_federal <- (function(df) {
    df <- df[!is.na(df$folha_bruta), ]
    df <- df[order(df$ano, df$mes), ]
    ano_min <- min(df$ano); mes_min <- min(df$mes[df$ano == ano_min])
    ano_max <- max(df$ano); mes_max <- max(df$mes[df$ano == ano_max])
    grade <- data.frame(
      t_idx = seq((ano_min - 1L) * 12L + mes_min,
                  (ano_max - 1L) * 12L + mes_max)
    )
    grade$ano <- ((grade$t_idx - 1L) %/% 12L) + 1L
    grade$mes <- ((grade$t_idx - 1L) %% 12L) + 1L
    df$t_idx  <- (df$ano - 1L) * 12L + df$mes
    merged <- merge(grade, df[, c("t_idx", "folha_bruta")], by = "t_idx", all.x = TRUE)
    merged <- merged[order(merged$t_idx), ]
    n_gaps <- sum(is.na(merged$folha_bruta))
    if (n_gaps > 0) {
      meses_falt <- paste(
        sprintf("%dM%02d", merged$ano[is.na(merged$folha_bruta)],
                           merged$mes[is.na(merged$folha_bruta)]),
        collapse = ", ")
      merged$folha_bruta <- approx(
        x = which(!is.na(merged$folha_bruta)),
        y = merged$folha_bruta[!is.na(merged$folha_bruta)],
        xout = seq_len(nrow(merged)), method = "linear", rule = 2
      )$y
      message(sprintf(
        "SIAPE: %d mês(es) ausente(s) interpolado(s) — %s (ZIP sem dados no Portal).",
        n_gaps, meses_falt))
    }
    merged[, c("ano", "mes", "folha_bruta")]
  })(folha_federal)

  folha_fed_trim <- folha_federal |>
    mutate(trimestre = ceiling(mes / 3L)) |>
    group_by(ano, trimestre) |>
    summarise(federal = sum(folha_bruta, na.rm = TRUE), .groups = "drop")
  message(sprintf("Componente federal (SIAPE): %d trimestres disponíveis.", nrow(folha_fed_trim)))
} else {
  stop(
    "Componente federal (SIAPE) indisponível após a etapa 2.1. ",
    "O índice de AAPP não pode ser calculado sem a folha federal observada."
  )
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
# A variável 2266 da tabela 1737 é usada aqui como nível do índice,
# no mesmo padrão adotado em serviços e nos blocos nominais do projeto.
# O deflator é a razão entre o nível do mês t e o nível de jan/2020.

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
  ano          = parsed$ano,
  mes          = parsed$mes,
  indice_nivel = ipca_cols$val,
  stringsAsFactors = FALSE
) |>
  filter(!is.na(indice_nivel), indice_nivel > 0, !is.na(ano), !is.na(mes)) |>
  arrange(ano, mes)

# Índice de preços reescalado, base jan/2020 = 1
idx_jan2020 <- which(ipca$ano == 2020 & ipca$mes == 1)
if (length(idx_jan2020) == 0) stop("IPCA: janeiro de 2020 não encontrado na série.")
ipca <- ipca |>
  mutate(
    # Preços acima de jan/2020 implicam deflator > 1 e reduzem a folha real.
    idx_preco = indice_nivel / indice_nivel[idx_jan2020]
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

# --- Denton-Cholette contra volume real AAPP anual ----------

vol_serie <- read.csv(arq_vol_serie, stringsAsFactors = FALSE)
vol_aapp <- vol_serie |>
  filter(atividade == "Adm., defesa, educação e saúde públicas e seguridade social") |>
  select(ano, vab_volume_rebased) |>
  arrange(ano)

if (nrow(vol_aapp) == 0 || !any(vol_aapp$ano == 2020)) {
  stop("Série de volume AAPP de 2020 não encontrada. Executar 00_dados_referencia.R.")
}

# vab_volume_rebased já está em base 2020=100 — sem normalização adicional
benchmark <- vol_aapp |>
  rename(bench = vab_volume_rebased)

# Anos com 4 trimestres completos na série de proxy (folha de pagamento)
# Não restringir ao período CR — a folha pode ter dados além de 2023
contagem       <- folha_real |> count(ano)
anos_completos <- contagem$ano[contagem$n == 4]
if (length(anos_completos) < nrow(contagem)) {
  excluidos <- setdiff(contagem$ano, anos_completos)
  message("AVISO: Anos com < 4 trimestres excluídos do Denton: ", paste(excluidos, collapse=", "))
}

ano_max_proxy <- max(anos_completos)

# Estender benchmark CR por tendência geométrica para cobrir todo o período da proxy.
# Permite que o Denton use a variação real da folha de pagamento para anos sem CR publicado.
if (ano_max_proxy > max(benchmark$ano)) {
  bench_ext <- estender_benchmark(benchmark$ano, benchmark$bench,
                                  ano_max = ano_max_proxy, n_ref = 3)
  benchmark <- data.frame(ano = bench_ext$ano, bench = bench_ext$bench)
}

anos_comuns <- intersect(anos_completos, benchmark$ano)

message(sprintf("\nDenton: %d–%d (%d anos, %d trimestres — %d com CR IBGE, %d extrapolados)",
                min(anos_comuns), max(anos_comuns),
                length(anos_comuns), length(anos_comuns) * 4,
                sum(anos_comuns %in% vol_aapp$ano),
                sum(!anos_comuns %in% vol_aapp$ano)))

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
cat(sprintf("%-6s %16s %16s\n", "Ano", "Var. índice (%)", "Var. VAB vol. (%)"))
cat(strrep("-", 42), "\n")

medias_anuais <- idx_aapp_final |>
  group_by(ano) |>
  summarise(media = mean(indice_adm_publica, na.rm = TRUE), .groups = "drop") |>
  arrange(ano)

for (i in 2:nrow(medias_anuais)) {
  ano_i   <- medias_anuais$ano[i]
  var_idx <- (medias_anuais$media[i] / medias_anuais$media[i-1] - 1) * 100
  vol_i   <- vol_aapp$vab_volume_rebased[vol_aapp$ano == ano_i]
  vol_im1 <- vol_aapp$vab_volume_rebased[vol_aapp$ano == medias_anuais$ano[i-1]]
  var_vab <- if (length(vol_i)==1 && length(vol_im1)==1)
               (vol_i / vol_im1 - 1) * 100 else NA_real_
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
