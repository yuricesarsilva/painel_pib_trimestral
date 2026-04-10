# ============================================================
# Projeto : Indicador de Atividade Econômica Trimestral — RR
# Script  : exploratorio/debug_xls.R
# Autor   : Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)
# Data    : 2026-04-10
# Descrição: Script de depuração — imprime linha a linha o
#            conteúdo da aba Tabela5.1 do XLS das Contas
#            Regionais para inspeção visual da estrutura.
#            Usado durante a exploração inicial dos dados.
#            Não gera outputs; apenas imprime no console.
# Entrada : data/raw/contas_regionais_2023/Tabela5.xls
# Saída   : (nenhuma — apenas console)
# Depende : readxl
# ============================================================

library(readxl)

caminho_xls <- file.path("data", "raw", "contas_regionais_2023", "Tabela5.xls")

df  <- read_excel(caminho_xls, sheet = "Tabela5.1", col_names = FALSE)
mat <- as.matrix(df)
mat[is.na(mat)] <- ""

for (i in seq_len(nrow(mat))) {
  cat(sprintf("Linha %02d: %s\n", i, paste(mat[i, ], collapse = " | ")))
}
