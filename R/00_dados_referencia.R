# ============================================================
# Projeto : Indicador de Atividade Econômica Trimestral — RR
# Script  : 00_dados_referencia.R
# Autor   : Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)
# Data    : 2026-04-10
# Descrição: Download das Contas Regionais IBGE 2023 (FTP) e
#            extração do VAB por atividade econômica para
#            Roraima. Gera a tabela de pesos setoriais usada
#            em todos os demais scripts do projeto.
# Entrada : FTP IBGE — Contas Regionais 2023, Tabela 5 (XLS)
# Saída   : data/processed/vab_roraima_2023.csv
# Depende : readxl
# Nota    : Executar com o diretório de trabalho definido como
#           a raiz do projeto (ou abrir via .Rproj).
# ============================================================

library(readxl)

# --- Caminhos (relativos à raiz do projeto) -----------------

dir_raw       <- file.path("data", "raw")
dir_processed <- file.path("data", "processed")
dir_extraido  <- file.path(dir_raw, "contas_regionais_2023")

caminho_zip   <- file.path(dir_raw, "contas_regionais_2023.zip")
caminho_xls   <- file.path(dir_extraido, "Tabela5.xls")
caminho_saida <- file.path(dir_processed, "vab_roraima_2023.csv")

# URL do FTP do IBGE — Contas Regionais do Brasil 2023
# Verificar endereço atual em: https://ftp.ibge.gov.br/Contas_Regionais/2023/
url_ibge <- "https://ftp.ibge.gov.br/Contas_Regionais/2023/xls/tabela5.zip"

# --- Download (idempotente: pula se o arquivo já existe) ----

if (!file.exists(caminho_zip)) {
  message("Baixando Contas Regionais 2023 do FTP do IBGE...")
  dir.create(dir_raw, recursive = TRUE, showWarnings = FALSE)
  download.file(url = url_ibge, destfile = caminho_zip, mode = "wb")
  message("Download concluído.")
} else {
  message("ZIP já existe localmente — pulando download.")
}

# --- Extração do ZIP (idempotente) --------------------------

if (!file.exists(caminho_xls)) {
  message("Extraindo arquivo ZIP...")
  dir.create(dir_extraido, recursive = TRUE, showWarnings = FALSE)
  unzip(caminho_zip, exdir = dir_extraido)
  message("Extração concluída.")
} else {
  message("XLS já existe — pulando extração.")
}

# --- Mapeamento de abas e nomenclatura das atividades -------

abas <- c(
  "Tabela5.1"  = "Total das Atividades",
  "Tabela5.2"  = "Agropecuária",
  "Tabela5.3"  = "Indústrias extrativas",
  "Tabela5.4"  = "Indústrias de transformação",
  "Tabela5.5"  = "Eletricidade, gás, água, esgoto e resíduos (SIUP)",
  "Tabela5.6"  = "Construção",
  "Tabela5.7"  = "Comércio e reparação de veículos automotores",
  "Tabela5.8"  = "Transporte, armazenagem e correio",
  "Tabela5.9"  = "Informação e comunicação",
  "Tabela5.10" = "Atividades financeiras, de seguros e serviços relacionados",
  "Tabela5.11" = "Atividades imobiliárias",
  "Tabela5.12" = "Adm., defesa, educação e saúde públicas e seguridade social",
  "Tabela5.13" = "Outros serviços"
)

# --- Função de extração do VAB de Roraima -------------------
# Estrutura da Tabela 5: cada aba contém séries anuais por UF.
# A seção de VAB a preços correntes começa após a linha 43.
# O ano aparece na coluna 1; o valor de Roraima está na coluna 6.

extrair_vab_roraima <- function(arquivo, nome_aba) {
  df  <- suppressWarnings(read_excel(arquivo, sheet = nome_aba, col_names = FALSE))
  mat <- as.matrix(df)
  mat[is.na(mat)] <- ""

  # Linhas com o rótulo "2023" na coluna 1, restritas à seção VAB (após linha 43)
  linhas_2023 <- which(mat[, 1] == "2023")
  linha_vab   <- linhas_2023[linhas_2023 > 43][1]

  # Fallback: última ocorrência de "2023" se não houver nenhuma após linha 43
  if (is.na(linha_vab)) linha_vab <- linhas_2023[length(linhas_2023)]

  suppressWarnings(as.numeric(mat[linha_vab, 6]))
}

# --- Extração por atividade ---------------------------------

message("\nExtraindo VAB por atividade — Roraima 2023...")

resultados <- data.frame(
  atividade   = character(),
  vab_2023_mi = numeric(),
  stringsAsFactors = FALSE
)

for (nome_aba in names(abas)) {
  val <- extrair_vab_roraima(caminho_xls, nome_aba)
  resultados <- rbind(resultados, data.frame(
    atividade   = abas[[nome_aba]],
    vab_2023_mi = val,
    stringsAsFactors = FALSE
  ))
}

# --- Participação no VAB total ------------------------------

total_vab <- resultados$vab_2023_mi[resultados$atividade == "Total das Atividades"]
resultados$participacao_pct <- round(resultados$vab_2023_mi / total_vab * 100, 2)

# --- Exibe resultado no console -----------------------------

cat("\n=== VAB POR ATIVIDADE — RORAIMA 2023 (R$ milhões correntes) ===\n\n")
cat(sprintf("%-65s %12s %8s\n", "Atividade", "VAB (R$ mi)", "% VAB"))
cat(strrep("-", 88), "\n")
for (i in seq_len(nrow(resultados))) {
  cat(sprintf(
    "%-65s %12.1f %7.2f%%\n",
    resultados$atividade[i],
    resultados$vab_2023_mi[i],
    resultados$participacao_pct[i]
  ))
}

# --- Salva CSV ----------------------------------------------

dir.create(dir_processed, recursive = TRUE, showWarnings = FALSE)
write.csv(resultados, caminho_saida, row.names = FALSE)
message(sprintf("\nArquivo salvo em: %s", caminho_saida))
