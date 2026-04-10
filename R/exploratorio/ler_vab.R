# ============================================================
# Projeto : Indicador de Atividade Econômica Trimestral — RR
# Script  : exploratorio/ler_vab.R
# Autor   : Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)
# Data    : 2026-04-10
# Descrição: Script de exploração — abordagem alternativa de
#            extração do VAB, buscando a string "Valor adicionado
#            bruto a preços correntes" nas abas em vez de usar
#            posição fixa de linha. Usado para validar a lógica
#            do script de produção (00_dados_referencia.R).
#            Não gera outputs persistentes.
# Entrada : data/raw/contas_regionais_2023/Tabela5.xls
# Saída   : (nenhuma — apenas console)
# Depende : readxl
# ============================================================

library(readxl)

caminho_xls <- file.path("data", "raw", "contas_regionais_2023", "Tabela5.xls")

atividades <- c(
  "5.1"  = "Total das Atividades",
  "5.2"  = "Agropecuária",
  "5.3"  = "Indústrias extrativas",
  "5.4"  = "Indústrias de transformação",
  "5.5"  = "Eletricidade, gás, água, esgoto e resíduos (SIUP)",
  "5.6"  = "Construção",
  "5.7"  = "Comércio e reparação de veículos",
  "5.8"  = "Transporte, armazenagem e correio",
  "5.9"  = "Informação e comunicação",
  "5.10" = "Atividades financeiras e seguros",
  "5.11" = "Atividades imobiliárias",
  "5.12" = "Adm., defesa, educação e saúde públicas (AAPP)",
  "5.13" = "Outros serviços"
)

resultados <- data.frame(atividade = character(), vab_2023 = numeric(), stringsAsFactors = FALSE)

for (i in seq_along(atividades)) {
  nome_aba <- paste0("Tabela", names(atividades)[i])
  df  <- read_excel(caminho_xls, sheet = nome_aba, col_names = FALSE)
  mat <- as.matrix(df)
  mat[is.na(mat)] <- ""

  # Busca por texto em vez de posição fixa
  linha_vab <- which(apply(mat, 1, function(x) {
    any(grepl("Valor adicionado bruto a preços correntes", x, ignore.case = TRUE))
  }))[1]
  col_ano <- which(apply(mat, 2, function(x) any(grepl("^2023$", x))))[1]

  if (!is.na(linha_vab) && !is.na(col_ano)) {
    val <- suppressWarnings(as.numeric(mat[linha_vab, col_ano]))
    resultados <- rbind(resultados, data.frame(
      atividade = atividades[i], vab_2023 = val, stringsAsFactors = FALSE
    ))
    cat(sprintf("%-60s: %15s\n", atividades[i], format(val, big.mark = ".", decimal.mark = ",")))
  } else {
    cat(sprintf("%-60s: NÃO ENCONTRADO\n", atividades[i]))
  }
}

total <- resultados$vab_2023[resultados$atividade == "Total das Atividades"]
resultados$participacao_pct <- round(resultados$vab_2023 / total * 100, 2)

cat("\n=== Resultado final ===\n")
print(resultados)
