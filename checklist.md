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
- [x] Registrar sugestões de aprimoramento das proxies em `notas/metodologia/sugestoes1.md`

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
  - [x] Censo 2017 não publicou tabela equivalente — mantido como referência metodológica secundária
- [x] Construir três versões do calendário (laboratório `notas/experimentos/teste_calendario_colheita_censo_agro_2006/`):
  - [x] Versão A — SEADI-RR: calendário oficial da secretaria estadual (versão de produção)
  - [x] Versão B — Censo Agro 2006, ponderado por área colhida
  - [x] Versão C — Censo Agro 2006, ponderado por nº de estabelecimentos
- [x] Versões A/B/C salvas em `data/referencias/` (versionadas no Git)
- [x] `01_agropecuaria.R` carrega calendário do CSV via parâmetro `versao_calendario`
  - [x] Versão ativa em produção: **SEADI** (`versao_calendario <- "seadi"`)
  - [x] Verificar que cada linha soma 1,0 (normalização automática no script) → OK
  - [x] Validar com calendário agroclimático de RR → OK (T3 = pico colheita soja/milho/arroz)
- [x] Salvar matriz ativa em `data/processed/coef_sazonais_colheita.csv`

### 1.2 Série mensal de produção de lavouras
- [x] Baixar PAM para Roraima via `sidrar` (tabela 5457 — temporárias e permanentes)
  - [x] Coletar quantidade produzida das 10 culturas para todos os anos disponíveis
  - [x] Último ano coberto pela PAM para RR: **2024**
- [x] Para o ano corrente não coberto pela PAM: LSPA (tabela 6588, c48) valor de dezembro
  - [x] Ano de corte: PAM até 2024, LSPA para **2025** (provisório)
  - [x] Ao publicar nova PAM, substituir valor LSPA automaticamente no script
- [x] Aplicar coeficientes sazonais do Censo → produção mensal por cultura
- [x] Calcular índice de Laspeyres de quantidade com pesos PAM da janela móvel dos 4 últimos anos disponíveis
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
  - [x] Lavouras e pecuária: calibração estrutural anual atualizada para o desenho vigente do projeto
- [x] Calcular índice agropecuário trimestral (base 2020 = 100)
- [x] Aplicar Denton-Cholette (`tempdisagg::td()`, `~ 0 + x`, `conversion="mean"`) contra VAB agropecuário anual
- [x] Validar: variação anual do índice **coincide exatamente** com Contas Regionais (2011–2023)
- ~~Gerar gráfico de validação (série vs. benchmark anual)~~ *(removido — validação numérica via `05d_validacao.R` é suficiente nesta fase)*
- [x] Salvar em `data/output/indice_agropecuaria.csv`
- [x] Atualizar `historico_simples.md` com conclusão da Fase 1

---

## Fase 2 — Administração Pública

### 2.1 Folha federal (SIAPE)
- [x] Investigar API do Portal da Transparência: endpoint `/remuneracao-servidores-ativos` retorna HTTP 403 para o cadastro padrão — independentemente do token ou parâmetros
- [x] Processar SIAPE via arquivos mensais `.zip` do Portal da Transparência
- [x] Tornar a base federal obrigatória: sem `data/raw/siape_rr_mensal.csv`, o script de AAPP para com erro

### 2.2 Folha estadual (FIPLAN/SEPLAN-RR — FIP 855)
- [x] Ler o relatório `FIP 855 - Resumo Mensal da Despesa Liquidada`
- [x] Construir a proxy estadual pela soma de `3190.1100` + `3190.1200` + `3190.1300`
- [x] Usar a série mensal diretamente e agregar por trimestre
- [x] Salvar em `data/raw/folha_estadual_rr_mensal.csv`

### 2.3 Folha municipal (SICONFI/STN — 15 municípios de RR)
- [x] Coletar RREO Anexo 06 via API SICONFI para todos os 15 municípios de RR
  - [x] Frequência confirmada: bimestral acumulado (RREO)
  - [x] Cobertura: 30–37 bimestres por município (variação por data de início dos relatórios)
- [x] Converter acumulado → incremental por município → agregar RR → trimestral
- [x] Salvar em `data/raw/folha_municipal_rr.csv`

### 2.4 Série de volume e benchmarking
- [x] Combinar folhas estadual + municipal + federal SIAPE (73 ZIPs mensais processados)
  → **REFORMA 2026-04-13**: SIAPE integrado com download manual dos ZIPs mensais do Portal da Transparência; meses ausentes (abr/2021, dez/2024, fev/2025 — ZIPs com Remuneracao.csv vazio) interpolados por aproximação linear
- [x] Deflacionar pelo IPCA nacional (SIDRA tab 1737, índice encadeado base jan/2020=1)
- [x] Agregar em trimestres
- [x] Calcular índice de volume (base 2020 = 100)
- [x] Aplicar Denton-Cholette contra VAB AAPP anual das Contas Regionais (2020–2023)
  → **REFORMA 2026-04-13**: benchmark substituído por índice de **volume** (Especiais IBGE `tab05.xls`); estendido geometricamente (+3,2%/ano) para 2024–2025
- [x] Validar: variação anual coincide exatamente com Contas Regionais (volume real, pós-reforma)
  - [x] 2021: +3,2% (índice) vs. +3,2% (IBGE volume) ✓
  - [x] 2022: +4,1% vs. +4,1% ✓
  - [x] 2023: +2,4% vs. +2,4% ✓
- [x] Salvar em `data/output/indice_adm_publica.csv` (24 obs., 2020T1–2025T4)
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
- [x] Pesos internos derivados das Contas Regionais 2020 (SIUP 5,51 / Const. 4,98 / Transf. 1,15)
- [x] Cálculo do índice composto com pesos normalizados dentro do bloco
- [x] Validação com `validar_serie()` em cada componente e no composto
- [x] Salvar em `data/output/indice_industria.csv`
- [x] **Executar** `R/03_industria.R` e verificar outputs
- [x] Validação manual: comparar variações anuais com Contas Regionais IBGE
  - Variações anuais: 2021 +10,6% / 2022 +20,6% / 2023 +9,4% / 2024 +17,5% / 2025 +19,2%
  - Denton garante exatidão vs. IBGE nos anos com benchmark (2020–2023)
  - SIUP segue influenciando fortemente o bloco, mas a base 2020 reduziu a distorção criada pelos pesos internos de 2021
  - 2025T3 inicialmente ausente: bug corrigido (grid de meses com saldo=0 para meses sem movimentação CAGED)
  - Índice final: 24 observações (2020T1–2025T4) ✓
- [x] Atualizar `historico_simples.md` com conclusão confirmada da Fase 3

---

## Fase 4 — Serviços Privados

### 4.0 Decisão metodológica — Comércio com ICMS (integrado em 2026-04-15)
- [x] ICMS por atividade (SEFAZ-RR) obtido em PDFs (trimestral 2020–2024 + mensal 2024–2026)
- [x] **Decisão**: integrar ICMS como 3º componente do Comércio com pesos energia 40% / ICMS 40% / CAGED G 20%
- [x] Pesos finais Comércio: energia comercial 40%, ICMS SEFAZ-RR deflacionado 40%, CAGED G 20%
- [x] Fallback automático no script para 2 componentes (energia 67% + CAGED 33%) se CSV ausente

### 4.1 Comércio
- [x] Reutilizar energia comercial ANEEL da coleta 3.1 (sem coleta adicional)
- [x] Obter ICMS por atividade econômica da SEFAZ-RR — segmento comércio
  → **INTEGRADO 2026-04-15**: `R/00b_icms_sefaz_atividade.R` extrai shares de PDFs da SEFAZ-RR;
    `icms_comercio_mi` em `data/processed/icms_sefaz_rr_trimestral.csv` (2020T1–2026T1)
  - [x] Deflacionar pelo IPCA nacional (deflator trimestral = média mensal do índice de preços jan/2020=1)
  - ~~Registrar datas de quebras tributárias~~ *(não há quebras documentadas no período 2020–2026)*
- [x] Reutilizar vínculos no comércio (CNAE G) do CAGED — cache da Fase 3
- [x] Construir índice composto (energia 40% + ICMS 40% + CAGED G 20%) com pesos explícitos
  - [x] Energia comercial como componente de volume físico (independente de preço)
  - [x] ICMS comércio deflacionado como componente de valor real
  - [x] Denton-Cholette contra VAB Comércio das Contas Regionais (2020–2023)

### 4.2 Transportes
- [x] Implementar coleta de dados do aeroporto de Boa Vista via ANAC
  - [x] Passageiros embarcados e desembarcados (VRA mensal — ICAO SBBV)
  - [x] Carga aérea (VRA mensal — ICAO SBBV)
- [x] Implementar coleta de vendas de óleo diesel em RR via ANP (CSV dados abertos — URL atualizada)
- [x] ANP diesel: 74 meses coletados (2020–2026) ✓
- [x] Construir índice composto com pesos explícitos
  - [x] Pesos nominais: passageiros ANAC 40%, carga ANAC 30%, diesel ANP 30%
  - [x] Fallback documentado: diesel ANP 100% quando ANAC indisponível
  - [x] Documentar sobreposição do diesel na nota técnica (proxy contaminada)
- [x] Denton-Cholette contra VAB Transporte das Contas Regionais (2020–2023)
- [x] ANAC: microdados mensais baixados manualmente (74 ZIPs, 2020–2026) ✓
  - Pasta: `bases_baixadas_manualmente/microdados_anac_mensal_2020.1_2026.2_basico`
  - 74 meses SBBV processados — 2.196.361 passageiros totais
- [x] Executar: Transportes com 24 trimestres (ANAC + diesel ANP) ✓

### 4.3 Atividades financeiras
- [x] Implementar coleta de concessões de crédito por UF via BCB OData (NotaCredito)
  - [x] Deflacionar pelo IPCA nacional
  - [x] Aplicar suavização (média móvel 3 meses)
- [x] Implementar coleta de depósitos bancários em RR via BCB Estban OData (verbete 160)
  - [x] Deflacionar pelo IPCA nacional
- [x] Índice composto: concessões 70% + depósitos 30% (com fallback se API indisponível)
- [x] Denton-Cholette contra VAB Financeiro das Contas Regionais (2020–2023)
- [x] BCB OData indisponível (HTTP 404) — resolvido via download manual ✓
  - Estban: 71 ZIPs processados (`bases_baixadas_manualmente/dados_estban_bcb`)
  - SCR concessões: 7 ZIPs processados (`bases_baixadas_manualmente/dados_bcb_src_2020_2025`)
  - Financeiro — 24 trimestres gerados (concessões 70% + depósitos 30%)
  - Nota: Denton-Cholette falhou por NA em alguns meses; índice gerado sem ancoragem plena

### 4.4 Imobiliário
- [x] Interpolação linear entre benchmarks anuais das Contas Regionais (sem proxy de mercado)
- [x] Extrapolação linear com tendência dos últimos 2 anos CR para 2024–2025

### 4.5 Outros serviços
- [x] Reutilizar CAGED I (alojamento/alimentação) — cache da Fase 3
- [x] Reutilizar CAGED M+N (prof./admin.) — cache da Fase 3
- [x] Reutilizar CAGED P+Q (educ./saúde privada) — cache da Fase 3
- [x] Pesos intra-bloco: proporcionais ao estoque médio de emprego de 2020 (dinâmicos)
- [x] Denton-Cholette contra VAB Outros Serviços das Contas Regionais (2020–2023)

### 4.6 Informação e comunicação / Extrativas
- [x] Info e Com: CAGED J (cache Fase 3) — Denton contra CR
- [x] Extrativas (0,05%): interpolação linear CR (mesma lógica do Imobiliário)

### 4.7 Índice composto de serviços privados
- [x] Script `R/04_servicos.R` criado e revisado
- [x] Laspeyres setorial com pesos dos subsetores derivados do VAB 2020 (7 subsetores)
- [x] Coluna de saída: `indice_servicos` + subíndices por setor
- [x] **Executar** `R/04_servicos.R` e verificar outputs
- [x] Validar: comparar variações anuais com Contas Regionais IBGE (2020–2023)
  - 2021: +19,0% / 2022: +7,7% / 2023: +12,0% / 2024: +11,8% / 2025: +10,8%
  - Denton âncora exatamente 2020–2023 (anos com benchmark CR)
  - Transportes com dados reais (diesel ANP — ANAC pendente); Financeiro com NA (BCB OData 404)
- [x] Confirmar 24 observações (2020T1–2025T4) no arquivo de saída ✓
- [x] Salvar em `data/output/indice_servicos.csv` ✓
- [x] Atualizar `historico_simples.md` com conclusão da Fase 4

---

## Fase 5 — Agregação e publicação

### 5.1 Índice geral agregado
- [x] Importar índices setoriais: agropecuária, AAPP, indústria, serviços
- [x] Aplicar pesos das Contas Regionais (participação no VAB total)
  → **REFORMA 2026-04-13**: pesos calculados dinamicamente do VAB nominal de 2020 (base correta do Laspeyres); bug corrigido — linha "Total das Atividades" excluída do denominador (duplicava a soma). Pesos corretos: Agro=6,89% | AAPP=45,01% | Ind=11,63% | Serv=36,46%
- [x] Calcular índice geral trimestral encadeado (base 2020 = 100)
- [x] Aplicar Denton-Cholette final contra VAB total de RR das Contas Regionais
  → **REFORMA 2026-04-13**: benchmark substituído — agora usa índice de **volume** (Especiais IBGE, `tab05.xls`, série encadeada 2002–2023), não VAB nominal (Tabela 5). Ver `notas/reformas/indicador_real/plano_reforma_indicador_real.md`.
- [x] Salvar em `data/output/indice_geral_rr.csv`
  → **CORREÇÃO 2026-04-14**: `extrapolar_tendencia()` corrigida para crescer pelo trimestre homólogo do ano anterior (preserva sazonalidade); todos os scripts setoriais (01–04) passaram a usar Denton sobre o período completo das proxies com benchmark estendido via `estender_benchmark()` em `utils.R` — elimina extrapolação plana que destruía a sazonalidade em 2024–2025
- [x] Alinhar a documentação interna da agregação ao código vigente
  → **CORREÇÃO 2026-04-14**: cabeçalho e comentários de `05_agregacao.R` atualizados para refletir pesos Laspeyres de 2020 e extrapolação por trimestre homólogo, evitando leitura incorreta de “pesos 2023” ou “tendência linear”

### 5.2 Teste de sensibilidade (versão A vs. versão B vs. versão C)

**Candidatos definidos — calendário agrícola (três versões já preparadas):**
- [x] Versão A (produção): Calendário SEADI-RR — `data/referencias/calendario_colheita_seadi_rr.csv`
      Fonte: Calendário Agrícola SEADI-RR (secretaria estadual de agricultura)
- [x] Versão B (candidata): Censo Agropecuário 2006, ponderado por área colhida
      `data/referencias/calendario_colheita_censo2006_area_rr.csv`
- [x] Versão C (candidata): Censo Agropecuário 2006, ponderado por nº de estabelecimentos
      `data/referencias/calendario_colheita_censo2006_estabelecimentos_rr.csv`
- [x] Para testar: script `R/05b_sensibilidade_calendario.R` criado e executado
      Usa `source(01_agropecuaria.R)` com variáveis pré-definidas — não-destrutivo

**Outros candidatos — pesos das proxies compostas:**
- [x] Otimizar pesos das proxies compostas por minimização da variância da correção Denton
      → **IMPLEMENTADO 2026-04-15**: script `R/05b_sensibilidade_pesos.R`; busca em grade (504 combinações,
        passo 5%); critério: `sum(diff(output/proxy)²)`. Resultados em `data/output/sensibilidade/`.
  - [x] Ind. Transformação: energia 70%→**55%** / CAGED C 30%→**45%** (melhoria 59,9%)
  - [x] Comércio: energia 40%→**60%** / ICMS 40%→**20%** / CAGED G 20% mantido
        *(decisão conservadora: ótimo Denton = 100% energia, mas ICMS tem histórico curto)*
  - [x] Transportes: pax 40%→**55%** / carga 30%→**0%** / diesel 30%→**45%** (melhoria 41,7%)
  - [x] Financeiro: concessões 70%→**40%** / depósitos 30%→**60%** (melhoria 90,5%)
  - [x] Documentar metodologia e decisões em `notas/metodologia/otimizacao_pesos_proxies.md`
  - [x] Pesos atualizados nos scripts `R/03_industria.R` e `R/04_servicos.R`
  - [ ] Re-rodar após publicação das CR 2024 (previsão: out/2026) para re-estimar com 5 anos de benchmark

**Execução do teste:**
- [x] Comparar versões A/B/C: calcular divergência trimestral e anual
      Resultados em `data/output/sensibilidade/comparacao_calendarios.csv`
- [ ] Documentar resultado do teste na nota técnica

**Resultado do teste (2026-04-12):**
- Médias anuais **idênticas** nas três versões (Denton correto: dif < 10⁻⁶)
- Divergência sazonal **alta**: RMSE B vs A = 126 pts; C vs A = 117 pts
- Ponto crítico: T4 — versão A (SEADI) = 200,9; versões B e C = ~27 (7x menor)
- Causa: soja (53% do peso das lavouras) — SEADI distribui colheita em T3+T4;
  Censo 2006 concentra quase tudo em T3 (calendário de 20 anos atrás)
- Impacto máximo no índice geral: ~21,7 pts por trimestre (pelo peso de 8,87%)
- **Conclusão: versão A (SEADI-RR) mantida como produção. Alta sensibilidade
  ao calendário documentada — hipótese metodológica relevante para nota técnica.**

### 5.3 Ajuste sazonal
- [x] Aplicar X-13ARIMA-SEATS (`seasonal`) ao índice geral
- [x] Aplicar X-13ARIMA-SEATS a cada componente setorial
- [x] Publicar duas versões: com ajuste sazonal e sem ajuste sazonal
- [x] Salvar em `data/output/indice_geral_rr_sa.csv` (série dessazonalizada)
      Arquivo gerado: `data/output/indice_geral_rr_sa.csv` (NSA + SA por componente)
      Fatores sazonais: `data/output/fatores_sazonais.csv`

**Resultado (2026-04-12, rerrodado após reforma 2026-04-13):**
- X-13ARIMA-SEATS convergiu para todos os 5 componentes (modo X-11, transformação auto)
- Fatores sazonais aditivos: geral range=15,13 pts; agropecuária range=294,61 pts
- Amplitude pico/vale NSA (2020–2023): 88,1 → 134,9; SA: 95,5 → 129,8 (mais suave ✓)
- Variações anuais: 2021 NSA +8,19% SA +8,29% | 2022 NSA +10,86% SA +10,95% | 2023 NSA +4,34% SA +4,45%
- IEEE_UNDERFLOW_FLAG: avisos normais do Fortran interno do X-13 no Windows (sem impacto)

### 5.4 Validação final
- [x] Variação anual do índice geral vs. Contas Regionais IBGE (todos os anos disponíveis)
      MAE = 0,00 pp (Denton ancora exatamente ao CR — por construção)
- [x] Comparar perfil de ciclo com IBC-BR e IBCR Norte (Banco Central)
      IBC-BR: corr nível=0,906; corr variação=0,401
      IBCR Norte: corr nível=0,374; corr variação=-0,419 (esperado — RR≠AM/PA)
- [x] Verificar correlação com arrecadação tributária total de RR
      → **RESULTADO 2026-04-15**: ICMS trimestral total x IAET-RR: r(nível)=0,754 | r(var. YoY)=-0,112 (20 pares).
      Correlação de nível razoável (tendência comum); variação descorrelacionada — esperado, pois ICMS é nominal e IAET é volume deflacionado.
- [x] Verificar comportamento em 2020 (queda COVID) vs. estados vizinhos
      Queda T2 (-9,8% vs T1); recuperação em T3 por colheita e AAPP estável
- [x] Documentar e justificar eventuais divergências
- [x] Montar relatório rápido `projeto x Contas Regionais` com nominal total, nominal setorial, PIB nominal e crescimento real do VAB
      → **RELATÓRIO 2026-04-14**: nota criada em `notas/metodologia/relatorio_comparacao_projeto_vs_cr.md`; comparação nominal fechada no total e nos 4 blocos, com nota explícita sobre a lacuna atual de `PIB real`.

**Resultado do teste (rerrodado após reforma 2026-04-13):**
- Crescimento RR 2021–2023 (real): **+8,2%, +10,9%, +4,3%** — antes era +12,3%, +17,2%, +20,3% nominal
- IBCR Norte: corr nível=0,386; corr variação=-0,195 (pré-reforma: corr=-0,74, MAE=14 pp; pós: MAE=5,2 pp)
- MAE vs. CR IBGE: 8,8 pp (esperado e correto — diferença ≈ inflação setorial de RR)
- Consistência interna: Agro domina variância trimestral (corr Agro-Geral=0,855);
  Ind-Serviços=0,498; AAPP-Serviços=0,214
- Ancoragem Denton perfeita: ✓ para 2020, 2021, 2022, 2023

### 5.5 Exportação dos dados
- [x] Gerar arquivo Excel com todas as séries (índice geral + setoriais + SA)
  - [x] Aba 1: Índice Geral (NSA + var. trim. e anual)
  - [x] Aba 2: Componentes Setoriais (4 blocos NSA)
  - [x] Aba 3: Dessazonalizado SA (índice geral + 4 blocos)
  - [x] Aba 4: Fatores Sazonais (aditivos, X-13ARIMA-SEATS)
  - [x] Aba 5: Metadados (fontes, pesos, notas metodológicas)
  - [x] Aba 6: VAB Nominal — índice real × deflator implícito / 100 (adicionado na reforma 2026-04-13)
- [x] Gerar arquivo CSV para cada série
- [x] Salvar em `data/output/`
      `IAET_RR_series.xlsx` | `IAET_RR_geral.csv` | `IAET_RR_componentes.csv` | `IAET_RR_dessazonalizado.csv` | `indice_nominal_rr.csv`
- [x] Corrigir o `05f_vab_nominal.R` para o fechamento anual do VAB nominal bater exatamente com o IBGE
      → **CORREÇÃO 2026-04-14**: deflator total deixou de ser média ponderada de deflatores setoriais e passou a usar o deflator implícito direto do total anual do IBGE; trimestralização via Denton mantida com IPCA. O `VAB nominal` anual agora fecha exatamente com as Contas Regionais em `2020–2023`, e o `PIB nominal` herdou esse fechamento nos anos benchmark.

### 5.6 Dashboard interativo
- [x] Criar estrutura do app (`dashboard/app.R`) — `bslib` v5 + `plotly` + `DT`
- [x] Implementar gráfico do índice geral (com e sem ajuste sazonal) — seletor NSA/SA + slider de período
- [x] Implementar gráfico de contribuição setorial — barras empilhadas (p.p.) + índices setoriais
- [x] Implementar tabela de variações (trimestre/trimestre e ano/ano) — `var_trim`, `var_anual`, `var_trim_sa`
- [x] Adicionar botão de download (CSV e XLSX) — com metadados e estilo SEPLAN no XLSX
- [x] Aba específica do PIB com VAB nominal, ILP e PIB nominal trimestral
- [x] Aba "Sobre" com pesos setoriais (pizza interativa) + metadados do projeto
- [x] App operacional localmente com leitura dos outputs em `data/output/`
- [x] Corrigir inicialização do app para aceitar execução pela raiz do projeto e pela pasta `dashboard/`
- [x] Remover dependência de `font_google()` no tema para evitar bloqueios de inicialização sem rede
- [x] Reorganizar a navegação do app para priorizar o IAET e permitir escolha de séries/componentes
- [x] Substituir linguagem técnica do painel por rótulos mais legíveis (`sem ajuste sazonal`, `dessazonalizado`, `taxa de crescimento anual`)
- [x] Criar abas específicas de taxas anuais para o bloco IAET e para o bloco PIB
- [x] Permitir alternância entre leitura anual e trimestral nas abas separadas de taxas
- [x] Mover legendas para fora da área útil dos gráficos
- [x] Tornar a aba `Sobre` interativa com escolha do ano da estrutura setorial e do período de referência
- [x] Reformular as abas finais para mostrar níveis nas séries e crescimento real abaixo, evitando leitura nominal indevida das taxas
- [x] Corrigir títulos dinâmicos das abas finais e converter gráficos de nível para colunas empilhadas
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

### 5.8 PIB nominal trimestral
- [x] Registrar desenho metodológico inicial em `notas/metodologia/ideia_pib.md`
- [x] Criar `notas/reformas/impostos/plano_reforma_impostos.md`
- [x] Criar `notas/reformas/impostos/checklist_reforma_impostos.md`
- [x] Investigar `ICMS` estadual, `ISS` municipal e bloco federal como candidatos ao ILP trimestral
- [x] Definir proxy final: `ICMS` estadual da SEFAZ-RR
- [x] Criar `R/05g_pib_nominal.R`
- [x] Gerar `data/output/pib_nominal_rr.csv`

### 5.9 VAB nominal setorial trimestral
- [x] Criar `R/05h_vab_nominal_setorial.R`
- [x] Gerar `data/output/vab_nominal_setorial_rr.csv`
- [x] Gerar `data/output/vab_nominal_setorial_anual_rr.csv`
- [x] Validar fechamento anual dos 4 blocos contra as Contas Regionais
      → **IMPLEMENTAÇÃO 2026-04-14**: `Agropecuária`, `AAPP`, `Indústria` e `Serviços`
      passaram a ter série trimestral nominal própria para `2020–2023`, construída com
      benchmark nominal anual das CR, deflator anual por bloco e Denton-Cholette.

### 5.10 PIB Real anual
- [x] Criar `R/05i_pib_real.R`
- [x] Gerar `data/output/pib_real_anual_rr.csv` (PIB real anual em R$ 2020 + taxa de crescimento)
- [x] Validar taxas de crescimento: 2021 +8,2% / 2022 +10,9% / 2023 +4,3% / 2024–2025 extrapolados
- [x] Integrar no dashboard (aba "PIB anual" — gráfico de crescimento real)

---

## Fase 6 — Manutenção e atualização trimestral

### 6.1 Infraestrutura de manutenção (implementada em 2026-04-18)
- [x] Criar `config/release.R` com variável `trimestre_publicado` (gate de publicação)
  - [x] Lido por `05e_exportacao.R` para filtrar a exportação pública
  - [x] Lido por `run_all.R` para exibir o trimestre publicado no cabeçalho e no resumo
- [x] Criar `R/06_coleta_fontes.R` — atualiza todas as fontes automatizáveis em um único comando
  - [x] SIDRA: PAM (5457), LSPA (6588), abate (1092), ovos (7524), IPCA (1737), PIB (5938)
  - [x] ANP: vendas de diesel RR (dados abertos, download inline)
  - [x] ANEEL: apaga cache do ano corrente para forçar re-download no próximo `run_all.R`
  - [x] Relatório de cobertura por fonte (automatizáveis e manuais) ao final
- [x] Criar `R/06_avanca_publicacao.R` — gate interativo para avanço do trimestre
  - [x] Checklist de 6 itens obrigatórios via `readline()` (todos devem ser confirmados)
  - [x] Atualiza `config/release.R` com o próximo trimestre
  - [x] Cria commit git com mensagem padronizada + tag (ex: `v2026-Q1`)
  - [x] Orienta a rodar `run_all.R` para exportação oficial

### 6.2 Rotina a cada trimestre (repetir para cada novo release)

**Etapa 1 — Atualizar fontes:**
- [ ] Rodar `source("R/06_coleta_fontes.R")` para atualizar SIDRA, ANP e ANEEL
- [ ] Baixar SIAPE (Portal da Transparência — ZIP mensal por UF) e colocar em `bases_baixadas_manualmente/dados_siape_portal_transparencia/`
- [ ] Baixar FIPLAN estadual (FIP 855) e colocar em `bases_baixadas_manualmente/dados_folha_rr_fip855/`
- [ ] Baixar ANAC Boa Vista (microdados VRA mensais) e colocar em `bases_baixadas_manualmente/microdados_anac_mensal_.../`
- [ ] Baixar BCB Estban (ZIPs mensais) e colocar em `bases_baixadas_manualmente/dados_estban_bcb/`
- [ ] Baixar BCB SCR (ZIPs de concessões) e colocar em `bases_baixadas_manualmente/dados_bcb_src_2020_2025/`
- [ ] Baixar ICMS SEFAZ-RR (PDFs por atividade) e colocar em `bases_baixadas_manualmente/dados_icms_por_atividade/`

**Etapa 2 — Verificar cobertura:**
- [ ] Re-rodar `source("R/06_coleta_fontes.R")` e confirmar que todas as fontes mostram OK para o trimestre alvo

**Etapa 3 — Modelagem e validação interna:**
- [ ] Rodar `source("R/run_all.R")` — pipeline completo (exportação ainda filtrada ao trimestre anterior)
- [ ] Confirmar que todas as validações automáticas passaram (`05d_validacao.R` sem alertas críticos)
- [ ] Verificar se há revisões nas Contas Regionais do IBGE e atualizar benchmarks se necessário
- [ ] Inspecionar outputs em `data/output/` e atualizar `logs/fontes_utilizadas.csv`
- [ ] Atualizar dashboard localmente e verificar visualmente as novas séries

**Etapa 4 — Publicação:**
- [ ] Gerar informativos internos SEPLAN e obter aprovação
- [ ] Redigir nota técnica conjuntural
- [ ] Realizar comunicação à imprensa
- [ ] Rodar `source("R/06_avanca_publicacao.R")` — checklist interativo avança `config/release.R`, cria commit e tag
- [ ] Rodar `source("R/run_all.R")` novamente — exportação oficial do novo trimestre gerada
- [ ] Distribuir: `data/output/IAET_RR_series.xlsx`, `IAET_RR_geral.csv`, `IAET_RR_componentes.csv`
- [ ] Atualizar `historico_simples.md` com o release
- [ ] Fazer `git push && git push origin <tag>`

---

## Status geral

| Fase | Descrição | Status |
|---|---|---|
| 0 | Planejamento e infraestrutura | 🟢 Concluída |
| 1 | Agropecuária | 🟢 Concluída |
| 2 | Administração Pública | 🟢 Concluída |
| 3 | Indústria | 🟢 Concluída |
| 4 | Serviços Privados | 🟢 Concluída |
| 5 | Agregação e publicação | 🟡 Em andamento (5.1–5.6, 5.8, 5.9 e 5.10 concluídas; 5.7 nota técnica pendente; publicação/testes finais do dashboard pendentes) |
| 6 | Manutenção trimestral | 🟡 Em andamento (6.1 infraestrutura concluída; 6.2 rotina operacional pronta para uso) |

> 🟢 Concluída · 🟡 Em andamento · ⚪ Não iniciada
