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
- [x] Registrar sugestões de aprimoramento das proxies em `sugestoes1.md`

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
- [x] Criar pasta `R/` com script de produção `00_dados_referencia.R`
- [x] Criar pasta `R/exploratorio/` com scripts históricos de exploração de dados
- [x] Adicionar regras de localização e versionamento de scripts ao `regras.md`
- [x] Criar `R/utils.R` com funções compartilhadas (validar_serie, denton, laspeyres, deflacionar)
- [x] Criar `R/run_all.R` com orquestrador do pipeline completo
- [x] Criar `logs/fontes_utilizadas.csv` para rastreabilidade dos dados por release
- [x] Criar `.env.exemplo` com template de credenciais
- [x] Adicionar `.env` e padrões `renv` ao `.gitignore`
- [x] Adicionar regras de ambiente, credenciais, QA, vintagem, pipeline e release ao `regras.md`
- [x] Criar projeto R (`painel_pib_trimestral.Rproj`) na pasta raiz
- [x] Inicializar `renv` (`renv::init()`) e commitar `renv.lock`
- [x] Instalar e registrar pacotes R necessários via `renv::snapshot()` (121 pacotes, R 4.4.0)
  - [x] `sidrar`
  - [x] `tempdisagg`
  - [x] `seasonal`
  - [x] `tidyverse` (dplyr, tidyr, ggplot2, lubridate, readr)
  - [x] `writexl` / `openxlsx`
  - [x] `httr2` / `jsonlite`
  - [x] `shiny` / `flexdashboard`
  - [x] `quarto`
  - [x] `renv`
  - [x] `dotenv` (leitura do .env)

### 0.3 Dados de referência (anuais — IBGE Contas Regionais)
- [x] Baixar publicação Contas Regionais 2023 do FTP do IBGE (Tabela5.xls — Roraima)
- [x] Extrair VAB por atividade para Roraima 2023 (13 atividades)
  - [x] Salvar em `data/processed/vab_roraima_2023.csv`
- [x] Atualizar pesos no README, plano_projeto.md e checklist com dados reais de 2023
- [x] Baixar série histórica completa (2010–2023) de VAB por atividade para RR
  - [x] Agropecuária
  - [x] Indústrias extrativas
  - [x] Indústrias de transformação
  - [x] SIUP
  - [x] Construção
  - [x] Comércio e reparação de veículos
  - [x] Transporte, armazenagem e correio
  - [x] Informação e comunicação
  - [x] Atividades financeiras e seguros
  - [x] Atividades imobiliárias
  - [x] AAPP
  - [x] Outros serviços
- [x] Organizar tabela de pesos setoriais por ano (2010–2023)
- [x] Salvar em `data/processed/contas_regionais_RR_serie.csv`

---

## Fase 1 — Agropecuária

### 1.0 Análise de cobertura das culturas incluídas no índice (transparência metodológica)
- [x] Baixar PAM (Produção Agrícola Municipal) para Roraima via `sidrar`
  - [x] Lavouras temporárias e permanentes (tabela 5457 — contém ambas via c782)
- [x] Calcular VBP total de todas as lavouras de Roraima (média 2018–2022)
- [x] Calcular VBP das 10 culturas cobertas
  - [x] Arroz
  - [x] Feijão
  - [x] Milho
  - [x] Soja
  - [x] Banana
  - [x] Cacau
  - [x] Cana-de-açúcar
  - [x] Laranja
  - [x] Mandioca
  - [x] Tomate
- [x] Gerar tabela com participação % de cada cultura no VBP total
- [x] Calcular percentual total coberto pelas 10 culturas → **90,4%** do VBP
- [x] Salvar tabela em `data/processed/cobertura_lspa_pam.csv`

### 1.1 Estrutura sazonal de colheita (calendário agrícola)
- [x] Localizar tabelas de "época de colheita" do Censo Agropecuário 2006 para Roraima
- [x] Verificar se o Censo Agropecuário 2017 publicou tabela equivalente
  - [x] Censo 2017 não publicou tabela equivalente — mantido Censo 2006 como referência
- [x] Construir matriz: cultura × mês → coeficiente de colheita
  - [x] Verificar que cada linha (cultura) soma 1,0 (100%) → OK
  - [x] Validar com calendário agroclimático de RR (chuvas: dez–abr; seca: mai–set) → OK
- [x] Salvar matriz em `data/processed/coef_sazonais_colheita.csv`

### 1.2 Série mensal de produção de lavouras
- [x] Baixar PAM para Roraima via `sidrar` (tabela 5457 — temporárias e permanentes)
  - [x] Coletar quantidade produzida das 10 culturas para todos os anos disponíveis
  - [x] Último ano coberto pela PAM para RR: **2024**
- [x] Para o ano corrente não coberto pela PAM: LSPA (tabela 6588, c48) valor de dezembro
  - [x] Ano de corte: PAM até 2024, LSPA para **2025** (provisório)
  - [x] Ao publicar nova PAM, substituir valor LSPA automaticamente no script
- [x] Aplicar coeficientes sazonais do Censo → produção mensal por cultura
- [x] Calcular índice de Laspeyres de quantidade com pesos PAM (VBP médio 2018–2022)
- [x] Agregar série mensal em trimestres
- [x] Salvar série em `data/processed/serie_lavouras_trimestral.csv`

### 1.3 Pecuária — verificação de disponibilidade e séries
- [x] Verificar disponibilidade de cada série para Roraima via SIDRA
  - [x] Abate (tabela 1092) → **DISPONÍVEL** (290 obs.)
  - [x] Produção de leite (tabela 74) → **SEM DADOS TRIMESTRAIS** para RR
  - [x] Produção de ovos de galinha (tabela 915) → **DISPONÍVEL** (57 obs.)
- [x] Baixar e calcular índice de volume: abate + ovos disponíveis
- [x] VBP pecuário para pesos: tabela 74 v215 (valor da produção animal)
- [x] Documentar séries indisponíveis para RR: leite trimestral sem cobertura
- [x] Salvar em `data/processed/serie_pecuaria_trimestral.csv`

### 1.4 Índice agropecuário agregado e benchmarking
- [x] Combinar lavouras e pecuária com pesos PAM + tab74 v215
  - [x] Lavouras: **93,0%** | Pecuária: **7,0%** (baseado em VBP médio 2018–2022)
- [x] Calcular índice agropecuário trimestral (base 2020 = 100)
- [x] Aplicar Denton-Cholette (`tempdisagg::td()`, `~ 0 + x`, `conversion="mean"`) contra VAB agropecuário anual
- [x] Validar: variação anual do índice **coincide exatamente** com Contas Regionais (2011–2023)
- [ ] Gerar gráfico de validação (série vs. benchmark anual) — Fase 5
- [x] Salvar em `data/output/indice_agropecuaria.csv`
- [x] Atualizar `historico_simples.md` com conclusão da Fase 1

---

## Fase 2 — Administração Pública

### 2.1 Folha federal (SIAPE)
- [x] Investigar API do Portal da Transparência: endpoint `/remuneracao-servidores-ativos` retorna HTTP 403 para o cadastro padrão — independentemente do token ou parâmetros
- [x] **Decisão metodológica**: componente federal omitido da proxy, mas incluído implicitamente via Denton-Cholette (benchmark IBGE engloba todo o VAB de AAPP, inclusive federal). Validação 2021–2023 confirma abordagem correta.
- [x] Alternativa futura documentada no script: download manual dos arquivos `.zip` mensais do portal

### 2.2 Folha estadual (SICONFI/STN — elemento 31)
- [x] Coletar RREO Anexo 06 via API SICONFI (STN) para o Estado de RR (id_ente=14)
  - [x] Escopo: elemento Pessoal e Encargos Sociais (cod_conta = RREO6PessoalEEncargosSociais), despesas liquidadas
  - [x] Alinhamento com IBGE: elemento 31 (pessoal ativo) — inativos e pensionistas são transferências, não VAB
  - [x] Cobertura: 2020–2026 (37 bimestres), bimestral acumulado
- [x] Converter acumulado → incremental → trimestral (distribuição uniforme intra-bimestre)
- [x] Salvar em `data/raw/folha_estadual_rr_mensal.csv`

### 2.3 Folha municipal (SICONFI/STN — 15 municípios de RR)
- [x] Coletar RREO Anexo 06 via API SICONFI para todos os 15 municípios de RR
  - [x] Frequência confirmada: bimestral acumulado (RREO)
  - [x] Cobertura: 30–37 bimestres por município (variação por data de início dos relatórios)
- [x] Converter acumulado → incremental por município → agregar RR → trimestral
- [x] Salvar em `data/raw/folha_municipal_rr.csv`

### 2.4 Série de volume e benchmarking
- [x] Combinar folhas estadual + municipal (federal=0 enquanto SIAPE pendente)
- [x] Deflacionar pelo IPCA nacional (SIDRA tab 1737, índice encadeado base jan/2020=1)
- [x] Agregar em trimestres
- [x] Calcular índice de volume (base 2020 = 100)
- [x] Aplicar Denton-Cholette contra VAB AAPP anual das Contas Regionais (2020–2023)
- [x] Validar: variação anual coincide exatamente com Contas Regionais
  - [x] 2021: +9,7% (índice) vs. +9,7% (IBGE) ✓
  - [x] 2022: +25,6% vs. +25,6% ✓
  - [x] 2023: +18,0% vs. +18,0% ✓
- [x] Salvar em `data/output/indice_adm_publica.csv` (16 obs., 2020T1–2023T4)
- [x] Atualizar `historico_simples.md` com conclusão da Fase 2

---

## Fase 3 — Indústria

### 3.1 Coleta ANEEL SAMP — energia por classe (SIUP + compartilhada com Fase 4)
- [x] Confirmar distribuidor RR: "BOA VISTA" (Roraima Energia S.A.), sistema isolado
- [x] Identificar dataset ANEEL SAMP: `3e153db4-a503-4093-88be-75d31b002dcf`
- [x] Confirmar filtros: NomTipoMercado = "Sistema Isolado - Regular", DscDetalheMercado = "Energia TE (kWh)"
- [x] Confirmar resource IDs por ano (2020–2026): `29f9fec9`, `84906f77`, `7e097631`, `b9ad890b`, `ff80dd21`, `6fac5605`, `56f1c242`
- [x] Confirmar cobertura: 12 meses/ano completos para todos os anos testados (2020, 2023)
- [x] Optar por API CKAN com filtros (não CSV 201 MB) — ~800 registros/ano para RR
- [x] Implementar coleta com paginação (limite 500 registros/chamada)
- [x] Salvar em `data/raw/aneel/aneel_energia_rr_{ano}.csv` (cache por ano, idempotente)
- [x] Consolidar em `data/raw/aneel/aneel_energia_rr.csv`
- [x] Classes disponíveis: Residencial, Comercial, Industrial, Poder público, Rural, Serv. público

### 3.2 Coleta CAGED Microdata — emprego por seção CNAE (Fase 3 + reutilizada na Fase 4)
- [x] Confirmar ausência de API filtrada por UF para Novo CAGED (2020+)
- [x] Confirmar FTP MTE: `ftp.mtps.gov.br/pdet/microdados/NOVO%20CAGED/{ano}/{yearmonth}/CAGEDMOV{yearmonth}.7z`
- [x] Confirmar 7-Zip disponível em `C:/Program Files/7-Zip/7z.exe`
- [x] Confirmar estrutura do arquivo: campos uf (col 3), seção CNAE (col 5), saldo (col 7)
- [x] Implementar extração com `data.table::fread` (filtro por UF=14, agregação por seção)
- [x] Salvar por mês em `data/raw/caged/caged_rr_{yearmonth}.csv` (idempotente)
- [x] Consolidar em `data/raw/caged/caged_rr_mensal.csv` com todas as seções CNAE
- [x] Script baixa TODAS as seções — Fase 4 reutiliza sem re-download (~2,5 GB one-time)

### 3.3 SIUP — índice de energia distribuída
- [x] Proxy: soma mensal de energia TE de todas as classes (kWh total)
- [x] Agregação trimestral: soma dos 3 meses (variável de fluxo)
- [x] Normalização: base 2020 = 100
- [x] Denton-Cholette contra VAB SIUP das Contas Regionais (Tab. 5.5)
- [x] Salvar como componente em `data/output/indice_industria.csv`

### 3.4 Construção — índice de emprego formal CNAE F
- [x] Proxy primária: estoque acumulado CAGED F (base 1000 + saldos mensais)
- [x] SNIC cimento: indisponível via API; script aceita CSV de download manual (condicional)
  - Se SNIC presente: CAGED F 60% + SNIC 40%
  - Se ausente: CAGED F 100%
- [x] ICMS materiais construção: excluído (SEFAZ-RR sem desagregação automatizável por CNAE)
- [x] Agregação trimestral: média dos 3 meses (variável de nível)
- [x] Denton-Cholette contra VAB Construção (Tab. 5.6)
- [x] Salvar como componente em `data/output/indice_industria.csv`

### 3.5 Indústria de Transformação — índice composto
- [x] Proxy: energia industrial ANEEL 70% + CAGED C acumulado 30%
- [x] Energia industrial = classe "Industrial" do ANEEL (reaproveitada da coleta 3.1)
- [x] ICMS industrial: excluído (SEFAZ-RR sem desagregação automatizável por CNAE)
- [x] Agregação trimestral: média dos 3 meses
- [x] Denton-Cholette contra VAB Ind. Transformação (Tab. 5.4)
- [x] Salvar como componente em `data/output/indice_industria.csv`

### 3.6 Índice industrial agregado e validação
- [x] Pesos internos derivados das Contas Regionais 2021 (SIUP 5,40 / Const. 4,89 / Transf. 1,31)
- [x] Cálculo do índice composto com pesos normalizados dentro do bloco
- [x] Validação com `validar_serie()` em cada componente e no composto
- [x] Salvar em `data/output/indice_industria.csv`
- [x] **Executar** `R/03_industria.R` e verificar outputs
- [x] Validação manual: comparar variações anuais com Contas Regionais IBGE
  - Variações anuais: 2021 −6,3% / 2022 +5,2% / 2023 +61,7% / 2024 −22,8% / 2025 +10,5%
  - Denton garante exatidão vs. IBGE nos anos com benchmark (2020–2023)
  - Variação 2023 elevada reflete instabilidade real do VAB SIUP nas CR (R$369M→R$1.243M)
  - 2025T3 inicialmente ausente: bug corrigido (grid de meses com saldo=0 para meses sem movimentação CAGED)
  - Índice final: 24 observações (2020T1–2025T4) ✓
- [x] Atualizar `historico_simples.md` com conclusão confirmada da Fase 3

---

## Fase 4 — Serviços Privados

### 4.1 Comércio
- [ ] Usar série de energia comercial coletada no SIUP (3.2) — sem coleta adicional
- [ ] Obter ICMS por atividade econômica da SEFAZ-RR — segmento comércio
  - [ ] Deflacionar pelo IPCA nacional
  - [ ] Registrar datas de quebras tributárias (mudanças de alíquota/regime) → dummy no script
- [ ] Baixar vínculos ativos no comércio (CNAE G) do CAGED para RR
- [ ] Construir índice composto (energia comercial + ICMS + CAGED) com pesos explícitos
  - [ ] Energia comercial como componente prioritário (volume físico independente de preço)
  - [ ] Documentar pesos escolhidos e justificativa
- [ ] Salvar em `data/processed/serie_comercio_trimestral.csv`

### 4.2 Transportes
- [ ] Baixar dados do aeroporto de Boa Vista via ANAC
  - [ ] Passageiros embarcados e desembarcados (mensal)
  - [ ] Carga aérea (mensal)
- [ ] Baixar vendas de óleo diesel em Roraima via ANP (mensal)
- [ ] Construir índice composto com pesos explícitos (diesel com peso menor)
  - [ ] Sugestão inicial: passageiros ANAC 40%, carga ANAC 30%, diesel 30%
  - [ ] Documentar sobreposição do diesel com agropecuária e construção na nota técnica
- [ ] Agregar em trimestres
- [ ] Salvar em `data/processed/serie_transportes_trimestral.csv`

### 4.3 Atividades financeiras
- [ ] Baixar concessões de crédito por UF para RR via BCB (Nota de Crédito)
  - [ ] Deflacionar pelo IPCA nacional
  - [ ] Aplicar suavização (média móvel 3 meses) antes de calcular o índice
- [ ] Baixar saldo de depósitos bancários em RR via BCB Estban (componente secundário)
  - [ ] Deflacionar pelo IPCA nacional
- [ ] Construir índice composto (concessões como proxy principal, depósitos como secundário)
- [ ] Salvar em `data/processed/serie_financeiro_trimestral.csv`

### 4.4 Outros serviços
- [ ] Baixar vínculos em saúde e educação privadas (CNAE P+Q) do CAGED para RR
- [ ] Baixar vínculos em alojamento e alimentação (CNAE I) do CAGED para RR
- [ ] Baixar vínculos em atividades profissionais e administrativas (CNAE M+N) do CAGED para RR
- [ ] Construir índice composto por subgrupo com pesos explícitos (participação no VAB de outros serviços)
- [ ] Salvar em `data/processed/serie_outros_servicos_trimestral.csv`

### 4.5 Índice de serviços privados e benchmarking
- [ ] Combinar comércio + transportes + financeiro + outros com pesos das Contas Regionais
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

### 5.2 Teste de sensibilidade (versão A vs. versão B)
- [ ] Gerar versão B do índice com variação de hipótese a definir, por exemplo:
  - [ ] Calendário agrícola alternativo (Censo 2017 se disponível, ou hipótese simplificada)
  - [ ] Pesos alternativos nos índices compostos (ex: ICMS com peso maior em Comércio)
- [ ] Comparar versão A e versão B: calcular divergência trimestral e anual
- [ ] Documentar resultado do teste na nota técnica

### 5.3 Ajuste sazonal
- [ ] Aplicar X-13ARIMA-SEATS (`seasonal`) ao índice geral
- [ ] Aplicar X-13ARIMA-SEATS a cada componente setorial
- [ ] Publicar duas versões: com ajuste sazonal e sem ajuste sazonal
- [ ] Salvar em `data/output/indice_geral_rr_sa.csv` (série dessazonalizada)

### 5.4 Validação final
- [ ] Variação anual do índice geral vs. Contas Regionais IBGE (todos os anos disponíveis)
- [ ] Comparar perfil de ciclo com IBC-BR e IBCR Norte (Banco Central)
- [ ] Verificar correlação com arrecadação tributária total de RR
- [ ] Verificar comportamento em 2020 (queda COVID) vs. estados vizinhos
- [ ] Documentar e justificar eventuais divergências

### 5.5 Exportação dos dados
- [ ] Gerar arquivo Excel com todas as séries (índice geral + setoriais + SA)
  - [ ] Aba: índice geral
  - [ ] Aba: componentes setoriais
  - [ ] Aba: série dessazonalizada
  - [ ] Aba: metadados e fontes
- [ ] Gerar arquivo CSV para cada série
- [ ] Salvar em `data/output/`

### 5.6 Dashboard interativo
- [ ] Criar estrutura do app (`dashboard/app.R`)
- [ ] Implementar gráfico do índice geral (com e sem ajuste sazonal)
- [ ] Implementar gráfico de contribuição setorial
- [ ] Implementar tabela de variações (trimestre/trimestre e ano/ano)
- [ ] Adicionar botão de download (CSV e XLSX)
- [ ] Testar em diferentes tamanhos de tela
- [ ] Publicar (Shinyapps.io ou servidor SEPLAN)

### 5.7 Nota técnica
- [ ] Criar arquivo `notas/nota_tecnica.qmd` (Quarto)
- [ ] Escrever seção de metodologia
  - [ ] Justificativa das proxies por setor (com classificação de qualidade: forte / aceitável / fraca)
  - [ ] Tabela de tipologia das proxies (volume / valor nominal / fluxo / estoque / insumo)
  - [ ] Cobertura das culturas agrícolas no índice (% do VBP — resultado da Etapa 1.0)
  - [ ] Tratamento da PAM/LSPA e coeficientes do Censo 2006
  - [ ] Método Denton-Cholette: explicação em linguagem acessível
  - [ ] Resultado do teste de sensibilidade (versão A vs. B)
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
| 0 | Planejamento e infraestrutura | 🟢 Concluída |
| 1 | Agropecuária | 🟢 Concluída |
| 2 | Administração Pública | 🟢 Concluída |
| 3 | Indústria | 🟢 Concluída |
| 4 | Serviços Privados | ⚪ Não iniciada |
| 5 | Agregação e publicação | ⚪ Não iniciada |
| 6 | Manutenção trimestral | ⚪ Não iniciada |

> 🟢 Concluída · 🟡 Em andamento · ⚪ Não iniciada
