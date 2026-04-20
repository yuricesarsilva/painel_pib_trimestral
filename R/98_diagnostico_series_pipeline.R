source("R/utils.R")

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(stringr)
  library(ggplot2)
})

dir_output <- file.path("data", "output", "diagnostico_series_pipeline")
dir_raw <- file.path("data", "raw")
dir_raw_sidra <- file.path(dir_raw, "sidra")
dir_processed <- file.path("data", "processed")
dir_notas <- file.path("notas", "metodologia")
arq_relatorio <- file.path(dir_notas, "diagnostico_series_pipeline.md")

dir.create(dir_output, recursive = TRUE, showWarnings = FALSE)

ano_inicio <- 2020L
ano_publicado <- 2025L
trimestre_publicado <- 4L

fmt_num <- function(x, digits = 2) {
  ifelse(is.na(x), "NA", format(round(x, digits), decimal.mark = ",", big.mark = ".", nsmall = digits))
}

periodo_mensal_seq <- function(ano_ini, mes_ini, ano_fim, mes_fim) {
  out <- character()
  ano <- ano_ini
  mes <- mes_ini
  repeat {
    out <- c(out, sprintf("%04dM%02d", ano, mes))
    if (ano == ano_fim && mes == mes_fim) break
    mes <- mes + 1L
    if (mes == 13L) {
      mes <- 1L
      ano <- ano + 1L
    }
  }
  out
}

periodo_bimestral_seq <- function(ano_ini, bim_ini, ano_fim, bim_fim) {
  out <- character()
  ano <- ano_ini
  bim <- bim_ini
  repeat {
    out <- c(out, sprintf("%04dB%d", ano, bim))
    if (ano == ano_fim && bim == bim_fim) break
    bim <- bim + 1L
    if (bim == 7L) {
      bim <- 1L
      ano <- ano + 1L
    }
  }
  out
}

periodo_trimestral_seq <- function(ano_ini, trim_ini, ano_fim, trim_fim) {
  out <- character()
  ano <- ano_ini
  trim <- trim_ini
  repeat {
    out <- c(out, sprintf("%04dT%d", ano, trim))
    if (ano == ano_fim && trim == trim_fim) break
    trim <- trim + 1L
    if (trim == 5L) {
      trim <- 1L
      ano <- ano + 1L
    }
  }
  out
}

contar_cobertura <- function(df, period_col, value_col, expected_periods = NULL) {
  df2 <- df |>
    mutate(
      .periodo = as.character(.data[[period_col]]),
      .valor = suppressWarnings(as.numeric(.data[[value_col]]))
    )

  obs <- unique(df2$.periodo[!is.na(df2$.periodo)])
  if (is.null(expected_periods)) expected_periods <- sort(obs)

  tibble(
    observacoes = nrow(df2),
    periodos_observados = length(obs),
    na_valor = sum(is.na(df2$.valor)),
    faltantes_grade = sum(!expected_periods %in% obs),
    primeiro_periodo = if (length(obs) > 0) min(obs) else NA_character_,
    ultimo_periodo = if (length(obs) > 0) max(obs) else NA_character_,
    periodos_faltantes = paste(head(expected_periods[!expected_periods %in% obs], 8), collapse = ", ")
  )
}

rebase_media_2020 <- function(df, value_col, out_col = "indice") {
  base_2020 <- df |>
    filter(ano == 2020) |>
    summarise(base = mean(.data[[value_col]], na.rm = TRUE)) |>
    pull(base)
  df |>
    mutate(!!out_col := .data[[value_col]] / base_2020 * 100)
}

preparar_dual_axis <- function(df_long, threshold = 2.0) {
  maxes <- df_long |>
    group_by(serie) |>
    summarise(max_val = max(abs(indice), na.rm = TRUE), .groups = "drop")
  med_max <- median(maxes$max_val, na.rm = TRUE)
  outliers <- maxes |> filter(max_val > threshold * med_max) |> pull(serie)

  if (length(outliers) == 0) return(list(df = df_long, sf = NULL, caption = NULL))

  main_max <- max(maxes$max_val[!maxes$serie %in% outliers], na.rm = TRUE)
  out_max  <- max(maxes$max_val[maxes$serie %in% outliers], na.rm = TRUE)
  sf <- main_max / out_max
  fator <- round(out_max / main_max, 1)

  caption <- sprintf(
    "Eixo direito (\u2192): %s. Amplitude ~%.0fx superior \u00e0s demais s\u00e9ries; escala independente.",
    paste(outliers, collapse = ", "), fator
  )

  df_long <- df_long |>
    mutate(
      indice = if_else(serie %in% outliers, indice * sf, indice),
      serie  = if_else(serie %in% outliers, paste0(serie, " \u2192"), serie)
    )
  list(df = df_long, sf = sf, caption = caption)
}

aplicar_dual_axis <- function(g, sf) {
  if (is.null(sf)) return(g)
  g + scale_y_continuous(
    name = "Índice (média 2020 = 100) — eixo esquerdo",
    sec.axis = sec_axis(~ . / sf, name = "Índice (média 2020 = 100) — eixo direito →")
  )
}

salvar_grafico <- function(df_long, titulo, nome_arquivo, nota = NULL, threshold = 2.0) {
  prep <- preparar_dual_axis(df_long, threshold = threshold)
  cap <- paste(c(prep$caption, nota), collapse = "\n") |> trimws()
  g <- ggplot(prep$df, aes(x = periodo, y = indice, color = serie, group = serie)) +
    geom_line(linewidth = 0.8, alpha = 0.95) +
    labs(
      title = titulo, x = NULL, y = "Índice (média 2020 = 100)", color = NULL,
      caption = if (nchar(cap) > 0) cap else NULL
    ) +
    theme_minimal(base_size = 11) +
    theme(
      legend.position = "bottom",
      axis.text.x = element_text(angle = 45, hjust = 1),
      plot.caption = element_text(hjust = 0, size = 8, color = "grey40")
    )
  g <- aplicar_dual_axis(g, prep$sf)
  ggsave(file.path(dir_output, nome_arquivo), plot = g, width = 10, height = 5.5, dpi = 150)
}

salvar_grafico_trimestral <- function(df_long, titulo, nome_arquivo, nota = NULL, threshold = 2.0) {
  prep <- preparar_dual_axis(df_long, threshold = threshold)
  cap <- paste(c(prep$caption, nota), collapse = "\n") |> trimws()
  ordem_periodos <- prep$df |> distinct(periodo) |> arrange(periodo) |> pull(periodo)
  g <- ggplot(
    prep$df |> mutate(periodo = factor(periodo, levels = ordem_periodos)),
    aes(x = periodo, y = indice, color = serie, group = serie)
  ) +
    geom_line(linewidth = 0.8, alpha = 0.95) +
    labs(
      title = titulo, x = NULL, y = "Índice (média 2020 = 100)", color = NULL,
      caption = if (nchar(cap) > 0) cap else NULL
    ) +
    theme_minimal(base_size = 11) +
    theme(
      legend.position = "bottom",
      axis.text.x = element_text(angle = 45, hjust = 1),
      plot.caption = element_text(hjust = 0, size = 8, color = "grey40")
    )
  g <- aplicar_dual_axis(g, prep$sf)
  ggsave(file.path(dir_output, nome_arquivo), plot = g, width = 10, height = 5.5, dpi = 150)
}

normalizar_trim_sidra <- function(df, descricao, filtro_extra = NULL) {
  nomes <- names(df)
  col_periodo <- nomes[grepl("Trimestre.*Código|Código.*Trimestre", nomes, ignore.case = TRUE)][1]
  if (is.na(col_periodo)) {
    col_periodo <- nomes[grepl("^Trimestre$", nomes, ignore.case = TRUE)][1]
  }
  col_valor <- names(df)[grepl("^Valor$", names(df), ignore.case = TRUE)][1]
  col_var <- names(df)[grepl("^Variável$|Variável", names(df), ignore.case = TRUE)][1]

  out <- df
  if (!is.null(filtro_extra)) out <- filtro_extra(out)

  if (!is.na(col_var)) {
    total_trimestre <- grep("Total do trimestre", out[[col_var]], ignore.case = TRUE, value = TRUE)
    if (length(total_trimestre) > 0) {
      out <- out |> filter(.data[[col_var]] %in% total_trimestre[1])
    }
  }

  out |>
    transmute(
      periodo = as.character(.data[[col_periodo]]),
      ano = as.integer(substr(periodo, 1, 4)),
      trimestre = suppressWarnings(as.integer(substr(periodo, nchar(periodo), nchar(periodo)))),
      valor = suppressWarnings(as.numeric(gsub(",", ".", .data[[col_valor]], fixed = TRUE)))
    ) |>
    filter(!is.na(ano), !is.na(trimestre), !is.na(valor))
}

parse_ipca_mensal <- function(df) {
  col_mes <- names(df)[grepl("Mês .*Código|Código.*Mês", names(df), ignore.case = TRUE)][1]
  col_val <- names(df)[grepl("^Valor$", names(df), ignore.case = TRUE)][1]
  df |>
    transmute(
      periodo = sprintf("%sM%s", substr(.data[[col_mes]], 1, 4), substr(.data[[col_mes]], 5, 6)),
      ano = as.integer(substr(.data[[col_mes]], 1, 4)),
      mes = as.integer(substr(.data[[col_mes]], 5, 6)),
      valor = suppressWarnings(as.numeric(gsub(",", ".", .data[[col_val]], fixed = TRUE)))
    ) |>
    filter(!is.na(ano), !is.na(mes))
}

parse_sidra_mensal <- function(df) {
  col_mes <- names(df)[grepl("Mês .*Código|Código.*Mês", names(df), ignore.case = TRUE)][1]
  col_val <- names(df)[grepl("^Valor$", names(df), ignore.case = TRUE)][1]
  df |>
    transmute(
      periodo = sprintf("%sM%s", substr(.data[[col_mes]], 1, 4), substr(.data[[col_mes]], 5, 6)),
      ano = as.integer(substr(.data[[col_mes]], 1, 4)),
      mes = as.integer(substr(.data[[col_mes]], 5, 6)),
      valor = suppressWarnings(as.numeric(gsub(",", ".", .data[[col_val]], fixed = TRUE)))
    ) |>
    filter(!is.na(ano), !is.na(mes), !is.na(valor))
}

read_csv2_safe <- function(path) {
  read_csv(path, show_col_types = FALSE)
}

# -------------------------------------------------------------------------
# Carga das séries
# -------------------------------------------------------------------------

indice_agro <- read_csv2_safe(file.path("data", "output", "indice_agropecuaria.csv"))
indice_aapp <- read_csv2_safe(file.path("data", "output", "indice_adm_publica.csv"))
indice_ind <- read_csv2_safe(file.path("data", "output", "indice_industria.csv"))
indice_serv <- read_csv2_safe(file.path("data", "output", "indice_servicos.csv"))
indice_nom <- read_csv2_safe(file.path("data", "output", "indice_nominal_rr.csv"))
ilp_trim <- read_csv2_safe(file.path("data", "output", "ilp_rr_trimestral.csv"))

serie_pec <- read_csv2_safe(file.path(dir_processed, "serie_pecuaria_trimestral.csv"))
serie_lav <- read_csv2_safe(file.path(dir_processed, "serie_lavouras_trimestral.csv"))
serie_cult <- read_csv2_safe(file.path(dir_processed, "serie_culturas_trimestral.csv"))
proxies_serv <- read_csv2_safe(file.path("data", "output", "sensibilidade", "proxies_servicos.csv"))
proxies_transf <- read_csv2_safe(file.path("data", "output", "sensibilidade", "proxies_transformacao.csv"))
icms_trim <- read_csv2_safe(file.path(dir_processed, "icms_sefaz_rr_trimestral.csv"))

siape <- read_csv2_safe(file.path(dir_raw, "siape_rr_mensal.csv")) |>
  mutate(periodo = sprintf("%04dM%02d", ano, mes))

estadual <- read_csv2_safe(file.path(dir_raw, "folha_estadual_rr_mensal.csv")) |>
  mutate(periodo = sprintf("%04dM%02d", ano, mes))

municipal <- read_csv2_safe(file.path(dir_raw, "folha_municipal_rr.csv")) |>
  mutate(periodo = sprintf("%04dB%d", ano, bimestre))

municipios_col <- names(municipal)[grepl("municip", names(municipal), ignore.case = TRUE)][1]
municipal_diag <- if (!is.na(municipios_col)) {
  grade_bim_ref <- periodo_bimestral_seq(2020, 1, 2025, 6)

  municipal |>
    mutate(municipio = .data[[municipios_col]]) |>
    group_by(municipio) |>
    summarise(
      primeiro_periodo_observado = if (all(is.na(periodo))) NA_character_ else min(periodo, na.rm = TRUE),
      ultimo_periodo_observado = if (all(is.na(periodo))) NA_character_ else max(periodo, na.rm = TRUE),
      .groups = "drop"
    ) |>
    rowwise() |>
    mutate(
      n_observacoes_janela_2020_2025 = sum(
        municipal$periodo[municipal[[municipios_col]] == municipio] %in% grade_bim_ref,
        na.rm = TRUE
      ),
      n_faltantes_janela_2020_2025 = length(grade_bim_ref) - n_observacoes_janela_2020_2025,
      periodos_faltantes = paste(
        grade_bim_ref[
          !grade_bim_ref %in% municipal$periodo[municipal[[municipios_col]] == municipio]
        ],
        collapse = ", "
      )
    ) |>
    ungroup()
} else {
  tibble(
    municipio = character(),
    primeiro_periodo_observado = character(),
    ultimo_periodo_observado = character(),
    n_observacoes_janela_2020_2025 = integer(),
    n_faltantes_janela_2020_2025 = integer(),
    periodos_faltantes = character()
  )
}

ipca <- parse_ipca_mensal(read_csv2_safe(file.path(dir_raw, "ipca_mensal.csv")))
pmc <- parse_sidra_mensal(read_csv2_safe(file.path(dir_raw_sidra, "pmc_rr.csv")))
pms <- parse_sidra_mensal(read_csv2_safe(file.path(dir_raw_sidra, "pms_rr.csv")))

anac <- read_csv2_safe(file.path(dir_raw, "anac", "anac_bvb_mensal.csv")) |>
  mutate(periodo = sprintf("%04dM%02d", ano, mes))

anp <- read_csv2_safe(file.path(dir_raw, "anp", "anp_diesel_rr_mensal.csv")) |>
  mutate(periodo = sprintf("%04dM%02d", ano, mes))

estban <- read_csv2_safe(file.path(dir_raw, "bcb", "bcb_estban_rr_mensal.csv")) |>
  mutate(periodo = sprintf("%04dM%02d", ano, mes))

concessoes <- read_csv2_safe(file.path(dir_raw, "bcb", "bcb_concessoes_rr_mensal.csv")) |>
  mutate(periodo = sprintf("%04dM%02d", ano, mes))

aneel <- read_csv2_safe(file.path(dir_raw, "aneel", "aneel_energia_rr.csv")) |>
  mutate(
    ano = as.integer(substr(as.character(data), 1, 4)),
    mes = as.integer(substr(as.character(data), 6, 7)),
    periodo = sprintf("%04dM%02d", ano, mes)
  )

caged <- read_csv2_safe(file.path(dir_raw, "caged", "caged_rr_mensal.csv")) |>
  mutate(periodo = sprintf("%04dM%02d", ano, mes))

abate_raw <- normalizar_trim_sidra(
  read_csv2_safe(file.path(dir_raw_sidra, "abate_rr.csv")),
  "Abate",
  filtro_extra = function(df) {
    col_reb <- names(df)[grepl("Tipo de rebanho bovino", names(df), ignore.case = TRUE) &
                           !grepl("Código", names(df), ignore.case = TRUE)][1]
    if (!is.na(col_reb)) {
      df <- df |> filter(grepl("Total", .data[[col_reb]], ignore.case = TRUE))
    }
    df
  }
) |>
  rename(abate = valor)

ovos_raw <- normalizar_trim_sidra(
  read_csv2_safe(file.path(dir_raw_sidra, "ovos_rr.csv")),
  "Ovos",
  filtro_extra = function(df) {
    col_final <- names(df)[grepl("Finalidade da produção", names(df), ignore.case = TRUE) &
                             !grepl("Código", names(df), ignore.case = TRUE)][1]
    if (!is.na(col_final)) {
      df <- df |> filter(grepl("^Total$", .data[[col_final]], ignore.case = TRUE))
    }
    df
  }
) |>
  rename(ovos = valor)

abate_idx <- abate_raw |>
  group_by(ano, trimestre) |>
  summarise(abate = mean(abate, na.rm = TRUE), .groups = "drop") |>
  rebase_media_2020("abate", "indice") |>
  filter(ano >= 2020, ano <= 2025) |>
  mutate(serie = "Abate bovino")

ovos_idx <- ovos_raw |>
  group_by(ano, trimestre) |>
  summarise(ovos = mean(ovos, na.rm = TRUE), .groups = "drop") |>
  rebase_media_2020("ovos", "indice") |>
  filter(ano >= 2020, ano <= 2025) |>
  mutate(serie = "Ovos")

grade_mensal_2020_2025 <- periodo_mensal_seq(2020, 1, 2025, 12)
grade_trimestral_2020_2025 <- periodo_trimestral_seq(2020, 1, 2025, 4)
grade_bimestral_2020_2025 <- periodo_bimestral_seq(2020, 1, 2025, 6)

# -------------------------------------------------------------------------
# Tabela de diagnóstico das séries
# -------------------------------------------------------------------------

diag_tbl <- bind_rows(
  contar_cobertura(siape, "periodo", "folha_bruta", grade_mensal_2020_2025) |>
    mutate(
      bloco = "AAPP",
      atividade = "Folha federal",
      serie = "SIAPE",
      arquivo = "data/raw/siape_rr_mensal.csv",
      periodicidade = "Mensal",
      tratamento_na = "Interpolação linear de meses ausentes no código",
      uso_no_indice = "Somada à folha estadual e municipal; depois deflacionada"
    ),
  contar_cobertura(estadual, "periodo", "valor_mes", grade_mensal_2020_2025) |>
    mutate(
      bloco = "AAPP",
      atividade = "Folha estadual",
      serie = "FIPLAN FIP855",
      arquivo = "data/raw/folha_estadual_rr_mensal.csv",
      periodicidade = "Mensal",
      tratamento_na = "Sem correção específica; ausência entra como 0 na soma final",
      uso_no_indice = "Somada à folha federal e municipal; depois deflacionada"
    ),
  tibble(
    observacoes = nrow(municipal),
    periodos_observados = municipal_diag$n_observacoes_janela_2020_2025 |> sum(na.rm = TRUE),
    na_valor = sum(is.na(municipal$valor_acum)),
    faltantes_grade = municipal_diag$n_faltantes_janela_2020_2025 |> sum(na.rm = TRUE),
    primeiro_periodo = min(municipal_diag$primeiro_periodo_observado, na.rm = TRUE),
    ultimo_periodo = max(municipal_diag$ultimo_periodo_observado, na.rm = TRUE),
    periodos_faltantes = paste(head(municipal_diag$periodos_faltantes[municipal_diag$n_faltantes_janela_2020_2025 > 0], 4), collapse = " | ")
  ) |>
    mutate(
      bloco = "AAPP",
      atividade = "Folha municipal",
      serie = "SICONFI RREO Anexo 06",
      arquivo = "data/raw/folha_municipal_rr.csv",
      periodicidade = "Bimestral acumulada",
      tratamento_na = "Conversão acumulado->incremental; há municípios com cobertura incompleta; ausência entra como 0 na soma final",
      uso_no_indice = "Convertida para trimestral e somada à folha estadual e federal"
    ),
  contar_cobertura(ipca, "periodo", "valor", grade_mensal_2020_2025) |>
    mutate(
      bloco = "Deflação",
      atividade = "IPCA",
      serie = "IPCA mensal",
      arquivo = "data/raw/ipca_mensal.csv",
      periodicidade = "Mensal",
      tratamento_na = "Sem imputação; usado como nível de preços",
      uso_no_indice = "Deflator da AAPP e proxy temporal dos deflatores trimestrais"
    ),
  contar_cobertura(abate_raw |> mutate(periodo = sprintf("%04dT%d", ano, trimestre)), "periodo", "abate", grade_trimestral_2020_2025) |>
    mutate(
      bloco = "Agropecuária",
      atividade = "Pecuária",
      serie = "Abate bovino",
      arquivo = "data/raw/sidra/abate_rr.csv",
      periodicidade = "Trimestral",
      tratamento_na = "Sem fallback; completude é exigida na janela operacional",
      uso_no_indice = "Média ponderada com ovos na proxy de pecuária"
    ),
  contar_cobertura(ovos_raw |> mutate(periodo = sprintf("%04dT%d", ano, trimestre)), "periodo", "ovos", grade_trimestral_2020_2025) |>
    mutate(
      bloco = "Agropecuária",
      atividade = "Pecuária",
      serie = "Ovos",
      arquivo = "data/raw/sidra/ovos_rr.csv",
      periodicidade = "Trimestral",
      tratamento_na = "Sem fallback; completude é exigida na janela operacional",
      uso_no_indice = "Média ponderada com abate bovino na proxy de pecuária"
    ),
  contar_cobertura(serie_lav |> filter(ano >= 2020), "periodo", "indice_lavouras", grade_trimestral_2020_2025) |>
    mutate(
      bloco = "Agropecuária",
      atividade = "Lavouras",
      serie = "Índice de lavouras",
      arquivo = "data/processed/serie_lavouras_trimestral.csv",
      periodicidade = "Trimestral",
      tratamento_na = "PAM e LSPA são combinadas; sem imputação direta por NA",
      uso_no_indice = "Média ponderada de 10 culturas com pesos de VBP e calendário"
    ),
  contar_cobertura(serie_pec |> filter(ano >= 2020), "periodo", "indice_pecuaria", grade_trimestral_2020_2025) |>
    mutate(
      bloco = "Agropecuária",
      atividade = "Pecuária",
      serie = "Índice de pecuária",
      arquivo = "data/processed/serie_pecuaria_trimestral.csv",
      periodicidade = "Trimestral",
      tratamento_na = "Sem fallback; só é gerado com cobertura completa",
      uso_no_indice = "Componente da média ponderada do índice agro"
    ),
  contar_cobertura(aneel |> filter(classe == "Comercial"), "periodo", "energia_kwh", grade_mensal_2020_2025) |>
    mutate(
      bloco = "Serviços",
      atividade = "Comércio",
      serie = "ANEEL comercial",
      arquivo = "data/raw/aneel/aneel_energia_rr.csv",
      periodicidade = "Mensal",
      tratamento_na = "Sem imputação; se faltar, peso é redistribuído",
      uso_no_indice = "Componente da média ponderada do comércio"
    ),
  contar_cobertura(pmc |> filter(ano >= 2020), "periodo", "valor", grade_mensal_2020_2025) |>
    mutate(
      bloco = "Serviços",
      atividade = "Comércio",
      serie = "PMC",
      arquivo = "data/raw/sidra/pmc_rr.csv",
      periodicidade = "Mensal",
      tratamento_na = "Sem imputação; se faltar, peso é redistribuído",
      uso_no_indice = "Componente da média ponderada do comércio"
    ),
  contar_cobertura(icms_trim |> mutate(periodo = sprintf("%04dT%d", ano, trimestre)), "periodo", "icms_comercio_mi", grade_trimestral_2020_2025) |>
    mutate(
      bloco = "Serviços",
      atividade = "Comércio",
      serie = "ICMS comércio",
      arquivo = "data/processed/icms_sefaz_rr_trimestral.csv",
      periodicidade = "Trimestral",
      tratamento_na = "Se faltar, peso é redistribuído; no ILP faltantes viram 0",
      uso_no_indice = "Componente da média ponderada do comércio; também alimenta o ILP"
    ),
  contar_cobertura(caged |> filter(secao == "G"), "periodo", "saldo", grade_mensal_2020_2025) |>
    mutate(
      bloco = "Serviços",
      atividade = "Comércio",
      serie = "CAGED G",
      arquivo = "data/raw/caged/caged_rr_mensal.csv",
      periodicidade = "Mensal",
      tratamento_na = "Meses ausentes são completados com saldo=0 no código",
      uso_no_indice = "Componente da média ponderada do comércio"
    ),
  contar_cobertura(anac, "periodo", "pax_total", grade_mensal_2020_2025) |>
    mutate(
      bloco = "Serviços",
      atividade = "Transportes",
      serie = "ANAC passageiros",
      arquivo = "data/raw/anac/anac_bvb_mensal.csv",
      periodicidade = "Mensal",
      tratamento_na = "Sem imputação; se faltar, pesos são redistribuídos",
      uso_no_indice = "Componente da média ponderada dos transportes"
    ),
  contar_cobertura(anp, "periodo", "diesel_m3", grade_mensal_2020_2025) |>
    mutate(
      bloco = "Serviços",
      atividade = "Transportes",
      serie = "ANP diesel",
      arquivo = "data/raw/anp/anp_diesel_rr_mensal.csv",
      periodicidade = "Mensal",
      tratamento_na = "Sem imputação; se faltar, pesos são redistribuídos",
      uso_no_indice = "Componente da média ponderada dos transportes"
    ),
  contar_cobertura(estban, "periodo", "depositos", grade_mensal_2020_2025) |>
    mutate(
      bloco = "Serviços",
      atividade = "Financeiro",
      serie = "BCB Estban",
      arquivo = "data/raw/bcb/bcb_estban_rr_mensal.csv",
      periodicidade = "Mensal",
      tratamento_na = "Deflação pelo IPCA; se faltar, pesos são redistribuídos",
      uso_no_indice = "Componente da média ponderada do financeiro"
    ),
  contar_cobertura(concessoes, "periodo", "concessoes", grade_mensal_2020_2025) |>
    mutate(
      bloco = "Serviços",
      atividade = "Financeiro",
      serie = "BCB Concessões",
      arquivo = "data/raw/bcb/bcb_concessoes_rr_mensal.csv",
      periodicidade = "Mensal",
      tratamento_na = "Deflação pelo IPCA; se faltar, pesos são redistribuídos",
      uso_no_indice = "Componente da média ponderada do financeiro"
    ),
  contar_cobertura(
    read_csv2_safe(file.path(dir_raw, "aneel", "aneel_consumidores_residenciais_rr.csv")) |>
      mutate(periodo = sprintf("%04dM%02d", ano, mes)),
    "periodo", "consumidores_residenciais", grade_mensal_2020_2025
  ) |>
    mutate(
      bloco = "Serviços",
      atividade = "Imobiliário",
      serie = "ANEEL consumidores residenciais",
      arquivo = "data/raw/aneel/aneel_consumidores_residenciais_rr.csv",
      periodicidade = "Mensal",
      tratamento_na = "Sem imputação; usado como indicador temporal no Denton do subsetor",
      uso_no_indice = "Indicador temporal do índice de atividades imobiliárias"
    ),
  contar_cobertura(caged |> filter(secao == "I"), "periodo", "saldo", grade_mensal_2020_2025) |>
    mutate(
      bloco = "Serviços",
      atividade = "Outros serviços",
      serie = "CAGED I",
      arquivo = "data/raw/caged/caged_rr_mensal.csv",
      periodicidade = "Mensal",
      tratamento_na = "Meses ausentes são completados com saldo=0 no código",
      uso_no_indice = "Componente da média ponderada de outros serviços"
    ),
  contar_cobertura(caged |> filter(secao %in% c("M", "N")) |> group_by(periodo) |> summarise(saldo = sum(saldo, na.rm = TRUE), .groups = "drop"), "periodo", "saldo", grade_mensal_2020_2025) |>
    mutate(
      bloco = "Serviços",
      atividade = "Outros serviços",
      serie = "CAGED M+N",
      arquivo = "data/raw/caged/caged_rr_mensal.csv",
      periodicidade = "Mensal",
      tratamento_na = "Meses ausentes são completados com saldo=0 no código",
      uso_no_indice = "Componente da média ponderada de outros serviços"
    ),
  contar_cobertura(caged |> filter(secao %in% c("P", "Q")) |> group_by(periodo) |> summarise(saldo = sum(saldo, na.rm = TRUE), .groups = "drop"), "periodo", "saldo", grade_mensal_2020_2025) |>
    mutate(
      bloco = "Serviços",
      atividade = "Outros serviços",
      serie = "CAGED P+Q",
      arquivo = "data/raw/caged/caged_rr_mensal.csv",
      periodicidade = "Mensal",
      tratamento_na = "Meses ausentes são completados com saldo=0 no código",
      uso_no_indice = "Componente da média ponderada de outros serviços"
    ),
  contar_cobertura(pms |> filter(ano >= 2020), "periodo", "valor", grade_mensal_2020_2025) |>
    mutate(
      bloco = "Serviços",
      atividade = "Outros serviços / InfoCom",
      serie = "PMS",
      arquivo = "data/raw/sidra/pms_rr.csv",
      periodicidade = "Mensal",
      tratamento_na = "Sem imputação; se faltar, pesos são redistribuídos",
      uso_no_indice = "Componente da média ponderada de outros serviços e infocom"
    ),
  contar_cobertura(caged |> filter(secao == "J"), "periodo", "saldo", grade_mensal_2020_2025) |>
    mutate(
      bloco = "Serviços",
      atividade = "InfoCom",
      serie = "CAGED J",
      arquivo = "data/raw/caged/caged_rr_mensal.csv",
      periodicidade = "Mensal",
      tratamento_na = "Meses ausentes são completados com saldo=0 no código",
      uso_no_indice = "Componente da média ponderada de informação e comunicação"
    ),
  contar_cobertura(aneel |> filter(classe == "Industrial"), "periodo", "energia_kwh", grade_mensal_2020_2025) |>
    mutate(
      bloco = "Indústria",
      atividade = "Transformação",
      serie = "ANEEL industrial",
      arquivo = "data/raw/aneel/aneel_energia_rr.csv",
      periodicidade = "Mensal",
      tratamento_na = "Sem imputação; se faltar, transformação usa proxy remanescente",
      uso_no_indice = "Componente da média ponderada da transformação"
    ),
  contar_cobertura(caged |> filter(secao == "C"), "periodo", "saldo", grade_mensal_2020_2025) |>
    mutate(
      bloco = "Indústria",
      atividade = "Transformação",
      serie = "CAGED C",
      arquivo = "data/raw/caged/caged_rr_mensal.csv",
      periodicidade = "Mensal",
      tratamento_na = "Meses ausentes são completados com saldo=0 no código",
      uso_no_indice = "Componente da média ponderada da transformação"
    ),
  contar_cobertura(caged |> filter(secao == "F"), "periodo", "saldo", grade_mensal_2020_2025) |>
    mutate(
      bloco = "Indústria",
      atividade = "Construção",
      serie = "CAGED F",
      arquivo = "data/raw/caged/caged_rr_mensal.csv",
      periodicidade = "Mensal",
      tratamento_na = "Meses ausentes são completados com saldo=0 no código",
      uso_no_indice = "Proxy única da construção na configuração atual"
    ),
  contar_cobertura(indice_ind |> mutate(periodo = sprintf("%04dT%d", ano, trimestre)),
                   "periodo", "indice_extrativas", grade_trimestral_2020_2025) |>
    mutate(
      bloco = "Indústria",
      atividade = "Extrativas",
      serie = "Índice extrativas",
      arquivo = "data/output/indice_industria.csv",
      periodicidade = "Trimestral",
      tratamento_na = "Sem proxy própria; distribuição trimestral suave a partir do benchmark anual CR via Denton",
      uso_no_indice = "Componente do índice industrial com peso de VAB 2020"
    ),
  contar_cobertura(indice_nom, "periodo", "deflator_trimestral", grade_trimestral_2020_2025) |>
    mutate(
      bloco = "Deflação",
      atividade = "Deflator trimestral",
      serie = "Deflator implícito trimestral",
      arquivo = "data/output/indice_nominal_rr.csv",
      periodicidade = "Trimestral",
      tratamento_na = "Denton com fallback para IPCA reescalado se necessário",
      uso_no_indice = "Deflator do VAB nominal e insumo do PIB real"
    ),
  contar_cobertura(icms_trim |> mutate(periodo = sprintf("%04dT%d", ano, trimestre)), "periodo", "icms_total_mi", grade_trimestral_2020_2025) |>
    mutate(
      bloco = "Impostos",
      atividade = "ILP / impostos",
      serie = "ICMS total trimestral",
      arquivo = "data/processed/icms_sefaz_rr_trimestral.csv",
      periodicidade = "Trimestral",
      tratamento_na = "No PIB nominal, faltantes do indicador entram como 0 no Denton do ILP",
      uso_no_indice = "Indicador temporal do ILP trimestral"
    ),
  contar_cobertura(ilp_trim |> filter(ano <= 2025), "periodo", "ilp_nominal_mi", grade_trimestral_2020_2025) |>
    mutate(
      bloco = "Impostos",
      atividade = "ILP / impostos",
      serie = "ILP trimestral",
      arquivo = "data/output/ilp_rr_trimestral.csv",
      periodicidade = "Trimestral",
      tratamento_na = "Denton-Cholette com benchmark anual e ICMS como indicador",
      uso_no_indice = "Somado ao VAB nominal para formar o PIB nominal"
    )
) |>
  select(
    bloco, atividade, serie, arquivo, periodicidade, observacoes,
    periodos_observados, na_valor, faltantes_grade, primeiro_periodo,
    ultimo_periodo, periodos_faltantes, tratamento_na, uso_no_indice
  ) |>
  arrange(bloco, atividade, serie)

write_csv(diag_tbl, file.path(dir_output, "resumo_series.csv"))

# -------------------------------------------------------------------------
# Tabela de composição metodológica
# -------------------------------------------------------------------------

composicao_tbl <- tibble::tribble(
  ~bloco, ~atividade, ~combinacao,
  "Agropecuária", "Lavouras", "Média ponderada das 10 culturas com pesos de VBP da PAM; distribuição trimestral via calendário de colheita e LSPA/PAM",
  "Agropecuária", "Pecuária", "Média ponderada entre abate bovino e ovos",
  "Agropecuária", "Índice agropecuário", "Média ponderada entre lavouras e pecuária; depois Denton-Cholette contra benchmark anual de volume",
  "AAPP", "Índice de administração pública", "Soma nominal de folha estadual + municipal + federal; deflação pelo IPCA; depois Denton-Cholette contra benchmark anual",
  "Indústria", "SIUP", "Proxy única baseada na energia elétrica total distribuída pela ANEEL; depois Denton-Cholette contra benchmark anual",
  "Indústria", "Transformação", "Média ponderada entre energia industrial ANEEL e CAGED C",
  "Indústria", "Construção", "Proxy única baseada em CAGED F na configuração atual",
  "Indústria", "Extrativas", "Sem proxy própria de mercado; série trimestral distribuída a partir do benchmark anual das Contas Regionais via Denton-Cholette",
  "Indústria", "Índice industrial", "Média ponderada entre SIUP, Construção, Transformação e Extrativas com pesos de VAB 2020",
  "Serviços", "Comércio", "Média ponderada entre energia comercial, PMC, ICMS comércio e CAGED G",
  "Serviços", "Transportes", "Média ponderada entre passageiros ANAC e diesel ANP; carga ANAC permanece só no diagnóstico",
  "Serviços", "Financeiro", "Média ponderada entre concessões BCB e depósitos Estban, ambos deflacionados",
  "Serviços", "Imobiliário", "Denton-Cholette entre benchmarks anuais das Contas Regionais, usando consumidores residenciais da ANEEL como indicador temporal",
  "Serviços", "Outros serviços", "Média ponderada entre CAGED I, CAGED M+N, CAGED P+Q e PMS",
  "Serviços", "Informação e comunicação", "Média ponderada entre CAGED J e PMS",
  "Serviços", "Índice de serviços", "Média ponderada entre 6 subsetores com pesos de VAB 2020; ancoragem anual por Denton",
  "Deflação", "Deflator trimestral do VAB", "Denton-Cholette do deflator anual implícito, usando IPCA trimestral como indicador temporal",
  "Impostos", "ILP trimestral", "Denton-Cholette do ILP anual, usando ICMS total trimestral como indicador; PIB nominal = VAB nominal + ILP"
)

write_csv(composicao_tbl, file.path(dir_output, "combinacao_series.csv"))

# -------------------------------------------------------------------------
# Gráficos
# -------------------------------------------------------------------------

# --- Agropecuária --------------------------------------------------------

agro_comp <- indice_agro |>
  filter(ano >= 2020, ano <= 2025) |>
  transmute(
    periodo,
    `Índice lavouras`      = indice_lavouras,
    `Índice pecuária`      = indice_pecuaria,
    `Índice agropecuário`  = indice_agropecuaria
  ) |>
  pivot_longer(-periodo, names_to = "serie", values_to = "indice")
salvar_grafico(agro_comp, "Agropecuária: lavouras, pecuária e índice final", "agro_componentes.png")

top4_cult <- c("soja", "milho", "arroz", "banana")
vbp_outras <- c(mandioca = 73020, laranja = 30905.5, feijao = 9133.5,
                tomate = 8092, cacau = 7748.5, cana = 2562)
outras_total <- sum(vbp_outras)
outras_nomes <- paste(
  sprintf("%s (%.0f%%)", names(vbp_outras),
          round(vbp_outras / outras_total * 100, 0)),
  collapse = ", "
)

outras_lav <- serie_cult |>
  filter(ano >= 2020, ano <= 2025, nome_curto %in% names(vbp_outras)) |>
  mutate(peso = vbp_outras[nome_curto]) |>
  group_by(periodo, ano, trimestre) |>
  summarise(
    indice = sum(indice_cultura * peso, na.rm = TRUE) / sum(peso[!is.na(indice_cultura)], na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(serie = "Outras lavouras")

agro_lav <- bind_rows(
  serie_cult |>
    filter(ano >= 2020, ano <= 2025, nome_curto %in% top4_cult) |>
    transmute(periodo, serie = nome_curto, indice = indice_cultura),
  outras_lav |> transmute(periodo, serie, indice),
  indice_agro |>
    filter(ano >= 2020, ano <= 2025) |>
    transmute(periodo, serie = "Índice lavouras", indice = indice_lavouras)
)

nota_lav <- sprintf(
  "\"Outras lavouras\": média ponderada por VBP de %s.",
  outras_nomes
)
salvar_grafico_trimestral(
  agro_lav,
  "Lavouras: top 4 culturas, outras lavouras e índice",
  "agro_lavouras_proxies.png",
  nota = nota_lav,
  threshold = 4.0
)

agro_pec <- bind_rows(
  abate_idx |> transmute(periodo = sprintf("%04dT%d", ano, trimestre), serie, indice),
  ovos_idx  |> transmute(periodo = sprintf("%04dT%d", ano, trimestre), serie, indice),
  indice_agro |>
    filter(ano >= 2020, ano <= 2025) |>
    transmute(periodo, serie = "Índice pecuária", indice = indice_pecuaria)
) |>
  arrange(periodo, serie)
salvar_grafico_trimestral(agro_pec, "Pecuária: proxies e índice final", "agro_pecuaria_proxies.png")

# --- Administração pública -----------------------------------------------

aapp_comp <- indice_aapp |>
  filter(ano >= 2020, ano <= 2025) |>
  transmute(
    periodo,
    `Folha estadual`  = estadual,
    `Folha municipal` = municipal,
    `Folha federal`   = federal,
    `Folha total`     = folha_total
  ) |>
  pivot_longer(-periodo, names_to = "serie", values_to = "valor") |>
  group_by(serie) |>
  mutate(indice = valor / mean(valor[str_detect(periodo, "^2020T")], na.rm = TRUE) * 100) |>
  ungroup()

aapp_final <- indice_aapp |>
  filter(ano >= 2020, ano <= 2025) |>
  transmute(periodo, serie = "Índice AAPP", indice = indice_adm_publica)

salvar_grafico(
  bind_rows(aapp_comp |> select(periodo, serie, indice), aapp_final),
  "AAPP: componentes da folha e índice final",
  "aapp_componentes.png"
)

# --- Indústria -----------------------------------------------------------

ind_subset <- indice_ind |>
  filter(ano >= 2020, ano <= 2025) |>
  transmute(
    periodo = sprintf("%04dT%d", ano, trimestre),
    `Índice SIUP`          = indice_siup,
    `Índice construção`    = indice_construcao,
    `Índice transformação` = indice_transformacao,
    `Índice extrativas`    = indice_extrativas,
    `Índice indústria`     = indice_industria
  ) |>
  pivot_longer(-periodo, names_to = "serie", values_to = "indice")
salvar_grafico_trimestral(ind_subset, "Indústria: subsetores e índice final", "industria_subsetores.png")

aneel_total_trim <- aneel |>
  group_by(ano, mes) |>
  summarise(energia_total = sum(energia_kwh, na.rm = TRUE), .groups = "drop") |>
  mutate(trimestre = ceiling(mes / 3L)) |>
  group_by(ano, trimestre) |>
  summarise(energia_total = mean(energia_total, na.rm = TRUE), .groups = "drop") |>
  filter(ano >= 2020, ano <= 2025)
base_aneel_siup <- mean(aneel_total_trim$energia_total[aneel_total_trim$ano == 2020], na.rm = TRUE)

ind_siup_comp <- bind_rows(
  aneel_total_trim |>
    transmute(periodo = sprintf("%04dT%d", ano, trimestre), indice = energia_total / base_aneel_siup * 100, serie = "Energia elétrica total (ANEEL)"),
  indice_ind |>
    filter(ano >= 2020, ano <= 2025) |>
    transmute(periodo = sprintf("%04dT%d", ano, trimestre), indice = indice_siup, serie = "Índice SIUP")
)
salvar_grafico_trimestral(ind_siup_comp, "SIUP: proxy e índice final", "industria_siup_proxy.png")

caged_f_trim <- caged |>
  filter(secao == "F") |>
  mutate(trimestre = ceiling(mes / 3L)) |>
  group_by(ano, trimestre) |>
  summarise(saldo = sum(saldo, na.rm = TRUE), .groups = "drop") |>
  arrange(ano, trimestre) |>
  mutate(estoque = cumsum(saldo) + 10000L) |>
  filter(ano >= 2020, ano <= 2025)
base_const <- mean(caged_f_trim$estoque[caged_f_trim$ano == 2020], na.rm = TRUE)

ind_const_comp <- bind_rows(
  caged_f_trim |>
    transmute(periodo = sprintf("%04dT%d", ano, trimestre), indice = estoque / base_const * 100, serie = "CAGED F (estoque)"),
  indice_ind |>
    filter(ano >= 2020, ano <= 2025) |>
    transmute(periodo = sprintf("%04dT%d", ano, trimestre), indice = indice_construcao, serie = "Índice construção")
)
salvar_grafico_trimestral(ind_const_comp, "Construção: proxy e índice final", "industria_construcao_proxy.png")

ind_transf <- bind_rows(
  proxies_transf |>
    transmute(
      periodo = sprintf("%04dT%d", ano, trimestre),
      `Energia industrial (ANEEL)` = indice_energia_ind,
      `CAGED C (estoque)`          = indice_emprego_c
    ) |>
    pivot_longer(-periodo, names_to = "serie", values_to = "indice"),
  indice_ind |>
    filter(ano >= 2020, ano <= 2025) |>
    transmute(periodo = sprintf("%04dT%d", ano, trimestre), indice = indice_transformacao, serie = "Índice transformação")
)
salvar_grafico_trimestral(ind_transf, "Transformação: proxies e índice final", "industria_transformacao_proxies.png")

ind_extr <- indice_ind |>
  filter(ano >= 2020, ano <= 2025) |>
  transmute(
    periodo = sprintf("%04dT%d", ano, trimestre),
    indice = indice_extrativas,
    serie = "Índice extrativas"
  )
salvar_grafico_trimestral(ind_extr, "Extrativas: índice final", "industria_extrativas.png")

# --- Serviços ------------------------------------------------------------

serv_subset <- indice_serv |>
  filter(ano >= 2020, ano <= 2025) |>
  transmute(
    periodo = sprintf("%04dT%d", ano, trimestre),
    `Índice comércio`        = indice_comercio,
    `Índice transportes`     = indice_transportes,
    `Índice financeiro`      = indice_financeiro,
    `Índice imobiliário`     = indice_imobiliario,
    `Índice outros serviços` = indice_outros_servicos,
    `Índice InfoCom`         = indice_infocom,
    `Índice serviços`        = indice_servicos
  ) |>
  pivot_longer(-periodo, names_to = "serie", values_to = "indice")
salvar_grafico_trimestral(serv_subset, "Serviços: subsetores e índice final", "servicos_subsetores.png")

serv_com <- bind_rows(
  proxies_serv |>
    transmute(
      periodo = sprintf("%04dT%d", ano, trimestre),
      `Energia comercial (ANEEL)` = com_energia,
      PMC                         = com_pmc,
      `ICMS comércio`             = com_icms,
      `CAGED G (estoque)`         = com_caged_g
    ) |>
    pivot_longer(-periodo, names_to = "serie", values_to = "indice"),
  indice_serv |>
    filter(ano >= 2020, ano <= 2025) |>
    transmute(periodo = sprintf("%04dT%d", ano, trimestre), indice = indice_comercio, serie = "Índice comércio")
)
salvar_grafico_trimestral(serv_com, "Serviços - Comércio: proxies e índice", "servicos_comercio.png")

serv_transp <- bind_rows(
  proxies_serv |>
    transmute(
      periodo = sprintf("%04dT%d", ano, trimestre),
      `ANAC passageiros` = transp_pax, `ANAC carga` = transp_carga, `ANP diesel` = transp_diesel
    ) |>
    pivot_longer(-periodo, names_to = "serie", values_to = "indice"),
  indice_serv |>
    filter(ano >= 2020, ano <= 2025) |>
    transmute(periodo = sprintf("%04dT%d", ano, trimestre), indice = indice_transportes, serie = "Índice transportes")
)
salvar_grafico_trimestral(serv_transp, "Serviços - Transportes: proxies e índice", "servicos_transportes.png")

serv_fin <- bind_rows(
  proxies_serv |>
    transmute(
      periodo = sprintf("%04dT%d", ano, trimestre),
      `Concessões de crédito (BCB)` = fin_concessoes,
      `Depósitos bancários (BCB)`   = fin_depositos
    ) |>
    pivot_longer(-periodo, names_to = "serie", values_to = "indice"),
  indice_serv |>
    filter(ano >= 2020, ano <= 2025) |>
    transmute(periodo = sprintf("%04dT%d", ano, trimestre), indice = indice_financeiro, serie = "Índice financeiro")
)
salvar_grafico_trimestral(serv_fin, "Serviços - Financeiro: proxies e índice", "servicos_financeiro.png")

consumidores_resid <- read_csv2_safe(file.path(dir_raw, "aneel", "aneel_consumidores_residenciais_rr.csv")) |>
  mutate(
    data = as.Date(data),
    ano = as.integer(format(data, "%Y")),
    mes = as.integer(format(data, "%m")),
    trimestre = ceiling(mes / 3)
  ) |>
  group_by(ano, trimestre) |>
  summarise(consumidores_residenciais = mean(consumidores_residenciais, na.rm = TRUE), .groups = "drop")

base_cons_resid_2020 <- consumidores_resid |>
  filter(ano == 2020) |>
  summarise(base = mean(consumidores_residenciais, na.rm = TRUE)) |>
  pull(base)

serv_imob <- bind_rows(
  consumidores_resid |>
    filter(ano >= 2020, ano <= 2025) |>
    transmute(
      periodo = sprintf("%04dT%d", ano, trimestre),
      `Consumidores residenciais (ANEEL)` = consumidores_residenciais / base_cons_resid_2020 * 100
    ) |>
    pivot_longer(-periodo, names_to = "serie", values_to = "indice"),
  indice_serv |>
    filter(ano >= 2020, ano <= 2025) |>
    transmute(periodo = sprintf("%04dT%d", ano, trimestre), indice = indice_imobiliario, serie = "Ãndice imobiliÃ¡rio")
)
salvar_grafico_trimestral(serv_imob, "ServiÃ§os - Atividades imobiliÃ¡rias: proxy e Ã­ndice", "servicos_imobiliario.png")

serv_outros <- bind_rows(
  proxies_serv |>
    transmute(
      periodo = sprintf("%04dT%d", ano, trimestre),
      `CAGED I (estoque)`   = os_caged_i,
      `CAGED M+N (estoque)` = os_caged_mn,
      `CAGED P+Q (estoque)` = os_caged_pq,
      PMS                   = os_pms
    ) |>
    pivot_longer(-periodo, names_to = "serie", values_to = "indice"),
  indice_serv |>
    filter(ano >= 2020, ano <= 2025) |>
    transmute(periodo = sprintf("%04dT%d", ano, trimestre), indice = indice_outros_servicos, serie = "Índice outros serviços")
)
salvar_grafico_trimestral(serv_outros, "Serviços - Outros serviços: proxies e índice", "servicos_outros.png")

serv_inf <- bind_rows(
  proxies_serv |>
    transmute(
      periodo = sprintf("%04dT%d", ano, trimestre),
      `CAGED J (estoque)` = inf_caged_j,
      PMS                 = inf_pms
    ) |>
    pivot_longer(-periodo, names_to = "serie", values_to = "indice"),
  indice_serv |>
    filter(ano >= 2020, ano <= 2025) |>
    transmute(
      periodo = sprintf("%04dT%d", ano, trimestre),
      indice = indice_infocom,
      serie = "Índice InfoCom"
    )
)
salvar_grafico_trimestral(serv_inf, "Serviços - Informação e comunicação: proxies e índice", "servicos_infocom.png")

ipca_trim <- ipca |>
  mutate(trimestre = ceiling(mes / 3)) |>
  group_by(ano, trimestre) |>
  summarise(valor = mean(valor, na.rm = TRUE), .groups = "drop") |>
  filter(ano >= 2020, ano <= 2025) |>
  mutate(periodo = sprintf("%04dT%d", ano, trimestre)) |>
  rebase_media_2020("valor", "indice_ipca")

defl <- indice_nom |>
  filter(ano >= 2020, ano <= 2025) |>
  transmute(periodo, indice = deflator_trimestral, serie = "Deflator trimestral")

defl_comp <- bind_rows(
  ipca_trim |> transmute(periodo, indice = indice_ipca, serie = "IPCA trimestral"),
  defl
)
salvar_grafico(defl_comp, "Deflação: IPCA trimestral e deflator implícito", "deflacao_ipca_deflator.png")

impostos_comp <- bind_rows(
  icms_trim |>
    filter(ano >= 2020, ano <= 2025) |>
    transmute(periodo, indice = icms_total_mi / mean(icms_total_mi[ano == 2020], na.rm = TRUE) * 100, serie = "ICMS total"),
  ilp_trim |>
    filter(ano >= 2020, ano <= 2025) |>
    transmute(periodo, indice = ilp_nominal_mi / mean(ilp_nominal_mi[ano == 2020], na.rm = TRUE) * 100, serie = "ILP trimestral")
)
salvar_grafico(impostos_comp, "Impostos e ILP: ICMS total e ILP trimestral", "impostos_ilp_icms.png")

# -------------------------------------------------------------------------
# Relatório Markdown
# -------------------------------------------------------------------------

escrever_tabela_md <- function(df) {
  cab <- paste0("| ", paste(names(df), collapse = " | "), " |")
  sep <- paste0("| ", paste(rep("---", ncol(df)), collapse = " | "), " |")
  linhas <- apply(df, 1, function(x) paste0("| ", paste(x, collapse = " | "), " |"))
  c(cab, sep, linhas)
}

top_problemas <- diag_tbl |>
  mutate(chave = na_valor + faltantes_grade) |>
  arrange(desc(chave), bloco, atividade, serie) |>
  select(bloco, atividade, serie, na_valor, faltantes_grade, tratamento_na) |>
  slice_head(n = 12)

txt <- c(
  "# Diagnóstico das séries utilizadas no pipeline",
  "",
  sprintf("Gerado em %s pelo script `R/98_diagnostico_series_pipeline.R`.", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  "",
  "## Escopo",
  "",
  "Este documento consolida, para as séries atualmente usadas no pipeline do PIB trimestral de Roraima:",
  "",
  "- quantidade de NAs literais na variável operacional;",
  "- faltantes de cobertura na grade esperada da janela 2020–2025;",
  "- existência de tratamento preparado para faltantes;",
  "- forma de uso na composição da proxy ou do índice final;",
  "- gráficos comparativos das proxies por atividade.",
  "",
  "Foram incluídas também as séries de deflação e o bloco de impostos/ILP.",
  "",
  "## Leitura rápida",
  "",
  "- A maior parte das séries operacionais do núcleo 2020–2025 já está sem NAs literais, mas ainda existem problemas relevantes de cobertura em alguns insumos manuais e administrativos.",
  "- O caso mais sensível continua sendo a folha municipal: o arquivo não está cheio de `NA`, mas há faltantes de cobertura na grade bimestral e também valores trimestrais negativos na reconstrução.",
  "- No SIAPE, o tratamento de faltantes existe e está explícito: o código interpola meses ausentes. O cache federal já foi corrigido na rodada atual.",
  "- No CAGED, o padrão do projeto é completar meses ausentes com `saldo = 0` antes de construir o estoque acumulado.",
  "- Em serviços, quando uma proxy falta, o código redistribui os pesos apenas entre as proxies disponíveis do mesmo subsetor.",
  "- Em impostos, o ILP trimestral usa Denton-Cholette com ICMS total como indicador temporal.",
  "",
  "## Principais problemas por cobertura e NA",
  ""
)

txt <- c(txt, escrever_tabela_md(top_problemas))

txt <- c(
  txt,
  "",
  "## Quadro geral das séries",
  "",
  "A tabela abaixo resume o diagnóstico das principais séries efetivamente usadas no pipeline.",
  ""
)

tab_md <- diag_tbl |>
  mutate(
    observacoes = as.character(observacoes),
    periodos_observados = as.character(periodos_observados),
    na_valor = as.character(na_valor),
    faltantes_grade = as.character(faltantes_grade)
  ) |>
  select(
    bloco, atividade, serie, periodicidade, na_valor, faltantes_grade,
    primeiro_periodo, ultimo_periodo, tratamento_na, uso_no_indice
  )
txt <- c(txt, escrever_tabela_md(tab_md))

txt <- c(
  txt,
  "",
  "## Como as proxies entram nos índices",
  "",
  "A tabela abaixo resume a regra de combinação usada hoje no código.",
  ""
)
txt <- c(txt, escrever_tabela_md(composicao_tbl))

txt <- c(
  txt,
  "",
  "## Gráficos comparativos das proxies por atividade",
  "",
  "### Agropecuária",
  "",
  "![Agropecuária - subsetores e índice final](../../data/output/diagnostico_series_pipeline/agro_componentes.png)",
  "",
  "![Agropecuária - lavouras: culturas individuais e índice](../../data/output/diagnostico_series_pipeline/agro_lavouras_proxies.png)",
  "",
  "![Agropecuária - pecuária: proxies e índice](../../data/output/diagnostico_series_pipeline/agro_pecuaria_proxies.png)",
  "",
  "### Administração pública",
  "",
  "![AAPP - componentes da folha e índice final](../../data/output/diagnostico_series_pipeline/aapp_componentes.png)",
  "",
  "### Indústria",
  "",
  "![Indústria - subsetores e índice final](../../data/output/diagnostico_series_pipeline/industria_subsetores.png)",
  "",
  "![Indústria - SIUP: proxy e índice](../../data/output/diagnostico_series_pipeline/industria_siup_proxy.png)",
  "",
  "![Indústria - construção: proxy e índice](../../data/output/diagnostico_series_pipeline/industria_construcao_proxy.png)",
  "",
  "![Indústria - transformação: proxies e índice](../../data/output/diagnostico_series_pipeline/industria_transformacao_proxies.png)",
  "",
  "![Indústria - extrativas: índice final](../../data/output/diagnostico_series_pipeline/industria_extrativas.png)",
  "",
  "### Serviços",
  "",
  "![Serviços - subsetores e índice final](../../data/output/diagnostico_series_pipeline/servicos_subsetores.png)",
  "",
  "![Serviços - comércio: proxies e índice](../../data/output/diagnostico_series_pipeline/servicos_comercio.png)",
  "",
  "![Serviços - transportes: proxies e índice](../../data/output/diagnostico_series_pipeline/servicos_transportes.png)",
  "",
  "![Serviços - financeiro: proxies e índice](../../data/output/diagnostico_series_pipeline/servicos_financeiro.png)",
  "",
  "![Serviços - atividades imobiliárias: proxy e índice](../../data/output/diagnostico_series_pipeline/servicos_imobiliario.png)",
  "",
  "![Serviços - outros serviços: proxies e índice](../../data/output/diagnostico_series_pipeline/servicos_outros.png)",
  "",
  "![Serviços - informação e comunicação: proxies e índice](../../data/output/diagnostico_series_pipeline/servicos_infocom.png)",
  "",
  "### Deflação e impostos",
  "",
  "![Deflação](../../data/output/diagnostico_series_pipeline/deflacao_ipca_deflator.png)",
  "",
  "![Impostos e ILP](../../data/output/diagnostico_series_pipeline/impostos_ilp_icms.png)",
  "",
  "## Arquivos auxiliares gerados",
  "",
  "- `data/output/diagnostico_series_pipeline/resumo_series.csv`",
  "- `data/output/diagnostico_series_pipeline/combinacao_series.csv`",
  "- PNGs comparativos na mesma pasta.",
  "",
  "## Observações metodológicas finais",
  "",
  "- Este diagnóstico separa `NA literal` de `faltante de cobertura`. Em várias séries administrativas o problema real não é `NA` em célula, mas período ausente na grade esperada.",
  "- O diagnóstico foi montado sobre a configuração vigente do projeto em 2026-04-19. Se os pesos operacionais ou as fontes mudarem, este relatório deve ser regenerado.",
  "- O relatório não substitui a leitura dos scripts, mas ajuda a localizar rapidamente onde há risco de cobertura, redistribuição de pesos ou interpolação."
)

writeLines(txt, arq_relatorio, useBytes = TRUE)

message("Relatório salvo em: ", arq_relatorio)
message("Arquivos auxiliares em: ", dir_output)
