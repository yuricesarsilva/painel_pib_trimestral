# ============================================================
# Projeto : Indicador de Atividade Economica Trimestral - RR
# Script  : dashboard/app.R
# Autor   : Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)
# Data    : 2026-04-14
# Descricao: Dashboard Shiny interativo do IAET-RR, com foco no
#            indice geral, componentes ajustados e bloco do PIB nominal.
# Entrada : arquivos em data/output/
# Saida   : aplicacao Shiny
# Depende : shiny, bslib, dplyr, tidyr, readr, plotly, DT, openxlsx
# ============================================================

library(shiny)
library(bslib)
library(dplyr)
library(tidyr)
library(readr)
library(plotly)
library(DT)
library(openxlsx)

# ---------------------------------------------------------------------------
# 1. CAMINHOS DE DADOS
# ---------------------------------------------------------------------------

resolver_data_dir <- function() {
  dir_env <- Sys.getenv("IAET_DATA_DIR", unset = "")
  candidatos <- c(
    if (nzchar(dir_env)) dir_env else character(0),
    file.path("data", "output"),
    file.path("..", "data", "output")
  )

  for (dir_cand in candidatos) {
    if (file.exists(file.path(dir_cand, "indice_geral_rr_sa.csv"))) {
      return(normalizePath(dir_cand, winslash = "/", mustWork = TRUE))
    }
  }

  stop(
    "Diretorio de dados nao encontrado. ",
    "Configure IAET_DATA_DIR ou execute o app a partir da raiz do projeto."
  )
}

data_dir <- resolver_data_dir()

resolver_processed_dir <- function(data_dir) {
  candidatos <- c(
    file.path(dirname(data_dir), "processed"),
    file.path("data", "processed"),
    file.path("..", "data", "processed")
  )

  for (dir_cand in candidatos) {
    if (file.exists(file.path(dir_cand, "contas_regionais_RR_serie.csv"))) {
      return(normalizePath(dir_cand, winslash = "/", mustWork = TRUE))
    }
  }

  stop("Diretorio de dados processados nao encontrado.")
}

processed_dir <- resolver_processed_dir(data_dir)

arq_indices <- file.path(data_dir, "indice_geral_rr_sa.csv")
arq_pib     <- file.path(data_dir, "pib_nominal_rr.csv")
arq_ilp     <- file.path(data_dir, "ilp_rr_trimestral.csv")
arq_contas  <- file.path(processed_dir, "contas_regionais_RR_serie.csv")

# ---------------------------------------------------------------------------
# 2. LEITURA E PRE-PROCESSAMENTO
# ---------------------------------------------------------------------------

ultimo_benchmark <- 2023L

calc_var <- function(x, lag) {
  round((x / dplyr::lag(x, lag) - 1) * 100, 2)
}

fmt_pct <- function(x, digits = 1) {
  if (is.na(x)) return("-")
  paste0(ifelse(x > 0, "+", ""), format(round(x, digits), decimal.mark = ","), "%")
}

fmt_mi <- function(x, digits = 1) {
  if (is.na(x)) return("-")
  paste0("R$ ", format(round(x, digits), big.mark = ".", decimal.mark = ","), " mi")
}

fmt_bi <- function(x, digits = 2) {
  if (is.na(x)) return("-")
  paste0("R$ ", format(round(x / 1000, digits), big.mark = ".", decimal.mark = ","), " bi")
}

layout_legenda <- function() {
  list(
    orientation = "v",
    x = 1.02,
    xanchor = "left",
    y = 1,
    yanchor = "top",
    bgcolor = "rgba(255,255,255,0.85)"
  )
}

marcas_extrapolacao <- function(df, ano_benchmark = ultimo_benchmark) {
  if (!any(df$ano > ano_benchmark)) return(list(shapes = NULL, annotations = NULL))

  x_inicio <- df$label[match(min(df$label[df$ano > ano_benchmark]), df$label)]
  x_linha  <- paste0(ano_benchmark, "T4")

  list(
    shapes = list(
      list(
        type = "line",
        x0 = x_linha, x1 = x_linha,
        y0 = 0, y1 = 1, yref = "paper",
        line = list(color = "#9aa4b2", dash = "dot", width = 1.3)
      )
    ),
    annotations = list(
      list(
        x = x_inicio, y = 1, yref = "paper", xanchor = "left",
        text = "<- extrapolacao", showarrow = FALSE,
        font = list(size = 10, color = "#6b7280")
      )
    )
  )
}

dados_indices <- read_csv(arq_indices, show_col_types = FALSE) |>
  arrange(ano, trimestre) |>
  mutate(
    label = paste0(ano, "T", trimestre),
    origem = ifelse(ano <= ultimo_benchmark, "Benchmark CR IBGE", "Extrapolacao")
  )

dados_pib <- read_csv(arq_pib, show_col_types = FALSE) |>
  arrange(ano, trimestre) |>
  select(periodo, indice_nominal, vab_nominal_mi, icms_mi, ilp_nominal_mi, pib_nominal_mi, tipo_benchmark)

dados_ilp <- read_csv(arq_ilp, show_col_types = FALSE) |>
  arrange(ano, trimestre) |>
  select(periodo, ilp_anual_mi)

contas_regionais <- read_csv(
  arq_contas,
  show_col_types = FALSE
) |>
  mutate(
    bloco = case_when(
      grepl("Agropec", atividade)                     ~ "Agropecuaria",
      grepl("defesa", atividade)                      ~ "Adm. Publica",
      grepl("extrat|transforma|Eletricidade|SIUP|Constru", atividade) ~ "Industria",
      grepl("Total das Atividades", atividade)        ~ NA_character_,
      TRUE                                            ~ "Servicos Privados"
    )
  ) |>
  filter(!is.na(bloco)) |>
  group_by(ano, bloco) |>
  summarise(vab_mi = sum(vab_mi, na.rm = TRUE), .groups = "drop") |>
  group_by(ano) |>
  mutate(participacao_pct = 100 * vab_mi / sum(vab_mi, na.rm = TRUE)) |>
  ungroup()

serie <- dados_indices |>
  left_join(dados_pib, by = "periodo") |>
  left_join(dados_ilp, by = "periodo")

catalogo_series <- tibble::tibble(
  serie_id = c("iaet", "agro", "aapp", "industria", "servicos"),
  serie = c("IAET-RR", "Agropecuaria", "Adm. Publica", "Industria", "Servicos Privados"),
  col_nsa = c("indice_geral", "indice_agropecuaria", "indice_aapp", "indice_industria", "indice_servicos"),
  col_sa  = c("indice_geral_sa", "indice_agropecuaria_sa", "indice_aapp_sa", "indice_industria_sa", "indice_servicos_sa"),
  peso_2020 = c(NA_real_, 6.89, 45.01, 11.63, 36.46)
)

base_painel <- serie

indices_long <- bind_rows(lapply(seq_len(nrow(catalogo_series)), function(i) {
  tibble::tibble(
    periodo = base_painel$periodo,
    ano = base_painel$ano,
    trimestre = base_painel$trimestre,
    label = base_painel$label,
    origem = base_painel$origem,
    serie_id = catalogo_series$serie_id[i],
    serie = catalogo_series$serie[i],
    peso_2020 = catalogo_series$peso_2020[i],
    nsa = base_painel[[catalogo_series$col_nsa[i]]],
    sa = base_painel[[catalogo_series$col_sa[i]]]
  ) |>
    mutate(
      taxa_crescimento_anual_nsa = calc_var(nsa, 4),
      taxa_crescimento_anual_sa  = calc_var(sa, 4),
      taxa_crescimento_trimestral_nsa = calc_var(nsa, 1),
      taxa_crescimento_trimestral_sa  = calc_var(sa, 1)
    )
}))

contrib <- indices_long |>
  filter(serie_id != "iaet") |>
  mutate(contribuicao = taxa_crescimento_anual_nsa * peso_2020 / 100)

tabela_indices <- indices_long |>
  select(periodo, serie, nsa, sa, taxa_crescimento_anual_nsa, taxa_crescimento_trimestral_sa, peso_2020, origem) |>
  rename(
    Periodo = periodo,
    Serie = serie,
    `Indice sem ajuste sazonal` = nsa,
    `Indice dessazonalizado` = sa,
    `Taxa acumulada em 4 trimestres` = taxa_crescimento_anual_nsa,
    `Taxa de crescimento trimestral` = taxa_crescimento_trimestral_sa,
    `Peso 2020 (%)` = peso_2020,
    Origem = origem
  )

tabela_pib <- serie |>
  transmute(
    Periodo = periodo,
    Ano = ano,
    Trimestre = trimestre,
    `VAB nominal (R$ mi)` = vab_nominal_mi,
    `ICMS proxy (R$ mi)` = icms_mi,
    `ILP trimestral (R$ mi)` = ilp_nominal_mi,
    `PIB nominal (R$ mi)` = pib_nominal_mi,
    `Taxa acumulada em 4 trimestres do PIB` = calc_var(pib_nominal_mi, 4),
    `Taxa de crescimento trimestral do PIB` = calc_var(pib_nominal_mi, 1),
    Benchmark = tipo_benchmark
  )

taxas_anuais_iaet <- indices_long |>
  group_by(ano, serie) |>
  summarise(indice_medio = mean(nsa, na.rm = TRUE), .groups = "drop") |>
  group_by(serie) |>
  mutate(taxa_anual = calc_var(indice_medio, 1)) |>
  ungroup()

taxas_anuais_pib <- serie |>
  group_by(ano) |>
  summarise(
    `VAB nominal` = sum(vab_nominal_mi, na.rm = TRUE),
    `Impostos sobre produtos (ILP)` = sum(ilp_nominal_mi, na.rm = TRUE),
    `PIB nominal` = sum(pib_nominal_mi, na.rm = TRUE),
    .groups = "drop"
  ) |>
  pivot_longer(-ano, names_to = "serie", values_to = "valor") |>
  group_by(serie) |>
  mutate(taxa = calc_var(valor, 1)) |>
  ungroup()

# Dados para abas anuais -------------------------------------------------------
pib_anual_barras <- taxas_anuais_pib |>
  filter(serie != "PIB nominal") |>
  select(ano, serie, valor)

pib_anual_total <- taxas_anuais_pib |>
  filter(serie == "PIB nominal") |>
  select(ano, valor_pib = valor)

# PIB real anual: deflaciona PIB nominal pelo deflator implícito (indice_nominal / indice_geral)
pib_real_anual_taxa <- serie |>
  mutate(pib_real_mi = pib_nominal_mi * indice_geral / indice_nominal) |>
  group_by(ano) |>
  summarise(pib_real_mi = sum(pib_real_mi, na.rm = TRUE), .groups = "drop") |>
  mutate(taxa_anual = calc_var(pib_real_mi, 1)) |>
  filter(!is.na(taxa_anual))

vab_nominal_anual <- contas_regionais |>
  select(ano, bloco, vab_mi)

# Taxas de crescimento anuais reais por setor (para grafico de colunas agrupadas)
vab_real_anual_taxa <- taxas_anuais_iaet |>
  filter(serie != "IAET-RR", !is.na(taxa_anual)) |>
  select(ano, serie, taxa_anual)

# ---------------------------------------------------------------------------
# 3. PALETA
# ---------------------------------------------------------------------------

cores <- list(
  azul = "#123B72",
  azul_medio = "#2A6DB0",
  dourado = "#C68A18",
  verde = "#2F7A45",
  vermelho = "#C54A43",
  ardosia = "#5D6B7A"
)

cores_setores <- c(
  "Agropecuaria" = "#2F7A45",
  "Adm. Publica" = "#123B72",
  "Industria" = "#C68A18",
  "Servicos Privados" = "#2A6DB0"
)

cores_pib <- c(
  "VAB nominal" = "#123B72",
  "Impostos sobre produtos (ILP)" = "#C68A18",
  "PIB nominal" = "#2F7A45"
)

# ---------------------------------------------------------------------------
# 4. UI
# ---------------------------------------------------------------------------

ui <- page_navbar(
  title = div(
    style = "display:flex; align-items:center; gap:10px;",
    span(
      style = paste(
        "display:inline-flex; align-items:center; justify-content:center;",
        "width:38px; height:38px; border-radius:10px;",
        "background:#C68A18; color:white; font-weight:700;"
      ),
      "RR"
    ),
    div(
      tags$div(style = "font-weight:700; line-height:1;", "IAET-RR"),
      tags$div(style = "font-size:11px; opacity:.8; line-height:1.2;", "Atividade economica trimestral")
    )
  ),
  theme = bs_theme(
    version = 5,
    primary = cores$azul,
    secondary = cores$dourado,
    bg = "#EEF2F6",
    fg = "#1E293B",
    base_font = font_collection("Segoe UI", "Arial", "sans-serif"),
    heading_font = font_collection("Segoe UI", "Arial", "sans-serif")
  ),
  header = tags$style(HTML(" 
    .bslib-value-box .value-box-value { font-size: 1.7rem; }
    .bslib-value-box .value-box-title { font-weight: 600; }
    .card { border: 0; box-shadow: 0 10px 30px rgba(18,59,114,.08); }
    .nav-link { font-weight: 600; }
    .sidebar { background: #F8FAFC; }
  ")),

  nav_panel(
    title = "IAET",
    icon = icon("chart-line"),
    layout_sidebar(
      sidebar = sidebar(
        width = 320,
        h5("Explorar o IAET"),
        p(class = "text-muted small",
          "O painel principal privilegia o indice geral e compara sempre a serie sem ajuste sazonal com a dessazonalizada."),
        sliderInput(
          "range_iaet",
          "Janela de analise",
          min = 1L, max = nrow(serie),
          value = c(1L, nrow(serie)),
          step = 1L, ticks = FALSE
        ),
        radioButtons(
          "modo_taxa_iaet",
          "Taxas no grafico inferior",
          choices = c(
            "Taxa acumulada em 4 trimestres" = "anual",
            "Taxa de crescimento trimestral" = "trimestral",
            "Ambas" = "ambas"
          ),
          selected = "ambas"
        ),
        helpText("A taxa acumulada em 4 trimestres compara o trimestre atual com o mesmo trimestre do ano anterior. A taxa trimestral compara com o trimestre imediatamente anterior.")
      ),
      layout_columns(
        col_widths = c(4, 4, 4),
        value_box(
          title = "Periodo de referencia",
          value = textOutput("iaet_periodo_ref"),
          showcase = icon("calendar"),
          theme = "primary"
        ),
        value_box(
          title = "Taxa acumulada em 4 trimestres",
          value = textOutput("iaet_var_anual"),
          showcase = icon("arrow-trend-up"),
          theme = value_box_theme(bg = cores$dourado, fg = "white")
        ),
        value_box(
          title = "Taxa de crescimento trimestral",
          value = textOutput("iaet_var_trimestral"),
          showcase = icon("wave-square"),
          theme = value_box_theme(bg = cores$verde, fg = "white")
        )
      ),
      card(
        full_screen = TRUE,
        card_header("IAET-RR - indice principal (sem ajuste sazonal x dessazonalizado)"),
        card_body(plotlyOutput("grafico_iaet_nivel", height = "420px"))
      ),
      card(
        full_screen = TRUE,
        card_header("IAET-RR - taxas de crescimento"),
        card_body(plotlyOutput("grafico_iaet_taxas", height = "320px"))
      )
    )
  ),

  nav_panel(
    title = "Componentes",
    icon = icon("sliders"),
    layout_sidebar(
      sidebar = sidebar(
        width = 320,
        h5("Escolha o componente"),
        selectInput(
          "serie_comp",
          "Serie",
          choices = setNames(catalogo_series$serie_id[catalogo_series$serie_id != "iaet"],
                             catalogo_series$serie[catalogo_series$serie_id != "iaet"]),
          selected = "agro"
        ),
        sliderInput(
          "range_comp",
          "Janela de analise",
          min = 1L, max = nrow(serie),
          value = c(1L, nrow(serie)),
          step = 1L, ticks = FALSE
        ),
        checkboxGroupInput(
          "comp_contrib",
          "Setores na contribuicao",
          choices = setNames(catalogo_series$serie_id[catalogo_series$serie_id != "iaet"],
                             catalogo_series$serie[catalogo_series$serie_id != "iaet"]),
          selected = catalogo_series$serie_id[catalogo_series$serie_id != "iaet"]
        )
      ),
      layout_columns(
        col_widths = c(4, 4, 4),
        value_box(
          title = "Periodo de referencia",
          value = textOutput("comp_periodo_ref"),
          showcase = icon("calendar"),
          theme = "primary"
        ),
        value_box(
          title = "Taxa acumulada em 4 trimestres",
          value = textOutput("comp_var_anual"),
          showcase = icon("arrow-up-right-dots"),
          theme = value_box_theme(bg = cores$dourado, fg = "white")
        ),
        value_box(
          title = "Taxa de crescimento trimestral",
          value = textOutput("comp_var_trimestral"),
          showcase = icon("arrow-right-arrow-left"),
          theme = value_box_theme(bg = cores$verde, fg = "white")
        )
      ),
      card(
        full_screen = TRUE,
        card_header(textOutput("titulo_comp_nivel")),
        card_body(plotlyOutput("grafico_comp_nivel", height = "410px"))
      ),
      layout_columns(
        col_widths = c(6, 6),
        card(
          full_screen = TRUE,
          card_header(textOutput("titulo_comp_taxas")),
          card_body(plotlyOutput("grafico_comp_taxas", height = "300px"))
        ),
        card(
          full_screen = TRUE,
          card_header(textOutput("titulo_comp_contrib")),
          card_body(plotlyOutput("grafico_contrib", height = "300px"))
        )
      )
    )
  ),

  nav_panel(
    title = "PIB",
    icon = icon("coins"),
    layout_sidebar(
      sidebar = sidebar(
        width = 320,
        h5("Logica do PIB nominal"),
        checkboxGroupInput(
          "series_pib",
          "Series no grafico principal",
          choices = c(
            "VAB nominal" = "vab_nominal_mi",
            "Impostos sobre produtos (ILP)" = "ilp_nominal_mi",
            "PIB nominal" = "pib_nominal_mi"
          ),
          selected = c("vab_nominal_mi", "ilp_nominal_mi", "pib_nominal_mi")
        ),
        sliderInput(
          "range_pib",
          "Janela de analise",
          min = 1L, max = nrow(serie),
          value = c(1L, nrow(serie)),
          step = 1L, ticks = FALSE
        ),
        radioButtons(
          "modo_taxa_pib",
          "Taxa destacada",
          choices = c(
            "Taxa acumulada em 4 trimestres" = "anual",
            "Taxa de crescimento trimestral" = "trimestral",
            "Ambas" = "ambas"
          ),
          selected = "ambas"
        )
      ),
      layout_columns(
        col_widths = c(4, 4, 4),
        value_box(
          title = "Periodo de referencia",
          value = textOutput("pib_periodo_ref"),
          showcase = icon("calendar"),
          theme = "primary"
        ),
        value_box(
          title = "Taxa acumulada em 4 trimestres do PIB",
          value = textOutput("pib_var_anual"),
          showcase = icon("receipt"),
          theme = value_box_theme(bg = cores$dourado, fg = "white")
        ),
        value_box(
          title = "Taxa de crescimento trimestral do PIB",
          value = textOutput("pib_var_trimestral"),
          showcase = icon("sack-dollar"),
          theme = value_box_theme(bg = cores$verde, fg = "white")
        )
      ),
      card(
        full_screen = TRUE,
        card_header("Composicao do PIB nominal trimestral"),
        card_body(plotlyOutput("grafico_pib_nivel", height = "420px"))
      ),
      layout_columns(
        col_widths = c(7, 5),
        card(
          full_screen = TRUE,
          card_header("Taxas de crescimento do PIB nominal"),
          card_body(plotlyOutput("grafico_pib_taxas", height = "300px"))
        ),
        card(
          card_header("Como ler esta aba"),
          card_body(
            p(strong("Identidade contabil:"), " PIB = VAB + impostos liquidos sobre produtos."),
            p(strong("VAB nominal:"), " serie trimestral estimada a partir do IAET-RR em volume combinado com o deflator implicito anual das Contas Regionais, desagregado para frequencia trimestral com IPCA via Denton-Cholette."),
            p(strong("ILP trimestral:"), " benchmark anual do IBGE distribuido por Denton-Cholette com ICMS da SEFAZ-RR como proxy."),
            p(strong("PIB nominal:"), " soma trimestral entre VAB nominal e ILP."),
            p(class = "text-muted small",
              "Os anos de 2024 e 2025 ainda dependem de extrapolacao do benchmark anual e devem ser lidos como estimativas.")
          )
        )
      )
    )
  ),

  nav_panel(
    title = "PIB anual",
    icon = icon("percent"),
    card(
      full_screen = TRUE,
      card_header("PIB nominal de Roraima \u2014 valores anuais (R$ milh\u00f5es)"),
      card_body(plotlyOutput("grafico_pib_anual_nivel", height = "390px"))
    ),
    card(
      full_screen = TRUE,
      card_header("Crescimento real da atividade economica — taxa anual (IAET-RR)"),
      card_body(plotlyOutput("grafico_pib_anual_real", height = "330px"))
    )
  ),

  nav_panel(
    title = "IAET em nivel",
    icon = icon("chart-column"),
    card(
      full_screen = TRUE,
      card_header("VAB nominal por atividade \u2014 valores anuais (R$ milh\u00f5es)"),
      card_body(plotlyOutput("grafico_vab_nominal_anual", height = "390px"))
    ),
    card(
      full_screen = TRUE,
      card_header("VAB real por atividade — indice de volume anual (base 2020 = 100)"),
      card_body(plotlyOutput("grafico_vab_real_anual", height = "330px"))
    )
  ),

  nav_panel(
    title = "Dados",
    icon = icon("table"),
    layout_sidebar(
      sidebar = sidebar(
        width = 280,
        selectInput(
          "base_tabela",
          "Base exibida",
          choices = c(
            "Indices e componentes" = "indices",
            "PIB nominal" = "pib"
          ),
          selected = "indices"
        ),
        p(class = "text-muted small",
          "A mesma base selecionada aqui e usada no download.")
      ),
      card(
        card_header(
          div(
            style = "display:flex; justify-content:space-between; align-items:center;",
            span("Tabela exploratoria"),
            div(
              downloadButton("dl_csv", "CSV", class = "btn-sm btn-outline-primary me-1"),
              downloadButton("dl_xlsx", "XLSX", class = "btn-sm btn-primary")
            )
          )
        ),
        card_body(DTOutput("tabela_principal"))
      )
    )
  ),

  nav_panel(
    title = "Sobre",
    icon = icon("info-circle"),
    layout_sidebar(
      sidebar = sidebar(
        width = 320,
        selectInput(
          "ano_estrutura",
          "Ano da estrutura setorial",
          choices = sort(unique(contas_regionais$ano), decreasing = TRUE),
          selected = 2020
        ),
        sliderInput(
          "range_sobre",
          "Periodo de referencia",
          min = 1L, max = nrow(serie),
          value = c(1L, nrow(serie)),
          step = 1L, ticks = FALSE
        )
      ),
      layout_columns(
        col_widths = c(7, 5),
        card(
          card_header("Sobre o painel"),
          card_body(
            h5("IAET-RR"),
            p("Painel interativo do indicador trimestral de atividade economica de Roraima, com navegacao separada entre indice principal, componentes, taxas e bloco do PIB nominal."),
            hr(),
            h6("Principios desta versao"),
            tags$ul(
              tags$li("o indice principal e o foco da experiencia;"),
              tags$li("o usuario escolhe a janela de analise, o tipo de taxa e a serie que quer ver;"),
              tags$li("todos os graficos de indices comparam a serie sem ajuste sazonal com a dessazonalizada;"),
              tags$li("as abas de taxas permitem alternar entre leitura anual e trimestral;"),
              tags$li("o bloco PIB aparece em aba propria, com VAB, impostos e PIB.")
            ),
            hr(),
            h6("Cobertura"),
            tags$ul(
              uiOutput("sobre_periodo_ui"),
              tags$li("2020T1 a 2023T4 - benchmark anual das Contas Regionais do IBGE"),
              tags$li("2024T1 a 2025T4 - extrapolacao de tendencia/benchmark estendido"),
              tags$li("revisao esperada quando o IBGE divulgar as Contas Regionais 2024")
            )
          )
        ),
        card(
          card_header(textOutput("titulo_pesos")),
          card_body(
            plotlyOutput("grafico_pesos", height = "280px"),
            hr(),
            h6("Instituicao"),
            p(
              strong("Secretaria de Estado do Planejamento e Desenvolvimento de Roraima"),
              br(), "Coordenacao-Geral de Estudos Economicos e Sociais - CGEES",
              br(), "Divisao de Estudos e Analises Sociais - DIEAS"
            ),
            p(
              em("Yuri Cesar de Lima e Silva"),
              br(), "Coordenador da Equipe do PIB do Estado de Roraima"
            )
          )
        )
      )
    )
  ),

  nav_spacer(),
  nav_item(
    tags$a(
      icon("github"), "Codigo-fonte",
      href = "https://github.com/yuricesarsilva/painel_pib_trimestral",
      target = "_blank",
      class = "nav-link"
    )
  )
)

# ---------------------------------------------------------------------------
# 5. SERVER
# ---------------------------------------------------------------------------

server <- function(input, output, session) {

  atualizar_slider <- function(id_input) {
    observe({
      r <- input[[id_input]]
      if (is.null(r)) return()
      updateSliderInput(
        session, id_input,
        label = "Periodo de referencia"
      )
    })
  }

  atualizar_slider("range_iaet")
  atualizar_slider("range_comp")
  atualizar_slider("range_pib")
  atualizar_slider("range_sobre")

  faixa_df <- function(id_input, df = serie) {
    r <- input[[id_input]]
    if (is.null(r)) return(df)
    df[r[1]:r[2], ]
  }

  dados_iaet <- reactive({
    indices_long |>
      filter(serie_id == "iaet", periodo %in% faixa_df("range_iaet")$periodo)
  })

  dados_comp <- reactive({
    indices_long |>
      filter(serie_id == input$serie_comp, periodo %in% faixa_df("range_comp")$periodo)
  })

  dados_contrib <- reactive({
    contrib |>
      filter(
        serie_id %in% input$comp_contrib,
        periodo %in% faixa_df("range_comp")$periodo
      )
  })

  dados_pib_filtrados <- reactive({
    faixa_df("range_pib", serie) |>
      mutate(
        var_anual_vab = calc_var(vab_nominal_mi, 4),
        var_trimestral_vab = calc_var(vab_nominal_mi, 1),
        var_anual_ilp = calc_var(ilp_nominal_mi, 4),
        var_trimestral_ilp = calc_var(ilp_nominal_mi, 1),
        var_interanual_pib = calc_var(pib_nominal_mi, 4),
        var_trimestral_pib = calc_var(pib_nominal_mi, 1)
      )
  })

  dados_estrutura <- reactive({
    contas_regionais |>
      filter(ano == input$ano_estrutura)
  })

  output$iaet_periodo_ref <- renderText({
    tail(dados_iaet()$label, 1)
  })

  output$iaet_var_anual <- renderText({
    fmt_pct(tail(dados_iaet()$taxa_crescimento_anual_nsa, 1))
  })

  output$iaet_var_trimestral <- renderText({
    fmt_pct(tail(dados_iaet()$taxa_crescimento_trimestral_sa, 1))
  })

  output$comp_periodo_ref <- renderText({
    tail(dados_comp()$label, 1)
  })

  output$comp_var_anual <- renderText({
    fmt_pct(tail(dados_comp()$taxa_crescimento_anual_nsa, 1))
  })

  output$comp_var_trimestral <- renderText({
    fmt_pct(tail(dados_comp()$taxa_crescimento_trimestral_sa, 1))
  })

  output$titulo_comp_nivel <- renderText({
    paste0(unique(dados_comp()$serie), " - indice (sem ajuste sazonal x dessazonalizado)")
  })

  output$titulo_comp_taxas <- renderText({
    paste0(unique(dados_comp()$serie), " - taxas de crescimento")
  })

  output$titulo_comp_contrib <- renderText({
    peso_txt <- fmt_pct(unique(dados_comp()$peso_2020), digits = 2)
    paste0("Contribuicao setorial ao IAET - ", unique(dados_comp()$serie), " (peso 2020: ", peso_txt, ")")
  })

  output$pib_periodo_ref <- renderText({
    tail(dados_pib_filtrados()$label, 1)
  })

  output$pib_var_anual <- renderText({
    fmt_pct(tail(dados_pib_filtrados()$var_interanual_pib, 1))
  })

  output$pib_var_trimestral <- renderText({
    fmt_pct(tail(dados_pib_filtrados()$var_trimestral_pib, 1))
  })

  output$sobre_periodo_ui <- renderUI({
    dados <- faixa_df("range_sobre")
    tags$li(paste0("periodo selecionado no painel: ", dados$label[1], " a ", tail(dados$label, 1)))
  })

  output$titulo_pesos <- renderText({
    paste0("Estrutura setorial - ano de referencia ", input$ano_estrutura)
  })

  output$grafico_iaet_nivel <- renderPlotly({
    df <- dados_iaet()
    marcas <- marcas_extrapolacao(df)

    plot_ly(df, x = ~label) |>
      add_lines(
        y = ~nsa, name = "Sem ajuste sazonal",
        line = list(color = cores$azul, width = 2.6),
        hovertemplate = "Sem ajuste sazonal: %{y:.1f}<extra></extra>"
      ) |>
      add_lines(
        y = ~sa, name = "Dessazonalizado",
        line = list(color = cores$dourado, width = 2.4, dash = "dash"),
        hovertemplate = "Dessazonalizado: %{y:.1f}<extra></extra>"
      ) |>
      layout(
        xaxis = list(title = "", tickangle = -45),
        yaxis = list(title = "Indice (base 2020 = 100)", gridcolor = "#dbe3ec"),
        hovermode = "x unified",
        legend = layout_legenda(),
        margin = list(b = 70, r = 190),
        plot_bgcolor = "white",
        paper_bgcolor = "white",
        font = list(family = "Segoe UI"),
        shapes = marcas$shapes,
        annotations = marcas$annotations
      ) |>
      config(locale = "pt-BR")
  })

  output$grafico_iaet_taxas <- renderPlotly({
    df <- dados_iaet()
    modo <- input$modo_taxa_iaet

    p <- plot_ly(df, x = ~label) |>
      layout(
        xaxis = list(title = "", tickangle = -45),
        yaxis = list(title = "Varia\u00e7\u00e3o (%)", gridcolor = "#dbe3ec", zerolinecolor = "#9aa4b2"),
        hovermode = "x unified",
        legend = layout_legenda(),
        plot_bgcolor = "white",
        paper_bgcolor = "white",
        font = list(family = "Segoe UI")
      )

    if (modo %in% c("anual", "ambas")) {
      p <- p |>
        add_bars(
          y = ~taxa_crescimento_anual_nsa,
          name = "Taxa acumulada em 4 trimestres",
          marker = list(color = cores$azul_medio),
          hovertemplate = "Taxa acumulada em 4 trim.: %{y:.1f}%<extra></extra>"
        )
    }

    if (modo %in% c("trimestral", "ambas")) {
      p <- p |>
        add_lines(
          y = ~taxa_crescimento_trimestral_sa,
          name = "Taxa de crescimento trimestral",
          line = list(color = cores$dourado, width = 2.4),
          hovertemplate = "Taxa de crescimento trimestral: %{y:.1f}%<extra></extra>"
        )
    }

    p |>
      layout(legend = layout_legenda(), margin = list(b = 70, r = 190)) |>
      config(locale = "pt-BR")
  })

  output$grafico_comp_nivel <- renderPlotly({
    df <- dados_comp()
    marcas <- marcas_extrapolacao(df)

    plot_ly(df, x = ~label) |>
      add_lines(
        y = ~nsa, name = "Sem ajuste sazonal",
        line = list(color = cores$azul, width = 2.5),
        hovertemplate = "Sem ajuste sazonal: %{y:.1f}<extra></extra>"
      ) |>
      add_lines(
        y = ~sa, name = "Dessazonalizado",
        line = list(color = cores$dourado, width = 2.2, dash = "dash"),
        hovertemplate = "Dessazonalizado: %{y:.1f}<extra></extra>"
      ) |>
      layout(
        xaxis = list(title = "", tickangle = -45),
        yaxis = list(title = "Indice (base 2020 = 100)", gridcolor = "#dbe3ec"),
        hovermode = "x unified",
        legend = layout_legenda(),
        margin = list(b = 70, r = 190),
        plot_bgcolor = "white",
        paper_bgcolor = "white",
        font = list(family = "Segoe UI"),
        shapes = marcas$shapes,
        annotations = marcas$annotations
      ) |>
      config(locale = "pt-BR")
  })

  output$grafico_comp_taxas <- renderPlotly({
    df <- dados_comp()

    plot_ly(df, x = ~label) |>
      add_bars(
        y = ~taxa_crescimento_anual_nsa,
        name = "Taxa acumulada em 4 trimestres",
        marker = list(color = cores$azul_medio),
        hovertemplate = "Taxa acumulada em 4 trim.: %{y:.1f}%<extra></extra>"
      ) |>
      add_lines(
        y = ~taxa_crescimento_trimestral_sa,
        name = "Taxa de crescimento trimestral",
        line = list(color = cores$dourado, width = 2.3),
        hovertemplate = "Taxa de crescimento trimestral: %{y:.1f}%<extra></extra>"
      ) |>
      layout(
        xaxis = list(title = "", tickangle = -45),
        yaxis = list(title = "Varia\u00e7\u00e3o (%)", gridcolor = "#dbe3ec", zerolinecolor = "#9aa4b2"),
        hovermode = "x unified",
        legend = layout_legenda(),
        margin = list(b = 70, r = 190),
        plot_bgcolor = "white",
        paper_bgcolor = "white",
        font = list(family = "Segoe UI")
      ) |>
      config(locale = "pt-BR")
  })

  output$grafico_contrib <- renderPlotly({
    df <- dados_contrib()

    plot_ly(df, x = ~label, y = ~contribuicao, color = ~serie,
            colors = cores_setores, type = "bar") |>
      layout(
        barmode = "stack",
        xaxis = list(title = "", tickangle = -45),
        yaxis = list(title = "Pontos percentuais", gridcolor = "#dbe3ec", zerolinecolor = "#9aa4b2"),
        hovermode = "x unified",
        legend = layout_legenda(),
        margin = list(b = 70, r = 190),
        plot_bgcolor = "white",
        paper_bgcolor = "white",
        font = list(family = "Segoe UI")
      ) |>
      config(locale = "pt-BR")
  })

  output$grafico_pib_nivel <- renderPlotly({
    df <- dados_pib_filtrados()
    marcas <- marcas_extrapolacao(df)
    p <- plot_ly(df, x = ~label)

    if ("vab_nominal_mi" %in% input$series_pib) {
      p <- p |>
        add_bars(
          y = ~vab_nominal_mi,
          name = "VAB nominal",
          marker = list(color = cores_pib["VAB nominal"]),
          hovertemplate = "VAB: R$ %{y:,.1f} mi<extra></extra>"
        )
    }

    if ("ilp_nominal_mi" %in% input$series_pib) {
      p <- p |>
        add_bars(
          y = ~ilp_nominal_mi,
          name = "Impostos sobre produtos (ILP)",
          marker = list(color = cores_pib["Impostos sobre produtos (ILP)"]),
          hovertemplate = "ILP: R$ %{y:,.1f} mi<extra></extra>"
        )
    }

    if ("pib_nominal_mi" %in% input$series_pib) {
      p <- p |>
        add_lines(
          y = ~pib_nominal_mi,
          name = "PIB nominal",
          line = list(color = cores_pib["PIB nominal"], width = 2.8),
          hovertemplate = "PIB: R$ %{y:,.1f} mi<extra></extra>"
        )
    }

    p |>
      layout(
        barmode = "stack",
        xaxis = list(title = "", tickangle = -45),
        yaxis = list(title = "R$ milh\u00f5es", gridcolor = "#dbe3ec"),
        hovermode = "x unified",
        legend = layout_legenda(),
        margin = list(b = 70, r = 190),
        plot_bgcolor = "white",
        paper_bgcolor = "white",
        font = list(family = "Segoe UI"),
        shapes = marcas$shapes,
        annotations = marcas$annotations
      ) |>
      config(locale = "pt-BR")
  })

  output$grafico_pib_taxas <- renderPlotly({
    df <- dados_pib_filtrados()
    modo <- input$modo_taxa_pib

    p <- plot_ly(df, x = ~label) |>
      layout(
        xaxis = list(title = "", tickangle = -45),
        yaxis = list(title = "Varia\u00e7\u00e3o (%)", gridcolor = "#dbe3ec", zerolinecolor = "#9aa4b2"),
        hovermode = "x unified",
        legend = layout_legenda(),
        plot_bgcolor = "white",
        paper_bgcolor = "white",
        font = list(family = "Segoe UI")
      )

    if (modo %in% c("anual", "ambas")) {
      p <- p |>
        add_bars(
          y = ~var_interanual_pib,
          name = "Taxa acumulada em 4 trim. do PIB",
          marker = list(color = cores_pib["PIB nominal"]),
          hovertemplate = "Taxa acumulada em 4 trim. do PIB: %{y:.1f}%<extra></extra>"
        )
    }

    if (modo %in% c("trimestral", "ambas")) {
      p <- p |>
        add_lines(
          y = ~var_trimestral_pib,
          name = "Taxa de crescimento trimestral do PIB",
          line = list(color = cores$dourado, width = 2.4),
          hovertemplate = "Taxa de crescimento trimestral do PIB: %{y:.1f}%<extra></extra>"
        )
    }

    p |>
      layout(legend = layout_legenda(), margin = list(b = 70, r = 190)) |>
      config(locale = "pt-BR")
  })

  # Aba PIB anual — grafico 1: PIB nominal por componente (barras + linha)
  output$grafico_pib_anual_nivel <- renderPlotly({
    barras <- pib_anual_barras
    total  <- pib_anual_total

    plot_ly() |>
      add_bars(
        data = barras,
        x = ~ano, y = ~valor, color = ~serie,
        colors = c("VAB nominal" = "#123B72", "Impostos sobre produtos (ILP)" = "#C68A18"),
        hovertemplate = "%{fullData.name}: R$ %{y:,.1f} mi<extra></extra>"
      ) |>
      add_lines(
        data = total,
        x = ~ano, y = ~valor_pib,
        name = "PIB nominal",
        line = list(color = "#2F7A45", width = 3),
        marker = list(size = 8, color = "#2F7A45"),
        hovertemplate = "PIB nominal: R$ %{y:,.1f} mi<extra></extra>"
      ) |>
      layout(
        barmode = "stack",
        xaxis = list(title = "", dtick = 1, tickformat = "d"),
        yaxis = list(title = "R$ milh\u00f5es", gridcolor = "#dbe3ec"),
        hovermode = "x unified",
        legend = layout_legenda(),
        margin = list(b = 60, r = 190),
        plot_bgcolor = "white",
        paper_bgcolor = "white",
        font = list(family = "Segoe UI")
      ) |>
      config(locale = "pt-BR")
  })

  # Aba PIB anual — grafico 2: crescimento real do PIB
  output$grafico_pib_anual_real <- renderPlotly({
    df <- pib_real_anual_taxa

    plot_ly(df, x = ~ano, y = ~taxa_anual, type = "bar",
            marker = list(color = ifelse(df$taxa_anual >= 0, cores$azul_medio, cores$vermelho)),
            hovertemplate = "Crescimento real do PIB: %{y:.1f}%<extra></extra>",
            name = "Crescimento real do PIB") |>
      layout(
        xaxis = list(title = "", dtick = 1, tickformat = "d"),
        yaxis = list(title = "Varia\u00e7\u00e3o anual (%)", gridcolor = "#dbe3ec", zerolinecolor = "#9aa4b2"),
        hovermode = "x unified",
        showlegend = FALSE,
        margin = list(b = 60, r = 40),
        plot_bgcolor = "white",
        paper_bgcolor = "white",
        font = list(family = "Segoe UI")
      ) |>
      config(locale = "pt-BR")
  })

  # Aba IAET em nivel — grafico 1: VAB nominal por atividade (linhas anuais)
  output$grafico_vab_nominal_anual <- renderPlotly({
    df <- vab_nominal_anual

    plot_ly(df, x = ~ano, y = ~vab_mi, color = ~bloco,
            colors = cores_setores, type = "scatter", mode = "lines+markers",
            hovertemplate = "%{fullData.name}: R$ %{y:,.1f} mi<extra></extra>") |>
      layout(
        xaxis = list(title = "", dtick = 1, tickformat = "d"),
        yaxis = list(title = "R$ milh\u00f5es", gridcolor = "#dbe3ec"),
        hovermode = "x unified",
        legend = layout_legenda(),
        margin = list(b = 60, r = 190),
        plot_bgcolor = "white",
        paper_bgcolor = "white",
        font = list(family = "Segoe UI")
      ) |>
      config(locale = "pt-BR")
  })

  # Aba IAET em nivel — grafico 2: taxas de crescimento reais anuais por setor (colunas agrupadas)
  output$grafico_vab_real_anual <- renderPlotly({
    df <- vab_real_anual_taxa

    plot_ly(df, x = ~ano, y = ~taxa_anual, color = ~serie,
            colors = cores_setores, type = "bar",
            hovertemplate = "%{fullData.name}: %{y:.1f}%<extra></extra>") |>
      layout(
        barmode = "group",
        xaxis = list(title = "", dtick = 1, tickformat = "d"),
        yaxis = list(title = "Varia\u00e7\u00e3o anual (%)", gridcolor = "#dbe3ec", zerolinecolor = "#9aa4b2"),
        hovermode = "x unified",
        legend = layout_legenda(),
        margin = list(b = 60, r = 190),
        plot_bgcolor = "white",
        paper_bgcolor = "white",
        font = list(family = "Segoe UI")
      ) |>
      config(locale = "pt-BR")
  })

  output$grafico_pesos <- renderPlotly({
    df_pesos <- dados_estrutura() |>
      transmute(serie = bloco, peso = participacao_pct)

    cores_pizza <- setNames(
      unname(cores_setores[df_pesos$serie]),
      df_pesos$serie
    )

    plot_ly(
      df_pesos,
      labels = ~serie,
      values = ~peso,
      type = "pie",
      marker = list(colors = unname(cores_pizza)),
      textinfo = "label+percent",
      hovertemplate = "%{label}: %{value:.2f}%<extra></extra>"
    ) |>
      layout(
        showlegend = TRUE,
        legend = list(orientation = "v"),
        margin = list(t = 20, b = 20, l = 10, r = 120),
        font = list(family = "Segoe UI")
      ) |>
      config(locale = "pt-BR")
  })

  tabela_reativa <- reactive({
    if (identical(input$base_tabela, "pib")) {
      tabela_pib
    } else {
      tabela_indices
    }
  })

  output$tabela_principal <- renderDT({
    df <- tabela_reativa() |>
      mutate(across(where(is.numeric), ~ round(.x, 2)))

    datatable(
      df,
      rownames = FALSE,
      filter = "top",
      class = "table table-striped table-hover table-sm",
      options = list(
        pageLength = 18,
        scrollX = TRUE,
        dom = "lrtip",
        language = list(
          search = "Buscar:",
          lengthMenu = "Mostrar _MENU_ linhas",
          info = "Mostrando _START_-_END_ de _TOTAL_ registros",
          paginate = list(previous = "Anterior", `next` = "Proximo")
        )
      )
    )
  })

  output$dl_csv <- downloadHandler(
    filename = function() {
      prefixo <- if (identical(input$base_tabela, "pib")) "PIB_nominal_RR" else "IAET_RR_indices"
      paste0(prefixo, "_", format(Sys.Date(), "%Y%m%d"), ".csv")
    },
    content = function(file) {
      write_csv(tabela_reativa(), file)
    }
  )

  output$dl_xlsx <- downloadHandler(
    filename = function() {
      prefixo <- if (identical(input$base_tabela, "pib")) "PIB_nominal_RR" else "IAET_RR_indices"
      paste0(prefixo, "_", format(Sys.Date(), "%Y%m%d"), ".xlsx")
    },
    content = function(file) {
      wb <- createWorkbook()
      nome_aba <- if (identical(input$base_tabela, "pib")) "PIB Nominal" else "Indices"
      df <- tabela_reativa()

      addWorksheet(wb, nome_aba)
      writeData(wb, nome_aba, df, startRow = 3)
      writeData(wb, nome_aba, "SEPLAN/RR - CGEES/DIEAS", startRow = 1, colNames = FALSE)
      writeData(wb, nome_aba, paste("Gerado em", format(Sys.time(), "%d/%m/%Y %H:%M")), startRow = 2, colNames = FALSE)

      estilo_cab <- createStyle(
        fgFill = cores$azul,
        fontColour = "#FFFFFF",
        textDecoration = "bold",
        halign = "center",
        border = "TopBottomLeftRight"
      )

      addStyle(
        wb, nome_aba,
        style = estilo_cab,
        rows = 3, cols = 1:ncol(df),
        gridExpand = TRUE
      )
      setColWidths(wb, nome_aba, cols = 1:ncol(df), widths = "auto")
      saveWorkbook(wb, file, overwrite = TRUE)
    }
  )
}

# ---------------------------------------------------------------------------
# 6. RUN
# ---------------------------------------------------------------------------

shinyApp(ui = ui, server = server)

