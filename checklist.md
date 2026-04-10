# Checklist — Indicador de Atividade Econômica Trimestral de Roraima

> Marque cada item com `[x]` conforme for concluído.

---

## Fase 0 — Planejamento e infraestrutura

### 0.1 Metodologia
- [x] Definir produto final (índice de volume, sem R$)
- [x] Escolher ferramenta de implementação (R)
- [x] Definir período de cobertura (a partir de 2020)
- [x] Escolher método de desagregação temporal (Denton-Cholette)
- [x] Escolher método de ajuste sazonal (X-13ARIMA-SEATS)
- [x] Definir fórmula do índice (Laspeyres encadeado)
- [x] Definir deflator para séries nominais (IPCA nacional)
- [x] Mapear proxies por setor e respectivas fontes
- [x] Documentar decisões metodológicas no plano

### 0.2 Infraestrutura do projeto
- [x] Criar estrutura de pastas (`data/`, `R/`, `dashboard/`, `notas/`)
- [x] Criar repositório público no GitHub (`painel_pib_trimestral`)
- [x] Configurar `.gitignore` (excluir `data/`, arquivos R temporários)
- [x] Publicar plano metodológico (`plano_projeto.md`)
- [x] Publicar README no GitHub
- [x] Criar histórico em linguagem simples (`historico_simples.md`)
- [x] Criar checklist do projeto (`checklist.md`)
- [x] Criar `regras.md` com protocolo obrigatório de fim de sessão
- [x] Versionar a pasta `Base metodológica/` com os PDFs de referência
- [ ] Criar projeto R (`.Rproj`) na pasta raiz
- [ ] Instalar pacotes R necessários
  - [ ] `sidrar`
  - [ ] `tempdisagg`
  - [ ] `seasonal`
  - [ ] `tidyverse` (dplyr, tidyr, ggplot2, lubridate, readr)
  - [ ] `writexl` / `openxlsx`
  - [ ] `httr2` / `jsonlite`
  - [ ] `shiny` / `flexdashboard`
  - [ ] `quarto`

### 0.3 Dados de referência (anuais — IBGE Contas Regionais)
- [x] Baixar publicação Contas Regionais 2023 do FTP do IBGE (Tabela5.xls — Roraima)
- [x] Extrair VAB por atividade para Roraima 2023 (13 atividades)
  - [x] Salvar em `data/processed/vab_roraima_2023.csv`
- [x] Atualizar pesos no README, plano_projeto.md e checklist com dados reais de 2023
- [ ] Baixar série histórica completa (2010–2023) de VAB por atividade para RR
  - [ ] Agropecuária
  - [ ] Indústrias extrativas
  - [ ] Indústrias de transformação
  - [ ] SIUP
  - [ ] Construção
  - [ ] Comércio e reparação de veículos
  - [ ] Transporte, armazenagem e correio
  - [ ] Informação e comunicação
  - [ ] Atividades financeiras e seguros
  - [ ] Atividades imobiliárias
  - [ ] AAPP
  - [ ] Outros serviços
- [ ] Organizar tabela de pesos setoriais por ano (2010–2023)
- [ ] Salvar em `data/processed/contas_regionais_RR_serie.csv`

---

## Fase 1 — Agropecuária

### 1.0 Análise de cobertura da LSPA (transparência metodológica)
- [ ] Baixar PAM (Produção Agrícola Municipal) para Roraima via `sidrar`
  - [ ] Lavouras temporárias (tabela 5457)
  - [ ] Lavouras permanentes (tabela 5558)
- [ ] Calcular VBP total de todas as lavouras de Roraima (média 2018–2022)
- [ ] Calcular VBP das 10 culturas cobertas pela LSPA
  - [ ] Arroz
  - [ ] Feijão
  - [ ] Milho
  - [ ] Soja
  - [ ] Banana
  - [ ] Cacau
  - [ ] Cana-de-açúcar
  - [ ] Laranja
  - [ ] Mandioca
  - [ ] Tomate
- [ ] Gerar tabela com participação % de cada cultura no VBP total
- [ ] Calcular percentual total coberto pelas 10 culturas
- [ ] Registrar resultado no `historico_simples.md` e na nota técnica
- [ ] Salvar tabela em `data/processed/cobertura_lspa_pam.csv`

### 1.1 Estrutura sazonal de colheita (calendário agrícola)
- [ ] Localizar tabelas de "época de colheita" do Censo Agropecuário 2006 para Roraima
- [ ] Verificar se o Censo Agropecuário 2017 publicou tabela equivalente
  - [ ] Se sim: usar coeficientes de 2017 (mais recentes)
  - [ ] Se não: manter 2006 como referência
- [ ] Construir matriz: cultura × mês → coeficiente de colheita
  - [ ] Verificar que cada linha (cultura) soma 1,0 (100%)
  - [ ] Validar com calendário agroclimático de RR (chuvas: dez–abr; seca: mai–set)
- [ ] Salvar matriz em `data/processed/coef_sazonais_colheita.csv`

### 1.2 Série mensal de produção de lavouras
- [ ] Baixar LSPA para Roraima via `sidrar` (tabela 6588)
  - [ ] Coletar valor de dezembro de cada ano como produção anual definitiva
  - [ ] Coletar todas as 10 culturas disponíveis para RR
- [ ] Aplicar coeficientes sazonais do Censo → produção mensal por cultura
- [ ] Calcular índice de Laspeyres de quantidade com pesos PAM (VBP)
  - [ ] Definir ano-base dos pesos (média 2018–2022 ou último triênio disponível)
  - [ ] Verificar consistência: soma ponderada deve refletir estrutura produtiva
- [ ] Agregar série mensal em trimestres (soma ou média, conforme a variável)
- [ ] Salvar série em `data/processed/serie_lavouras_trimestral.csv`

### 1.3 Pecuária — verificação de disponibilidade e séries
- [ ] Verificar disponibilidade de cada série para Roraima via SIDRA
  - [ ] Abate de bovinos (tabela 1092) → disponível para RR? `[ ] Sim  [ ] Não`
  - [ ] Abate de suínos (tabela 1092) → disponível para RR? `[ ] Sim  [ ] Não`
  - [ ] Abate de aves (tabela 1092) → disponível para RR? `[ ] Sim  [ ] Não`
  - [ ] Produção de leite — litros (tabela 74) → disponível para RR? `[ ] Sim  [ ] Não`
  - [ ] Produção de ovos de galinha (tabela 915) → disponível para RR? `[ ] Sim  [ ] Não`
- [ ] Para cada série disponível:
  - [ ] Baixar dados via `sidrar`
  - [ ] Calcular índice de volume trimestral
- [ ] Baixar PPM (Pesquisa Pecuária Municipal) para pesos (tabela 3939)
- [ ] Construir índice pecuário ponderado pelos pesos PPM
- [ ] Documentar quais séries não têm cobertura para RR
- [ ] Salvar em `data/processed/serie_pecuaria_trimestral.csv`

### 1.4 Índice agropecuário agregado e benchmarking
- [ ] Combinar lavouras e pecuária com pesos PAM + PPM
- [ ] Calcular índice agropecuário trimestral (base 2020 = 100)
- [ ] Aplicar Denton-Cholette (`tempdisagg::td()`) contra VAB agropecuário anual das Contas Regionais
- [ ] Validar: variação anual do índice deve coincidir com Contas Regionais
- [ ] Gerar gráfico de validação (série vs. benchmark anual)
- [ ] Salvar em `data/output/indice_agropecuaria.csv`
- [ ] Atualizar `historico_simples.md` com conclusão da Fase 1

---

## Fase 2 — Administração Pública

### 2.1 Folha federal (SIAPE)
- [ ] Acessar API do Portal da Transparência
- [ ] Coletar folha de pagamento mensal (servidores com lotação em Roraima)
  - [ ] Definir filtros: UG de lotação em RR, competência mensal, 2020–presente
  - [ ] Tratar meses com 13º salário (não representam atividade adicional — excluir ou tratar)
- [ ] Verificar consistência da série (ausência de gaps, valores atípicos)
- [ ] Salvar dados brutos em `data/raw/siape_rr_mensal.csv`

### 2.2 Folha estadual
- [ ] Obter série mensal da folha de pagamento do governo estadual (SEPLAN/SEFAZ-RR)
- [ ] Verificar cobertura: servidores ativos, inativos, pensionistas — definir escopo
- [ ] Salvar em `data/raw/folha_estadual_rr_mensal.csv`

### 2.3 Folha municipal (estimada)
- [ ] Baixar dados de gastos com pessoal dos municípios de RR via SICONFI (STN)
- [ ] Verificar frequência disponível (trimestral ou semestral)
- [ ] Salvar em `data/raw/folha_municipal_rr.csv`

### 2.4 Série de volume e benchmarking
- [ ] Combinar folhas federal + estadual + municipal em série mensal total
- [ ] Deflacionar pelo IPCA nacional (série acumulada 12 meses ou deflator mensal encadeado)
- [ ] Agregar em trimestres
- [ ] Calcular índice de volume (base 2020 = 100)
- [ ] Aplicar Denton-Cholette contra VAB AAPP anual das Contas Regionais
- [ ] Validar: variação anual deve coincidir com Contas Regionais
- [ ] Salvar em `data/output/indice_adm_publica.csv`
- [ ] Atualizar `historico_simples.md` com conclusão da Fase 2

---

## Fase 3 — Indústria

### 3.1 Construção Civil
- [ ] Baixar vínculos ativos na construção (CNAE F) do CAGED para RR (2020–presente)
- [ ] Baixar ICMS sobre materiais de construção da SEFAZ-RR por atividade econômica
  - [ ] Deflacionar ICMS pelo IPCA nacional
- [ ] Construir índice composto (CAGED + ICMS) com pesos a definir
- [ ] Agregar em trimestres
- [ ] Salvar em `data/processed/serie_construcao_trimestral.csv`

### 3.2 SIUP — Serviços de Utilidade Pública
- [ ] Baixar consumo mensal de energia elétrica de Roraima (ANEEL / EPE / BEN)
  - [ ] Verificar desagregação: residencial, comercial, industrial, outros
- [ ] Calcular índice de volume trimestral
- [ ] Salvar em `data/processed/serie_siup_trimestral.csv`

### 3.3 Indústria de Transformação
- [ ] Baixar vínculos ativos na indústria de transformação (CNAE C) do CAGED para RR
- [ ] Baixar ICMS sobre bens industriais da SEFAZ-RR
  - [ ] Deflacionar pelo IPCA nacional
- [ ] Construir índice composto
- [ ] Salvar em `data/processed/serie_transformacao_trimestral.csv`

### 3.4 Índice industrial agregado e benchmarking
- [ ] Combinar construção + SIUP + transformação com pesos das Contas Regionais
- [ ] Calcular índice industrial trimestral (base 2020 = 100)
- [ ] Aplicar Denton-Cholette contra VAB industrial anual das Contas Regionais
- [ ] Validar resultado
- [ ] Salvar em `data/output/indice_industria.csv`
- [ ] Atualizar `historico_simples.md` com conclusão da Fase 3

---

## Fase 4 — Serviços Privados

### 4.1 Comércio
- [ ] Obter ICMS por atividade econômica da SEFAZ-RR — segmento comércio
  - [ ] Deflacionar pelo IPCA nacional
- [ ] Baixar vínculos ativos no comércio (CNAE G) do CAGED para RR
- [ ] Construir índice composto (ICMS primário + CAGED como controle)
- [ ] Verificar e documentar eventuais mudanças de alíquota ou regime no período
- [ ] Salvar em `data/processed/serie_comercio_trimestral.csv`

### 4.2 Transportes
- [ ] Baixar dados do aeroporto de Boa Vista via ANAC
  - [ ] Passageiros embarcados e desembarcados (mensal)
  - [ ] Carga aérea (mensal)
- [ ] Baixar vendas de óleo diesel em Roraima via ANP (mensal)
- [ ] Construir índice composto (ANAC + diesel) com pesos a definir
  - [ ] Documentar sobreposição do diesel com agropecuária e construção
- [ ] Agregar em trimestres
- [ ] Salvar em `data/processed/serie_transportes_trimestral.csv`

### 4.3 Outros serviços (saúde, educação, financeiro)
- [ ] Baixar vínculos em saúde e educação privadas (CNAE P+Q) do CAGED para RR
- [ ] Baixar operações de crédito e depósitos bancários em RR via BCB Estban
- [ ] Construir índice composto
- [ ] Salvar em `data/processed/serie_outros_servicos_trimestral.csv`

### 4.4 Índice de serviços privados e benchmarking
- [ ] Combinar comércio + transportes + outros com pesos das Contas Regionais
- [ ] Calcular índice de serviços privados trimestral (base 2020 = 100)
- [ ] Aplicar Denton-Cholette contra VAB serviços privados anual das Contas Regionais
- [ ] Validar resultado
- [ ] Salvar em `data/output/indice_servicos.csv`
- [ ] Atualizar `historico_simples.md` com conclusão da Fase 4

---

## Fase 5 — Agregação e publicação

### 5.1 Índice geral agregado
- [ ] Importar índices setoriais: agropecuária, AAPP, indústria, serviços
- [ ] Aplicar pesos das Contas Regionais (participação no VAB total)
- [ ] Calcular índice geral trimestral encadeado (base 2020 = 100)
- [ ] Aplicar Denton-Cholette final contra PIB total de RR das Contas Regionais
- [ ] Salvar em `data/output/indice_geral_rr.csv`

### 5.2 Ajuste sazonal
- [ ] Aplicar X-13ARIMA-SEATS (`seasonal`) ao índice geral
- [ ] Aplicar X-13ARIMA-SEATS a cada componente setorial
- [ ] Publicar duas versões: com ajuste sazonal e sem ajuste sazonal
- [ ] Salvar em `data/output/indice_geral_rr_sa.csv` (série dessazonalizada)

### 5.3 Validação final
- [ ] Variação anual do índice geral vs. Contas Regionais IBGE (todos os anos disponíveis)
- [ ] Comparar perfil de ciclo com IBC-BR e IBCR Norte (Banco Central)
- [ ] Verificar correlação com arrecadação tributária total de RR
- [ ] Verificar comportamento em 2020 (queda COVID) vs. estados vizinhos
- [ ] Documentar e justificar eventuais divergências

### 5.4 Exportação dos dados
- [ ] Gerar arquivo Excel com todas as séries (índice geral + setoriais + SA)
  - [ ] Aba: índice geral
  - [ ] Aba: componentes setoriais
  - [ ] Aba: série dessazonalizada
  - [ ] Aba: metadados e fontes
- [ ] Gerar arquivo CSV para cada série
- [ ] Salvar em `data/output/`

### 5.5 Dashboard interativo
- [ ] Criar estrutura do app (`dashboard/app.R`)
- [ ] Implementar gráfico do índice geral (com e sem ajuste sazonal)
- [ ] Implementar gráfico de contribuição setorial
- [ ] Implementar tabela de variações (trimestre/trimestre e ano/ano)
- [ ] Adicionar botão de download (CSV e XLSX)
- [ ] Testar em diferentes tamanhos de tela
- [ ] Publicar (Shinyapps.io ou servidor SEPLAN)

### 5.6 Nota técnica
- [ ] Criar arquivo `notas/nota_tecnica.qmd` (Quarto)
- [ ] Escrever seção de metodologia
  - [ ] Justificativa das proxies por setor
  - [ ] Cobertura da LSPA (% do VBP agropecuário — resultado da Etapa 1.0)
  - [ ] Tratamento da LSPA (coeficientes do Censo 2006)
  - [ ] Método Denton-Cholette: explicação em linguagem acessível
  - [ ] Limitações e ressalvas do indicador
- [ ] Escrever seção de análise conjuntural (trimestre mais recente)
- [ ] Inserir gráficos e tabelas
- [ ] Revisar e aprovar internamente na SEPLAN
- [ ] Gerar PDF final
- [ ] Publicar

---

## Fase 6 — Manutenção e atualização trimestral

### A cada trimestre (rotina de atualização)
- [ ] Atualizar dados de todas as fontes no script de cada setor
- [ ] Rodar scripts na ordem: 01 → 02 → 03 → 04 → 05
- [ ] Verificar se há revisões nas Contas Regionais do IBGE e atualizar pesos se necessário
- [ ] Atualizar arquivo Excel e CSVs de output
- [ ] Atualizar dashboard
- [ ] Redigir nova nota técnica conjuntural
- [ ] Fazer commit no GitHub com tag da versão (ex: `v2025-Q1`)
- [ ] Atualizar `historico_simples.md`

---

## Status geral

| Fase | Descrição | Status |
|---|---|---|
| 0 | Planejamento e infraestrutura | 🟡 Em andamento |
| 1 | Agropecuária | ⚪ Não iniciada |
| 2 | Administração Pública | ⚪ Não iniciada |
| 3 | Indústria | ⚪ Não iniciada |
| 4 | Serviços Privados | ⚪ Não iniciada |
| 5 | Agregação e publicação | ⚪ Não iniciada |
| 6 | Manutenção trimestral | ⚪ Não iniciada |

> 🟢 Concluída · 🟡 Em andamento · ⚪ Não iniciada
