# ============================================================
# Projeto : Indicador de Atividade Econômica Trimestral — RR
# Script  : 00_dados_referencia.R
# Autor   : Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)
# Data    : 2026-04-10
# Descrição: Download das Contas Regionais IBGE 2023 (FTP) e
#            extração do VAB por atividade econômica para
#            Roraima — série histórica 2010–2023. Gera a tabela
#            de pesos setoriais usada em todos os demais scripts.
# Entrada : FTP IBGE — Contas Regionais 2023, Tabela 5 (XLS)
# Saída   : data/processed/vab_roraima_2023.csv
#            data/processed/contas_regionais_RR_serie.csv
# Depende : readxl
# Nota    : Executar com o diretório de trabalho definido como
#           a raiz do projeto (ou abrir via .Rproj).
# ============================================================

library(readxl)

# --- Caminhos (relativos à raiz do projeto) -----------------

dir_raw       <- file.path("data", "raw")
dir_processed <- file.path("data", "processed")
dir_extraido  <- file.path(dir_raw, "contas_regionais_2023")

caminho_zip        <- file.path(dir_raw, "contas_regionais_2023.zip")
caminho_xls        <- file.path(dir_extraido, "Tabela5.xls")
caminho_saida_2023 <- file.path(dir_processed, "vab_roraima_2023.csv")
caminho_saida_hist <- file.path(dir_processed, "contas_regionais_RR_serie.csv")

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

# --- Função de extração do VAB de Roraima — série histórica -
# Estrutura da Tabela 5: cada aba contém séries anuais por UF.
# A seção de VAB a preços correntes começa após a linha 43.
# O ano aparece na coluna 1; o valor de Roraima está na coluna 6.

extrair_vab_serie <- function(arquivo, nome_aba, anos = 2010:2023) {
  df  <- suppressWarnings(read_excel(arquivo, sheet = nome_aba, col_names = FALSE))
  mat <- as.matrix(df)
  mat[is.na(mat)] <- ""

  linhas_por_ano <- lapply(anos, function(ano) {
    linhas_ano <- which(mat[, 1] == as.character(ano))
    # Preferir a ocorrência após linha 43 (seção VAB a preços correntes)
    linha_vab  <- linhas_ano[linhas_ano > 43][1]
    # Fallback: última ocorrência disponível
    if (is.na(linha_vab)) linha_vab <- linhas_ano[length(linhas_ano)]
    val <- suppressWarnings(as.numeric(mat[linha_vab, 6]))
    data.frame(ano = ano, vab_mi = val, stringsAsFactors = FALSE)
  })

  do.call(rbind, linhas_por_ano)
}

# --- Extração da série histórica (2010–2023) por atividade --

anos_serie <- 2010:2023

message("\nExtraindo série histórica de VAB por atividade — Roraima 2010–2023...")

lista_atividades <- lapply(names(abas), function(nome_aba) {
  serie <- extrair_vab_serie(caminho_xls, nome_aba, anos = anos_serie)
  serie$atividade <- abas[[nome_aba]]
  serie
})

serie_completa <- do.call(rbind, lista_atividades)

# Calcular participação no VAB total por ano
totais_anuais <- serie_completa[serie_completa$atividade == "Total das Atividades",
                                c("ano", "vab_mi")]
names(totais_anuais)[2] <- "total_mi"

serie_completa <- merge(serie_completa, totais_anuais, by = "ano", all.x = TRUE)
serie_completa$participacao_pct <- round(serie_completa$vab_mi / serie_completa$total_mi * 100, 2)
serie_completa$total_mi <- NULL

# Ordenar: por atividade, depois por ano
serie_completa <- serie_completa[order(serie_completa$atividade, serie_completa$ano), ]

# --- Exibe resumo no console --------------------------------

cat("\n=== VAB POR ATIVIDADE — RORAIMA (R$ milhões correntes) ===\n\n")
cat(sprintf("%-65s %6s %12s %8s\n", "Atividade", "Ano", "VAB (R$ mi)", "% VAB"))
cat(strrep("-", 96), "\n")
for (i in seq_len(nrow(serie_completa))) {
  cat(sprintf(
    "%-65s %6d %12.1f %7.2f%%\n",
    serie_completa$atividade[i],
    serie_completa$ano[i],
    serie_completa$vab_mi[i],
    serie_completa$participacao_pct[i]
  ))
}

# --- Slice de 2023 para compatibilidade com scripts existentes

resultados_2023 <- serie_completa[serie_completa$ano == 2023, c("atividade", "vab_mi", "participacao_pct")]
names(resultados_2023)[2] <- "vab_2023_mi"
rownames(resultados_2023) <- NULL

# --- Salva CSVs ---------------------------------------------

dir.create(dir_processed, recursive = TRUE, showWarnings = FALSE)

write.csv(serie_completa, caminho_saida_hist, row.names = FALSE)
message(sprintf("Série histórica salva em: %s", caminho_saida_hist))

write.csv(resultados_2023, caminho_saida_2023, row.names = FALSE)
message(sprintf("Pesos 2023 salvos em:     %s", caminho_saida_2023))
