# ============================================================
# Projeto : Indicador de Atividade Economica Trimestral - RR
# Script  : run_all.R
# Autor   : Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)
# Data    : 2026-04-10
# Descricao: Orquestrador do pipeline completo. Executa os
#            scripts setoriais na ordem correta, com registro
#            de tempo e parada imediata em caso de erro.
#            Usar este script para toda execucao de producao.
# Entrada : (nenhuma - chama os demais scripts)
# Saida   : todos os outputs gerados pelos scripts setoriais
# Depende : (nenhum pacote adicional - apenas base R)
# Nota    : Executar com o diretorio de trabalho na raiz do
#           projeto. Nunca rodar scripts setoriais avulsos fora
#           desta sequencia.
# ============================================================

# --- Verificacao do diretorio de trabalho -------------------

if (!file.exists("R/utils.R")) {
  stop(
    "Diretorio de trabalho incorreto.\n",
    "Execute este script com a raiz do projeto como working directory.\n",
    "No RStudio: abrir o .Rproj e usar Session > Set Working Directory > To Project Directory.",
    call. = FALSE
  )
}

# --- Gate de publicação --------------------------------------
source("config/release.R")
cat(sprintf(
  "\n>>> TRIMESTRE PUBLICADO: %s <<<\n    A exportação oficial será filtrada até este trimestre.\n    Para avançar: source(\"R/06_avanca_publicacao.R\")\n\n",
  trimestre_publicado
))

# --- Configuracao do pipeline --------------------------------

# Scripts a executar, na ordem obrigatoria
pipeline <- list(
  list(script = "R/00_dados_referencia.R", descricao = "Dados de referencia (Contas Regionais)"),
  list(script = "R/01_agropecuaria.R",     descricao = "Fase 1 - Agropecuaria"),
  list(script = "R/02_adm_publica.R",      descricao = "Fase 2 - Administracao Publica"),
  list(script = "R/03_industria.R",        descricao = "Fase 3 - Industria"),
  list(script = "R/04_servicos.R",         descricao = "Fase 4 - Servicos Privados"),
  list(script = "R/05_agregacao.R",        descricao = "Fase 5.1 - Agregacao e Outputs"),
  list(script = "R/05c_ajuste_sazonal.R",  descricao = "Fase 5.3 - Ajuste sazonal"),
  list(script = "R/05d_validacao.R",       descricao = "Fase 5.4 - Validacao final"),
  list(script = "R/05e_exportacao.R",      descricao = "Fase 5.5 - Exportacao"),
  list(script = "R/05f_vab_nominal.R",     descricao = "Fase 5.6 - VAB Nominal Trimestral"),
  list(script = "R/00b_icms_sefaz_atividade.R",
       descricao = "Fase 5.7 - ICMS por Atividade (shares trimestrais)"),
  list(script = "R/05g_pib_nominal.R",     descricao = "Fase 5.8 - PIB Nominal Trimestral"),
  list(script = "R/05h_vab_nominal_setorial.R",
       descricao = "Fase 5.9 - VAB Nominal Setorial Trimestral"),
  list(script = "R/05i_pib_real.R",        descricao = "Fase 5.10 - PIB Real Trimestral")
)

# --- Funcoes auxiliares de log -------------------------------

ts_fmt  <- function() format(Sys.time(), "%H:%M:%S")
divisor <- paste(rep("-", 60), collapse = "")

log_inicio <- function(descricao) {
  cat(sprintf("\n%s\n[%s] INICIANDO: %s\n%s\n", divisor, ts_fmt(), descricao, divisor))
}

log_ok <- function(descricao, duracao_seg) {
  cat(sprintf("[%s] OK: %s (%.1f s)\n", ts_fmt(), descricao, duracao_seg))
}

log_erro <- function(descricao, msg_erro) {
  cat(sprintf("\n[%s] ERRO: %s\n  Detalhe: %s\n", ts_fmt(), descricao, msg_erro))
}

# --- Execucao do pipeline ------------------------------------

cat(sprintf("\n%s\n  PIPELINE PIB TRIMESTRAL RR\n  Inicio: %s\n%s\n",
  divisor, format(Sys.time(), "%Y-%m-%d %H:%M:%S"), divisor))

resultados <- data.frame(
  script    = character(),
  descricao = character(),
  status    = character(),
  duracao_s = numeric(),
  stringsAsFactors = FALSE
)

for (etapa in pipeline) {

  # Pular scripts ainda nao implementados
  if (!file.exists(etapa$script)) {
    cat(sprintf("\n[%s] PULANDO (nao implementado): %s\n", ts_fmt(), etapa$script))
    resultados <- rbind(resultados, data.frame(
      script    = etapa$script,
      descricao = etapa$descricao,
      status    = "nao_implementado",
      duracao_s = 0,
      stringsAsFactors = FALSE
    ))
    next
  }

  log_inicio(etapa$descricao)
  t_inicio <- proc.time()["elapsed"]

  resultado <- tryCatch({
    source(etapa$script, local = new.env(parent = globalenv()))
    "ok"
  }, error = function(e) {
    log_erro(etapa$descricao, conditionMessage(e))
    conditionMessage(e)
  })

  duracao <- proc.time()["elapsed"] - t_inicio

  if (resultado == "ok") {
    log_ok(etapa$descricao, duracao)
    status <- "ok"
  } else {
    # Para imediatamente - nao continuar com dado incorreto
    stop(sprintf(
      "\nPipeline interrompido em: %s\nMotivo: %s\n\nCorrija o erro e rode run_all.R novamente.",
      etapa$script, resultado
    ), call. = FALSE)
  }

  resultados <- rbind(resultados, data.frame(
    script    = etapa$script,
    descricao = etapa$descricao,
    status    = status,
    duracao_s = round(duracao, 1),
    stringsAsFactors = FALSE
  ))
}

# --- Resumo final --------------------------------------------

cat(sprintf("\n%s\n  PIPELINE CONCLUIDO - %s\n%s\n",
  divisor, format(Sys.time(), "%Y-%m-%d %H:%M:%S"), divisor))
cat("\nResumo por etapa:\n")
for (i in seq_len(nrow(resultados))) {
  cat(sprintf("  [%-16s] %s (%s s)\n",
    resultados$status[i],
    resultados$descricao[i],
    resultados$duracao_s[i]
  ))
}

cat(sprintf(
  "\nTrimestre publicado : %s\nExportacao oficial  : filtrada ate %s (IAET_RR_series.xlsx e CSVs publicos)\n",
  trimestre_publicado, trimestre_publicado
))
cat(sprintf(
  "Para avançar o release: source(\"R/06_avanca_publicacao.R\")\n\nProximos passos:\n  1. Inspecionar outputs em data/output/ para validacao interna\n  2. Atualizar logs/fontes_utilizadas.csv\n  3. Quando pronto para publicar: rodar 06_avanca_publicacao.R\n\n"
))
