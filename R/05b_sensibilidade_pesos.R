# ============================================================
# Projeto : PIB Trimestral de Roraima
# Script  : 05b_sensibilidade_pesos.R
# Autor   : Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)
# Data    : 2026-04-15
# Fase    : 5.2 — Sensibilidade dos pesos das proxies compostas
#
# Descrição:
#   Para cada setor com pesos definidos ad hoc, realiza busca em
#   grade sobre todas as combinações de pesos (passo 5%, soma = 1)
#   e identifica os pesos que minimizam o critério interno do
#   Denton-Cholette:
#
#     Objetivo = sum( diff(output[t] / proxy[t])^2 )
#
#   Interpretação: um proxy perfeito tem razão output/proxy
#   constante no tempo — o Denton não precisa "sacolejar" a série
#   para bater o benchmark anual. O objetivo mede essa oscilação.
#   Pesos ótimos = proxy que o Denton menos distorce.
#
# Setores analisados — pesos anteriores à otimização (ad hoc, pré-2026-04-15):
#   - Ind. Transformação : energia industrial 70% + CAGED C 30%
#   - Comércio           : energia com. 40% + ICMS 40% + CAGED G 20%
#   - Transportes        : pax ANAC 40% + carga ANAC 30% + diesel 30%
#   - Financeiro         : concessões BCB 70% + depósitos Estban 30%
#
# Pesos adotados após otimização (aplicados em produção desde 2026-04-15):
#   - Ind. Transformação : energia industrial 55% + CAGED C 45%
#   - Comércio           : energia com. 60% + ICMS 20% + CAGED G 20% (conservador)
#   - Transportes        : pax ANAC 55% + carga ANAC 0% + diesel 45%
#   - Financeiro         : concessões BCB 40% + depósitos Estban 60%
#
# Entrada : data/output/sensibilidade/proxies_transformacao.csv
#            data/output/sensibilidade/proxies_servicos.csv
#            data/processed/contas_regionais_RR_volume.csv
# Saída   : data/output/sensibilidade/pesos_otimos.csv
#            data/output/sensibilidade/grid_completo.csv
# Depende : dplyr, readr, tidyr, tempdisagg, R/utils.R
# Nota    : Este script é exploratório (não faz parte do pipeline
#           de produção). Rodar após run_all.R para garantir que
#           os arquivos de proxies estejam atualizados.
# ============================================================

source("R/utils.R")

library(dplyr)
library(readr)
library(tidyr)

# ---- Caminhos -----------------------------------------------

dir_output <- file.path("data", "output")
dir_sens   <- file.path(dir_output, "sensibilidade")
dir_proc   <- file.path("data", "processed")

arq_transf  <- file.path(dir_sens, "proxies_transformacao.csv")
arq_serv    <- file.path(dir_sens, "proxies_servicos.csv")
arq_vol_cr  <- file.path(dir_proc, "contas_regionais_RR_volume.csv")

for (arq in c(arq_transf, arq_serv, arq_vol_cr)) {
  if (!file.exists(arq))
    stop("Arquivo ausente: ", arq,
         "\n  Execute run_all.R antes deste script.", call. = FALSE)
}

# ---- Parâmetros ---------------------------------------------

anos_cr    <- 2020:2023   # anos com benchmark oficial das CR
passo_grid <- 0.05        # incremento no grid de pesos (5%)

# ====================================================================
# BLOCO 1 — Funções auxiliares
# ====================================================================

#' Calcula o critério interno do Denton-Cholette para uma proxy
#' composta com pesos dados.
#'
#' @param proxy  vetor numérico trimestral (≥ 1 observação por benchmark)
#' @param bench  vetor numérico anual (benchmark CR)
#' @param ano_ini  inteiro — primeiro ano do proxy trimestral
#' @return escalar: sum(diff(output/proxy)^2) — menor = melhor
objetivo_denton <- function(proxy, bench, ano_ini) {
  n_b <- length(bench)
  n_p <- length(proxy)
  if (n_p < n_b * 4)           return(Inf)
  if (any(is.na(proxy)))        return(Inf)
  if (any(proxy <= 0))          return(Inf)
  if (any(is.na(bench)))        return(Inf)
  if (any(bench <= 0))          return(Inf)

  out <- tryCatch(
    denton(proxy, bench, ano_inicio = ano_ini, metodo = "denton-cholette"),
    error = function(e) NULL
  )
  if (is.null(out)) return(Inf)

  ratio <- as.numeric(out) / as.numeric(proxy[seq_along(out)])
  sum(diff(ratio)^2, na.rm = TRUE)
}

#' Gera grade de pesos para n componentes (soma = 1, passos passo_grid)
#' Retorna data.frame com colunas w1, w2, [w3]
grade_pesos <- function(n_comp, passo = passo_grid) {
  vals <- round(seq(0, 1, by = passo), 10)
  if (n_comp == 2) {
    grd <- data.frame(w1 = vals, w2 = round(1 - vals, 10))
    return(grd[grd$w1 >= 0 & grd$w2 >= 0, ])
  }
  if (n_comp == 3) {
    grd <- expand.grid(w1 = vals, w2 = vals)
    grd$w3 <- round(1 - grd$w1 - grd$w2, 10)
    return(grd[grd$w3 >= 0 & grd$w1 >= 0 & grd$w2 >= 0, ])
  }
  stop("grade_pesos suporta apenas 2 ou 3 componentes.", call. = FALSE)
}

#' Executa busca em grade para um setor e retorna resultado completo
#'
#' @param df_proxy  data.frame com colunas ano, trimestre, e as proxies
#' @param nomes_comp  vetor de nomes das colunas de proxy
#' @param bench_anual  vetor numérico — benchmark anual (ordenado por ano)
#' @param pesos_atuais  vetor numérico — pesos de produção atuais
#' @param nome_setor  string — nome para mensagens e output
busca_grade <- function(df_proxy, nomes_comp, bench_anual,
                         pesos_atuais, nome_setor) {

  n_comp <- length(nomes_comp)
  message(sprintf("\n--- %s (%d componentes) ---", nome_setor, n_comp))

  # Filtrar apenas o período de benchmark e verificar completude
  df_bench <- df_proxy |> filter(ano %in% anos_cr) |> arrange(ano, trimestre)

  for (nm in nomes_comp) {
    n_na <- sum(is.na(df_bench[[nm]]))
    if (n_na > 0)
      message(sprintf("  AVISO: %s tem %d NAs no período de benchmark.", nm, n_na))
  }

  ano_ini <- min(anos_cr)

  # Função de proxy composta (média ponderada dos componentes disponíveis)
  proxy_composta <- function(pesos_vec) {
    mat <- as.matrix(df_bench |> select(all_of(nomes_comp)))
    ok  <- !is.na(mat)                              # matriz lógica
    # Para cada trimestre, média ponderada dos disponíveis
    vapply(seq_len(nrow(mat)), function(i) {
      p <- pesos_vec[ok[i, ]]
      v <- mat[i, ok[i, ]]
      if (length(v) == 0 || sum(p) == 0) return(NA_real_)
      sum(v * p) / sum(p)
    }, numeric(1))
  }

  # Objetivo com pesos atuais
  prx_atual <- proxy_composta(pesos_atuais)
  obj_atual <- objetivo_denton(prx_atual, bench_anual, ano_ini)
  message(sprintf("  Objetivo (pesos atuais %s): %.6f",
                  paste0(round(pesos_atuais * 100), "%", collapse = "/"),
                  obj_atual))

  # Grade de pesos
  grd <- grade_pesos(n_comp)
  n_grd <- nrow(grd)
  message(sprintf("  Avaliando %d combinações de pesos...", n_grd))

  resultados <- lapply(seq_len(n_grd), function(i) {
    pw <- as.numeric(grd[i, ])
    prx <- proxy_composta(pw)
    obj <- objetivo_denton(prx, bench_anual, ano_ini)
    c(pw, objetivo = obj)
  })

  res_df <- as.data.frame(do.call(rbind, resultados))
  names(res_df) <- c(paste0("w", seq_len(n_comp)), "objetivo")
  res_df$setor <- nome_setor

  # Melhor combinação
  idx_min <- which.min(res_df$objetivo)
  pesos_otimos <- as.numeric(res_df[idx_min, paste0("w", seq_len(n_comp))])
  obj_otimo    <- res_df$objetivo[idx_min]

  melhoria <- if (is.finite(obj_atual) && obj_atual > 0)
    (obj_atual - obj_otimo) / obj_atual * 100 else NA_real_

  message(sprintf("  Objetivo (pesos ótimos  %s): %.6f",
                  paste0(round(pesos_otimos * 100), "%", collapse = "/"),
                  obj_otimo))
  message(sprintf("  Melhoria: %.1f%%", melhoria))

  list(
    grid    = res_df,
    resumo  = data.frame(
      setor          = nome_setor,
      componentes    = paste(nomes_comp, collapse = " + "),
      pesos_atuais   = paste0(round(pesos_atuais * 100), "%", collapse = "/"),
      pesos_otimos   = paste0(round(pesos_otimos * 100), "%", collapse = "/"),
      objetivo_atual = round(obj_atual,  6),
      objetivo_otimo = round(obj_otimo,  6),
      melhoria_pct   = round(melhoria,   1),
      stringsAsFactors = FALSE
    ),
    pesos_otimos_vec = setNames(pesos_otimos, nomes_comp)
  )
}

# ====================================================================
# BLOCO 2 — Carregar dados
# ====================================================================

message("\n=== Carregando dados ===\n")

vol_cr <- read_csv(arq_vol_cr, show_col_types = FALSE)

bench_setor <- function(padrao) {
  vol_cr |>
    filter(grepl(padrao, atividade, ignore.case = TRUE),
           ano %in% anos_cr) |>
    arrange(ano) |>
    pull(vab_volume_rebased)
}

proxies_transf <- read_csv(arq_transf, show_col_types = FALSE)
proxies_serv   <- read_csv(arq_serv,   show_col_types = FALSE)

message(sprintf("Proxies Transformação: %d trimestres, colunas: %s",
                nrow(proxies_transf), paste(names(proxies_transf), collapse = ", ")))
message(sprintf("Proxies Serviços:      %d trimestres, colunas: %s",
                nrow(proxies_serv),   paste(names(proxies_serv),   collapse = ", ")))

# ====================================================================
# BLOCO 3 — Análise por setor
# ====================================================================

resultados_lista <- list()
grids_lista      <- list()

# ------------------------------------------------------------------
# 3.1 Indústria de Transformação
# ------------------------------------------------------------------

bench_transf <- bench_setor("transforma")

if (length(bench_transf) == length(anos_cr) &&
    "indice_energia_ind" %in% names(proxies_transf) &&
    "indice_emprego_c"   %in% names(proxies_transf)) {

  r_transf <- busca_grade(
    df_proxy     = proxies_transf,
    nomes_comp   = c("indice_energia_ind", "indice_emprego_c"),
    bench_anual  = bench_transf,
    pesos_atuais = c(0.70, 0.30),
    nome_setor   = "Ind. Transformacao"
  )
  resultados_lista[["transf"]] <- r_transf$resumo
  grids_lista[["transf"]]      <- r_transf$grid

} else {
  message("Ind. Transformação: proxies incompletas ou benchmark ausente — pulando.")
}

# ------------------------------------------------------------------
# 3.2 Comércio
# ------------------------------------------------------------------

bench_com <- bench_setor("Com.rcio")

comp_com_disp <- intersect(c("com_energia", "com_icms", "com_caged_g"),
                            names(proxies_serv))

if (length(bench_com) == length(anos_cr) && length(comp_com_disp) >= 2) {

  # Pesos atuais de produção (na ordem dos componentes disponíveis)
  pesos_com_ref <- c(com_energia = 0.40, com_icms = 0.40, com_caged_g = 0.20)
  pesos_com_atual <- pesos_com_ref[comp_com_disp]
  pesos_com_atual <- pesos_com_atual / sum(pesos_com_atual)  # renormalizar se componente ausente

  r_com <- busca_grade(
    df_proxy     = proxies_serv,
    nomes_comp   = comp_com_disp,
    bench_anual  = bench_com,
    pesos_atuais = pesos_com_atual,
    nome_setor   = "Comercio"
  )
  resultados_lista[["com"]] <- r_com$resumo
  grids_lista[["com"]]      <- r_com$grid

} else {
  message("Comércio: proxies insuficientes ou benchmark ausente — pulando.")
}

# ------------------------------------------------------------------
# 3.3 Transportes
# ------------------------------------------------------------------

bench_transp <- bench_setor("Transporte")

comp_transp_disp <- intersect(c("transp_pax", "transp_carga", "transp_diesel"),
                               names(proxies_serv))

if (length(bench_transp) == length(anos_cr) && length(comp_transp_disp) >= 2) {

  pesos_transp_ref <- c(transp_pax = 0.40, transp_carga = 0.30, transp_diesel = 0.30)
  pesos_transp_atual <- pesos_transp_ref[comp_transp_disp]
  pesos_transp_atual <- pesos_transp_atual / sum(pesos_transp_atual)

  r_transp <- busca_grade(
    df_proxy     = proxies_serv,
    nomes_comp   = comp_transp_disp,
    bench_anual  = bench_transp,
    pesos_atuais = pesos_transp_atual,
    nome_setor   = "Transportes"
  )
  resultados_lista[["transp"]] <- r_transp$resumo
  grids_lista[["transp"]]      <- r_transp$grid

} else {
  message("Transportes: proxies insuficientes ou benchmark ausente — pulando.")
}

# ------------------------------------------------------------------
# 3.4 Financeiro
# ------------------------------------------------------------------

bench_fin <- bench_setor("financeiras")

comp_fin_disp <- intersect(c("fin_concessoes", "fin_depositos"),
                            names(proxies_serv))

if (length(bench_fin) == length(anos_cr) && length(comp_fin_disp) >= 2) {

  pesos_fin_ref <- c(fin_concessoes = 0.70, fin_depositos = 0.30)
  pesos_fin_atual <- pesos_fin_ref[comp_fin_disp]

  r_fin <- busca_grade(
    df_proxy     = proxies_serv,
    nomes_comp   = comp_fin_disp,
    bench_anual  = bench_fin,
    pesos_atuais = pesos_fin_atual,
    nome_setor   = "Financeiro"
  )
  resultados_lista[["fin"]] <- r_fin$resumo
  grids_lista[["fin"]]      <- r_fin$grid

} else {
  message("Financeiro: proxies insuficientes ou benchmark ausente — pulando.")
}

# ====================================================================
# BLOCO 4 — Consolidar e salvar
# ====================================================================

message("\n=== Consolidando resultados ===\n")

if (length(resultados_lista) == 0) {
  message("Nenhum setor pôde ser analisado. Verificar arquivos de proxy.")
} else {

  resumo_final <- bind_rows(resultados_lista)
  grid_final   <- bind_rows(grids_lista)

  write_csv(resumo_final, file.path(dir_sens, "pesos_otimos.csv"))
  write_csv(grid_final,   file.path(dir_sens, "grid_completo.csv"))

  message(sprintf("✓ Resultados salvos em: %s", dir_sens))
  message(sprintf("  pesos_otimos.csv   — %d setores", nrow(resumo_final)))
  message(sprintf("  grid_completo.csv  — %d combinações avaliadas", nrow(grid_final)))

  message("\n=== TABELA RESUMO ===\n")
  cat(sprintf("%-22s %-30s %-30s %10s %10s %10s\n",
              "Setor", "Pesos atuais", "Pesos ótimos",
              "Obj.atual", "Obj.ótimo", "Melhoria%"))
  cat(strrep("-", 120), "\n")
  for (i in seq_len(nrow(resumo_final))) {
    r <- resumo_final[i, ]
    cat(sprintf("%-22s %-30s %-30s %10.4f %10.4f %9.1f%%\n",
                r$setor,
                r$pesos_atuais,
                r$pesos_otimos,
                r$objetivo_atual,
                r$objetivo_otimo,
                r$melhoria_pct))
  }

  # Aviso se melhoria relevante
  cat("\n")
  grandes <- resumo_final[!is.na(resumo_final$melhoria_pct) &
                           resumo_final$melhoria_pct > 10, ]
  if (nrow(grandes) > 0) {
    message("ATENÇÃO: os seguintes setores têm melhoria > 10% com pesos ótimos:")
    for (i in seq_len(nrow(grandes))) {
      message(sprintf("  %s: %s → %s (%.1f%% de melhoria)",
                      grandes$setor[i],
                      grandes$pesos_atuais[i],
                      grandes$pesos_otimos[i],
                      grandes$melhoria_pct[i]))
    }
    message("  Considere atualizar os pesos de produção nos scripts setoriais.")
  } else {
    message("OK: nenhum setor tem melhoria > 10%. Pesos de produção razoáveis.")
  }
}

message("\n=== Fase 5.2 (Sensibilidade de Pesos) concluída ===")
message(sprintf("  Resultados em: %s", dir_sens))
