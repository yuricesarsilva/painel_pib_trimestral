# ============================================================
# Projeto : Indicador de Atividade Econômica Trimestral — RR
# Script  : 05e_exportacao.R
# Autor   : Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)
# Data    : 2026-04-13
# Fase    : 5.5 — Exportação dos dados
#
# Descrição:
#   Gera o arquivo Excel de publicação com 5 abas:
#     1. Índice Geral     — série trimestral NSA com variações (2020T1–)
#     2. Componentes      — quatro blocos setoriais NSA + variação anual
#     3. Dessazonalizado  — índice geral e componentes SA
#     4. Fatores Sazonais — fatores aditivos X-13ARIMA-SEATS
#     5. Metadados        — fontes, metodologia e notas
#   Também gera CSVs individuais por série.
#
# Entrada : data/output/indice_geral_rr.csv
#            data/output/indice_geral_rr_sa.csv
#            data/output/fatores_sazonais.csv
#            logs/fontes_utilizadas.csv
# Saída   : data/output/IAET_RR_series.xlsx  (publicação)
#            data/output/IAET_RR_geral.csv
#            data/output/IAET_RR_componentes.csv
#            data/output/IAET_RR_dessazonalizado.csv
# Depende : dplyr, readr, openxlsx
# ============================================================

library(dplyr)
library(readr)
library(openxlsx)

dir_output    <- file.path("data", "output")
dir_logs      <- file.path("logs")

arq_geral     <- file.path(dir_output, "indice_geral_rr.csv")
arq_sa        <- file.path(dir_output, "indice_geral_rr_sa.csv")
arq_fatores   <- file.path(dir_output, "fatores_sazonais.csv")
arq_fontes    <- file.path(dir_logs,   "fontes_utilizadas.csv")
arq_xlsx      <- file.path(dir_output, "IAET_RR_series.xlsx")

# ============================================================
# ETAPA 5.5.1 — Carregar e preparar dados
# ============================================================

message("\n=== ETAPA 5.5.1: Preparando dados ===\n")

nsa <- read_csv(arq_geral, show_col_types = FALSE) |> arrange(ano, trimestre)
sa  <- read_csv(arq_sa,    show_col_types = FALSE) |> arrange(ano, trimestre)
fat <- read_csv(arq_fatores, show_col_types = FALSE) |> arrange(ano, trimestre)

# --- Gate de publicação: filtrar até trimestre_publicado ----
# O trimestre publicado é definido em config/release.R e só
# avança via 06_avanca_publicacao.R, após comunicação à imprensa.
source("config/release.R")
ano_pub_exp  <- as.integer(sub("T.*", "", trimestre_publicado))
trim_pub_exp <- as.integer(sub(".*T", "", trimestre_publicado))

filtrar_pub <- function(df) {
  df[df$ano < ano_pub_exp | (df$ano == ano_pub_exp & df$trimestre <= trim_pub_exp), ]
}

n_antes <- nrow(nsa)
nsa <- filtrar_pub(nsa)
sa  <- filtrar_pub(sa)
fat <- filtrar_pub(fat)
n_retidos <- nrow(nsa)

if (n_antes > n_retidos) {
  message(sprintf(
    "Gate de publicação: %d trimestre(s) retido(s) fora do release (publicado: %s).",
    n_antes - n_retidos, trimestre_publicado
  ))
}
message(sprintf("Exportando %d trimestres (até %s).", n_retidos, trimestre_publicado))

# Variações trimestrais e anuais para o índice geral
enriquecer_geral <- function(df, col_idx) {
  df |>
    arrange(ano, trimestre) |>
    mutate(
      var_trim_pct = round((.data[[col_idx]] / lag(.data[[col_idx]]) - 1) * 100, 2),
      media_anual  = ave(.data[[col_idx]], ano, FUN = mean),
      var_ano_pct  = round((media_anual / lag(media_anual, 4) - 1) * 100, 2)
    ) |>
    select(-media_anual)
}

# Aba 1 — Índice Geral NSA
aba1 <- nsa |>
  select(periodo, ano, trimestre, indice_geral) |>
  enriquecer_geral("indice_geral") |>
  rename(
    Período           = periodo,
    Ano               = ano,
    Trimestre         = trimestre,
    `Índice Geral`    = indice_geral,
    `Var. trim. (%)`  = var_trim_pct,
    `Var. anual (%)` = var_ano_pct
  )

# Aba 2 — Componentes setoriais NSA
aba2 <- nsa |>
  select(periodo, ano, trimestre,
         indice_agropecuaria, indice_aapp, indice_industria, indice_servicos) |>
  arrange(ano, trimestre) |>
  mutate(across(starts_with("indice_"), \(x) round(x, 4))) |>
  rename(
    Período            = periodo,
    Ano                = ano,
    Trimestre          = trimestre,
    Agropecuária       = indice_agropecuaria,
    `Adm. Pública`     = indice_aapp,
    Indústria          = indice_industria,
    `Serviços Privados`= indice_servicos
  )

# Aba 3 — Dessazonalizado (SA)
aba3 <- sa |>
  select(periodo, ano, trimestre,
         indice_geral_sa,
         indice_agropecuaria_sa, indice_aapp_sa,
         indice_industria_sa, indice_servicos_sa) |>
  arrange(ano, trimestre) |>
  mutate(across(ends_with("_sa"), \(x) round(x, 4))) |>
  rename(
    Período                   = periodo,
    Ano                       = ano,
    Trimestre                 = trimestre,
    `Índice Geral SA`         = indice_geral_sa,
    `Agropecuária SA`         = indice_agropecuaria_sa,
    `Adm. Pública SA`         = indice_aapp_sa,
    `Indústria SA`            = indice_industria_sa,
    `Serviços Privados SA`    = indice_servicos_sa
  )

# Aba 4 — Fatores sazonais
aba4 <- fat |>
  mutate(across(starts_with("fator_"), round, 4)) |>
  rename(
    Período               = periodo,
    Ano                   = ano,
    Trimestre             = trimestre,
    `Fator Geral`         = fator_geral,
    `Fator Agropecuária`  = fator_agropecuaria,
    `Fator Adm. Pública`  = fator_aapp,
    `Fator Indústria`     = fator_industria,
    `Fator Serviços`      = fator_servicos
  )

# Aba 5 — Metadados
fontes <- if (file.exists(arq_fontes)) {
  read_csv(arq_fontes, show_col_types = FALSE)
} else {
  data.frame(nota = "Arquivo fontes_utilizadas.csv não encontrado.")
}

meta_geral <- data.frame(
  Campo    = c("Indicador", "Período base", "Cobertura temporal",
               "Método de desagregação", "Ajuste sazonal",
               "Benchmark anual", "Deflator",
               "Unidade", "Referência metodológica",
               "Elaboração", "Última atualização"),
  Descrição = c(
    "Indicador de Atividade Econômica Trimestral — Roraima (IAET-RR)",
    "2020 = 100 (média dos quatro trimestres de 2020)",
    paste0("2020T1 – ", tail(nsa$periodo, 1), " (", nrow(nsa), " trimestres)"),
    "Denton-Cholette (pacote tempdisagg — R)",
    "X-13ARIMA-SEATS, modo X-11, transformação automática (pacote seasonal — R)",
    "VAB a preços correntes das Contas Regionais do IBGE — Roraima 2023 (out/2025)",
    "IPCA nacional (SIDRA Tab. 1737, variável 2266 — nível do índice)",
    "Índice adimensional (sem unidade monetária)",
    "IBCR — Banco Central do Brasil; IBC-Br — Banco Central do Brasil",
    "SEPLAN/RR — Coordenação-Geral de Estudos Econômicos e Sociais (CGEES) / DIEAS",
    format(Sys.Date(), "%d/%m/%Y")
  )
)

meta_pesos <- data.frame(
  `Bloco setorial` = c("Agropecuária", "Adm. Pública (AAPP)",
                        "Indústria", "Serviços Privados"),
  `Peso VAB 2023 (%)` = c(8.87, 46.21, 11.60, 33.32),
  `Composição` = c(
    "Lavouras (PAM/LSPA, 93%) + Pecuária (PPM/Abate/Ovos, 7%)",
    "Folha federal SIAPE + Folha estadual e municipal (SICONFI)",
    "SIUP (5,40%) + Construção (4,89%) + Transf. (1,31%)",
    "Comércio + Transportes + Financeiro + Imobiliário + Outros + InfoCom"
  ),
  check.names = FALSE
)

message(sprintf("Aba 1 — Índice Geral: %d linhas", nrow(aba1)))
message(sprintf("Aba 2 — Componentes:  %d linhas", nrow(aba2)))
message(sprintf("Aba 3 — SA:           %d linhas", nrow(aba3)))
message(sprintf("Aba 4 — Fatores:      %d linhas", nrow(aba4)))
message(sprintf("Aba 5 — Metadados:    %d fontes + %d campos gerais",
                nrow(fontes), nrow(meta_geral)))


# ============================================================
# ETAPA 5.5.2 — Construir workbook Excel com formatação
# ============================================================

message("\n=== ETAPA 5.5.2: Construindo arquivo Excel ===\n")

wb <- createWorkbook()

# Estilos
st_titulo <- createStyle(
  fontSize = 13, fontColour = "#FFFFFF", halign = "left", valign = "center",
  fgFill = "#1F4E79", textDecoration = "bold", wrapText = FALSE
)
st_header <- createStyle(
  fontSize = 11, fontColour = "#FFFFFF", halign = "center", valign = "center",
  fgFill = "#2E75B6", textDecoration = "bold", border = "Bottom",
  borderColour = "#FFFFFF", wrapText = TRUE
)
st_num <- createStyle(numFmt = "0.0000", halign = "right")
st_pct <- createStyle(numFmt = '0.00"%"', halign = "right")
st_str <- createStyle(halign = "left")
st_zebra_a <- createStyle(fgFill = "#EBF3FB")
st_zebra_b <- createStyle(fgFill = "#FFFFFF")
st_nota <- createStyle(fontSize = 9, fontColour = "#595959",
                        textDecoration = "italic", wrapText = TRUE)

escrever_aba <- function(wb, nome_aba, df, titulo,
                          cols_num = NULL, cols_pct = NULL, cols_str = NULL,
                          nota = NULL) {
  addWorksheet(wb, nome_aba, gridLines = FALSE)
  row_titulo  <- 1
  row_header  <- 2
  row_dados   <- 3
  row_nota    <- row_dados + nrow(df) + 1

  # Título
  writeData(wb, nome_aba, titulo, startRow = row_titulo, startCol = 1)
  addStyle(wb, nome_aba, st_titulo,
           rows = row_titulo, cols = 1:ncol(df), gridExpand = TRUE)
  mergeCells(wb, nome_aba, rows = row_titulo, cols = 1:ncol(df))
  setRowHeights(wb, nome_aba, rows = row_titulo, heights = 24)

  # Header
  writeData(wb, nome_aba, df, startRow = row_header, startCol = 1,
            headerStyle = st_header, borders = "none")
  setRowHeights(wb, nome_aba, rows = row_header, heights = 30)

  # Zebra
  for (i in seq_len(nrow(df))) {
    st_z <- if (i %% 2 == 1) st_zebra_a else st_zebra_b
    addStyle(wb, nome_aba, st_z,
             rows = row_dados + i - 1, cols = 1:ncol(df), gridExpand = TRUE)
  }

  # Formatos de célula
  if (!is.null(cols_num))
    addStyle(wb, nome_aba, st_num,
             rows = row_dados:(row_dados + nrow(df) - 1),
             cols = cols_num, gridExpand = TRUE, stack = TRUE)
  if (!is.null(cols_pct))
    addStyle(wb, nome_aba, st_pct,
             rows = row_dados:(row_dados + nrow(df) - 1),
             cols = cols_pct, gridExpand = TRUE, stack = TRUE)
  if (!is.null(cols_str))
    addStyle(wb, nome_aba, st_str,
             rows = row_dados:(row_dados + nrow(df) - 1),
             cols = cols_str, gridExpand = TRUE, stack = TRUE)

  # Nota de rodapé
  if (!is.null(nota)) {
    writeData(wb, nome_aba, nota, startRow = row_nota, startCol = 1)
    addStyle(wb, nome_aba, st_nota,
             rows = row_nota, cols = 1:ncol(df), gridExpand = TRUE)
    mergeCells(wb, nome_aba, rows = row_nota, cols = 1:ncol(df))
    setRowHeights(wb, nome_aba, rows = row_nota, heights = 36)
  }

  # Larguras de coluna — auto
  setColWidths(wb, nome_aba, cols = 1:ncol(df), widths = "auto")
}

# ---- Aba 1: Índice Geral ----
escrever_aba(
  wb, "Índice Geral",
  aba1,
  titulo  = "IAET-RR — Índice Geral de Atividade Econômica Trimestral de Roraima (base 2020 = 100)",
  cols_str = 1,
  cols_num = c(2, 3, 4),
  cols_pct = c(5, 6),
  nota = paste0(
    "Nota: Série sem ajuste sazonal (NSA). Base 2020 = 100 (média dos quatro trimestres de 2020). ",
    "Variação trimestral: variação relativa ao trimestre imediatamente anterior. ",
    "Variação anual: variação relativa ao mesmo período do ano anterior (4 trimestres). ",
    "Período 2024–2025: extrapolado por tendência geométrica — revisar quando CR 2024 for publicado (prev. out/2026). ",
    "Elaboração: SEPLAN/RR — CGEES/DIEAS."
  )
)

# ---- Aba 2: Componentes ----
escrever_aba(
  wb, "Componentes Setoriais",
  aba2,
  titulo  = "IAET-RR — Componentes Setoriais (base 2020 = 100, sem ajuste sazonal)",
  cols_str = 1,
  cols_num = c(2, 3, 4, 5, 6, 7),
  nota = paste0(
    "Pesos no VAB 2023 (CR IBGE): Agropecuária=8,87% | Adm. Pública=46,21% | ",
    "Indústria=11,60% | Serviços Privados=33,32%. ",
    "Período 2024–2025: extrapolado (Agropecuária e Adm. Pública com tendência 2022–2023; ",
    "Indústria e Serviços com série completa até 2025T4). ",
    "Elaboração: SEPLAN/RR — CGEES/DIEAS."
  )
)

# ---- Aba 3: Dessazonalizado ----
escrever_aba(
  wb, "Dessazonalizado (SA)",
  aba3,
  titulo  = "IAET-RR — Séries Dessazonalizadas por X-13ARIMA-SEATS (base 2020 = 100)",
  cols_str = 1,
  cols_num = c(2, 3, 4, 5, 6, 7, 8),
  nota = paste0(
    "Método: X-13ARIMA-SEATS, modo X-11, transformação automática (pacote seasonal — R). ",
    "Estimado sobre 24 trimestres (2020T1–2025T4). ",
    "SA = seasonally adjusted (dessazonalizado). ",
    "Elaboração: SEPLAN/RR — CGEES/DIEAS."
  )
)

# ---- Aba 4: Fatores Sazonais ----
escrever_aba(
  wb, "Fatores Sazonais",
  aba4,
  titulo  = "IAET-RR — Fatores Sazonais Aditivos (X-13ARIMA-SEATS, tabela D10)",
  cols_str = 1,
  cols_num = c(2, 3, 4, 5, 6, 7, 8),
  nota = paste0(
    "Fatores aditivos: SA = NSA − fator (fator > 0 indica trimestre acima da média sazonal). ",
    "Agropecuária: fator de grande amplitude (~300 pts) reflexo da colheita da soja (T3). ",
    "Indústria: fator multiplicativo convertido para aditivo. ",
    "Elaboração: SEPLAN/RR — CGEES/DIEAS."
  )
)

# ---- Aba 5: Metadados ----
addWorksheet(wb, "Metadados", gridLines = FALSE)

writeData(wb, "Metadados",
          "IAET-RR — Metadados, Fontes e Notas Metodológicas",
          startRow = 1, startCol = 1)
addStyle(wb, "Metadados", st_titulo, rows = 1, cols = 1:4, gridExpand = TRUE)
mergeCells(wb, "Metadados", rows = 1, cols = 1:4)
setRowHeights(wb, "Metadados", rows = 1, heights = 24)

writeData(wb, "Metadados", "Informações gerais",
          startRow = 3, startCol = 1)
addStyle(wb, "Metadados",
         createStyle(textDecoration = "bold", fgFill = "#BDD7EE"),
         rows = 3, cols = 1:2, gridExpand = TRUE)

writeData(wb, "Metadados", meta_geral, startRow = 4, startCol = 1,
          headerStyle = st_header)
addStyle(wb, "Metadados", st_str,
         rows = 5:(4 + nrow(meta_geral)), cols = 1:2, gridExpand = TRUE)

row_pesos <- 4 + nrow(meta_geral) + 2
writeData(wb, "Metadados", "Pesos setoriais (VAB 2023, CR IBGE)",
          startRow = row_pesos, startCol = 1)
addStyle(wb, "Metadados",
         createStyle(textDecoration = "bold", fgFill = "#BDD7EE"),
         rows = row_pesos, cols = 1:4, gridExpand = TRUE)

writeData(wb, "Metadados", meta_pesos, startRow = row_pesos + 1, startCol = 1,
          headerStyle = st_header)

row_fontes <- row_pesos + nrow(meta_pesos) + 3
writeData(wb, "Metadados", "Fontes de dados utilizadas",
          startRow = row_fontes, startCol = 1)
addStyle(wb, "Metadados",
         createStyle(textDecoration = "bold", fgFill = "#BDD7EE"),
         rows = row_fontes, cols = 1:ncol(fontes), gridExpand = TRUE)

writeData(wb, "Metadados", fontes, startRow = row_fontes + 1, startCol = 1,
          headerStyle = st_header)

setColWidths(wb, "Metadados", cols = 1:4, widths = c(25, 50, 20, 15))


# ============================================================
# ETAPA 5.5.3 — Salvar Excel e CSVs individuais
# ============================================================

message("\n=== ETAPA 5.5.3: Salvando arquivos ===\n")

saveWorkbook(wb, arq_xlsx, overwrite = TRUE)
message(sprintf("✓ Excel salvo: %s", arq_xlsx))

# CSVs individuais
arq_csv_geral  <- file.path(dir_output, "IAET_RR_geral.csv")
arq_csv_comp   <- file.path(dir_output, "IAET_RR_componentes.csv")
arq_csv_sa     <- file.path(dir_output, "IAET_RR_dessazonalizado.csv")

write_csv(aba1, arq_csv_geral)
write_csv(aba2, arq_csv_comp)
write_csv(aba3, arq_csv_sa)

message(sprintf("✓ CSV geral:         %s", arq_csv_geral))
message(sprintf("✓ CSV componentes:   %s", arq_csv_comp))
message(sprintf("✓ CSV dessaz.:       %s", arq_csv_sa))


# ============================================================
# ETAPA 5.5.4 — Sumário
# ============================================================

message("\n=== ETAPA 5.5.4: Sumário ===\n")

cat(sprintf("\n%s\n", strrep("=", 55)))
cat("EXPORTAÇÃO CONCLUÍDA — IAET-RR\n")
cat(sprintf("%s\n\n", strrep("=", 55)))
cat(sprintf("Excel: %s\n", basename(arq_xlsx)))
cat(sprintf("  Aba 1: Índice Geral         — %d obs.\n", nrow(aba1)))
cat(sprintf("  Aba 2: Componentes Setoriais — %d obs.\n", nrow(aba2)))
cat(sprintf("  Aba 3: Dessazonalizado (SA)  — %d obs.\n", nrow(aba3)))
cat(sprintf("  Aba 4: Fatores Sazonais      — %d obs.\n", nrow(aba4)))
cat(sprintf("  Aba 5: Metadados             — %d campos + %d fontes\n\n",
            nrow(meta_geral), nrow(fontes)))
cat(sprintf("CSVs individuais:\n"))
cat(sprintf("  %s\n", basename(arq_csv_geral)))
cat(sprintf("  %s\n", basename(arq_csv_comp)))
cat(sprintf("  %s\n\n", basename(arq_csv_sa)))

message("=== Fase 5.5 concluída ===")
