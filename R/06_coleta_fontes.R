# ============================================================
# Projeto : Indicador de Atividade Econômica Trimestral — RR
# Script  : 06_coleta_fontes.R
# Autor   : Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)
# Fase    : 6 — Manutenção trimestral
#
# Descrição:
#   Atualiza em um único comando todas as fontes automatizáveis
#   do pipeline. Ao final, imprime um relatório de cobertura
#   comparando cada fonte com o próximo trimestre a publicar.
#
#   Fontes automatizadas aqui:
#     - SIDRA: PAM (tab 5457), LSPA (6588), abate (1092),
#              ovos (7524), IPCA (1737), PIB anual (5938)
#     - ANP: vendas de diesel RR (dados abertos)
#     - ANEEL: apaga cache do(s) ano(s) atual(is) para forçar
#              re-download no próximo run_all.R
#
#   Fontes manuais (reportadas, não coletadas aqui):
#     - SIAPE, FIPLAN, ANAC, BCB Estban, BCB SCR, ICMS SEFAZ
#
#   NÃO executa modelagem. NÃO avança o trimestre publicado.
#   Após rodar este script: baixar fontes manuais pendentes →
#   source("R/run_all.R") para modelagem e exportação.
#
# Uso: source("R/06_coleta_fontes.R")
# ============================================================

if (!file.exists("R/utils.R")) {
  stop("Diretório de trabalho incorreto. Execute na raiz do projeto.", call. = FALSE)
}

library(sidrar)
library(dplyr)

source("config/release.R")

# --- Trimestre alvo (próximo após o publicado) ---------------

ano_pub  <- as.integer(sub("T.*", "", trimestre_publicado))
trim_pub <- as.integer(sub(".*T", "", trimestre_publicado))
trim_alvo <- if (trim_pub < 4L) trim_pub + 1L else 1L
ano_alvo  <- if (trim_pub < 4L) ano_pub     else ano_pub + 1L
mes_fim_alvo <- trim_alvo * 3L   # T1→3, T2→6, T3→9, T4→12

divisor <- paste(rep("=", 65), collapse = "")
divisor2 <- paste(rep("-", 75), collapse = "")

cat(sprintf("\n%s\n  COLETA DE FONTES — IAET-RR\n%s\n", divisor, divisor))
cat(sprintf("  Publicado : %s\n", trimestre_publicado))
cat(sprintf("  Alvo      : %dT%d\n\n", ano_alvo, trim_alvo))

# ============================================================
# SEÇÃO 1 — SIDRA (automatizado)
# ============================================================

cat(sprintf("%s\nSEÇÃO 1 — SIDRA\n%s\n", divisor, divisor2))

sidra_tasks <- list(
  list(api  = "/t/5457/n3/14/v/214,215/p/all/c782/all",
       dest = "data/raw/sidra/pam_temp_rr.csv",
       desc = "PAM lavouras (tab 5457)"),
  list(api  = "/t/6588/n3/14/v/35/p/all/c48/all",
       dest = "data/raw/sidra/lspa_rr.csv",
       desc = "LSPA previsão safras (tab 6588)"),
  list(api  = "/t/1092/n3/14/v/284/p/all/c12716/all",
       dest = "data/raw/sidra/abate_rr.csv",
       desc = "Abate bovino (tab 1092)"),
  list(api  = "/t/7524/n3/14/v/29/p/all",
       dest = "data/raw/sidra/ovos_rr.csv",
       desc = "Produção de ovos (tab 7524)"),
  list(api  = "/t/1737/n1/all/v/2266/p/all/d/v2266%2013",
       dest = "data/raw/ipca_mensal.csv",
       desc = "IPCA mensal (tab 1737)")
)

for (t in sidra_tasks) {
  message(sprintf("  %s ...", t$desc))
  df <- tryCatch(
    get_sidra(api = t$api),
    error = function(e) { message("    ERRO: ", e$message); NULL }
  )
  if (!is.null(df)) {
    write.csv(df, t$dest, row.names = FALSE)
    message(sprintf("    OK — %d linhas → %s", nrow(df), basename(t$dest)))
  }
}

# PIB anual (tab 5938) — usa get_sidra() com argumentos nomeados
dest_pib <- "data/raw/sidra/pib_rr_anual_sidra_5938.csv"
message(sprintf("  PIB anual SIDRA (tab 5938) ..."))
pib_raw <- tryCatch(
  get_sidra(x = 5938, variable = 37,
            period = sprintf("2010-%d", ano_alvo),
            geo = "State", geo.filter = list("State" = 14)),
  error = function(e) { message("    ERRO: ", e$message); NULL }
)
if (!is.null(pib_raw)) {
  write.csv(pib_raw, dest_pib, row.names = FALSE)
  message(sprintf("    OK — %d linhas → %s", nrow(pib_raw), basename(dest_pib)))
}

# ============================================================
# SEÇÃO 2 — ANP diesel (automatizado)
# ============================================================

cat(sprintf("\n%s\nSEÇÃO 2 — ANP diesel\n%s\n", divisor, divisor2))

arq_anp  <- "data/raw/anp/anp_diesel_rr_mensal.csv"
tmp_anp  <- tempfile(fileext = ".csv")
ano_arq  <- format(Sys.Date(), "%Y")

urls_anp <- c(
  sprintf(paste0("https://www.gov.br/anp/pt-br/centrais-de-conteudo/dados-abertos/",
                 "arquivos/vdpb/vendas-derivados-petroleo-e-etanol/",
                 "vendas-combustiveis-m3-1990-%s.csv"), ano_arq),
  paste0("https://www.gov.br/anp/pt-br/centrais-de-conteudo/dados-abertos/",
         "arquivos/vdpb/vendas-derivados-petroleo-e-etanol/",
         "vendas-combustiveis-m3-1990-2025.csv")
)

anp_ok <- FALSE
for (url_t in urls_anp) {
  res <- tryCatch({
    download.file(url_t, tmp_anp, method = "libcurl", mode = "wb", quiet = TRUE)
    file.size(tmp_anp) > 50000
  }, error = function(e) FALSE)
  if (res) { message(sprintf("  Download OK: %s", basename(url_t))); anp_ok <- TRUE; break }
}

if (anp_ok) {
  anp_full <- tryCatch(
    read.csv(tmp_anp, sep = ";", stringsAsFactors = FALSE, check.names = FALSE,
             fileEncoding = "latin1"),
    error = function(e) {
      tryCatch(read.csv(tmp_anp, sep = ";", stringsAsFactors = FALSE, check.names = FALSE),
               error = function(e2) NULL)
    }
  )
  if (!is.null(anp_full) && nrow(anp_full) > 0) {
    nomes_orig <- names(anp_full)
    nomes_norm <- tolower(iconv(nomes_orig, from = "latin1", to = "ASCII//TRANSLIT"))
    nomes_norm <- gsub("[^a-z0-9]", "_", nomes_norm)
    names(anp_full) <- nomes_norm

    col_est  <- names(anp_full)[grepl("estado|unidade_da_federa", names(anp_full))][1]
    col_prod <- names(anp_full)[grepl("produto|combustivel|tipo", names(anp_full))][1]
    col_ano  <- names(anp_full)[grepl("^ano$", names(anp_full))][1]
    col_mes  <- names(anp_full)[grepl("^m[ae]s$|^m_s$", names(anp_full))][1]
    col_vol  <- names(anp_full)[grepl("m3|vendas|volume", names(anp_full))][1]

    meses_pt <- c(JAN=1,FEV=2,MAR=3,ABR=4,MAI=5,JUN=6,
                  JUL=7,AGO=8,SET=9,OUT=10,NOV=11,DEZ=12)

    anp_rr <- anp_full[
      grepl("RORAIMA|^RR$", toupper(iconv(anp_full[[col_est]], to = "ASCII//TRANSLIT"))) &
      grepl("DIESEL|OLEO.*DIESEL", toupper(iconv(anp_full[[col_prod]], to = "ASCII//TRANSLIT"))),
    ]

    mes_num <- meses_pt[toupper(substr(
      iconv(as.character(anp_rr[[col_mes]]), to = "ASCII//TRANSLIT"), 1, 3))]

    anp_out <- data.frame(
      ano       = suppressWarnings(as.integer(anp_rr[[col_ano]])),
      mes       = as.integer(mes_num),
      diesel_m3 = suppressWarnings(
        as.numeric(gsub(",", ".", gsub("\\.", "", as.character(anp_rr[[col_vol]]))))
      )
    )
    anp_out <- anp_out[!is.na(anp_out$ano) & !is.na(anp_out$mes) &
                         !is.na(anp_out$diesel_m3) & anp_out$ano >= 2020, ]
    anp_out <- anp_out[order(anp_out$ano, anp_out$mes), ]

    write.csv(anp_out, arq_anp, row.names = FALSE)
    message(sprintf("  Salvo: %d obs. (Roraima diesel) → %s", nrow(anp_out), basename(arq_anp)))
  } else {
    message("  AVISO: arquivo ANP baixado mas não parseable — cache anterior mantido")
  }
} else {
  message("  AVISO: download ANP falhou — cache anterior mantido se existir")
}

# ============================================================
# SEÇÃO 3 — ANEEL (apaga cache para forçar re-download)
# ============================================================

cat(sprintf("\n%s\nSEÇÃO 3 — ANEEL (preparar re-download)\n%s\n", divisor, divisor2))

anos_aneel_apagar <- unique(c(ano_pub, ano_alvo))
for (ano_a in anos_aneel_apagar) {
  f_ano <- sprintf("data/raw/aneel/aneel_energia_rr_%d.csv", ano_a)
  if (file.exists(f_ano)) {
    file.remove(f_ano)
    message(sprintf("  Cache ANEEL %d apagado — será re-baixado em run_all.R", ano_a))
  } else {
    message(sprintf("  Cache ANEEL %d não existe — será baixado em run_all.R", ano_a))
  }
}
f_consol <- "data/raw/aneel/aneel_energia_rr.csv"
if (file.exists(f_consol)) {
  file.remove(f_consol)
  message("  Cache consolidado ANEEL apagado — será reconstruído em run_all.R")
}

# ============================================================
# SEÇÃO 4 — CAGED (idempotente, não requer ação aqui)
# ============================================================

cat(sprintf("\n%s\nSEÇÃO 4 — CAGED\n%s\n", divisor, divisor2))

fs_caged <- list.files("data/raw/caged", pattern = "^caged_rr_[0-9]{6}\\.csv$")
if (length(fs_caged) > 0) {
  max_ym <- max(as.integer(sub("caged_rr_([0-9]{6})\\.csv", "\\1", fs_caged)))
  message(sprintf("  Cache disponível até %dM%02d.", max_ym %/% 100L, max_ym %% 100L))
  message("  Novos meses serão baixados automaticamente via FTP em run_all.R (03_industria.R).")
} else {
  message("  AVISO: nenhum cache CAGED encontrado. run_all.R fará o download completo.")
}

# ============================================================
# FUNÇÕES AUXILIARES DE COBERTURA
# ============================================================

max_ano_mes <- function(caminho) {
  if (!file.exists(caminho)) return(list(ok = FALSE, str = "—"))
  df <- tryCatch(read.csv(caminho, stringsAsFactors = FALSE), error = function(e) NULL)
  if (is.null(df) || nrow(df) == 0) return(list(ok = FALSE, str = "vazio"))
  ano <- suppressWarnings(as.integer(df$ano))
  mes <- suppressWarnings(as.integer(df$mes))
  v <- !is.na(ano) & !is.na(mes) & ano > 2010 & mes >= 1 & mes <= 12
  if (!any(v)) return(list(ok = FALSE, str = "sem datas"))
  m <- which.max(ano[v] * 100L + mes[v])
  list(ok = TRUE, ano = ano[v][m], mes = mes[v][m],
       str = sprintf("%dM%02d", ano[v][m], mes[v][m]))
}

max_ano_trim_proc <- function(caminho) {
  if (!file.exists(caminho)) return(list(ok = FALSE, str = "—"))
  df <- tryCatch(read.csv(caminho, stringsAsFactors = FALSE), error = function(e) NULL)
  if (is.null(df) || nrow(df) == 0) return(list(ok = FALSE, str = "vazio"))
  ano  <- suppressWarnings(as.integer(df$ano))
  trim <- suppressWarnings(as.integer(df$trimestre))
  v <- !is.na(ano) & !is.na(trim)
  if (!any(v)) return(list(ok = FALSE, str = "sem períodos"))
  m <- which.max(ano[v] * 10L + trim[v])
  list(ok = TRUE, ano = ano[v][m], trim = trim[v][m],
       str = sprintf("%dT%d", ano[v][m], trim[v][m]))
}

max_sidra_trim <- function(caminho) {
  if (!file.exists(caminho)) return(list(ok = FALSE, str = "—"))
  df <- tryCatch(
    read.csv(caminho, check.names = FALSE, stringsAsFactors = FALSE),
    error = function(e) NULL
  )
  if (is.null(df) || nrow(df) == 0) return(list(ok = FALSE, str = "vazio"))
  col <- names(df)[grepl("Trimestre.*digo", names(df))][1]
  if (is.na(col)) return(list(ok = FALSE, str = "col. não encontrada"))
  cod <- suppressWarnings(as.integer(df[[col]]))
  cod <- cod[!is.na(cod) & cod > 200000L]
  if (length(cod) == 0) return(list(ok = FALSE, str = "sem trimestres"))
  mc  <- max(cod)
  list(ok = TRUE, ano = mc %/% 100L, trim = mc %% 100L,
       str = sprintf("%dT%d", mc %/% 100L, mc %% 100L))
}

max_aneel_cob <- function() {
  caminho <- "data/raw/aneel/aneel_energia_rr.csv"
  if (!file.exists(caminho)) return(list(ok = FALSE, str = "—"))
  df <- tryCatch(read.csv(caminho, stringsAsFactors = FALSE), error = function(e) NULL)
  if (is.null(df) || nrow(df) == 0) return(list(ok = FALSE, str = "vazio"))
  datas <- suppressWarnings(as.Date(paste0(df$data, "-01")))
  datas <- datas[!is.na(datas)]
  if (length(datas) == 0) return(list(ok = FALSE, str = "datas inválidas"))
  md <- max(datas)
  list(ok = TRUE, ano = as.integer(format(md, "%Y")), mes = as.integer(format(md, "%m")),
       str = format(md, "%YM%m"))
}

max_caged_cob <- function() {
  fs <- list.files("data/raw/caged", pattern = "^caged_rr_[0-9]{6}\\.csv$")
  if (length(fs) == 0) return(list(ok = FALSE, str = "—"))
  ym <- max(as.integer(sub("caged_rr_([0-9]{6})\\.csv", "\\1", fs)))
  list(ok = TRUE, ano = ym %/% 100L, mes = ym %% 100L,
       str = sprintf("%dM%02d", ym %/% 100L, ym %% 100L))
}

max_pam_cob <- function() {
  caminho <- "data/raw/sidra/pam_temp_rr.csv"
  if (!file.exists(caminho)) return(list(ok = FALSE, str = "—"))
  df <- tryCatch(
    read.csv(caminho, check.names = FALSE, stringsAsFactors = FALSE),
    error = function(e) NULL
  )
  if (is.null(df)) return(list(ok = FALSE, str = "erro"))
  col <- names(df)[grepl("^Ano$", names(df))][1]
  if (is.na(col)) return(list(ok = FALSE, str = "col. Ano não encontrada"))
  anos <- suppressWarnings(as.integer(df[[col]]))
  anos <- anos[!is.na(anos) & anos > 2000L]
  if (length(anos) == 0) return(list(ok = FALSE, str = "sem anos"))
  list(ok = TRUE, ano = max(anos), str = as.character(max(anos)))
}

max_lspa_cob <- function() {
  caminho <- "data/raw/sidra/lspa_rr.csv"
  if (!file.exists(caminho)) return(list(ok = FALSE, str = "—"))
  df <- tryCatch(
    read.csv(caminho, check.names = FALSE, stringsAsFactors = FALSE),
    error = function(e) NULL
  )
  if (is.null(df)) return(list(ok = FALSE, str = "erro"))
  col <- names(df)[grepl("^M.s$", names(df))][1]
  if (is.na(col)) return(list(ok = FALSE, str = "col. Mês não encontrada"))
  meses_pt <- c(janeiro=1,fevereiro=2,março=3,abril=4,maio=5,junho=6,
                julho=7,agosto=8,setembro=9,outubro=10,novembro=11,dezembro=12)
  txt  <- tolower(trimws(df[[col]]))
  anos <- suppressWarnings(
    as.integer(regmatches(txt, regexpr("[12][0-9]{3}", txt)))
  )
  nome <- tolower(trimws(sub("\\s+[12][0-9]{3}.*$", "", txt)))
  meses <- as.integer(meses_pt[nome])
  v <- !is.na(anos) & !is.na(meses)
  if (!any(v)) return(list(ok = FALSE, str = "sem datas"))
  m <- which.max(anos[v] * 100L + meses[v])
  list(ok = TRUE, ano = anos[v][m], mes = meses[v][m],
       str = sprintf("%dM%02d", anos[v][m], meses[v][m]))
}

# Avalia status de fonte mensal para o trimestre alvo
status_m <- function(cob, manual = FALSE) {
  suf <- if (manual) " *" else ""
  if (!cob$ok) return(paste0("N/A", suf))
  if (cob$ano > ano_alvo ||
      (cob$ano == ano_alvo && cob$mes >= mes_fim_alvo)) return(paste0("OK", suf))
  # Lista o que falta
  a <- cob$ano; m <- cob$mes + 1L
  if (m > 12L) { m <- 1L; a <- a + 1L }
  faltam <- character()
  repeat {
    if (a > ano_alvo || (a == ano_alvo && m > mes_fim_alvo)) break
    faltam <- c(faltam, sprintf("%dM%02d", a, m))
    m <- m + 1L; if (m > 12L) { m <- 1L; a <- a + 1L }
  }
  if (length(faltam) == 0) return(paste0("OK", suf))
  paste0("FALTA ", paste(faltam, collapse = " "), suf)
}

# Avalia status de fonte trimestral para o trimestre alvo
status_t <- function(cob, manual = FALSE) {
  suf <- if (manual) " *" else ""
  if (!cob$ok) return(paste0("N/A", suf))
  if (cob$ano > ano_alvo ||
      (cob$ano == ano_alvo && cob$trim >= trim_alvo)) return(paste0("OK", suf))
  paste0("FALTA ", ano_alvo, "T", trim_alvo, suf)
}

# ============================================================
# RELATÓRIO DE COBERTURA
# ============================================================

cat(sprintf("\n%s\n  RELATÓRIO DE COBERTURA — TRIMESTRE ALVO: %dT%d\n%s\n",
            divisor, ano_alvo, trim_alvo, divisor))
cat(sprintf("%-32s %-14s %s\n", "Fonte", "Fim atual", "Status para alvo"))
cat(divisor2, "\n")

pam_c    <- max_pam_cob()
lspa_c   <- max_lspa_cob()
abate_c  <- max_sidra_trim("data/raw/sidra/abate_rr.csv")
ovos_c   <- max_sidra_trim("data/raw/sidra/ovos_rr.csv")
ipca_c   <- max_ano_mes("data/raw/ipca_mensal.csv")
aneel_c  <- max_aneel_cob()
caged_c  <- max_caged_cob()
anp_c    <- max_ano_mes("data/raw/anp/anp_diesel_rr_mensal.csv")
estban_c <- max_ano_mes("data/raw/bcb/bcb_estban_rr_mensal.csv")
scr_c    <- max_ano_mes("data/raw/bcb/bcb_concessoes_rr_mensal.csv")
anac_c   <- max_ano_mes("data/raw/anac/anac_bvb_mensal.csv")
siape_c  <- max_ano_mes("data/raw/siape_rr_mensal.csv")
fiplan_c <- max_ano_mes("data/raw/folha_estadual_rr_mensal.csv")
icms_c   <- max_ano_trim_proc("data/processed/icms_sefaz_rr_trimestral.csv")

linhas <- list(
  list(nome = "PAM lavouras (anual/estrutural)", fim = pam_c$str,
       st   = if (pam_c$ok && pam_c$ano >= ano_pub) "OK (anual — estrutural)" else paste0("N/A: ", pam_c$str)),
  list(nome = "LSPA (leitura mais recente)",    fim = if (lspa_c$ok) lspa_c$str else "—",
       st   = if (lspa_c$ok) "OK (distribuído por calendário)" else "N/A"),
  list(nome = "Abate bovino (SIDRA 1092)",      fim = if (abate_c$ok) abate_c$str else "—",
       st   = status_t(abate_c)),
  list(nome = "Ovos (SIDRA 7524)",              fim = if (ovos_c$ok)  ovos_c$str  else "—",
       st   = status_t(ovos_c)),
  list(nome = "IPCA (SIDRA 1737)",              fim = if (ipca_c$ok)  ipca_c$str  else "—",
       st   = status_m(ipca_c)),
  list(nome = "ANEEL energia",                  fim = if (aneel_c$ok) aneel_c$str else "— (apagado)",
       st   = if (!aneel_c$ok) "Será re-baixado em run_all.R" else status_m(aneel_c)),
  list(nome = "CAGED (FTP MTE)",                fim = if (caged_c$ok) caged_c$str else "—",
       st   = status_m(caged_c)),
  list(nome = "ANP diesel",                     fim = if (anp_c$ok)   anp_c$str   else "—",
       st   = status_m(anp_c)),
  list(nome = "BCB Estban",                     fim = if (estban_c$ok) estban_c$str else "—",
       st   = status_m(estban_c, manual = TRUE)),
  list(nome = "BCB SCR (concessões)",           fim = if (scr_c$ok)   scr_c$str   else "—",
       st   = status_m(scr_c, manual = TRUE)),
  list(nome = "ANAC Boa Vista",                 fim = if (anac_c$ok)  anac_c$str  else "—",
       st   = status_m(anac_c, manual = TRUE)),
  list(nome = "SIAPE federal",                  fim = if (siape_c$ok) siape_c$str else "—",
       st   = status_m(siape_c, manual = TRUE)),
  list(nome = "FIPLAN estadual",                fim = if (fiplan_c$ok) fiplan_c$str else "—",
       st   = status_m(fiplan_c, manual = TRUE)),
  list(nome = "ICMS SEFAZ-RR",                 fim = if (icms_c$ok)  icms_c$str  else "—",
       st   = status_t(icms_c, manual = TRUE))
)

n_ok    <- 0L
n_falta <- 0L
for (l in linhas) {
  eh_ok <- grepl("^OK", l$st)
  if (eh_ok) n_ok <- n_ok + 1L else n_falta <- n_falta + 1L
  cat(sprintf("%-32s %-14s %s\n", l$nome, l$fim, l$st))
}

cat(divisor2, "\n")
cat("* fonte manual — baixar e colocar na pasta indicada antes de rodar run_all.R\n\n")
cat(sprintf("Fontes OK: %d | Fontes com pendências: %d\n\n", n_ok, n_falta))

if (n_falta == 0L) {
  cat(sprintf(
    "TODAS AS FONTES COBERTAS.\nPipeline pronto para produzir %dT%d.\n",
    ano_alvo, trim_alvo
  ))
  cat("Próximo passo: source(\"R/run_all.R\") para modelagem e inspeção interna.\n")
  cat("Após comunicar à imprensa: source(\"R/06_avanca_publicacao.R\")\n")
} else {
  cat(sprintf(
    "PENDÊNCIAS IDENTIFICADAS para %dT%d.\n",
    ano_alvo, trim_alvo
  ))
  cat("1. Baixar as fontes marcadas com FALTA (manuais: ver pasta bases_baixadas_manualmente/).\n")
  cat("2. Re-rodar source(\"R/06_coleta_fontes.R\") para confirmar cobertura.\n")
  cat("3. Quando todas OK: source(\"R/run_all.R\") para inspeção interna.\n")
}

message("\n=== 06_coleta_fontes.R concluído ===")
