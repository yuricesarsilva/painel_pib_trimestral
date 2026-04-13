# ============================================================
# Projeto : Indicador de Atividade Econômica Trimestral — RR
# Script  : 05c_ajuste_sazonal.R
# Autor   : Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)
# Data    : 2026-04-12
# Fase    : 5.3 — Ajuste sazonal X-13ARIMA-SEATS
#
# Descrição:
#   Aplica X-13ARIMA-SEATS (pacote `seasonal`) ao índice geral e aos
#   quatro componentes setoriais. Publica duas versões de cada série:
#     - sem ajuste sazonal (série bruta, "NSA")
#     - com ajuste sazonal  (série dessazonalizada, "SA")
#
# Notas metodológicas:
#   - 24 trimestres (2020T1–2025T4): tamanho mínimo adequado para X-13
#   - 2020T1–2023T4: ancorados ao VAB das Contas Regionais (Denton)
#   - 2024T1–2025T4: extrapolados com tendência geométrica (provisório)
#   - Agropecuária tem sazonalidade muito forte (amplitude ~17x) →
#     transformação automática (log se multiplicativa)
#   - Outliers COVID (2020T1–T3) detectados automaticamente pelo X-13
#   - Fallback para suavização STL se X-13 não convergir
#
# Entrada : data/output/indice_geral_rr.csv
# Saída   : data/output/indice_geral_rr_sa.csv  (série completa NSA + SA)
#            data/output/fatores_sazonais.csv    (fatores por componente)
# Depende : dplyr, readr, seasonal
# ============================================================

library(dplyr)
library(readr)
library(seasonal)

dir_output <- file.path("data", "output")

arq_entrada <- file.path(dir_output, "indice_geral_rr.csv")
arq_saida   <- file.path(dir_output, "indice_geral_rr_sa.csv")
arq_fatores <- file.path(dir_output, "fatores_sazonais.csv")

# ============================================================
# ETAPA 5.3.1 — Carregar dados
# ============================================================

message("\n=== ETAPA 5.3.1: Carregando índice geral ===\n")

dados <- read_csv(arq_entrada, show_col_types = FALSE) |>
  arrange(ano, trimestre)

message(sprintf("Série: %d trimestres (%s a %s)",
                nrow(dados), dados$periodo[1], dados$periodo[nrow(dados)]))

ano_ini  <- dados$ano[1]
trim_ini <- dados$trimestre[1]

# Séries a ajustar
series_nomes <- c(
  "indice_geral",
  "indice_agropecuaria",
  "indice_aapp",
  "indice_industria",
  "indice_servicos"
)

# ============================================================
# ETAPA 5.3.2 — Função de ajuste sazonal com fallback STL
# ============================================================

#' Aplica X-13ARIMA-SEATS a um vetor numérico.
#' Se X-13 falhar, usa STL como fallback.
#'
#' @param x        vetor numérico da série
#' @param freq     frequência (4 = trimestral)
#' @param ano_ini  ano de início
#' @param trim_ini trimestre de início
#' @param nome     nome da série (para mensagens)
#' @return lista com: sa (série SA), fator (fator sazonal), metodo, aviso
ajustar_sazonal <- function(x, freq = 4, ano_ini, trim_ini = 1, nome = "") {

  ts_x <- ts(x, start = c(ano_ini, trim_ini), frequency = freq)

  # Tentativa 1: X-13 com detecção automática de transformação e outliers
  fit <- tryCatch(
    seas(
      ts_x,
      transform.function = "auto",   # X-13 decide log vs. nenhuma
      outlier            = "",        # detecta outliers (AO, LS, TC)
      x11                = ""         # forçar X-11 em vez de SEATS se necessário
    ),
    error = function(e) {
      message(sprintf("  [%s] X-13 modo 1 falhou: %s", nome, e$message))
      NULL
    }
  )

  # Tentativa 2: SEATS sem x11, sem detecção de outlier
  if (is.null(fit)) {
    fit <- tryCatch(
      seas(
        ts_x,
        transform.function = "auto",
        outlier.types      = "none"
      ),
      error = function(e) {
        message(sprintf("  [%s] X-13 modo 2 falhou: %s", nome, e$message))
        NULL
      }
    )
  }

  # Tentativa 3: sem transformação, sem outlier
  if (is.null(fit)) {
    fit <- tryCatch(
      seas(
        ts_x,
        transform.function = "none",
        outlier.types      = "none"
      ),
      error = function(e) {
        message(sprintf("  [%s] X-13 modo 3 falhou: %s", nome, e$message))
        NULL
      }
    )
  }

  if (!is.null(fit)) {
    sa_ts    <- final(fit)           # série SA
    fator_ts <- series(fit, "d10")  # fatores sazonais (S-I ratio ajustado)
    if (is.null(fator_ts)) fator_ts <- ts_x / sa_ts  # fallback para fator simples

    transf <- tryCatch(udg(fit, "finaltransformation"),
                       error = function(e) "?")
    n_out  <- tryCatch({
                out <- outlier(fit)
                # outlier() pode retornar df, vetor ou NULL — contar linhas/elementos
                if (is.data.frame(out)) nrow(out)
                else if (is.null(out))   0L
                else                     sum(nchar(as.character(out)) > 0)
              }, error = function(e) NA_integer_)
    message(sprintf("  [%s] X-13 concluído. Transformação: %s | Outliers: %s",
                    nome, transf,
                    if (is.na(n_out)) "n/d" else as.character(n_out)))

    return(list(
      sa     = as.numeric(sa_ts),
      fator  = as.numeric(fator_ts),
      metodo = "X-13ARIMA-SEATS",
      aviso  = ""
    ))
  }

  # Fallback: STL decomposition
  message(sprintf("  [%s] *** Fallback para STL ***", nome))
  stl_fit <- tryCatch(
    stl(ts_x, s.window = "periodic", robust = TRUE),
    error = function(e) {
      message(sprintf("  [%s] STL também falhou: %s — série original mantida.", nome, e$message))
      NULL
    }
  )

  if (!is.null(stl_fit)) {
    sa_vals    <- as.numeric(ts_x - stl_fit$time.series[, "seasonal"])
    fator_vals <- as.numeric(stl_fit$time.series[, "seasonal"])
    return(list(
      sa     = sa_vals,
      fator  = fator_vals,
      metodo = "STL (fallback)",
      aviso  = "X-13 não convergiu; ajuste via STL decomposition."
    ))
  }

  # Último recurso: sem ajuste
  message(sprintf("  [%s] Sem ajuste — série original retornada.", nome))
  return(list(
    sa     = as.numeric(ts_x),
    fator  = rep(1, length(x)),
    metodo = "nenhum",
    aviso  = "X-13 e STL falharam; série sem ajuste sazonal."
  ))
}

# ============================================================
# ETAPA 5.3.3 — Aplicar ajuste a cada série
# ============================================================

message("\n=== ETAPA 5.3.3: Ajuste sazonal por componente ===\n")

resultados_sa    <- list()
resultados_fator <- list()
metodos          <- character(length(series_nomes))
avisos           <- character(length(series_nomes))

for (i in seq_along(series_nomes)) {
  nm <- series_nomes[i]
  message(sprintf("\n--- %s ---", nm))

  x <- dados[[nm]]

  if (all(is.na(x))) {
    message(sprintf("  [%s] Série toda NA — pulando.", nm))
    resultados_sa[[nm]]    <- rep(NA_real_, nrow(dados))
    resultados_fator[[nm]] <- rep(NA_real_, nrow(dados))
    metodos[i] <- "NA"
    avisos[i]  <- "Série toda NA."
    next
  }

  res <- ajustar_sazonal(x,
                          freq     = 4,
                          ano_ini  = ano_ini,
                          trim_ini = trim_ini,
                          nome     = nm)

  resultados_sa[[nm]]    <- res$sa
  resultados_fator[[nm]] <- res$fator
  metodos[i] <- res$metodo
  avisos[i]  <- res$aviso
}

# ============================================================
# ETAPA 5.3.4 — Montar e exportar série completa NSA + SA
# ============================================================

message("\n=== ETAPA 5.3.4: Exportando séries NSA e SA ===\n")

# Série completa: original (NSA) + dessazonalizada (SA) para cada componente
resultado <- dados |>
  mutate(
    # Índice geral
    indice_geral_sa          = round(resultados_sa[["indice_geral"]], 6),
    # Componentes setoriais SA
    indice_agropecuaria_sa   = round(resultados_sa[["indice_agropecuaria"]], 6),
    indice_aapp_sa           = round(resultados_sa[["indice_aapp"]], 6),
    indice_industria_sa      = round(resultados_sa[["indice_industria"]], 6),
    indice_servicos_sa       = round(resultados_sa[["indice_servicos"]], 6)
  ) |>
  select(
    periodo, ano, trimestre,
    # Geral (NSA e SA)
    indice_geral, indice_geral_sa,
    # Setoriais NSA
    indice_agropecuaria, indice_aapp, indice_industria, indice_servicos,
    # Setoriais SA
    indice_agropecuaria_sa, indice_aapp_sa, indice_industria_sa, indice_servicos_sa
  )

write_csv(resultado, arq_saida)
message(sprintf("✓ Série NSA+SA salva: %s (%d obs.)", arq_saida, nrow(resultado)))

# ============================================================
# ETAPA 5.3.5 — Exportar fatores sazonais
# ============================================================

fatores <- dados |>
  select(periodo, ano, trimestre) |>
  mutate(
    fator_geral        = round(resultados_fator[["indice_geral"]], 6),
    fator_agropecuaria = round(resultados_fator[["indice_agropecuaria"]], 6),
    fator_aapp         = round(resultados_fator[["indice_aapp"]], 6),
    fator_industria    = round(resultados_fator[["indice_industria"]], 6),
    fator_servicos     = round(resultados_fator[["indice_servicos"]], 6)
  )

write_csv(fatores, arq_fatores)
message(sprintf("✓ Fatores sazonais salvos: %s", arq_fatores))

# ============================================================
# ETAPA 5.3.6 — Sumário de métodos e validação básica
# ============================================================

message("\n=== ETAPA 5.3.6: Sumário ===\n")

cat(sprintf("\n%s\n", strrep("=", 65)))
cat("SUMÁRIO — Ajuste sazonal X-13ARIMA-SEATS\n")
cat(sprintf("%s\n\n", strrep("=", 65)))

cat(sprintf("%-28s  %-22s  %s\n", "Série", "Método", "Aviso"))
cat(strrep("-", 75), "\n")
for (i in seq_along(series_nomes)) {
  cat(sprintf("%-28s  %-22s  %s\n",
              series_nomes[i], metodos[i],
              if (nchar(avisos[i]) > 0) avisos[i] else "ok"))
}

# Validação: variação anual da série SA (base 2020 = 100)
cat("\n\nVariações anuais — índice geral NSA vs. SA (média anual):\n\n")
cat(sprintf("%-6s  %12s  %12s\n", "Ano", "NSA (bruto)", "SA (dessaz.)"))
cat(strrep("-", 35), "\n")

medias <- resultado |>
  group_by(ano) |>
  summarise(
    nsa = mean(indice_geral,    na.rm = TRUE),
    sa  = mean(indice_geral_sa, na.rm = TRUE),
    n   = n(),
    .groups = "drop"
  ) |>
  filter(n == 4)

for (i in 2:nrow(medias)) {
  var_nsa <- (medias$nsa[i] / medias$nsa[i-1] - 1) * 100
  var_sa  <- (medias$sa[i]  / medias$sa[i-1]  - 1) * 100
  cat(sprintf("%d vs %d:  %+10.2f%%  %+10.2f%%\n",
              medias$ano[i], medias$ano[i-1], var_nsa, var_sa))
}

# Amplitude sazonal: para fatores aditivos, usar range (max - min)
# O fator d10 é aditivo: SA = NSA - fator (fator > 0 = acima da média sazonal)
fator_geral_vals <- fatores$fator_geral[!is.na(fatores$fator_geral)]
if (length(fator_geral_vals) > 0) {
  cat(sprintf(
    "\nFator sazonal (índice geral — aditivo): mín=%+.2f | máx=%+.2f | range=%.2f pts\n",
    min(fator_geral_vals), max(fator_geral_vals),
    max(fator_geral_vals) - min(fator_geral_vals)
  ))
}

fator_agro_vals <- fatores$fator_agropecuaria[!is.na(fatores$fator_agropecuaria)]
if (length(fator_agro_vals) > 0) {
  cat(sprintf(
    "Fator sazonal (agropecuária — aditivo): mín=%+.2f | máx=%+.2f | range=%.2f pts\n",
    min(fator_agro_vals), max(fator_agro_vals),
    max(fator_agro_vals) - min(fator_agro_vals)
  ))
}

# Variação residual da série SA (deve ser menor que a NSA)
cat(sprintf(
  "\nAmplitude pico/vale NSA (índice geral 2020–2023): %.1f → %.1f\n",
  min(dados$indice_geral[dados$ano <= 2023]),
  max(dados$indice_geral[dados$ano <= 2023])
))
cat(sprintf(
  "Amplitude pico/vale SA  (índice geral 2020–2023): %.1f → %.1f\n",
  min(resultado$indice_geral_sa[resultado$ano <= 2023]),
  max(resultado$indice_geral_sa[resultado$ano <= 2023])
))

cat("\n")
message(sprintf("\n=== Fase 5.3 concluída ==="))
message(sprintf("  Saídas:"))
message(sprintf("    %s", arq_saida))
message(sprintf("    %s", arq_fatores))
