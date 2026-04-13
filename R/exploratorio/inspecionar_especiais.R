# Inspeção do tab04.xls (VAB nominal) e valores completos de Roraima em tab05.xls
library(readxl)

arq_vol <- file.path("data", "raw", "especiais_2023", "tab05.xls")
arq_nom <- file.path("data", "raw", "especiais_2023", "tab04.xls")

# --- Estrutura de tab04.xls ---
cat("=== tab04.xls — abas ===\n")
print(excel_sheets(arq_nom))

cat("\n=== tab04.xls — Tabela4 (primeiras 60 linhas, colunas 1-5) ===\n")
df4 <- suppressWarnings(read_excel(arq_nom, sheet = "Tabela4", col_names = FALSE, n_max = 70))
mat4 <- as.matrix(df4)
mat4[is.na(mat4)] <- ""
for (i in 1:min(60, nrow(mat4))) {
  linha <- paste(sprintf("%-25s", mat4[i, 1:min(5, ncol(mat4))]), collapse = " | ")
  cat(sprintf("L%02d: %s\n", i, linha))
}

# --- Valores completos de Roraima — tab05.xls todas as atividades ---
cat("\n\n=== Valores de Roraima em tab05.xls — todas as atividades ===\n\n")

abas_vol <- c(
  "Tabela5.1"  = "Total das Atividades",
  "Tabela5.2"  = "Agropecuaria",
  "Tabela5.3"  = "Extrativas",
  "Tabela5.4"  = "Transformacao",
  "Tabela5.5"  = "SIUP",
  "Tabela5.6"  = "Construcao",
  "Tabela5.7"  = "Comercio",
  "Tabela5.8"  = "Transportes",
  "Tabela5.9"  = "InfoCom",
  "Tabela5.10" = "Financeiro",
  "Tabela5.11" = "Imobiliarias",
  "Tabela5.12" = "AAPP",
  "Tabela5.13" = "OutrosServicos"
)

# Anos da tabela: cols 2 a 23 = 2002 a 2023
anos <- 2002:2023

for (aba in names(abas_vol)) {
  df <- suppressWarnings(read_excel(arq_vol, sheet = aba, col_names = FALSE))
  mat <- as.matrix(df)
  mat[is.na(mat)] <- ""
  linha_rr <- which(mat[, 1] == "Roraima")[1]
  if (is.na(linha_rr)) {
    cat(sprintf("%-12s: Roraima NAO ENCONTRADO\n", abas_vol[aba]))
    next
  }
  vals <- suppressWarnings(as.numeric(mat[linha_rr, 2:23]))
  # Mostrar 2010-2023
  idx <- (anos >= 2010)
  cat(sprintf("\n%-16s (linha %d, base 2002=100):\n", abas_vol[aba], linha_rr))
  cat(sprintf("  Ano: %s\n", paste(sprintf("%8d", anos[idx]), collapse = "")))
  cat(sprintf("  Val: %s\n", paste(sprintf("%8.2f", vals[idx]), collapse = "")))
}
