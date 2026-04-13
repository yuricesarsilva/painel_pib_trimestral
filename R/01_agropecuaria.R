# ============================================================
# Projeto : Indicador de Atividade Econômica Trimestral — RR
# Script  : 01_agropecuaria.R
# Autor   : Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)
# Data    : 2026-04-10
# Descrição: Índice trimestral de atividade agropecuária de
#            Roraima. Etapa 1.0 — cobertura PAM; Etapa 1.1 —
#            calendário de colheita (Censo Agro 2006); Etapa
#            1.2 — série mensal/trimestral de lavouras (PAM
#            definitivo + LSPA dezembro para ano corrente);
#            Etapa 1.3 — pecuária (abate, leite, ovos via
#            SIDRA); Etapa 1.4 — índice agregado com Denton-
#            Cholette contra VAB agropecuário anual do IBGE.
# Entrada : SIDRA IBGE — tabs 5457, 6588, 3939, 1092, 74, 915;
#            data/processed/contas_regionais_RR_serie.csv
# Saída   : data/processed/cobertura_lspa_pam.csv
#            data/processed/coef_sazonais_colheita.csv
#            data/processed/serie_lavouras_trimestral.csv
#            data/processed/serie_pecuaria_trimestral.csv
#            data/output/indice_agropecuaria.csv
# Depende : sidrar, dplyr, tidyr, lubridate, tempdisagg
#            R/utils.R
# Nota    : Tab 5457 contém lavouras temporárias e permanentes
#           (classificação c782). Tab 6588 (LSPA) usa c48 e
#           retorna período como "dezembro AAAA".
# ============================================================

source("R/utils.R")

library(sidrar)
library(dplyr)
library(tidyr)
library(lubridate)

# --- Caminhos -----------------------------------------------

dir_processed  <- file.path("data", "processed")
dir_output     <- file.path("data", "output")
dir_raw_sidra  <- file.path("data", "raw", "sidra")
dir_referencias <- file.path("data", "referencias")

dir.create(dir_processed, recursive = TRUE, showWarnings = FALSE)
dir.create(dir_output,    recursive = TRUE, showWarnings = FALSE)
dir.create(dir_raw_sidra, recursive = TRUE, showWarnings = FALSE)

arq_pam       <- file.path(dir_raw_sidra, "pam_temp_rr.csv")       # tab 5457: todas lavouras
arq_lspa      <- file.path(dir_raw_sidra, "lspa_rr.csv")           # tab 6588
arq_ppm       <- file.path(dir_raw_sidra, "ppm_vbp_rr.csv")         # tab 74 v215
arq_abate     <- file.path(dir_raw_sidra, "abate_rr.csv")          # tab 1092
arq_leite     <- file.path(dir_raw_sidra, "leite_rr.csv")          # tab 74
arq_ovos      <- file.path(dir_raw_sidra, "ovos_rr.csv")           # tab 915

arq_cobertura <- file.path(dir_processed, "cobertura_lspa_pam.csv")
arq_coef_saz  <- file.path(dir_processed, "coef_sazonais_colheita.csv")

# --- Calendários de colheita (versão A = produção; B e C = teste A/B Fase 5.2) ---
#   seadi           — Calendário agrícola SEADI-RR (versão A — padrão de produção)
#                     Fonte: Calendário Agrícola SEADI-RR (PDF da secretaria estadual)
#                     Mais aderente à realidade local; revisado pela SEADI para cada cultura em RR.
#   censo2006_area  — Censo Agropecuário 2006, coeficientes por área colhida (versão B)
#                     Fonte: IBGE, ufs.zip, tabelas de época principal de colheita por UF
#   censo2006_estab — Censo Agropecuário 2006, coeficientes por nº de estabelecimentos (versão C)
#                     Fonte: idem acima, ponderação alternativa
#
# Para rodar o teste A/B (Fase 5.2), mude o valor abaixo e reexecute o script.
versao_calendario <- "seadi"

arq_cal_seadi  <- file.path(dir_referencias, "calendario_colheita_seadi_rr.csv")
arq_cal_area   <- file.path(dir_referencias, "calendario_colheita_censo2006_area_rr.csv")
arq_cal_estab  <- file.path(dir_referencias, "calendario_colheita_censo2006_estabelecimentos_rr.csv")
arq_lavouras  <- file.path(dir_processed, "serie_lavouras_trimestral.csv")
arq_pecuaria  <- file.path(dir_processed, "serie_pecuaria_trimestral.csv")
arq_indice    <- file.path(dir_output,    "indice_agropecuaria.csv")
arq_cr_serie  <- file.path(dir_processed, "contas_regionais_RR_serie.csv")

# --- Culturas de interesse ----------------------------------
# Nomes exatos como aparecem na tabela SIDRA 5457
# (coluna "Produto das lavouras temporárias e permanentes")

culturas_pam <- c(
  "Arroz (em casca)",
  "Feijão (em grão)",
  "Milho (em grão)",
  "Soja (em grão)",
  "Cana-de-açúcar",
  "Mandioca",
  "Tomate",
  "Banana (cacho)",
  "Cacau (em amêndoa)",
  "Laranja"
)

# Mapa nome PAM → nome curto interno (snake_case)
nomes_curtos_pam <- c(
  "Arroz (em casca)"   = "arroz",
  "Feijão (em grão)"   = "feijao",
  "Milho (em grão)"    = "milho",
  "Soja (em grão)"     = "soja",
  "Cana-de-açúcar"     = "cana",
  "Mandioca"           = "mandioca",
  "Tomate"             = "tomate",
  "Banana (cacho)"     = "banana",
  "Cacau (em amêndoa)" = "cacau",
  "Laranja"            = "laranja"
)

# Mapa padrão LSPA → nome curto (para tab 6588, produtos hierárquicos)
# Vários produtos podem ter múltiplas safras; somar todas antes de atribuir.
padroes_lspa <- list(
  arroz   = "^1\\.4 Arroz$",
  feijao  = "Feijão",
  milho   = "Milho",
  soja    = "^1\\.17 Soja$",
  cana    = "^11 Cana-de-açúcar$",
  mandioca = "^21 Mandioca$",
  tomate  = "^24 Tomate$",
  banana  = "^4 Banana$",
  cacau   = "^8 Cacau$",
  laranja = "^18 Laranja$"
)

# Ordem canônica das culturas (igual ao calendário de colheita)
culturas_ord <- names(padroes_lspa)

# Anos para cálculo dos pesos Laspeyres
anos_peso <- 2018:2022

# --- Função: download idempotente via SIDRA -----------------

baixar_sidra <- function(api_url, caminho_cache, descricao) {
  if (!file.exists(caminho_cache)) {
    message("Baixando ", descricao, " ...")
    df <- get_sidra(api = api_url)
    write.csv(df, caminho_cache, row.names = FALSE)
    message(descricao, ": ", nrow(df), " linhas salvas em cache.")
    df
  } else {
    message(descricao, ": usando cache (", basename(caminho_cache), ")")
    read.csv(caminho_cache, check.names = FALSE, stringsAsFactors = FALSE)
  }
}

# --- Função: detectar colunas SIDRA por padrão de nome -----

detectar_col <- function(df, padroes, excluir = "ódigo|Código") {
  for (pat in padroes) {
    col <- names(df)[grepl(pat, names(df), ignore.case = TRUE) &
                       !grepl(excluir, names(df), ignore.case = TRUE)]
    if (length(col) > 0) return(col[1])
  }
  return(NA_character_)
}

# ============================================================
# ETAPA 1.0 — Análise de cobertura PAM
# ============================================================

message("\n=== ETAPA 1.0: Cobertura das culturas no VBP de lavouras de RR ===\n")

# Tab 5457: lavouras temporárias E permanentes (c782), vars 214=qtd, 215=VBP
pam_raw <- baixar_sidra(
  "/t/5457/n3/14/v/214,215/p/all/c782/all",
  arq_pam, "PAM lavouras temporárias e permanentes (tab 5457)"
)

# Detectar colunas
col_prod_pam <- detectar_col(pam_raw, c("lavouras temporárias e permanentes",
                                         "lavouras temporárias", "Produto das lavouras"))
col_var_pam  <- detectar_col(pam_raw, c("^Variável$"))
col_ano_pam  <- detectar_col(pam_raw, c("^Ano$"))
col_val_pam  <- detectar_col(pam_raw, c("^Valor$"))

message(sprintf("Colunas PAM: produto='%s' | variavel='%s' | ano='%s' | valor='%s'",
                col_prod_pam, col_var_pam, col_ano_pam, col_val_pam))

# Normalizar
pam <- pam_raw %>%
  transmute(
    produto  = .data[[col_prod_pam]],
    variavel = .data[[col_var_pam]],
    ano      = suppressWarnings(as.integer(.data[[col_ano_pam]])),
    valor    = suppressWarnings(as.numeric(gsub(",", ".", .data[[col_val_pam]])))
  ) %>%
  filter(!is.na(ano), ano > 0, !is.na(valor), valor > 0,
         produto != "Total")   # excluir linha de total agregado

pam_qtd <- pam %>% filter(grepl("Quantidade", variavel, ignore.case = TRUE))
pam_vbp <- pam %>% filter(grepl("Valor", variavel, ignore.case = TRUE))

message(sprintf("PAM: %d obs. quantidade | %d obs. VBP | %d produtos distintos",
                nrow(pam_qtd), nrow(pam_vbp), length(unique(pam$produto))))

# --- Cobertura: VBP médio 2018–2022 -------------------------

vbp_all <- pam_vbp %>%
  filter(ano %in% anos_peso) %>%
  group_by(produto) %>%
  summarise(vbp_medio = mean(valor, na.rm = TRUE), .groups = "drop")

total_vbp <- sum(vbp_all$vbp_medio, na.rm = TRUE)

cobertura_tbl <- vbp_all %>%
  mutate(
    incluida         = produto %in% culturas_pam,
    participacao_pct = round(vbp_medio / total_vbp * 100, 2)
  ) %>%
  arrange(desc(vbp_medio))

cobertura_total_pct <- round(
  sum(cobertura_tbl$vbp_medio[cobertura_tbl$incluida], na.rm = TRUE) / total_vbp * 100, 1
)

cat(sprintf(
  "\nCOBERTURA DAS 10 CULTURAS NO VBP TOTAL DE LAVOURAS — RR (média %d–%d): %.1f%%\n\n",
  min(anos_peso), max(anos_peso), cobertura_total_pct
))
cat(sprintf("%-40s %12s %8s\n", "Produto", "VBP médio", "% VBP"))
cat(strrep("-", 65), "\n")
for (i in seq_len(nrow(cobertura_tbl))) {
  r <- cobertura_tbl[i, ]
  cat(sprintf("%-40s %12.0f %7.2f%% %s\n",
              r$produto, r$vbp_medio, r$participacao_pct,
              if (r$incluida) "[incluída]" else ""))
}
cat(strrep("-", 65), "\n")

write.csv(cobertura_tbl, arq_cobertura, row.names = FALSE)
message(sprintf("Cobertura salva: %s (%.1f%% do VBP coberto pelas 10 culturas)",
                arq_cobertura, cobertura_total_pct))

# ============================================================
# ETAPA 1.1 — Calendário de colheita
# ============================================================

message("\n=== ETAPA 1.1: Calendário de colheita ===\n")

# Os coeficientes mensais de colheita distribuem a produção anual (PAM/LSPA)
# entre os 12 meses do ano, refletindo o ritmo real de colheita em Roraima.
# Cada linha (cultura) soma exatamente 1,0.
#
# Três versões disponíveis em data/referencias/:
#   A (padrão) — SEADI-RR: calendário agrícola oficial da Secretaria de
#                Agricultura do estado de Roraima. Mais aderente ao ciclo
#                atual das culturas no estado. Fonte primária desta versão.
#   B — Censo Agropecuário 2006, ponderado por área colhida.
#       Coeficientes derivados das tabelas de época de colheita por UF/produto.
#       Culturas sem dados mensais no Censo ficam com distribuição uniforme (1/12).
#   C — Censo Agropecuário 2006, ponderado por nº de estabelecimentos.
#       Ponderação alternativa à versão B; feijão = média de feijão-de-cor e fradinho.
#
# Versões B e C são candidatas ao teste de sensibilidade (Fase 5.2).
# Para reproduzir o teste, altere `versao_calendario` no bloco de parâmetros
# (próximo do topo do script) e reexecute.

meses <- c("jan", "fev", "mar", "abr", "mai", "jun",
           "jul", "ago", "set", "out", "nov", "dez")

arq_cal <- switch(versao_calendario,
  seadi           = arq_cal_seadi,
  censo2006_area  = arq_cal_area,
  censo2006_estab = arq_cal_estab,
  stop("versao_calendario inválida: '", versao_calendario,
       "'. Use 'seadi', 'censo2006_area' ou 'censo2006_estab'.")
)

if (!file.exists(arq_cal)) {
  stop("Arquivo de calendário não encontrado: ", arq_cal)
}

cal_raw <- read.csv(arq_cal, check.names = FALSE, stringsAsFactors = FALSE)

# Selecionar apenas as culturas do conjunto de trabalho, na ordem canônica
cal_filt <- cal_raw[cal_raw$cultura %in% culturas_ord, ]
cal_filt  <- cal_filt[match(culturas_ord, cal_filt$cultura), ]

if (nrow(cal_filt) < length(culturas_ord)) {
  faltando <- setdiff(culturas_ord, cal_filt$cultura)
  stop("Calendário '", versao_calendario, "': culturas faltando — ",
       paste(faltando, collapse = ", "))
}

coef_colheita <- as.matrix(cal_filt[, meses])
rownames(coef_colheita) <- cal_filt$cultura

# Substituir NA por 0 (meses sem colheita registrada = zero)
coef_colheita[is.na(coef_colheita)] <- 0

# Normalizar cada linha para soma exata = 1 (protege contra imprecisão de float)
somas <- rowSums(coef_colheita)
if (any(somas == 0)) {
  stop("Linha(s) com soma zero: ", paste(culturas_ord[somas == 0], collapse = ", "))
}
coef_colheita <- sweep(coef_colheita, 1, somas, "/")

somas_check <- rowSums(coef_colheita)
problemas <- rownames(coef_colheita)[abs(somas_check - 1) > 1e-9]
if (length(problemas) > 0) {
  stop("Coeficientes com soma != 1 após normalização: ", paste(problemas, collapse = ", "))
}

message(sprintf("Versão do calendário: %s (%s)", versao_calendario, basename(arq_cal)))
for (i in seq_len(nrow(coef_colheita))) {
  meses_ativos <- sum(coef_colheita[i, ] > 0)
  message(sprintf("  %-10s  fonte: %-40s  meses ativos: %d",
                  rownames(coef_colheita)[i],
                  cal_filt$fonte_mensalizacao[i],
                  meses_ativos))
}

df_coef <- cbind(data.frame(cultura = culturas_ord, versao = versao_calendario),
                 as.data.frame(coef_colheita))
write.csv(df_coef, arq_coef_saz, row.names = FALSE)
message(sprintf("\nCalendário salvo: %s", arq_coef_saz))

# ============================================================
# ETAPA 1.2 — Série mensal e trimestral de lavouras
# ============================================================

message("\n=== ETAPA 1.2: Série mensal/trimestral de lavouras ===\n")

# --- 1.2a. Quantidade anual por cultura (PAM) ---------------

qtd_pam <- pam_qtd %>%
  filter(produto %in% culturas_pam) %>%
  mutate(nome_curto = nomes_curtos_pam[produto]) %>%
  select(nome_curto, ano, qtd_t = valor) %>%
  filter(!is.na(nome_curto))

ultimo_ano_pam <- if (nrow(qtd_pam) > 0) max(qtd_pam$ano) else 2020L
message(sprintf("Último ano coberto pela PAM para RR: %d", ultimo_ano_pam))

# --- 1.2b. LSPA dezembro para anos sem PAM ------------------

lspa_raw <- baixar_sidra(
  "/t/6588/n3/14/v/35/p/all/c48/all",
  arq_lspa, "LSPA previsão de safras (tab 6588)"
)

col_prod_lspa <- detectar_col(lspa_raw, c("Produto das lavouras"))
col_mes_lspa  <- detectar_col(lspa_raw, c("^Mês$", "Mês e Ano", "Mês"))
col_val_lspa  <- detectar_col(lspa_raw, c("^Valor$"))

# Extrair dezembro de cada ano: "dezembro AAAA"
lspa_dez <- lspa_raw %>%
  transmute(
    produto = .data[[col_prod_lspa]],
    mes_txt = as.character(.data[[col_mes_lspa]]),
    valor   = suppressWarnings(as.numeric(gsub(",", ".", .data[[col_val_lspa]])))
  ) %>%
  filter(grepl("^dezembro", mes_txt, ignore.case = TRUE),
         !is.na(valor), valor > 0) %>%
  mutate(ano = suppressWarnings(
    as.integer(regmatches(mes_txt, regexpr("[12][0-9]{3}", mes_txt)))
  )) %>%
  filter(!is.na(ano))

# Agregar por nome_curto somando safras (feijão 1ª+2ª+3ª, milho 1ª+2ª)
qtd_lspa <- bind_rows(lapply(names(padroes_lspa), function(nm) {
  pat <- padroes_lspa[[nm]]
  lspa_dez %>%
    filter(grepl(pat, produto, ignore.case = FALSE)) %>%
    group_by(ano) %>%
    summarise(qtd_t = sum(valor, na.rm = TRUE), .groups = "drop") %>%
    mutate(nome_curto = nm)
})) %>%
  filter(ano > ultimo_ano_pam) %>%
  select(nome_curto, ano, qtd_t)

if (nrow(qtd_lspa) > 0) {
  anos_lspa <- sort(unique(qtd_lspa$ano))
  message(sprintf("LSPA: dados provisórios para %s (substitui PAM quando publicada)",
                  paste(anos_lspa, collapse = ", ")))
} else {
  message("LSPA: nenhum ano posterior à PAM — usando apenas dados definitivos.")
}

# Combinar PAM (definitivo) + LSPA (provisório)
qtd_total <- bind_rows(qtd_pam, qtd_lspa) %>% arrange(nome_curto, ano)

message(sprintf("Total de registros de produção: %d (culturas × anos)",
                nrow(qtd_total)))

# --- 1.2c. Pesos Laspeyres: VBP médio 2018–2022 -------------

vbp_pesos <- pam_vbp %>%
  filter(produto %in% culturas_pam, ano %in% anos_peso) %>%
  mutate(nome_curto = nomes_curtos_pam[produto]) %>%
  filter(!is.na(nome_curto)) %>%
  group_by(nome_curto) %>%
  summarise(vbp_medio = mean(valor, na.rm = TRUE), .groups = "drop") %>%
  mutate(peso = vbp_medio / sum(vbp_medio, na.rm = TRUE))

cat("\nPesos Laspeyres (VBP médio 2018–2022):\n")
for (i in seq_len(nrow(vbp_pesos))) {
  cat(sprintf("  %-10s  %.4f  (VBP médio: %.0f mil R$)\n",
              vbp_pesos$nome_curto[i], vbp_pesos$peso[i], vbp_pesos$vbp_medio[i]))
}

# --- 1.2d. Distribuição mensal: quantidade × coeficiente ----

prod_mensal <- qtd_total %>%
  filter(nome_curto %in% rownames(coef_colheita)) %>%
  rowwise() %>%
  mutate(
    mes   = list(1:12),
    qtd_m = list(qtd_t * coef_colheita[nome_curto, ])
  ) %>%
  ungroup() %>%
  select(nome_curto, ano, mes, qtd_m) %>%
  unnest(cols = c(mes, qtd_m))

# --- 1.2e. Índice de Laspeyres mensal -----------------------

idx_mensal <- prod_mensal %>%
  inner_join(vbp_pesos %>% select(nome_curto, peso), by = "nome_curto") %>%
  group_by(ano, mes) %>%
  summarise(
    indice_bruto = sum(qtd_m * peso, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(ano, mes)

# Base 2020 = 100
media_2020 <- mean(idx_mensal$indice_bruto[idx_mensal$ano == 2020], na.rm = TRUE)
if (is.na(media_2020) || media_2020 == 0) {
  stop("Sem dados de 2020 para normalizar o índice de lavouras.")
}
idx_mensal <- idx_mensal %>%
  mutate(indice_lavouras = indice_bruto / media_2020 * 100)

# --- 1.2f. Agregar para trimestral --------------------------

idx_lavouras_trim <- idx_mensal %>%
  mutate(trimestre = ceiling(mes / 3L)) %>%
  group_by(ano, trimestre) %>%
  summarise(indice_lavouras = mean(indice_lavouras, na.rm = TRUE), .groups = "drop") %>%
  mutate(periodo = sprintf("%dT%d", ano, trimestre)) %>%
  arrange(ano, trimestre)

validar_serie(idx_lavouras_trim$indice_lavouras, "indice_lavouras_trimestral")
write.csv(idx_lavouras_trim, arq_lavouras, row.names = FALSE)
message(sprintf("\nSérie de lavouras: %d trimestres (%s a %s)",
                nrow(idx_lavouras_trim),
                head(idx_lavouras_trim$periodo, 1),
                tail(idx_lavouras_trim$periodo, 1)))

# ============================================================
# ETAPA 1.3 — Pecuária
# ============================================================

message("\n=== ETAPA 1.3: Pecuária — disponibilidade para RR ===\n")

# Tab 74 v/215: Valor da produção de origem animal por tipo de produto (anual)
# Usado para calcular o peso relativo pecuária / lavouras no índice agropecuário
ppm_raw <- baixar_sidra(
  "/t/74/n3/14/v/215/p/all/c80/all",
  arq_ppm, "VBP pecuário — tab 74 v215"
)

abate_raw <- tryCatch(
  baixar_sidra("/t/1092/n3/14/v/284/p/all/c12716/all",
               arq_abate, "Abate de animais — RR (tab 1092)"),
  error = function(e) { message("  tab 1092 falhou: ", e$message); NULL }
)

# Tab 74 é ANUAL — usada apenas para VBP pecuário (pesos), não como série trimestral
# Para série pecuária trimestral, usar tab 1092 (abate) se disponível
leite_raw <- NULL  # Sem série trimestral de leite disponível para RR via SIDRA

ovos_raw <- tryCatch(
  baixar_sidra("/t/915/n3/14/v/29/p/all",
               arq_ovos, "Produção de ovos — RR (tab 915)"),
  error = function(e) { message("  tab 915 falhou: ", e$message); NULL }
)

tem_dados_validos <- function(df, descricao) {
  if (is.null(df)) {
    message(sprintf("  %-28s: falhou na consulta", descricao))
    return(FALSE)
  }
  col_val <- detectar_col(df, c("^Valor$"))
  if (is.na(col_val)) {
    message(sprintf("  %-28s: coluna Valor não encontrada", descricao))
    return(FALSE)
  }
  n_ok <- sum(!is.na(suppressWarnings(as.numeric(gsub(",", ".",
             df[[col_val]])))) &
             suppressWarnings(as.numeric(gsub(",", ".", df[[col_val]]))) > 0,
             na.rm = TRUE)
  disp <- n_ok > 0
  message(sprintf("  %-28s: %s (%d obs. válidas)",
                  descricao, if (disp) "DISPONÍVEL" else "SEM DADOS PARA RR", n_ok))
  disp
}

cat("Disponibilidade das séries pecuárias para Roraima:\n")
disp_abate <- tem_dados_validos(abate_raw, "Abate (tab 1092)")
disp_leite <- tem_dados_validos(leite_raw, "Leite (tab 74)")
disp_ovos  <- tem_dados_validos(ovos_raw,  "Ovos (tab 915)")

# Normaliza série trimestral SIDRA → data.frame(ano, trim, valor)
normalizar_trim_sidra <- function(df) {
  col_val <- detectar_col(df, c("^Valor$"))
  col_per <- detectar_col(df, c("Trimestre", "^Trimestre", "Período$"))
  if (is.na(col_val) || is.na(col_per)) return(NULL)

  df %>%
    transmute(
      periodo = as.character(.data[[col_per]]),
      valor   = suppressWarnings(as.numeric(gsub(",", ".", .data[[col_val]])))
    ) %>%
    filter(!is.na(valor), valor > 0) %>%
    mutate(
      ano  = suppressWarnings(as.integer(
               regmatches(periodo, regexpr("[12][0-9]{3}", periodo)))),
      trim = case_when(
        grepl("1[º°o]|Q1|1\\.tri|1st|jan|Jan", periodo, ignore.case = TRUE) ~ 1L,
        grepl("2[º°o]|Q2|2\\.tri|2nd|abr|Apr", periodo, ignore.case = TRUE) ~ 2L,
        grepl("3[º°o]|Q3|3\\.tri|3rd|jul|Jul", periodo, ignore.case = TRUE) ~ 3L,
        grepl("4[º°o]|Q4|4\\.tri|4th|out|Oct", periodo, ignore.case = TRUE) ~ 4L,
        TRUE ~ NA_integer_
      )
    ) %>%
    filter(!is.na(ano), !is.na(trim)) %>%
    arrange(ano, trim)
}

series_pec <- list()
if (disp_abate) {
  ab <- normalizar_trim_sidra(abate_raw)
  if (!is.null(ab)) {
    series_pec$abate <- ab %>%
      group_by(ano, trim) %>%
      summarise(abate = sum(valor, na.rm = TRUE), .groups = "drop")
  }
}
if (disp_leite) {
  lt <- normalizar_trim_sidra(leite_raw)
  if (!is.null(lt)) series_pec$leite <- lt %>% rename(leite = valor) %>% select(ano, trim, leite)
}
if (disp_ovos) {
  ov <- normalizar_trim_sidra(ovos_raw)
  if (!is.null(ov)) series_pec$ovos <- ov %>% rename(ovos = valor) %>% select(ano, trim, ovos)
}

if (length(series_pec) == 0) {
  message("\nNenhuma série pecuária trimestral disponível para RR.")
  message("Proxy pecuário: interpolação linear do VAB agropecuário anual (Contas Regionais).")

  cr_serie <- read.csv(arq_cr_serie, stringsAsFactors = FALSE)
  vab_agro_anual <- cr_serie %>%
    filter(atividade == "Agropecuária") %>%
    select(ano, vab_mi) %>% arrange(ano)

  base_pec <- mean(vab_agro_anual$vab_mi[vab_agro_anual$ano == 2020], na.rm = TRUE)
  idx_pec_trim <- vab_agro_anual %>%
    crossing(trimestre = 1:4) %>%
    arrange(ano, trimestre) %>%
    mutate(
      indice_pecuaria = vab_mi / base_pec * 100,
      periodo         = sprintf("%dT%d", ano, trimestre)
    ) %>%
    select(ano, trimestre, periodo, indice_pecuaria)

  metodo_pec <- "interpolação VAB anual"

} else {
  normalizar_idx <- function(df, col) {
    base <- mean(df[[col]][df$ano == 2020], na.rm = TRUE)
    if (is.na(base) || base == 0) base <- mean(df[[col]], na.rm = TRUE)
    df %>% mutate(idx = .data[[col]] / base * 100) %>% select(ano, trim, idx)
  }

  lista_idx <- lapply(names(series_pec), function(nm) {
    normalizar_idx(series_pec[[nm]], nm)
  })

  idx_pec_comb <- Reduce(
    function(a, b) full_join(a, b, by = c("ano", "trim"), suffix = c("_a", "_b")),
    lista_idx
  )
  idx_cols <- grep("^idx", names(idx_pec_comb), value = TRUE)
  idx_pec_comb$indice_pecuaria <- rowMeans(idx_pec_comb[, idx_cols, drop = FALSE],
                                           na.rm = TRUE)
  idx_pec_trim <- idx_pec_comb %>%
    mutate(periodo = sprintf("%dT%d", ano, trim)) %>%
    select(ano, trimestre = trim, periodo, indice_pecuaria) %>%
    arrange(ano, trimestre)

  metodo_pec <- paste("séries SIDRA:", paste(names(series_pec), collapse = "+"))
}

validar_serie(idx_pec_trim$indice_pecuaria, "indice_pecuaria_trimestral")
write.csv(idx_pec_trim, arq_pecuaria, row.names = FALSE)
message(sprintf("Série pecuária salva (%s): %d obs.", metodo_pec, nrow(idx_pec_trim)))

# ============================================================
# ETAPA 1.4 — Índice agropecuário agregado + Denton-Cholette
# ============================================================

message("\n=== ETAPA 1.4: Índice agropecuário e Denton-Cholette ===\n")

# --- Pesos lavouras vs. pecuária (VBP PAM + PPM) ------------

vbp_total_lavouras <- sum(vbp_pesos$vbp_medio, na.rm = TRUE)

col_val_ppm <- detectar_col(ppm_raw, c("^Valor$"))
col_ano_ppm <- detectar_col(ppm_raw, c("^Ano$"))
col_prod_ppm <- detectar_col(ppm_raw, c("Tipo de produto"))

vbp_total_pecuaria <- if (!is.na(col_val_ppm) && !is.na(col_ano_ppm)) {
  ppm_raw %>%
    transmute(
      ano     = suppressWarnings(as.integer(.data[[col_ano_ppm]])),
      produto = if (!is.na(col_prod_ppm)) .data[[col_prod_ppm]] else "Total",
      vbp     = suppressWarnings(as.numeric(gsub(",", ".", .data[[col_val_ppm]])))
    ) %>%
    # Usar apenas "Total" para evitar dupla contagem; ou excluir Total se quiser granular
    filter(grepl("^Total$", produto, ignore.case = TRUE),
           ano %in% anos_peso, !is.na(vbp), vbp > 0) %>%
    pull(vbp) %>% mean(na.rm = TRUE)
} else {
  message("AVISO: VBP pecuário não processado — usando peso padrão pecuária = 30%.")
  vbp_total_lavouras * 30 / 70
}

if (is.na(vbp_total_pecuaria) || vbp_total_pecuaria == 0) {
  message("AVISO: VBP pecuário zerado — usando peso padrão pecuária = 30%.")
  vbp_total_pecuaria <- vbp_total_lavouras * 30 / 70
}

peso_lavouras <- vbp_total_lavouras / (vbp_total_lavouras + vbp_total_pecuaria)
peso_pecuaria <- 1 - peso_lavouras

cat(sprintf("Pesos no índice agropecuário:\n  Lavouras: %.1f%%  Pecuária: %.1f%%\n\n",
            peso_lavouras * 100, peso_pecuaria * 100))

# --- Combinar lavouras + pecuária ---------------------------

idx_agro <- idx_lavouras_trim %>%
  select(ano, trimestre, indice_lavouras) %>%
  full_join(
    idx_pec_trim %>% select(ano, trimestre, indice_pecuaria),
    by = c("ano", "trimestre")
  ) %>%
  mutate(indice_agro_raw = peso_lavouras * indice_lavouras +
                           peso_pecuaria * indice_pecuaria) %>%
  arrange(ano, trimestre) %>%
  filter(!is.na(indice_agro_raw))

# --- Denton-Cholette: ancoragem ao VAB agropecuário anual ---

cr_serie <- read.csv(arq_cr_serie, stringsAsFactors = FALSE)
vab_agro <- cr_serie %>%
  filter(atividade == "Agropecuária") %>%
  select(ano, vab_mi) %>% arrange(ano)

vab_base2020 <- vab_agro$vab_mi[vab_agro$ano == 2020]
if (length(vab_base2020) == 0 || is.na(vab_base2020)) {
  stop("VAB agropecuário de 2020 não encontrado nas Contas Regionais.")
}

benchmark <- vab_agro %>%
  mutate(bench = vab_mi / vab_base2020 * 100)

anos_comuns <- intersect(unique(idx_agro$ano), benchmark$ano)

# Garantir completude: exatamente 4 trimestres por ano
contagem <- idx_agro %>% filter(ano %in% anos_comuns) %>% count(ano)
anos_completos <- contagem$ano[contagem$n == 4]
if (length(anos_completos) < length(anos_comuns)) {
  excluidos <- setdiff(anos_comuns, anos_completos)
  message("AVISO: Anos excluídos do Denton (< 4 trimestres): ",
          paste(excluidos, collapse = ", "))
}
anos_comuns <- anos_completos

message(sprintf("Denton: %d–%d (%d anos, %d trimestres)",
                min(anos_comuns), max(anos_comuns),
                length(anos_comuns), length(anos_comuns) * 4))

idx_d   <- idx_agro  %>% filter(ano %in% anos_comuns) %>% arrange(ano, trimestre)
bench_d <- benchmark %>% filter(ano %in% anos_comuns) %>% arrange(ano)

serie_denton <- denton(
  indicador_trim  = idx_d$indice_agro_raw,
  benchmark_anual = bench_d$bench,
  ano_inicio      = min(anos_comuns),
  trimestre_ini   = 1,
  metodo          = "denton-cholette"
)

idx_agro_final <- idx_d %>%
  mutate(
    indice_agropecuaria = serie_denton,
    periodo             = sprintf("%dT%d", ano, trimestre)
  ) %>%
  select(periodo, ano, trimestre, indice_lavouras, indice_pecuaria,
         indice_agro_raw, indice_agropecuaria)

validar_serie(idx_agro_final$indice_agropecuaria, "indice_agropecuaria")

# --- Validação: variação anual índice vs. VAB IBGE ----------

cat("\nValidação — variação anual do índice vs. VAB agropecuário (Contas Regionais):\n\n")
cat(sprintf("%-6s %16s %16s\n", "Ano", "Var. índice (%)", "Var. VAB nom. (%)"))
cat(strrep("-", 42), "\n")

medias_anuais <- idx_agro_final %>%
  group_by(ano) %>%
  summarise(media = mean(indice_agropecuaria, na.rm = TRUE), .groups = "drop") %>%
  arrange(ano)

for (i in 2:nrow(medias_anuais)) {
  ano_i   <- medias_anuais$ano[i]
  var_idx <- (medias_anuais$media[i] / medias_anuais$media[i-1] - 1) * 100
  vab_i   <- vab_agro$vab_mi[vab_agro$ano == ano_i]
  vab_im1 <- vab_agro$vab_mi[vab_agro$ano == medias_anuais$ano[i-1]]
  var_vab <- if (length(vab_i) == 1 && length(vab_im1) == 1)
               (vab_i / vab_im1 - 1) * 100 else NA_real_
  cat(sprintf("%-6d %15.1f%% %15.1f%%\n", ano_i, var_idx, var_vab))
}

write.csv(idx_agro_final, arq_indice, row.names = FALSE)
message(sprintf(
  "\nÍndice agropecuário salvo: %s\n  Período: %s a %s | Observações: %d",
  arq_indice,
  head(idx_agro_final$periodo, 1),
  tail(idx_agro_final$periodo, 1),
  nrow(idx_agro_final)
))

message("\n=== Fase 1 — Agropecuária: script concluído com sucesso ===")
