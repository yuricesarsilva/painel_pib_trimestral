# =============================================================================
# IAET-RR — Indicador de Atividade Econômica Trimestral de Roraima
# Dashboard Shiny interativo
# SEPLAN/RR — CGEES/DIEAS
# =============================================================================

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
# O dashboard procura os dados em `data/output/` relativo ao diretório de
# trabalho. Execute o app com `setwd()` apontando para a raiz do projeto, ou
# configure IAET_DATA_DIR como variável de ambiente.

resolver_data_dir <- function() {
  dir_env <- Sys.getenv("IAET_DATA_DIR", unset = "")
  candidatos <- c(
    if (nzchar(dir_env)) dir_env else character(0),
    file.path("data", "output"),
    file.path("..", "data", "output")
  )

  for (dir_cand in candidatos) {
    if (file.exists(file.path(dir_cand, "indice_geral_rr.csv"))) {
      return(normalizePath(dir_cand, winslash = "/", mustWork = TRUE))
    }
  }

  stop(
    "Diretorio de dados nao encontrado. ",
    "Configure IAET_DATA_DIR ou execute o app a partir da raiz do projeto."
  )
}

data_dir <- resolver_data_dir()

arq_geral  <- file.path(data_dir, "indice_geral_rr.csv")
arq_sa     <- file.path(data_dir, "indice_geral_rr_sa.csv")
arq_nominal <- file.path(data_dir, "vab_nominal_rr_reais.csv")

# ---------------------------------------------------------------------------
# 2. LEITURA E PRÉ-PROCESSAMENTO
# ---------------------------------------------------------------------------
geral <- read_csv(arq_geral,  show_col_types = FALSE)
sa    <- read_csv(arq_sa,     show_col_types = FALSE)
nom   <- read_csv(arq_nominal, show_col_types = FALSE)

# Série principal: une NSA e SA
serie <- geral |>
  left_join(sa |> select(periodo, indice_geral_sa), by = "periodo") |>
  left_join(nom |> select(periodo, vab_nominal_mi), by = "periodo") |>
  arrange(periodo)

# Rótulo de período (eixo X)
serie <- serie |>
  mutate(label = paste0(ano, "T", trimestre))

# Variações ---------------------------------------------------------------
calc_var <- function(x, lag) round((x / dplyr::lag(x, lag) - 1) * 100, 2)

tabela_var <- serie |>
  mutate(
    var_trim    = calc_var(indice_geral, 1),   # t/t-1
    var_anual   = calc_var(indice_geral, 4),   # t/t-4
    var_trim_sa = calc_var(indice_geral_sa, 1),
    vab_mi_fmt  = round(vab_nominal_mi, 1)
  ) |>
  select(
    Período   = periodo,
    `Índice (NSA)` = indice_geral,
    `Índice (SA)`  = indice_geral_sa,
    `Var. trim. %` = var_trim,
    `Var. anual %` = var_anual,
    `Var. trim. SA %` = var_trim_sa,
    `VAB Nominal (R$ mi)` = vab_mi_fmt,
    `Agropecuária` = indice_agropecuaria,
    `Adm. Pública` = indice_aapp,
    `Indústria`    = indice_industria,
    `Serviços Privados` = indice_servicos
  )

# Período mais recente com dado não extrapolado
ultimo_benchmark <- 2023  # CR IBGE disponível até 2023

# Rótulos legíveis para componentes
componentes <- c(
  "indice_agropecuaria" = "Agropecuária",
  "indice_aapp"         = "Adm. Pública",
  "indice_industria"    = "Indústria",
  "indice_servicos"     = "Serviços Privados"
)

# Pesos 2020 (base Laspeyres — manter sincronizado com 05_agregacao.R)
pesos_2020 <- c(
  indice_agropecuaria = 6.89,
  indice_aapp         = 45.01,
  indice_industria    = 11.63,
  indice_servicos     = 36.46
)

# Contribuição à variação anual (pontos percentuais)
contrib <- serie |>
  mutate(across(all_of(names(pesos_2020)), ~ calc_var(.x, 4), .names = "var_{.col}")) |>
  mutate(across(
    starts_with("var_indice"),
    ~ .x * pesos_2020[sub("var_", "", cur_column())] / 100,
    .names = "contrib_{.col}"
  )) |>
  select(periodo, label, ano, trimestre,
         starts_with("contrib_var_")) |>
  rename_with(~ sub("contrib_var_", "", .x), starts_with("contrib_var_")) |>
  pivot_longer(all_of(names(pesos_2020)),
               names_to = "setor", values_to = "contribuicao") |>
  mutate(setor = componentes[setor])

# ---------------------------------------------------------------------------
# 3. PALETA DE CORES
# ---------------------------------------------------------------------------
cores <- list(
  azul    = "#14346A",
  dourado = "#C89114",
  verde   = "#2E7D32",
  vermelho = "#C62828",
  cinza   = "#607D8B",
  azul_claro = "#1976D2"
)

cores_setores <- c(
  "Agropecuária"      = "#2E7D32",
  "Adm. Pública"      = "#14346A",
  "Indústria"         = "#C89114",
  "Serviços Privados" = "#1976D2"
)

# ---------------------------------------------------------------------------
# 4. UI
# ---------------------------------------------------------------------------
ui <- page_navbar(
  title = div(
    img(src = "https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/Bras%C3%A3o_de_Roraima.svg/60px-Bras%C3%A3o_de_Roraima.svg.png",
        height = "32px", style = "margin-right: 8px;"),
    "IAET-RR"
  ),
  theme = bs_theme(
    version = 5,
    primary  = "#14346A",
    secondary = "#C89114",
    base_font = font_collection("Segoe UI", "Arial", "sans-serif"),
    heading_font = font_collection("Segoe UI", "Arial", "sans-serif")
  ),
  navbar_options = navbar_options(bg = "#14346A", inverse = TRUE),

  # ── ABA 1: Índice Geral ──────────────────────────────────────────────────
  nav_panel(
    title = "Índice Geral",
    icon  = icon("chart-line"),
    layout_columns(
      fill = FALSE,
      col_widths = c(4, 4, 4),

      value_box(
        title = "Último trimestre disponível",
        value = textOutput("ultimo_periodo"),
        showcase = icon("calendar"),
        theme = "primary"
      ),
      value_box(
        title = "Variação anual (t/t-4)",
        value = textOutput("var_anual_ult"),
        showcase = icon("arrow-trend-up"),
        theme = value_box_theme(bg = "#C89114", fg = "white")
      ),
      value_box(
        title = "VAB nominal estimado",
        value = textOutput("vab_ult"),
        showcase = icon("dollar-sign"),
        theme = value_box_theme(bg = "#2E7D32", fg = "white")
      )
    ),

    card(
      card_header("Série histórica — Índice IAET-RR (base 2020 = 100)"),
      card_body(
        checkboxGroupInput(
          "series_exibir",
          label = NULL,
          choices  = c("Sem ajuste sazonal (NSA)" = "nsa",
                       "Dessazonalizado (SA)"      = "sa"),
          selected = c("nsa", "sa"),
          inline   = TRUE
        ),
        sliderInput(
          "range_periodos",
          label    = NULL,
          min      = 1L,
          max      = nrow(serie),
          value    = c(1L, nrow(serie)),
          step     = 1L,
          ticks    = FALSE,
          width    = "100%"
        ),
        plotlyOutput("grafico_geral", height = "420px")
      )
    )
  ),

  # ── ABA 2: Componentes ──────────────────────────────────────────────────
  nav_panel(
    title = "Componentes",
    icon  = icon("chart-bar"),

    card(
      card_header("Contribuição setorial à variação anual (p.p.)"),
      card_body(plotlyOutput("grafico_contrib", height = "440px"))
    ),

    card(
      card_header("Índices setoriais (base 2020 = 100)"),
      card_body(plotlyOutput("grafico_setores", height = "420px"))
    )
  ),

  # ── ABA 3: VAB Nominal ──────────────────────────────────────────────────
  nav_panel(
    title = "VAB Nominal",
    icon  = icon("coins"),

    card(
      card_header("VAB Nominal Trimestral — Roraima (R$ milhões, preços correntes)"),
      card_body(plotlyOutput("grafico_nominal", height = "420px"))
    ),

    layout_columns(
      col_widths = c(6, 6),
      card(
        card_header("Variação nominal anual (%)"),
        card_body(plotlyOutput("grafico_var_nominal", height = "300px"))
      ),
      card(
        card_header("Nota metodológica"),
        card_body(
          p(strong("Fonte:"), "SEPLAN/RR — CGEES/DIEAS, a partir de IBGE Contas Regionais."),
          p(strong("Método:"), "VAB nominal = índice real × deflator implícito / 100."),
          p(strong("Deflator:"), "Derivado das Contas Regionais (VAB nominal / VAB real),",
            "desagregado trimestralmente via Denton-Cholette com IPCA como proxy."),
          p(strong("Base de escala:"), "VAB nominal anual de 2020 (R$ 14.524 mi ÷ 4 = R$ 3.631 mi/trimestre)."),
          p(class = "text-muted small",
            "Os valores de 2024–2025 são estimados por extrapolação de tendência.",
            "Serão revisados com a publicação das CR IBGE 2024 (previsão: out/2026).")
        )
      )
    )
  ),

  # ── ABA 4: Tabela e Download ─────────────────────────────────────────────
  nav_panel(
    title = "Dados",
    icon  = icon("table"),

    card(
      card_header(
        div(
          style = "display: flex; justify-content: space-between; align-items: center;",
          span("Série completa — IAET-RR"),
          div(
            downloadButton("dl_csv",  "CSV",  class = "btn-sm btn-outline-primary me-1"),
            downloadButton("dl_xlsx", "XLSX", class = "btn-sm btn-primary")
          )
        )
      ),
      card_body(
        DTOutput("tabela_principal")
      )
    )
  ),

  # ── ABA 5: Sobre ─────────────────────────────────────────────────────────
  nav_panel(
    title = "Sobre",
    icon  = icon("info-circle"),

    layout_columns(
      col_widths = c(7, 5),
      card(
        card_header("Sobre o IAET-RR"),
        card_body(
          h5("Indicador de Atividade Econômica Trimestral de Roraima"),
          p("O IAET-RR é um proxy do PIB estadual trimestral desenvolvido pela",
            strong("SEPLAN/RR"), "para acompanhamento da conjuntura econômica de",
            "Roraima em tempo próximo ao real."),
          hr(),
          h6("Metodologia"),
          tags$ul(
            tags$li(strong("Índice:"), "Laspeyres encadeado por volume — padrão das Contas Nacionais IBGE"),
            tags$li(strong("Base:"), "Média de 2020 = 100"),
            tags$li(strong("Pesos:"), "Participação no VAB nominal de 2020 (Contas Regionais IBGE)"),
            tags$li(strong("Desagregação:"), "Denton-Cholette — benchmark: índice de volume real (CR IBGE)"),
            tags$li(strong("Ajuste sazonal:"), "X-13ARIMA-SEATS")
          ),
          hr(),
          h6("Cobertura"),
          tags$ul(
            tags$li("2020T1 a 2023T4 — âncora CR IBGE 2023 (dados definitivos)"),
            tags$li("2024T1 a 2025T4 — extrapolação de tendência geométrica"),
            tags$li("Será atualizado com CR IBGE 2024 (previsão IBGE: out/2026)")
          )
        )
      ),
      card(
        card_header("Estrutura setorial"),
        card_body(
          plotlyOutput("grafico_pesos", height = "280px"),
          hr(),
          h6("Instituição"),
          p(strong("Secretaria de Estado do Planejamento e Desenvolvimento de Roraima"),
            br(), "Coordenação-Geral de Estudos Econômicos e Sociais — CGEES",
            br(), "Divisão de Estudos e Análises Sociais — DIEAS"),
          p(em("Yuri Cesar de Lima e Silva"),
            br(), "Coordenador da Equipe do PIB do Estado de Roraima")
        )
      )
    )
  ),

  nav_spacer(),
  nav_item(
    tags$a(
      icon("github"), "Código-fonte",
      href   = "https://github.com/yuricesarsilva/painel_pib_trimestral",
      target = "_blank",
      class  = "nav-link"
    )
  )
)

# ---------------------------------------------------------------------------
# 5. SERVER
# ---------------------------------------------------------------------------
server <- function(input, output, session) {

  # -- Reativo: janela de períodos selecionada --------------------------------
  serie_filtrada <- reactive({
    r <- input$range_periodos
    serie[r[1]:r[2], ]
  })

  # -- Atualizar labels do slider conforme seleção ---------------------------
  observe({
    r  <- input$range_periodos
    lb <- serie$label[r[1]]
    ub <- serie$label[r[2]]
    updateSliderInput(session, "range_periodos",
                      label = paste("Período:", lb, "→", ub))
  })

  # -- Value boxes -----------------------------------------------------------
  output$ultimo_periodo <- renderText({
    tail(serie$label, 1)
  })

  output$var_anual_ult <- renderText({
    n    <- nrow(serie)
    vvar <- round((serie$indice_geral[n] / serie$indice_geral[n - 4] - 1) * 100, 1)
    paste0(ifelse(vvar >= 0, "+", ""), vvar, "%")
  })

  output$vab_ult <- renderText({
    v <- tail(serie$vab_nominal_mi, 1)
    paste0("R$ ", format(round(v / 1e3, 2), big.mark = ".", decimal.mark = ","), " bi")
  })

  # -- Gráfico: série geral NSA/SA -------------------------------------------
  output$grafico_geral <- renderPlotly({
    df <- serie_filtrada()

    p <- plot_ly(df, x = ~label) |>
      layout(
        xaxis = list(title = "", tickangle = -45, tickfont = list(size = 10)),
        yaxis = list(title = "Índice (base 2020 = 100)", gridcolor = "#e8e8e8"),
        hovermode = "x unified",
        legend = list(orientation = "h", y = -0.18),
        plot_bgcolor  = "white",
        paper_bgcolor = "white",
        font = list(family = "Source Sans 3"),
        shapes = list(
          list(type = "line",
               x0 = "2023T4", x1 = "2023T4",
               y0 = 0, y1 = 1, yref = "paper",
               line = list(color = "#999", dash = "dot", width = 1.5))
        ),
        annotations = list(
          list(x = "2024T1", y = 1, yref = "paper", xanchor = "left",
               text = "← extrapolação", showarrow = FALSE,
               font = list(size = 10, color = "#999"))
        )
      )

    if ("nsa" %in% input$series_exibir) {
      p <- p |> add_trace(
        y    = ~indice_geral,
        name = "NSA",
        type = "scatter", mode = "lines+markers",
        line    = list(color = cores$azul, width = 2),
        marker  = list(color = cores$azul, size = 5),
        hovertemplate = "NSA: %{y:.1f}<extra></extra>"
      )
    }

    if ("sa" %in% input$series_exibir) {
      p <- p |> add_trace(
        y    = ~indice_geral_sa,
        name = "SA (dessazonalizado)",
        type = "scatter", mode = "lines",
        line    = list(color = cores$dourado, width = 2, dash = "dash"),
        hovertemplate = "SA: %{y:.1f}<extra></extra>"
      )
    }

    p
  })

  # -- Gráfico: contribuição setorial ----------------------------------------
  output$grafico_contrib <- renderPlotly({
    df_c <- contrib |>
      filter(!is.na(contribuicao)) |>
      mutate(cor = cores_setores[setor])

    plot_ly(df_c, x = ~periodo, y = ~contribuicao, color = ~setor,
            colors = cores_setores, type = "bar") |>
      layout(
        barmode = "stack",
        xaxis = list(title = "", tickangle = -45, tickfont = list(size = 9)),
        yaxis = list(title = "Pontos percentuais (p.p.)", gridcolor = "#e8e8e8",
                     zeroline = TRUE, zerolinecolor = "#555"),
        legend = list(orientation = "h", y = -0.22),
        hovermode = "x unified",
        plot_bgcolor  = "white",
        paper_bgcolor = "white",
        font = list(family = "Source Sans 3"),
        shapes = list(
          list(type = "line",
               x0 = "2024T1", x1 = "2024T1",
               y0 = 0, y1 = 1, yref = "paper",
               line = list(color = "#999", dash = "dot", width = 1.5))
        )
      )
  })

  # -- Gráfico: índices setoriais --------------------------------------------
  output$grafico_setores <- renderPlotly({
    df <- serie |>
      select(label, all_of(names(pesos_2020))) |>
      pivot_longer(-label, names_to = "setor", values_to = "indice") |>
      mutate(setor = componentes[setor])

    plot_ly(df, x = ~label, y = ~indice, color = ~setor,
            colors = cores_setores, type = "scatter", mode = "lines") |>
      add_segments(x = "2023T4", xend = "2023T4", y = 0, yend = 400,
                   line = list(color = "#999", dash = "dot", width = 1),
                   showlegend = FALSE, inherit = FALSE) |>
      layout(
        xaxis = list(title = "", tickangle = -45, tickfont = list(size = 9)),
        yaxis = list(title = "Índice (base 2020 = 100)", gridcolor = "#e8e8e8"),
        hovermode = "x unified",
        legend = list(orientation = "h", y = -0.22),
        plot_bgcolor  = "white",
        paper_bgcolor = "white",
        font = list(family = "Source Sans 3")
      )
  })

  # -- Gráfico: VAB nominal em R$ milhões ------------------------------------
  output$grafico_nominal <- renderPlotly({
    df <- serie |> filter(!is.na(vab_nominal_mi))

    # Separar benchmark e extrapolado
    df_bench <- df |> filter(ano <= ultimo_benchmark)
    df_extrap <- df |> filter(ano > ultimo_benchmark)

    plot_ly() |>
      add_bars(
        data = df_bench,
        x = ~label, y = ~vab_nominal_mi,
        name = "Dados CR IBGE 2023",
        marker = list(color = cores$azul),
        hovertemplate = "R$ %{y:,.1f} mi<extra></extra>"
      ) |>
      add_bars(
        data = df_extrap,
        x = ~label, y = ~vab_nominal_mi,
        name = "Extrapolação (2024–2025)",
        marker = list(color = cores$azul_claro, opacity = 0.7),
        hovertemplate = "R$ %{y:,.1f} mi (est.)<extra></extra>"
      ) |>
      layout(
        barmode = "stack",
        xaxis = list(title = "", tickangle = -45, tickfont = list(size = 9)),
        yaxis = list(title = "R$ milhões", gridcolor = "#e8e8e8",
                     tickformat = ",.0f"),
        hovermode = "x unified",
        legend = list(orientation = "h", y = -0.22),
        plot_bgcolor  = "white",
        paper_bgcolor = "white",
        font = list(family = "Source Sans 3")
      )
  })

  # -- Gráfico: variação nominal anual ---------------------------------------
  output$grafico_var_nominal <- renderPlotly({
    df <- serie |>
      filter(!is.na(vab_nominal_mi)) |>
      mutate(var = round((vab_nominal_mi / lag(vab_nominal_mi, 4) - 1) * 100, 1)) |>
      filter(!is.na(var))

    plot_ly(df, x = ~label, y = ~var,
            type = "bar",
            marker = list(
              color = ifelse(df$var >= 0, cores$verde, cores$vermelho)
            ),
            hovertemplate = "%{y:.1f}%<extra></extra>") |>
      layout(
        xaxis = list(title = "", tickangle = -45, tickfont = list(size = 9)),
        yaxis = list(title = "%", gridcolor = "#e8e8e8",
                     zeroline = TRUE, zerolinecolor = "#555"),
        plot_bgcolor  = "white",
        paper_bgcolor = "white",
        font = list(family = "Source Sans 3"),
        showlegend = FALSE
      )
  })

  # -- Gráfico: pesos setoriais (pizza) --------------------------------------
  output$grafico_pesos <- renderPlotly({
    df_pesos <- data.frame(
      setor = names(pesos_2020),
      peso  = as.numeric(pesos_2020)
    ) |> mutate(setor = componentes[setor])

    plot_ly(df_pesos, labels = ~setor, values = ~peso,
            type = "pie",
            marker = list(colors = unname(cores_setores[df_pesos$setor])),
            textinfo = "label+percent",
            hovertemplate = "%{label}: %{value:.1f}%<extra></extra>") |>
      layout(
        showlegend = FALSE,
        margin = list(t = 20, b = 20, l = 10, r = 10),
        font = list(family = "Source Sans 3", size = 11)
      )
  })

  # -- Tabela principal ------------------------------------------------------
  output$tabela_principal <- renderDT({
    df <- tabela_var |>
      mutate(across(where(is.numeric), ~ round(.x, 2)))

    datatable(
      df,
      rownames  = FALSE,
      filter    = "top",
      class     = "table table-striped table-hover table-sm",
      options   = list(
        pageLength = 24,
        scrollX    = TRUE,
        dom        = "lrtip",
        language   = list(
          search      = "Buscar:",
          lengthMenu  = "Mostrar _MENU_ linhas",
          info        = "Mostrando _START_–_END_ de _TOTAL_ registros",
          paginate    = list(previous = "Anterior", `next` = "Próximo")
        )
      )
    ) |>
      formatStyle(
        "Var. anual %",
        color = styleInterval(0, c("#C62828", "#2E7D32")),
        fontWeight = "bold"
      ) |>
      formatStyle(
        "Var. trim. %",
        color = styleInterval(0, c("#C62828", "#2E7D32"))
      )
  })

  # -- Downloads -------------------------------------------------------------
  df_download <- reactive({
    tabela_var |>
      mutate(
        Fonte     = "SEPLAN/RR — CGEES/DIEAS",
        Benchmark = ifelse(as.integer(substr(Período, 1, 4)) <= ultimo_benchmark,
                           "CR IBGE 2023 (definitivo)",
                           "Extrapolação de tendência")
      )
  })

  output$dl_csv <- downloadHandler(
    filename = function() {
      paste0("IAET_RR_", format(Sys.Date(), "%Y%m%d"), ".csv")
    },
    content = function(file) {
      write_csv(df_download(), file)
    }
  )

  output$dl_xlsx <- downloadHandler(
    filename = function() {
      paste0("IAET_RR_", format(Sys.Date(), "%Y%m%d"), ".xlsx")
    },
    content = function(file) {
      wb <- createWorkbook()
      addWorksheet(wb, "IAET-RR")
      writeData(wb, "IAET-RR", df_download(), startRow = 3)

      # Cabeçalho com metadados
      writeData(wb, "IAET-RR",
                data.frame(x = "IAET-RR — Indicador de Atividade Econômica Trimestral de Roraima"),
                startRow = 1, colNames = FALSE)
      writeData(wb, "IAET-RR",
                data.frame(x = paste("Gerado em:", format(Sys.time(), "%d/%m/%Y %H:%M"), "| SEPLAN/RR — CGEES/DIEAS")),
                startRow = 2, colNames = FALSE)

      # Estilo de cabeçalho
      estilo_cab <- createStyle(
        fgFill = "#14346A", fontColour = "#FFFFFF",
        textDecoration = "bold", halign = "center",
        border = "TopBottomLeftRight"
      )
      addStyle(wb, "IAET-RR",
               style = estilo_cab,
               rows = 3, cols = 1:ncol(df_download()),
               gridExpand = TRUE)

      setColWidths(wb, "IAET-RR", cols = 1:ncol(df_download()),
                   widths = "auto")

      saveWorkbook(wb, file, overwrite = TRUE)
    }
  )
}

# ---------------------------------------------------------------------------
# 6. RUN
# ---------------------------------------------------------------------------
shinyApp(ui = ui, server = server)
