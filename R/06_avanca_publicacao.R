# ============================================================
# Projeto : Indicador de Atividade Econômica Trimestral — RR
# Script  : 06_avanca_publicacao.R
# Autor   : Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)
# Fase    : 6 — Avanço controlado do release trimestral
#
# Descrição:
#   Conduz o checklist obrigatório antes de avançar o
#   trimestre publicado. Só prossegue se todos os itens forem
#   confirmados. Ao final:
#     - Atualiza config/release.R com o novo trimestre
#     - Faz commit git com mensagem padronizada
#     - Cria tag git (ex: v2026-Q1)
#     - Orienta a rodar run_all.R para a publicação oficial
#
# Uso: source("R/06_avanca_publicacao.R")
#      (requer sessão interativa — não usar em modo batch)
# ============================================================

if (!file.exists("R/utils.R")) {
  stop("Diretório de trabalho incorreto. Execute na raiz do projeto.", call. = FALSE)
}

source("config/release.R")

divisor <- paste(rep("=", 65), collapse = "")

# --- Calcular próximo trimestre ------------------------------

ano_pub  <- as.integer(sub("T.*", "", trimestre_publicado))
trim_pub <- as.integer(sub(".*T", "", trimestre_publicado))
trim_prox <- if (trim_pub < 4L) trim_pub + 1L else 1L
ano_prox  <- if (trim_pub < 4L) ano_pub       else ano_pub + 1L
proximo <- sprintf("%dT%d", ano_prox, trim_prox)

# Rótulo de tag git: v2026-Q1, v2026-Q2 etc.
tag_git <- sprintf("v%d-Q%d", ano_prox, trim_prox)

cat(sprintf("\n%s\n  AVANÇO DE PUBLICAÇÃO: %s → %s\n%s\n\n",
            divisor, trimestre_publicado, proximo, divisor))

# --- Checklist obrigatório ----------------------------------

itens <- list(
  list(id = 1, texto = "Dados de todas as fontes conferidos e completos para o trimestre"),
  list(id = 2, texto = "run_all.R executado sem erros com os dados do trimestre"),
  list(id = 3, texto = "Validações automáticas (05d_validacao.R) sem alertas críticos"),
  list(id = 4, texto = "Dashboard atualizado e verificado visualmente"),
  list(id = 5, texto = "Informativos internos SEPLAN gerados e aprovados"),
  list(id = 6, texto = "Comunicação à imprensa realizada")
)

cat("Confirme cada item antes de prosseguir (s = sim / n = não):\n\n")

for (item in itens) {
  repeat {
    resp <- tryCatch(
      tolower(trimws(readline(sprintf("  [%d] %s? (s/n): ", item$id, item$texto)))),
      error = function(e) "n"
    )
    if (resp %in% c("s", "n")) break
    cat("      Responda s ou n.\n")
  }
  if (resp != "s") {
    cat(sprintf(
      "\nItem [%d] não confirmado. Avanço cancelado.\nConclua os pendentes e rode novamente.\n\n",
      item$id
    ))
    invisible(return(NULL))
  }
}

cat(sprintf(
  "\nTodos os itens confirmados.\n\nAvançar trimestre_publicado de %s para %s? (s/n): ",
  trimestre_publicado, proximo
))
confirmacao <- tryCatch(
  tolower(trimws(readline())),
  error = function(e) "n"
)
if (confirmacao != "s") {
  cat("Avanço cancelado pelo usuário.\n")
  invisible(return(NULL))
}

# --- Atualizar config/release.R -----------------------------

novo_conteudo <- sprintf(
'# ============================================================
# Projeto : Indicador de Atividade Economica Trimestral - RR
# Arquivo : config/release.R
# Fase    : 6 - Gate de publicacao trimestral
#
# Este arquivo controla qual trimestre esta oficialmente
# publicado pelo IAET-RR. A exportacao do pipeline (05e) e
# o orquestrador (run_all) leem esta variavel para filtrar
# os arquivos de saida.
#
# COMO AVANCAR:
#   1. Garantir que todos os dados do proximo trimestre estao
#      disponiveis (conferir via 06_coleta_fontes.R).
#   2. Gerar informativos internos e comunicar a imprensa.
#   3. Rodar: source("R/06_avanca_publicacao.R")
#      O script fara o checklist, atualizara este arquivo,
#      criara o commit e a tag git automaticamente.
#
# NAO editar este arquivo manualmente fora do fluxo acima.
# ============================================================

trimestre_publicado <- "%s"
', proximo)

writeLines(novo_conteudo, "config/release.R")
cat(sprintf("\nconfig/release.R atualizado: trimestre_publicado <- \"%s\"\n", proximo))

# --- Commit e tag git ---------------------------------------

msg_commit <- sprintf(
  'Avanca publicacao para %s\n\nChecklist confirmado por %s em %s.\nTag: %s\n\nCo-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>',
  proximo,
  Sys.getenv("USERNAME", unset = "usuario"),
  format(Sys.Date(), "%Y-%m-%d"),
  tag_git
)

ret_add <- system('git add config/release.R', intern = FALSE)
ret_commit <- system(
  sprintf('git commit -m "%s"', gsub('"', "'", msg_commit)),
  intern = FALSE
)
ret_tag <- system(sprintf('git tag %s', tag_git), intern = FALSE)

if (ret_commit == 0L) {
  cat(sprintf("Commit criado com sucesso.\n"))
} else {
  cat("AVISO: commit git falhou. Verifique manualmente.\n")
}
if (ret_tag == 0L) {
  cat(sprintf("Tag git criada: %s\n", tag_git))
} else {
  cat(sprintf("AVISO: tag %s falhou (pode já existir). Verifique manualmente.\n", tag_git))
}

cat(sprintf("Para enviar ao repositório remoto:\n  git push && git push origin %s\n\n", tag_git))

# --- Instrução final ----------------------------------------

cat(sprintf(
  "%s\n  PRÓXIMO PASSO\n%s\n\nRode agora:\n  source(\"R/run_all.R\")\n\nO pipeline irá exportar os dados oficialmente com %s.\nApós verificar os arquivos em data/output/, distribua:\n  - data/output/IAET_RR_series.xlsx\n  - data/output/IAET_RR_geral.csv\n  - data/output/IAET_RR_componentes.csv\n\n",
  divisor, divisor, proximo
))

message("=== 06_avanca_publicacao.R concluído ===")
