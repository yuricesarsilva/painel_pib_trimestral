# ============================================================
# Projeto : Indicador de Atividade Econômica Trimestral — RR
# Script  : exploratorio/ler_xls2.R
# Autor   : Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)
# Data    : 2026-04-10
# Descrição: Script de exploração — lê e imprime todas as abas
#            do XLS das Contas Regionais (exceto Sumário) para
#            inspecionar visualmente os dados de cada atividade.
#            Usado durante a exploração inicial dos dados.
#            Não gera outputs; apenas imprime no console.
# Entrada : data/raw/contas_regionais_2023/Tabela5.xls
# Saída   : (nenhuma — apenas console)
# Depende : readxl
# ============================================================

library(readxl)

caminho_xls <- file.path("data", "raw", "contas_regionais_2023", "Tabela5.xls")

abas <- excel_sheets(caminho_xls)

for (aba in abas[abas != "Sumário"]) {
  df <- read_excel(caminho_xls, sheet = aba, col_names = FALSE)
  cat("\n===", aba, "===\n")
  print(as.data.frame(df))
}
