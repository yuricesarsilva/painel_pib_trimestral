# ============================================================
# Projeto : Indicador de Atividade Econômica Trimestral — RR
# Script  : utils.R
# Autor   : Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)
# Data    : 2026-04-10
# Descrição: Funções auxiliares compartilhadas por todos os
#            scripts setoriais. Carregar com source("R/utils.R")
#            no início de cada script.
# Entrada : (nenhuma — apenas definições de funções)
# Saída   : (nenhuma — apenas definições de funções)
# Depende : tempdisagg
# ============================================================


# ============================================================
# LOGGING
# ============================================================

#' Imprime mensagem com timestamp no console
#'
#' @param msg  Texto da mensagem
#' @param nivel "INFO" (padrão), "AVISO" ou "ERRO"
log_msg <- function(msg, nivel = "INFO") {
  cat(sprintf("[%s][%s] %s\n",
    format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    nivel,
    msg
  ))
}


# ============================================================
# QA — VALIDAÇÃO DE SÉRIES TEMPORAIS
# ============================================================

#' Valida uma série temporal antes de salvar ou usar em cálculos
#'
#' Interrompe a execução (stop) se a série tiver problemas críticos.
#' Emite aviso (warning) para variações extremas — podem ser legítimas
#' (ex: colapso em 2020) mas devem ser inspecionadas manualmente.
#'
#' @param serie          Vetor numérico com valores em ordem temporal
#' @param nome_serie     Nome da série para mensagens de erro (string)
#' @param permite_na     Se FALSE (padrão), qualquer NA é erro crítico
#' @param variacao_max   Variação máxima período a período (padrão 0.50 = 50%)
#' @param n_min          Número mínimo de observações (padrão 4)
#'
#' @return invisible(TRUE) se passou; stop() se falhou
validar_serie <- function(serie, nome_serie,
                          permite_na     = FALSE,
                          variacao_max   = 0.50,
                          n_min          = 4) {

  erros    <- character(0)
  avisos   <- character(0)

  # 1. Comprimento mínimo
  if (length(serie) < n_min) {
    erros <- c(erros, sprintf(
      "comprimento insuficiente — %d obs. (mínimo esperado: %d)",
      length(serie), n_min
    ))
  }

  # 2. Valores NA
  n_na <- sum(is.na(serie))
  if (!permite_na && n_na > 0) {
    erros <- c(erros, sprintf("%d valor(es) NA encontrado(s)", n_na))
  }

  # 3. Valores zero ou negativos (índices de volume devem ser > 0)
  serie_valida <- serie[!is.na(serie)]
  if (length(serie_valida) > 0 && any(serie_valida <= 0)) {
    erros <- c(erros, sprintf(
      "%d valor(es) zero ou negativo(s) — índice de volume deve ser positivo",
      sum(serie_valida <= 0)
    ))
  }

  # 4. Variações extremas (aviso, não erro)
  if (length(serie_valida) >= 2) {
    variacoes <- abs(diff(serie_valida) / serie_valida[-length(serie_valida)])
    posicoes_extremas <- which(variacoes > variacao_max)
    if (length(posicoes_extremas) > 0) {
      avisos <- c(avisos, sprintf(
        "variação acima de %.0f%% em %d período(s) (posições: %s) — inspecionar manualmente",
        variacao_max * 100,
        length(posicoes_extremas),
        paste(posicoes_extremas, collapse = ", ")
      ))
    }
  }

  # Emite avisos
  for (av in avisos) {
    warning(sprintf("[%s] %s", nome_serie, av), call. = FALSE)
  }

  # Para na presença de erros críticos
  if (length(erros) > 0) {
    stop(sprintf(
      "\n[VALIDAÇÃO FALHOU — %s]\n%s\n",
      nome_serie,
      paste("  •", erros, collapse = "\n")
    ), call. = FALSE)
  }

  log_msg(sprintf("Série validada: %s (%d obs.)", nome_serie, length(serie)))
  invisible(TRUE)
}


# ============================================================
# DEFLAÇÃO
# ============================================================

#' Deflaciona uma série nominal pelo IPCA
#'
#' Constrói um índice de preços encadeado a partir das variações mensais
#' do IPCA e divide a série nominal pelo índice, ancorando no período base.
#'
#' @param valores_nominais  Vetor numérico de valores em preços correntes
#' @param ipca_var_pct      Vetor de variações mensais do IPCA em % (ex: 0.52 para 0,52%)
#'                          Deve ter o mesmo comprimento que valores_nominais
#' @param idx_base          Índice (posição) do período de referência no vetor
#'                          O deflator será = 1 neste período (padrão: primeiro período)
#'
#' @return Vetor numérico em preços constantes do período base
deflacionar <- function(valores_nominais, ipca_var_pct, idx_base = 1) {

  if (length(valores_nominais) != length(ipca_var_pct)) {
    stop("'valores_nominais' e 'ipca_var_pct' devem ter o mesmo comprimento.", call. = FALSE)
  }

  # Constrói índice de preços encadeado (base = 1 no período idx_base)
  fatores      <- 1 + ipca_var_pct / 100
  indice_preco <- cumprod(fatores)
  indice_preco <- indice_preco / indice_preco[idx_base]

  valores_reais <- valores_nominais / indice_preco
  return(valores_reais)
}


# ============================================================
# DESAGREGAÇÃO TEMPORAL — DENTON-CHOLETTE
# ============================================================

#' Aplica Denton-Cholette para desagregar série anual em trimestral
#'
#' Wrapper em torno de tempdisagg::td(). Garante que a média dos quatro
#' trimestres de cada ano reproduza o valor anual do benchmark (Contas Regionais).
#'
#' @param indicador_trim  Série trimestral de alta frequência (vetor numérico ou ts)
#'                        Usada como distribuidor da variação intra-anual
#' @param benchmark_anual Série anual de baixa frequência (vetor numérico ou ts)
#'                        Tipicamente: VAB anual das Contas Regionais do IBGE
#' @param ano_inicio      Primeiro ano da série (inteiro)
#' @param trimestre_ini   Primeiro trimestre (1 a 4, padrão 1)
#' @param metodo          Método Denton (padrão "proportional" — recomendado para índices)
#'
#' @return Vetor numérico com série trimestral ajustada ao benchmark
denton <- function(indicador_trim, benchmark_anual,
                   ano_inicio, trimestre_ini = 1,
                   metodo = "proportional") {

  if (!requireNamespace("tempdisagg", quietly = TRUE)) {
    stop("Pacote 'tempdisagg' necessário. Instalar com: install.packages('tempdisagg')", call. = FALSE)
  }

  # Garantir vetores numéricos univariados antes de converter em ts
  indicador_trim  <- as.numeric(indicador_trim)
  benchmark_anual <- as.numeric(benchmark_anual)

  # Converter para objetos ts univariados
  indicador_trim  <- ts(indicador_trim,
    start     = c(ano_inicio, trimestre_ini),
    frequency = 4
  )
  benchmark_anual <- ts(benchmark_anual,
    start     = ano_inicio,
    frequency = 1
  )

  # Métodos aceitos pelo tempdisagg: "denton-cholette", "denton", "chow-lin-maxlog",
  # "fernandez", "litterman-maxlog", "uniform", entre outros.
  # Padrão do projeto: "denton-cholette" (preserva movimento da série indicadora).
  # Para índices (média trimestral = benchmark anual), usar conversion = "mean".
  # IMPORTANTE: o Denton no tempdisagg requer fórmula sem intercepto (~ 0 + x).
  # A fórmula padrão (~ x) inclui intercepto implícito e gera matrix no RHS.
  # conversion = "mean": benchmark anual = média dos 4 trimestres (padrão de índices).
  modelo    <- tempdisagg::td(benchmark_anual ~ 0 + indicador_trim,
                              method     = metodo,
                              conversion = "mean")
  resultado <- as.numeric(predict(modelo))
  return(resultado)
}


# ============================================================
# ENCADEAMENTO — ÍNDICE DE LASPEYRES
# ============================================================

#' Calcula índice de Laspeyres de quantidade com pesos fixos
#'
#' Para cada período t, o índice é a média ponderada das quantidades
#' relativas ao período base, com pesos proporcionais ao VBP (ou VAB)
#' do período de referência.
#'
#' @param quantidades  Matrix ou data frame: linhas = períodos, colunas = produtos/culturas
#'                     Os valores devem ser quantidades físicas (não índices)
#' @param pesos        Vetor numérico de pesos (ex: VBP da PAM por cultura)
#'                     Deve ter o mesmo comprimento que o número de colunas de 'quantidades'
#' @param idx_base     Índice da linha (período) de referência para base = 100
#'                     Padrão: média de todos os períodos como base
#'
#' @return Vetor numérico com o índice de Laspeyres (base 100 no período idx_base)
laspeyres <- function(quantidades, pesos, idx_base = NULL) {

  quantidades <- as.matrix(quantidades)

  if (ncol(quantidades) != length(pesos)) {
    stop(sprintf(
      "Número de colunas em 'quantidades' (%d) difere do comprimento de 'pesos' (%d).",
      ncol(quantidades), length(pesos)
    ), call. = FALSE)
  }

  # Normaliza pesos para soma = 1
  w <- pesos / sum(pesos, na.rm = TRUE)

  # Índice não normalizado: soma ponderada das quantidades por período
  indice_bruto <- as.numeric(quantidades %*% w)

  # Define período base
  if (is.null(idx_base)) {
    base_valor <- mean(indice_bruto, na.rm = TRUE)
  } else {
    base_valor <- indice_bruto[idx_base]
  }

  indice <- (indice_bruto / base_valor) * 100
  return(indice)
}


# ============================================================
# UTILIDADES GERAIS
# ============================================================

#' Lê variável de ambiente obrigatória; para com mensagem clara se ausente
#'
#' @param nome_var  Nome da variável de ambiente (string)
#' @return Valor da variável (string)
ler_credencial <- function(nome_var) {
  val <- Sys.getenv(nome_var)
  if (nchar(val) == 0) {
    stop(sprintf(
      "Variável de ambiente '%s' não definida.\nConfigure o arquivo .env na raiz do projeto (ver .env.exemplo).",
      nome_var
    ), call. = FALSE)
  }
  return(val)
}

#' Agrega série mensal em trimestral por soma ou média
#'
#' @param valores   Vetor numérico de valores mensais (comprimento múltiplo de 3)
#' @param funcao    "soma" (padrão para fluxos) ou "media" (para estoques/índices)
#'
#' @return Vetor numérico de valores trimestrais
mensal_para_trimestral <- function(valores, funcao = "soma") {

  n <- length(valores)
  if (n %% 3 != 0) {
    stop(sprintf(
      "O vetor deve ter comprimento múltiplo de 3 (atual: %d).", n
    ), call. = FALSE)
  }

  grupos <- rep(seq_len(n / 3), each = 3)

  if (funcao == "soma") {
    resultado <- tapply(valores, grupos, sum, na.rm = TRUE)
  } else if (funcao == "media") {
    resultado <- tapply(valores, grupos, mean, na.rm = TRUE)
  } else {
    stop("'funcao' deve ser 'soma' ou 'media'.", call. = FALSE)
  }

  return(as.numeric(resultado))
}
