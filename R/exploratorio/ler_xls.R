# ============================================================
# Projeto : Indicador de Atividade Econômica Trimestral — RR
# Script  : exploratorio/ler_xls.R
# Autor   : Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)
# Data    : 2026-04-10
# Descrição: Script de exploração — lista as abas do XLS das
#            Contas Regionais e exporta a primeira aba como CSV
#            para inspeção em editor de planilhas.
#            Usado durante a exploração inicial dos dados.
# Entrada : data/raw/contas_regionais_2023/Tabela5.xls
# Saída   : data/raw/tabela5_raw.csv (temporário, não versionado)
# Depende : readxl
# ============================================================

library(readxl)

caminho_xls <- file.path("data", "raw", "contas_regionais_2023", "Tabela5.xls")
caminho_csv <- file.path("data", "raw", "tabela5_raw.csv")

abas <- excel_sheets(caminho_xls)
cat("Abas encontradas:", paste(abas, collapse = " | "), "\n\n")

df <- read_excel(caminho_xls, sheet = 1, col_names = FALSE)
write.csv(as.data.frame(df), caminho_csv, row.names = FALSE)
cat("CSV salvo com", nrow(df), "linhas e", ncol(df), "colunas\n")
cat("Caminho:", caminho_csv, "\n")
