# ============================================================
# Projeto : Indicador de Atividade Economica Trimestral - RR
# Script  : 00b_icms_sefaz_atividade.R
# Autor   : Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)
# Data    : 2026-04-15
# Descricao: Extrai as participacoes setoriais do ICMS de
#   Roraima a partir dos PDFs de arrecadacao por atividade
#   economica (SEFAZ-RR) e aplica essas participacoes sobre
#   a serie total confiavel (icms_sefaz_rr_mensal.csv) para
#   gerar a serie trimestral com abertura setorial.
#
#   Logica central:
#     Os PDFs fornecem apenas a COMPOSICAO (%) do ICMS por
#     setor — nao os valores absolutos, que continuam vindo
#     da serie mensal ja processada (fonte confiavel).
#     ICMS setorial = participacao_pdf x total_serie_mensal
#
#   Fontes dos PDFs (ultima pagina de cada arquivo):
#     Setor Secundario (Industria) -> icms_industria_mi
#     Terciario Comercio Atacado + Varejo -> icms_comercio_mi
#     Terciario Servicos -> icms_servicos_mi
#     Contribuintes Nao Cadastrados -> redistribuidos
#       proporcionalmente entre os tres setores acima
#
#   Cobertura dos PDFs:
#     trimestral_2020.1-2024.2/  -> 2020T1 a 2024T2 (direto)
#     mensal_2024.05_2026.02/    -> 2024-05 em diante
#       (agregado a trimestre via soma ponderada interna)
#     Sobreposicao 2024T2: trimestral tem precedencia.
#
# Entrada : bases_baixadas_manualmente/dados_icms_por_atividade/
#            data/processed/icms_sefaz_rr_mensal.csv
# Saida   : data/processed/icms_sefaz_rr_trimestral.csv
# Depende : dplyr, readr, pdftools
# ============================================================

source("R/utils.R")

library(dplyr)
library(readr)
library(pdftools)

# --- Caminhos -----------------------------------------------

dir_icms_base   <- file.path("bases_baixadas_manualmente",
                              "dados_icms_por_atividade")
dir_trim_pdf    <- file.path(dir_icms_base, "trimestral_2020.1-2024.2")
dir_mes_pdf     <- file.path(dir_icms_base, "mensal_2024.05_2026.02")
arq_icms_mensal <- file.path("data", "processed", "icms_sefaz_rr_mensal.csv")
arq_saida       <- file.path("data", "processed", "icms_sefaz_rr_trimestral.csv")

for (d in c(dir_trim_pdf, dir_mes_pdf)) {
  if (!dir.exists(d)) stop("Pasta nao encontrada: ", d, call. = FALSE)
}
if (!file.exists(arq_icms_mensal)) {
  stop("Arquivo de ICMS mensal nao encontrado: ", arq_icms_mensal, call. = FALSE)
}


# ============================================================
# Funcoes auxiliares
# ============================================================

# Converte numero no formato brasileiro "1.234.567,89" para double
br_para_num <- function(x) {
  x <- trimws(x)
  x <- gsub("\\.", "", x)
  x <- gsub(",",  ".", x)
  suppressWarnings(as.numeric(x))
}

# Extrai o primeiro numero BR de uma linha que contenha o padrao
extrair_valor <- function(linhas, padrao) {
  hits <- grep(padrao, linhas, value = TRUE, ignore.case = TRUE, perl = TRUE)
  if (length(hits) == 0) return(NA_real_)
  nums <- regmatches(
    hits[1],
    gregexpr("\\d{1,3}(?:\\.\\d{3})*,\\d{2}", hits[1], perl = TRUE)
  )[[1]]
  if (length(nums) == 0) return(NA_real_)
  br_para_num(nums[1])
}

# Extrai valores setoriais da ultima pagina do PDF (tabela-resumo SEFAZ)
extrair_setores_pdf <- function(caminho_pdf) {
  paginas <- tryCatch(
    pdf_text(caminho_pdf),
    error = function(e) {
      warning(sprintf("Falha ao ler PDF '%s': %s", basename(caminho_pdf), e$message))
      return(NULL)
    }
  )
  if (is.null(paginas) || length(paginas) == 0) return(NULL)

  # Ultima pagina = tabela-resumo por setor economico
  linhas <- strsplit(paginas[length(paginas)], "\n")[[1]]
  linhas <- trimws(linhas)
  linhas <- linhas[nchar(linhas) > 0]

  list(
    total          = extrair_valor(linhas, "Total Arrecadado"),
    industria      = extrair_valor(linhas, "SETOR SECUND"),
    comercio_atac  = extrair_valor(linhas, "Com.rcio Atac"),
    comercio_varej = extrair_valor(linhas, "Com.rcio Varej"),
    servicos_terc  = extrair_valor(linhas, "Servi.os"),
    nao_cadastrado = extrair_valor(linhas, "N.O CADASTR")
  )
}

# Extrai participacoes e monta tibble de uma linha (um periodo)
montar_linha_shares <- function(setores, ano, trimestre, fonte) {
  total  <- coalesce(setores$total, 0)
  ind    <- coalesce(setores$industria,      0)
  com    <- coalesce(setores$comercio_atac,  0) +
            coalesce(setores$comercio_varej, 0)
  serv   <- coalesce(setores$servicos_terc,  0)
  nao    <- coalesce(setores$nao_cadastrado, 0)

  tibble(
    ano        = ano,
    trimestre  = trimestre,
    fonte      = fonte,
    total_pdf  = total,
    industria  = ind,
    comercio   = com,
    servicos   = serv,
    nao_cad    = nao
  )
}

mes_para_trimestre <- function(mes) ceiling(as.integer(mes) / 3L)


# ============================================================
# ETAPA 1 — PDFs trimestrais (2020T1 a 2024T2)
# ============================================================

message("\n=== ETAPA 1: PDFs trimestrais ===\n")

pdfs_trim <- sort(list.files(dir_trim_pdf, pattern = "\\.pdf$",
                              recursive = TRUE, full.names = TRUE))

if (length(pdfs_trim) == 0) {
  stop("Nenhum PDF trimestral encontrado em: ", dir_trim_pdf, call. = FALSE)
}

shares_trim <- vector("list", length(pdfs_trim))

for (i in seq_along(pdfs_trim)) {
  nome <- basename(pdfs_trim[i])

  # Formato esperado: "ICMS por Atividade - 02_tri_2021.pdf"
  m <- regmatches(nome, regexpr("(\\d{2})_tri_(\\d{4})", nome, perl = TRUE))
  if (length(m) == 0) {
    warning("Nome inesperado, ignorando: ", nome)
    next
  }
  partes    <- regmatches(m, gregexpr("\\d+", m))[[1]]
  tri_pdf   <- as.integer(partes[1])
  ano_pdf   <- as.integer(partes[2])

  setores <- extrair_setores_pdf(pdfs_trim[i])
  if (is.null(setores)) next

  shares_trim[[i]] <- montar_linha_shares(
    setores, ano_pdf, tri_pdf, "trimestral_pdf"
  )

  message(sprintf(
    "  %dT%d: total_pdf=%.0f | ind=%.0f | com=%.0f | serv=%.0f | n_cad=%.0f",
    ano_pdf, tri_pdf,
    coalesce(setores$total, 0), coalesce(setores$industria, 0),
    coalesce(setores$comercio_atac, 0) + coalesce(setores$comercio_varej, 0),
    coalesce(setores$servicos_terc, 0), coalesce(setores$nao_cadastrado, 0)
  ))
}

shares_trim_df <- bind_rows(shares_trim) |> arrange(ano, trimestre)
message(sprintf("\nPDFs trimestrais processados: %d periodos", nrow(shares_trim_df)))


# ============================================================
# ETAPA 2 — PDFs mensais (2024-05 em diante) -> trimestral
# ============================================================

message("\n=== ETAPA 2: PDFs mensais ===\n")

pdfs_mes <- sort(list.files(dir_mes_pdf, pattern = "\\.pdf$",
                             recursive = TRUE, full.names = TRUE))

if (length(pdfs_mes) == 0) {
  stop("Nenhum PDF mensal encontrado em: ", dir_mes_pdf, call. = FALSE)
}

shares_mes <- vector("list", length(pdfs_mes))

for (i in seq_along(pdfs_mes)) {
  nome <- basename(pdfs_mes[i])

  # Formato esperado: "ICMS por atividade - 06.2025.pdf"
  m <- regmatches(nome, regexpr("(\\d{2})\\.(\\d{4})", nome, perl = TRUE))
  if (length(m) == 0) {
    warning("Nome inesperado, ignorando: ", nome)
    next
  }
  partes  <- regmatches(m, gregexpr("\\d+", m))[[1]]
  mes_pdf <- as.integer(partes[1])
  ano_pdf <- as.integer(partes[2])

  setores <- extrair_setores_pdf(pdfs_mes[i])
  if (is.null(setores)) next

  linha <- montar_linha_shares(
    setores, ano_pdf, mes_para_trimestre(mes_pdf), "mensal_pdf"
  )
  shares_mes[[i]] <- bind_cols(linha, tibble(mes = mes_pdf))

  message(sprintf(
    "  %d-%02d: total_pdf=%.0f | ind=%.0f | com=%.0f | serv=%.0f",
    ano_pdf, mes_pdf,
    coalesce(setores$total, 0), coalesce(setores$industria, 0),
    coalesce(setores$comercio_atac, 0) + coalesce(setores$comercio_varej, 0),
    coalesce(setores$servicos_terc, 0)
  ))
}

shares_mes_df <- bind_rows(shares_mes) |> arrange(ano, mes)

# Agregar mensais a trimestral: share trimestral = soma setores / soma total
# Usa os valores absolutos internos dos PDFs apenas para ponderar a composicao
shares_mes_trim <- shares_mes_df |>
  group_by(ano, trimestre) |>
  summarise(
    fonte      = "mensal_pdf_agregado",
    total_pdf  = sum(total_pdf, na.rm = TRUE),
    industria  = sum(industria, na.rm = TRUE),
    comercio   = sum(comercio,  na.rm = TRUE),
    servicos   = sum(servicos,  na.rm = TRUE),
    nao_cad    = sum(nao_cad,   na.rm = TRUE),
    n_meses    = n(),
    .groups    = "drop"
  )

message(sprintf(
  "\nPDFs mensais: %d arquivos -> %d trimestres apos agregacao",
  nrow(shares_mes_df), nrow(shares_mes_trim)
))


# ============================================================
# ETAPA 3 — Combinar: trimestral tem precedencia sobre mensal
# ============================================================

message("\n=== ETAPA 3: Combinando shares ===\n")

# Ultimo trimestre coberto pelos PDFs trimestrais
ultimo_trim <- shares_trim_df |>
  filter(!is.na(total_pdf)) |>
  arrange(ano, trimestre) |>
  slice_tail(n = 1) |>
  transmute(chave = ano * 10L + trimestre) |>
  pull()

shares_mensal_extra <- shares_mes_trim |>
  filter(ano * 10L + trimestre > ultimo_trim) |>
  select(-any_of("n_meses"))

shares_completo <- bind_rows(shares_trim_df, shares_mensal_extra) |>
  arrange(ano, trimestre) |>
  mutate(periodo = sprintf("%dT%d", ano, trimestre))

message(sprintf(
  "Shares combinados: %d trimestres (%s a %s)",
  nrow(shares_completo),
  shares_completo$periodo[1],
  tail(shares_completo$periodo, 1)
))


# ============================================================
# ETAPA 4 — Total ICMS confiavel: agregar mensal -> trimestral
# ============================================================

message("\n=== ETAPA 4: Total ICMS da serie confiavel (mensal -> trim) ===\n")

icms_mensal <- read_csv(arq_icms_mensal, show_col_types = FALSE) |>
  arrange(ano, mes)

icms_trim_total <- icms_mensal |>
  mutate(trimestre = mes_para_trimestre(mes)) |>
  group_by(ano, trimestre) |>
  summarise(
    icms_total_mi = sum(icms_mi, na.rm = TRUE),
    n_meses       = n(),
    .groups       = "drop"
  ) |>
  mutate(periodo = sprintf("%dT%d", ano, trimestre)) |>
  arrange(ano, trimestre)

# Avisar trimestres incompletos (menos de 3 meses)
incompletos <- filter(icms_trim_total, n_meses < 3L)
if (nrow(incompletos) > 0) {
  warning(sprintf(
    "%d trimestre(s) com menos de 3 meses na serie mensal: %s",
    nrow(incompletos), paste(incompletos$periodo, collapse = ", ")
  ))
}

message(sprintf(
  "ICMS total trimestral: %d trimestres (%s a %s)",
  nrow(icms_trim_total),
  icms_trim_total$periodo[1],
  tail(icms_trim_total$periodo, 1)
))


# ============================================================
# ETAPA 5 — Participacoes e ICMS setorial
# ============================================================

message("\n=== ETAPA 5: ICMS setorial = participacao x total confiavel ===\n")

resultado <- icms_trim_total |>
  left_join(
    shares_completo |>
      select(ano, trimestre, periodo, fonte, total_pdf,
             industria, comercio, servicos, nao_cad),
    by = c("ano", "trimestre", "periodo")
  ) |>
  mutate(
    tem_share = !is.na(total_pdf) & total_pdf > 0,

    # Soma dos tres setores catalogados (sem nao-cadastrados)
    soma_tres = coalesce(industria, 0) +
                coalesce(comercio,  0) +
                coalesce(servicos,  0),

    # Redistribuir contribuintes nao-cadastrados proporcionalmente
    # entre industria, comercio e servicos
    ind_adj = ifelse(
      tem_share & soma_tres > 0,
      industria + coalesce(nao_cad, 0) * industria / soma_tres,
      industria
    ),
    com_adj = ifelse(
      tem_share & soma_tres > 0,
      comercio  + coalesce(nao_cad, 0) * comercio  / soma_tres,
      comercio
    ),
    serv_adj = ifelse(
      tem_share & soma_tres > 0,
      servicos  + coalesce(nao_cad, 0) * servicos  / soma_tres,
      servicos
    ),

    # Participacoes ajustadas (sobre o total_pdf)
    pct_industria = ifelse(tem_share, ind_adj  / total_pdf, NA_real_),
    pct_comercio  = ifelse(tem_share, com_adj  / total_pdf, NA_real_),
    pct_servicos  = ifelse(tem_share, serv_adj / total_pdf, NA_real_),

    # ICMS setorial = participacao x total confiavel
    icms_industria_mi = pct_industria * icms_total_mi,
    icms_comercio_mi  = pct_comercio  * icms_total_mi,
    icms_servicos_mi  = pct_servicos  * icms_total_mi
  ) |>
  select(
    ano, trimestre, periodo,
    icms_total_mi,
    icms_industria_mi,
    icms_comercio_mi,
    icms_servicos_mi,
    pct_industria,
    pct_comercio,
    pct_servicos,
    fonte_share = fonte,
    tem_share
  ) |>
  arrange(ano, trimestre)


# ============================================================
# ETAPA 6 — Validacao
# ============================================================

message("\n=== ETAPA 6: Validacao ===\n")

# Verificar que soma setorial = total (dentro de tolerancia numerica)
resultado |>
  filter(tem_share) |>
  mutate(
    soma_set   = icms_industria_mi + icms_comercio_mi + icms_servicos_mi,
    desvio_pct = abs(soma_set - icms_total_mi) / icms_total_mi * 100
  ) |>
  summarise(
    max_desvio = max(desvio_pct, na.rm = TRUE),
    med_desvio = mean(desvio_pct, na.rm = TRUE)
  ) |>
  (\(x) message(sprintf(
    "Desvio soma setorial vs. total: max=%.6f%% | media=%.6f%%",
    x$max_desvio, x$med_desvio
  )))()

sem_share <- filter(resultado, !tem_share)
if (nrow(sem_share) > 0) {
  warning(sprintf(
    "ICMS setorial sera NA em %d trimestre(s) sem shares: %s",
    nrow(sem_share), paste(sem_share$periodo, collapse = ", ")
  ))
}

validar_serie(resultado$icms_total_mi, "ICMS total trimestral")

message("\nResumo por trimestre:")
for (i in seq_len(nrow(resultado))) {
  r <- resultado[i, ]
  if (r$tem_share) {
    message(sprintf(
      "  %s | total=%.1f | ind=%.1f (%4.1f%%) | com=%.1f (%4.1f%%) | serv=%.1f (%4.1f%%) [%s]",
      r$periodo, r$icms_total_mi,
      r$icms_industria_mi, r$pct_industria * 100,
      r$icms_comercio_mi,  r$pct_comercio  * 100,
      r$icms_servicos_mi,  r$pct_servicos  * 100,
      r$fonte_share
    ))
  } else {
    message(sprintf(
      "  %s | total=%.1f | setorial=NA (sem PDF de shares)",
      r$periodo, r$icms_total_mi
    ))
  }
}


# ============================================================
# ETAPA 7 — Salvar
# ============================================================

message("\n=== ETAPA 7: Salvando ===\n")

write_csv(resultado, arq_saida)
message(sprintf("Salvo: %s (%d linhas, %d com shares setoriais)",
                arq_saida, nrow(resultado), sum(resultado$tem_share)))
