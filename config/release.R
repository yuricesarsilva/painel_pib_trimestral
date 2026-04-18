# ============================================================
# Projeto : Indicador de Atividade Econômica Trimestral — RR
# Arquivo : config/release.R
# Fase    : 6 — Gate de publicação trimestral
#
# Este arquivo controla qual trimestre está oficialmente
# publicado pelo IAET-RR. A exportação do pipeline (05e) e
# o orquestrador (run_all) lêem esta variável para filtrar
# os arquivos de saída.
#
# COMO AVANÇAR:
#   1. Garantir que todos os dados do próximo trimestre estão
#      disponíveis (conferir via 06_coleta_fontes.R).
#   2. Gerar informativos internos e comunicar à imprensa.
#   3. Rodar: source("R/06_avanca_publicacao.R")
#      O script fará o checklist, atualizará este arquivo,
#      criará o commit e a tag git automaticamente.
#
# NÃO editar este arquivo manualmente fora do fluxo acima.
# ============================================================

trimestre_publicado <- "2025T4"
