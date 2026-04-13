# ============================================================
# Projeto : Indicador de Atividade Econômica Trimestral — RR
# Script  : 00_dados_referencia.R
# Autor   : Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)
# Data    : 2026-04-13
# Descrição: Download das Contas Regionais IBGE 2023 (FTP) e
#            extração do VAB por atividade econômica para
#            Roraima — série histórica 2002–2023. Gera:
#              (1) tabela de VAB nominal por atividade (pesos)
#              (2) série encadeada de volume (base 2020=100)
#                  para ancoragem do Denton-Cholette nos scripts
#                  setoriais (reforma metodológica 2026-04-13)
# Entrada : FTP IBGE — Contas Regionais 2023:
#             Conta_da_Producao_2002_2023_xls.zip  → VAB nominal
#             Especiais_2002_2023_xls.zip           → volume
# Saída   : data/processed/vab_roraima_2023.csv
#            data/processed/contas_regionais_RR_serie.csv
#            data/processed/contas_regionais_RR_volume.csv  ← NOVO
# Depende : readxl
# Nota    : Executar com o diretório de trabalho definido como
#           a raiz do projeto (ou abrir via .Rproj).
# ============================================================

library(readxl)

# --- Caminhos (relativos à raiz do projeto) -----------------

dir_raw       <- file.path("data", "raw")
dir_processed <- file.path("data", "processed")
dir_extraido  <- file.path(dir_raw, "contas_regionais_2023")
dir_especiais <- file.path(dir_raw, "especiais_2023")

caminho_zip        <- file.path(dir_raw, "contas_regionais_2023.zip")
caminho_xls        <- file.path(dir_extraido, "Tabela5.xls")
caminho_saida_2023 <- file.path(dir_processed, "vab_roraima_2023.csv")
caminho_saida_hist <- file.path(dir_processed, "contas_regionais_RR_serie.csv")

# URLs do FTP do IBGE — Contas Regionais do Brasil 2023
url_nominal  <- "https://ftp.ibge.gov.br/Contas_Regionais/2023/xls/Conta_da_Producao_2002_2023_xls.zip"
url_especiais <- "https://ftp.ibge.gov.br/Contas_Regionais/2023/xls/Especiais_2002_2023_xls.zip"

caminho_zip_esp  <- file.path(dir_raw, "especiais_2002_2023.zip")
caminho_xls_vol  <- file.path(dir_especiais, "tab05.xls")
caminho_saida_vol <- file.path(dir_processed, "contas_regionais_RR_volume.csv")

# ============================================================
# PARTE 1 — VAB NOMINAL (Conta da Produção — Tabela 5 = RR)
# ============================================================

# --- Download (idempotente: pula se o arquivo já existe) ----

if (!file.exists(caminho_zip)) {
  message("Baixando Conta da Produção 2002-2023 do FTP do IBGE...")
  dir.create(dir_raw, recursive = TRUE, showWarnings = FALSE)
  download.file(url = url_nominal, destfile = caminho_zip, mode = "wb")
  message("Download concluído.")
} else {
  message("ZIP nominal já existe localmente — pulando download.")
}

# --- Extração do ZIP (idempotente) --------------------------

if (!file.exists(caminho_xls)) {
  message("Extraindo arquivo ZIP de contas da produção...")
  dir.create(dir_extraido, recursive = TRUE, showWarnings = FALSE)
  unzip(caminho_zip, exdir = dir_extraido)
  message("Extração concluída.")
} else {
  message("XLS nominal já existe — pulando extração.")
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


# ============================================================
# PARTE 2 — SÉRIE ENCADEADA DE VOLUME (Especiais — tab05.xls)
#
# Fonte  : Especiais_2002_2023_xls.zip → tab05.xls
# Tabela : "Série encadeada do volume do VAB, por atividades
#           econômicas, segundo Brasil, Grandes Regiões e UF"
# Base   : 2002 = 100 (fixo — já encadeado pelo IBGE)
# Saída  : vab_volume_rebased (base 2020 = 100)
#
# Reforma metodológica 2026-04-13: o benchmark do Denton-Cholette
# nos scripts setoriais 01–04 deve usar vab_volume_rebased em vez
# de vab_mi (nominal), para que o índice final seja de volume real.
# ============================================================

message("\n=== PARTE 2: Série encadeada de volume — Especiais IBGE ===\n")

# --- Download (idempotente) ---------------------------------

if (!file.exists(caminho_zip_esp)) {
  message("Baixando Especiais 2002-2023 do FTP do IBGE...")
  download.file(url = url_especiais, destfile = caminho_zip_esp, mode = "wb")
  message("Download concluído.")
} else {
  message("ZIP especiais já existe localmente — pulando download.")
}

# --- Extração (idempotente) ---------------------------------

if (!file.exists(caminho_xls_vol)) {
  message("Extraindo arquivo ZIP de especiais...")
  dir.create(dir_especiais, recursive = TRUE, showWarnings = FALSE)
  unzip(caminho_zip_esp, exdir = dir_especiais)
  message("Extração concluída.")
} else {
  message("XLS de volume já existe — pulando extração.")
}

# --- Mapeamento: aba do tab05 → nome da atividade -----------
# A aba Tabela5.N do tab05 corresponde à mesma atividade N do
# Conta da Produção. Nomes padronizados idênticos aos de 'abas'.

abas_vol <- c(
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

# --- Função de extração do índice de volume de Roraima ------
#
# Estrutura de tab05.xls (confirmada por inspeção em 2026-04-13):
#   - Linha 1 : título
#   - Linha 3 : cabeçalho ("Brasil, Grandes Regiões e UF" | anos)
#   - Linha 4 : anos nas colunas (col 2 = 2002, ..., col 23 = 2023)
#   - Linha 5 : "Total das Atividades" (rótulo do bloco)
#   - Linha 11: Roraima — em todas as abas
#   - Colunas 2–23: valores do índice base 2002=100

extrair_volume_rr <- function(arquivo, nome_aba, anos = 2002:2023) {
  df  <- suppressWarnings(read_excel(arquivo, sheet = nome_aba, col_names = FALSE))
  mat <- as.matrix(df)
  mat[is.na(mat)] <- ""

  # Localizar linha de Roraima (robusta: não depende de número fixo de linha)
  linha_rr <- which(trimws(mat[, 1]) == "Roraima")[1]
  if (is.na(linha_rr)) {
    warning(sprintf("[%s] Roraima não encontrado — verificar estrutura da aba.", nome_aba))
    return(NULL)
  }

  # Anos nas colunas 2–23 (confirmado por inspeção)
  n_anos <- length(anos)
  vals <- suppressWarnings(as.numeric(mat[linha_rr, 2:(1 + n_anos)]))

  data.frame(
    ano          = anos,
    vol_2002_100 = round(vals, 6),
    stringsAsFactors = FALSE
  )
}

# --- Extrair volume para todas as atividades ----------------

anos_vol <- 2002:2023

message("Extraindo índice de volume para Roraima (base 2002=100)...")

lista_vol <- lapply(names(abas_vol), function(nome_aba) {
  serie <- extrair_volume_rr(caminho_xls_vol, nome_aba, anos = anos_vol)
  if (is.null(serie)) return(NULL)
  serie$atividade <- abas_vol[[nome_aba]]
  serie
})

volume_completo <- do.call(rbind, Filter(Negate(is.null), lista_vol))

# --- Rebasear: 2002=100 → 2020=100 -------------------------
#
# Como o IBGE já fornece índice de base fixa (2002=100), o rebase
# é direto: dividir cada série pelo seu valor em 2020 e × 100.
# Isso preserva todas as taxas de crescimento interanuais.

rebasing <- volume_completo[volume_completo$ano == 2020, c("atividade", "vol_2002_100")]
names(rebasing)[2] <- "base_2020"

volume_completo <- merge(volume_completo, rebasing, by = "atividade", all.x = TRUE)
volume_completo$vab_volume_rebased <- round(
  volume_completo$vol_2002_100 / volume_completo$base_2020 * 100, 6
)
volume_completo$base_2020 <- NULL

volume_completo <- volume_completo[order(volume_completo$atividade, volume_completo$ano), ]

# --- Validação básica: 2020 deve ser exatamente 100 ---------

check_2020 <- volume_completo[volume_completo$ano == 2020, ]
desvios <- abs(check_2020$vab_volume_rebased - 100)
if (any(desvios > 0.001)) {
  stop(sprintf("Rebase falhou: desvio máximo de 2020=100 é %.6f (atividade: %s)",
               max(desvios),
               check_2020$atividade[which.max(desvios)]))
}
message("  Validação OK: todas as atividades têm vab_volume_rebased = 100,000 em 2020.")

# --- Exibir variações anuais para RR (2018–2023) ------------

cat("\n=== VARIAÇÕES ANUAIS — VOLUME RR (base 2020=100) ===\n\n")
cat(sprintf("%-55s", "Atividade"))
for (ano in 2019:2023) {
  cat(sprintf(" %7d", ano))
}
cat("\n")
cat(strrep("-", 55 + 8 * 5), "\n")

for (at in unique(volume_completo$atividade)) {
  serie <- volume_completo[volume_completo$atividade == at, ]
  serie <- serie[order(serie$ano), ]
  cat(sprintf("%-55s", substr(at, 1, 54)))
  for (ano in 2019:2023) {
    i_at  <- which(serie$ano == ano)
    i_ant <- which(serie$ano == ano - 1)
    if (length(i_at) == 1 && length(i_ant) == 1) {
      tx <- (serie$vab_volume_rebased[i_at] / serie$vab_volume_rebased[i_ant] - 1) * 100
      cat(sprintf(" %+6.1f%%", tx))
    } else {
      cat(sprintf(" %7s", "n/d"))
    }
  }
  cat("\n")
}

# --- Salvar CSV ---------------------------------------------

write.csv(volume_completo[, c("atividade", "ano", "vol_2002_100", "vab_volume_rebased")],
          caminho_saida_vol, row.names = FALSE)
message(sprintf("\n✓ Volume rebased (base 2020=100) salvo em: %s", caminho_saida_vol))
message(sprintf("  %d observações | %d atividades | %d anos (2002–2023)",
                nrow(volume_completo),
                length(unique(volume_completo$atividade)),
                length(anos_vol)))

message("\n=== 00_dados_referencia.R concluído ===")
message("  Saídas geradas:")
message(sprintf("    %s", caminho_saida_hist))
message(sprintf("    %s", caminho_saida_2023))
message(sprintf("    %s", caminho_saida_vol))
