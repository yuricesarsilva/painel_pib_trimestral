# ============================================================
# Projeto : Indicador de Atividade Econômica Trimestral — RR
# Script  : 02_adm_publica.R
# Autor   : Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)
# Data    : 2026-04-10
# Descrição: Índice trimestral de Administração Pública de RR.
#   Etapa 2.1 — Folha federal: Portal da Transparência (SIAPE),
#               servidores ativos com lotação em RR. Requer token
#               em .env (TOKEN_TRANSPARENCIA). Se token não estiver
#               disponível, o módulo federal é pulado e a série é
#               estimada com base nos demais componentes.
#   Etapa 2.2 — Folha estadual (elemento 31 — pessoal ativo):
#               SICONFI/STN — RREO Anexo 06, governo do estado de RR.
#   Etapa 2.3 — Folha municipal: SICONFI/STN — RREO Anexo 06,
#               todos os 15 municípios de RR, elemento pessoal.
#   Etapa 2.4 — Série de volume, Denton-Cholette e validação.
# Entrada : API Portal da Transparência (token em .env)
#            API SICONFI/STN (pública)
#            data/processed/contas_regionais_RR_serie.csv
# Saída   : data/raw/siape_rr_mensal.csv (se token disponível)
#            data/raw/folha_estadual_rr_mensal.csv
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
# ETAPA 2.1 — Folha Federal (SIAPE via Portal da Transparência)
# ============================================================

message("\n=== ETAPA 2.1: Folha Federal — Portal da Transparência (SIAPE) ===\n")

carregar_env(".env")
token_siape <- Sys.getenv("TOKEN_TRANSPARENCIA")
tem_token   <- nchar(token_siape) > 0

if (!file.exists(arq_siape)) {
  if (!tem_token) {
    message("TOKEN_TRANSPARENCIA não configurado no .env.")
    message("  → Módulo SIAPE será pulado. Configure o token e reexecute para incluir a folha federal.")
    folha_federal <- NULL
  } else {
    message("Coletando folha federal via Portal da Transparência...")
    message("Endpoint: /api-de-dados/remuneracao-servidores-ativos (paginado, UF=RR)")

    base_pt <- "https://api.portaldatransparencia.gov.br/api-de-dados"

    # Testar autenticação com uma chamada simples
    teste <- request(paste0(base_pt, "/orgaos-siafi")) |>
      req_headers("chave-api" = token_siape) |>
      req_url_query(pagina = 1) |>
      req_error(is_error = function(r) FALSE) |>
      req_perform()

    if (resp_status(teste) != 200) {
      message(sprintf("  Token rejeitado (status %d). Verifique se o token foi ativado via e-mail.",
                      resp_status(teste)))
      message("  → Módulo SIAPE pulado. Reexecute após ativar o token.")
      folha_federal <- NULL
    } else {
      message("  Token validado. Iniciando coleta mensal...")

      # Coletar remuneração mensal de servidores civis ativos com exercício em RR
      # Endpoint: /remuneracao-servidores-ativos — retorna por servidor
      # Estratégia: coletar total bruto por competência, agregando todas as páginas

      coletar_folha_mes <- function(mes_ano) {
        # mes_ano no formato "MMAAAA" (ex: "012020")
        total <- 0
        pagina <- 1
        repeat {
          r <- request(paste0(base_pt, "/remuneracao-servidores-ativos")) |>
            req_headers("chave-api" = token_siape) |>
            req_url_query(
              mesAno      = mes_ano,
              orgaoExercicio = "26000",   # SIAPE - servidores civis
              pagina      = pagina
            ) |>
            req_throttle(rate = 6) |>   # max 6 req/s (< 400/min)
            req_retry(max_tries = 3, backoff = ~ 10) |>
            req_error(is_error = function(r) FALSE) |>
            req_perform()

          if (resp_status(r) != 200) break

          dados <- resp_body_json(r)
          if (length(dados) == 0) break

          # Filtrar UF de exercício = RR e somar remuneração bruta elemento 31
          # A API retorna dados individuais; agregar
          for (sv in dados) {
            # Verificar se o servidor está em RR
            uf_exerc <- sv$orgaoExercicio$siglaUFExercicio %||% ""
            if (uf_exerc == "RR") {
              remun <- as.numeric(sv$remuneracaoBasicaBruta %||% 0)
              total <- total + remun
            }
          }

          if (length(dados) < 500) break   # última página
          pagina <- pagina + 1
          Sys.sleep(0.15)   # respeitoso com o limite de 400 req/min
        }
        total
      }

      # Operador %||% para NULL-coalesce
      `%||%` <- function(a, b) if (!is.null(a)) a else b

      # Gerar competências de jan/2020 até mês atual
      datas <- seq(as.Date(paste0(ano_inicio, "-01-01")),
                   Sys.Date(),
                   by = "month")
      competencias <- format(datas, "%m%Y")

      folha_federal_lista <- lapply(competencias, function(comp) {
        log_msg(sprintf("SIAPE coletando: %s", comp))
        val <- tryCatch(coletar_folha_mes(comp),
                        error = function(e) { warning(e$message); NA_real_ })
        data.frame(competencia = comp, valor_bruto = val, stringsAsFactors = FALSE)
      })

      folha_federal <- do.call(rbind, folha_federal_lista)
      write.csv(folha_federal, arq_siape, row.names = FALSE)
      message(sprintf("Folha federal salva: %s (%d competências)", arq_siape, nrow(folha_federal)))
    }
  }
} else {
  message("Folha federal: usando cache (", arq_siape, ")")
  folha_federal <- read.csv(arq_siape, stringsAsFactors = FALSE)
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
if (!is.null(folha_federal) && nrow(folha_federal) > 0) {
  folha_fed_trim <- folha_federal |>
    mutate(
      ano       = as.integer(substr(competencia, 3, 6)),
      mes       = as.integer(substr(competencia, 1, 2)),
      trimestre = ceiling(mes / 3L)
    ) |>
    filter(!is.na(valor_bruto)) |>
    group_by(ano, trimestre) |>
    summarise(federal = sum(valor_bruto, na.rm = TRUE), .groups = "drop")
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
