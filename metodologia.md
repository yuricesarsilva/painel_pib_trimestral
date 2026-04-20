# Metodologia do PIB Trimestral de Roraima
### Indicador de Atividade Econômica Trimestral — IAET-RR

**Autoria:** Yuri Cesar de Lima e Silva · SEPLAN/RR — CGEES/DIEAS  
**Versão:** 1.1 · Abril/2026  
**Cobertura:** 2020T1 – 2025T4  
**Benchmark:** Contas Regionais IBGE 2020–2023  
**Trimestre publicado:** 2025T4 (gate em `config/release.R`)

---

## Sumário

1. [Contexto e Motivação](#1-contexto-e-motivação)
2. [Arquitetura do Sistema](#2-arquitetura-do-sistema)
3. [Índice de Laspeyres Encadeado por Volume](#3-índice-de-laspeyres-encadeado-por-volume)
4. [Desagregação Temporal — Método Denton-Cholette](#4-desagregação-temporal--método-denton-cholette)
5. [Ajuste Sazonal — X-13ARIMA-SEATS](#5-ajuste-sazonal--x-13arima-seats)
6. [Componentes Setoriais](#6-componentes-setoriais)
   - [6.1 Agropecuária](#61-agropecuária)
   - [6.2 Administração Pública (AAPP)](#62-administração-pública-aapp)
   - [6.3 Indústria](#63-indústria)
   - [6.4 Serviços Privados](#64-serviços-privados)
7. [Otimização de Pesos — Critério de Variância do Denton](#7-otimização-de-pesos--critério-de-variância-do-denton)
8. [PIB Nominal Trimestral](#8-pib-nominal-trimestral)
9. [PIB Real Trimestral](#9-pib-real-trimestral)
10. [Resultados de Validação](#10-resultados-de-validação)
11. [Qualidade das Proxies e Cobertura](#11-qualidade-das-proxies-e-cobertura)
12. [Ciclo de Manutenção Trimestral](#12-ciclo-de-manutenção-trimestral)
13. [Limitações e Agenda de Revisão](#13-limitações-e-agenda-de-revisão)
14. [Referências](#14-referências)

---

## 1. Contexto e Motivação

O Brasil não dispõe de estimativa oficial do PIB estadual em frequência trimestral. As **Contas Regionais do IBGE** — referência metodológica deste projeto — são publicadas anualmente e com defasagem média de dois anos (as contas de 2023 foram divulgadas em outubro de 2025). Roraima, estado com estrutura econômica singular e participação desproporcionalmente elevada do setor público, carece portanto de um indicador conjuntural que permita monitorar a evolução da atividade econômica em tempo próximo ao real.

Este projeto preenche essa lacuna construindo o **Indicador de Atividade Econômica Trimestral de Roraima (IAET-RR)**, um índice encadeado de volume que serve como instrumento metodológico para gerar o **PIB real e nominal trimestral de Roraima** a partir de 2020T1.

> ⚠️ **Restrições estruturais de Roraima**  
> O estado segue sem cobertura da PIM-PF regional e não dispõe de IPCA estadual em nenhum período. Em contrapartida, a PMC e a PMS existem para Roraima em nível de UF e passaram a reforçar o bloco de serviços privados; o IPCA nacional continua sendo o deflator adotado para as séries nominais.

A solução adotada é construir um **índice encadeado de volume sem unidade monetária** — metodologicamente convergente com o **IBCR (Índice de Atividade Econômica Regional) do Banco Central do Brasil** — utilizando proxies de alta frequência disponíveis para Roraima e ancorando os totais anuais nas Contas Regionais via Denton-Cholette.

**Produtos estatísticos gerados:**

- PIB nominal trimestral de Roraima em R\$ milhões (VAB + impostos líquidos sobre produtos)
- PIB real trimestral em R\$ milhões de 2020 e índice encadeado de volume (base média 2020 = 100)
- IAET-RR: índice agregado e por bloco setorial, com e sem ajuste sazonal
- Dashboard interativo com download CSV/XLSX
- Cobertura: 2020T1–2025T4 (2020–2023 com benchmark oficial; 2024–2025 preliminar)

---

## 2. Arquitetura do Sistema

O pipeline é composto por seis fases sequenciais, implementadas em R. A estrutura garante reprodutibilidade total: dado o mesmo conjunto de entradas, o pipeline reaplica todo o processamento e gera as mesmas saídas.

**Fase 1: Agropecuária → Fase 2: Adm. Pública → Fase 3: Indústria → Fase 4: Serviços → Fase 5: Agregação, Ajuste Sazonal e Publicação → Fase 6: Manutenção Trimestral**

Cada fase produz um índice setorial com base média 2020 = 100, ancorado anualmente nas Contas Regionais do IBGE via Denton-Cholette. A Fase 5 agrega os quatro blocos setoriais com pesos Laspeyres de 2020, produz o índice geral, aplica X-13ARIMA-SEATS e deriva o PIB nominal e real. A Fase 6 gerencia o ciclo trimestral de atualização de dados e o gate de publicação oficial.

### Gate de publicação — `config/release.R`

A variável `trimestre_publicado` em `config/release.R` controla qual trimestre está oficialmente publicado. O script `05e_exportacao.R` lê este parâmetro e filtra todas as saídas públicas (Excel e CSVs) até esse limite. O avanço do trimestre publicado só ocorre via `06_avanca_publicacao.R`, após checklist interativo confirmado.

### Scripts do pipeline

| Script | Fase | Saída principal |
|---|---|---|
| `00_dados_referencia.R` | Pré-processamento | Pesos nominais e benchmarks de volume (CR IBGE) |
| `00b_icms_sefaz_atividade.R` | Pré-processamento | `icms_sefaz_rr_trimestral.csv` (shares SEFAZ-RR) |
| `01_agropecuaria.R` | 1 | `indice_agropecuaria.csv` |
| `02_adm_publica.R` | 2 | `indice_adm_publica.csv` |
| `03_industria.R` | 3 | `indice_industria.csv` |
| `04_servicos.R` | 4 | `indice_servicos.csv` |
| `05_agregacao.R` | 5.1 | `indice_geral_rr.csv` |
| `05b_sensibilidade_pesos.R` | 5.2 | Grid de pesos ótimos das proxies compostas (3.836 combinações) |
| `05c_ajuste_sazonal.R` | 5.3 | `indice_geral_rr_sa.csv`, `fatores_sazonais.csv` |
| `05d_validacao.R` | 5.4 | `validacao_relatorio.csv` |
| `05e_exportacao.R` | 5.5 | `IAET_RR_series.xlsx` (filtrado por `trimestre_publicado`) |
| `05f_vab_nominal.R` | 5.6 | `indice_nominal_rr.csv` |
| `05g_pib_nominal.R` | 5.7 | `pib_nominal_rr.csv` |
| `05h_vab_nominal_setorial.R` | 5.8 | `vab_nominal_setorial_rr.csv` |
| `05i_pib_real.R` | 5.9 | `pib_real_rr.csv`, `pib_real_anual_rr.csv` |
| `06_coleta_fontes.R` | 6 | Atualiza caches SIDRA/ANP/ANEEL; relatório de cobertura |
| `06_avanca_publicacao.R` | 6 | Avança `config/release.R`; commit + tag git |

---

## 3. Índice de Laspeyres Encadeado por Volume

O IAET-RR é um **índice encadeado de volume com pesos fixos do ano-base 2020**, seguindo o padrão das Contas Nacionais do IBGE. A formulação é convergente com o método adotado pelo IBCR (Banco Central do Brasil).

### Fórmula base (Laspeyres)

$$I_t = \frac{\displaystyle\sum_{i} w_i \cdot \tilde{x}_{it}}{\displaystyle\sum_{i} w_i \cdot \tilde{x}_{i,0}} \times 100$$

onde $w_i$ é o peso do setor $i$ (participação no VAB nominal de 2020), $\tilde{x}_{it}$ é o índice de volume do setor $i$ no trimestre $t$, e $\tilde{x}_{i,0}$ é o valor médio de 2020 (= 100 por construção).

### Encadeamento anual

Os pesos são calculados a partir do **VAB nominal de 2020** (ano-base do índice) e permanecem fixos até que novas Contas Regionais sejam publicadas. A cada nova publicação anual do IBGE (tipicamente com dois anos de defasagem), os pesos são revisados dinamicamente pelo script `00_dados_referencia.R`.

### Pesos setoriais efetivos (base 2020)

| Bloco | Atividades incluídas | Peso 2020 (%) |
|---|---|---|
| Agropecuária | Lavouras + pecuária | 6,89% |
| Administração Pública | AAPP, defesa, saúde e educação públicas, seguridade social | 45,01% |
| Indústria | SIUP + construção + ind. de transformação + ind. extrativas | 11,63% |
| Serviços Privados | Comércio, transportes, financeiro, imobiliário, outros serviços, informação e comunicação | 36,46% |

> ℹ️ **Distinção entre pesos contábeis e técnicos**  
> Os pesos *contábeis* (participação no VAB de 2020) são usados na agregação entre setores e subsetores, derivados das Contas Regionais. Os pesos *técnicos* — que definem como múltiplas proxies são combinadas dentro de um mesmo subsetor (ex.: 55% energia + 45% emprego na indústria de transformação) — foram otimizados pelo critério de variância do Denton (ver Seção 7).

---

## 4. Desagregação Temporal — Método Denton-Cholette

O Denton-Cholette é o método central do projeto. Ele garante que a **média dos quatro trimestres de cada ano reproduza exatamente o benchmark anual** das Contas Regionais do IBGE, preservando ao máximo o perfil trimestral indicado pelas proxies.

### Função-objetivo

$$\min_{p_1,\ldots,p_T} \sum_{t=2}^{T} \left(\frac{p_t}{x_t} - \frac{p_{t-1}}{x_{t-1}}\right)^2 \quad \text{sujeito a} \quad \frac{1}{4}\sum_{q=1}^{4} p_{4(j-1)+q} = B_j \quad \forall\, j$$

onde $p_t$ é o valor trimestral estimado, $x_t$ é o indicador proxy no trimestre $t$, e $B_j$ é o benchmark anual (índice de volume das Contas Regionais) do ano $j$.

**Interpretação:** a razão $p_t / x_t$ representa o fator de escala entre a série estimada e a proxy. Quando a proxy captura perfeitamente o perfil intra-anual, esse fator é constante ao longo do tempo. Quanto mais a razão varia, mais a proxy se afasta do comportamento real do setor.

### Implementação em R

```r
tempdisagg::td(benchmark ~ 0 + indicador, conversion = "mean")
```

> ⚠️ **Detalhes de implementação críticos**  
> (a) **Fórmula sem intercepto obrigatória**: `~ 0 + indicador`. A forma com intercepto `~ indicador` gera uma matriz RHS que o algoritmo Denton rejeita.  
> (b) **`conversion = "mean"` obrigatório para índices**: a média dos quatro trimestres deve igualar o benchmark anual, não a soma. A opção `"sum"` seria correta para variáveis de fluxo (e.g., VAB nominal em R\$ milhões).

### Decisão sobre o benchmark: volume, não nominal

> ✅ **Reforma metodológica de 13/04/2026**  
> O benchmark anual do Denton-Cholette passou a utilizar o **índice encadeado de volume** das Contas Regionais (`Especiais_2002_2023_xls.zip`, aba `tab05.xls`) em vez do VAB nominal.  
>
> **Motivação:** as proxies trimestrais são indicadores de volume (emprego, energia, passageiros). Ancorá-las ao VAB nominal introduzia inflação setorial no índice real, gerando crescimentos artificialmente elevados (+20% em 2023 com benchmark nominal vs. +4% com benchmark de volume). Com a ancoragem ao volume, as taxas anuais refletem crescimento real e são diretamente comparáveis ao IBCR do Banco Central.

### Tratamento de anos sem benchmark

Para os anos 2024 e 2025 (sem Contas Regionais publicadas), a função `estender_benchmark()` em `utils.R` calcula a **taxa de crescimento geométrica dos últimos 3 anos disponíveis** da série de volume das CR e projeta o benchmark para os anos extras. O cálculo é:

$$\hat{B}_{j} = B_{\text{último}} \times (1 + \hat{g})^{j - \text{último}}, \qquad \hat{g} = \left(\frac{B_{\text{último}}}{B_{\text{último}-n+1}}\right)^{1/(n-1)} - 1$$

onde $n$ é o número de anos de referência (padrão: 3) e $\hat{g}$ é a taxa geométrica anual implícita. O log de execução registra a taxa calculada por setor. Esses valores serão substituídos quando as CR 2024 forem divulgadas pelo IBGE (previsão: outubro de 2026).

---

## 5. Ajuste Sazonal — X-13ARIMA-SEATS

O ajuste sazonal é aplicado ao índice geral e aos quatro blocos setoriais via **X-13ARIMA-SEATS**, implementado pelo pacote R `seasonal` (interface para o programa X-13 do U.S. Census Bureau). O projeto publica tanto a série *sem ajuste sazonal (NSA)* quanto a série *dessazonalizada (SA)*.

| Série | Uso recomendado |
|---|---|
| Sem ajuste sazonal (NSA) | Comparações interanuais (taxa em 4 trimestres), comportamento estrutural |
| Dessazonalizada (SA) | Taxa de crescimento trimestral, leitura conjuntural do momento corrente |

As saídas estão em `data/output/indice_geral_rr_sa.csv` (índices SA por bloco) e `data/output/fatores_sazonais.csv` (fatores sazonais aditivos por componente e trimestre).

---

## 6. Componentes Setoriais

### 6.1 Agropecuária

**Peso no VAB de 2020: 6,89%.** O índice agropecuário é composto por dois subíndices — lavouras e pecuária — calibrados por parâmetro estrutural anual específico dos subsetores da agropecuária, combinado às proxies trimestrais observáveis do projeto.

No estado atual do pipeline, o script usa os caches locais do SIDRA por padrão e só rebaixa novamente as séries quando `atualizar_sidra <- TRUE` é definido explicitamente.

#### Lavouras — hierarquia de fontes

| Situação | Fonte | SIDRA | Critério |
|---|---|---|---|
| Ano com PAM disponível | Produção Agrícola Municipal (PAM) | Tab. 5457 (c782) | Dado consolidado definitivo |
| Ano corrente sem PAM | Levantamento Sistemático (LSPA — leitura mais recente disponível) | Tab. 6588 (c48) | Estimativa provisória; substituída automaticamente quando PAM for publicada |

> ℹ️ **Como a LSPA é usada no pipeline**  
> A LSPA não é um fluxo mensal — ela publica revisões mensais da *projeção anual* de produção. Para cada combinação (produto, ano), o script seleciona o mês mais recente disponível no cache (`slice_max(mes_num)`). Se dezembro já foi publicado, usa-se o fechamento definitivo; se o ano ainda está em curso, usa-se o mês mais recente como melhor estimativa provisória da safra anual. O log de execução registra qual mês está sendo usado para cada ano ("fechamento de dez (definitivo)" ou "provisório — leitura de [mês]"). A desagregação intra-anual é sempre derivada dos coeficientes de colheita, tanto para PAM quanto para LSPA.

**Método de desagregação intra-anual:**

1. Tomar a produção anual por cultura (toneladas ou unidades).
2. Aplicar **coeficientes mensais de colheita** como pesos de distribuição ao longo dos 12 meses.
3. Agregar meses em trimestres.
4. Calcular índice de Laspeyres com pesos VBP médio dos **4 últimos anos disponíveis da PAM** (Tab. 5457, variável *valor da produção*). No processamento atual, a janela efetiva é **2021–2024**.
5. Aplicar Denton-Cholette contra o VAB agropecuário anual das Contas Regionais.

#### Calendários de colheita disponíveis

| Versão | Fonte | Arquivo | Status |
|---|---|---|---|
| **A — SEADI-RR** (ativo) | Calendário Agrícola oficial da Secretaria de Agricultura de RR | `calendario_colheita_seadi_rr.csv` | Produção |
| B — Censo 2006 (área) | Censo Agropecuário 2006, época de colheita, ponderação por área colhida | `calendario_colheita_censo2006_area_rr.csv` | Sensibilidade |
| C — Censo 2006 (estab.) | Idem, ponderação por número de estabelecimentos | `calendario_colheita_censo2006_estabelecimentos_rr.csv` | Sensibilidade |

#### Culturas cobertas e cobertura de VBP

| Cultura | Cobertura do VBP total (RR) |
|---|---|
| Soja | ~54,3% |
| Milho | ~10,6% |
| Arroz | ~9,5% |
| Banana | ~8,0% |
| Mandioca | ~4,6% |
| Laranja | ~2% |
| Feijão | <1% |
| Cana-de-açúcar | <1% |
| Tomate + Cacau | <1% |
| **Total coberto** | **~90,5% do VBP de lavouras** |

#### Pecuária

| Proxy | Fonte/SIDRA | Frequência | Status para RR |
|---|---|---|---|
| Abate de bovinos | IBGE Abate, Tab. 1092 | Trimestral | Disponível |
| Produção de ovos de galinha | IBGE Ovos, Tab. 7524 | Trimestral | Disponível |
| Produção de leite | IBGE Leite, Tab. 74 | Trimestral | Indisponível para RR — excluída |

O bloco pecuário operacional usa apenas as séries trimestrais efetivamente observáveis para Roraima no pipeline atual: abate bovino (Tab. 1092) e ovos de galinha (Tab. 7524). O IBGE não divulga, para Roraima, séries trimestrais equivalentes de abate de suínos e frango no desenho operacional adotado aqui; por isso, a proxy de abate é estritamente bovina.

Os pesos entre lavouras e pecuária são calibrados a partir de uma tabulação anual específica dos subsetores da agropecuária usada como parâmetro interno do projeto. Dentro da proxy pecuária trimestral, o abate bovino recebe peso predominante sobre ovos.

Desde a revisão metodológica desta etapa, a pecuária trimestral não usa mais fallback por interpolação anual quando faltam dados observados. O bloco só é calculado quando `abate` e `ovos` apresentam cobertura trimestral completa no período operacional exigido pelo script; no estado atual, a janela validada vai de `2020T1` a `2025T4`.

**Pesos:** a composição entre lavouras e pecuária usa calibração estrutural anual; a composição interna da pecuária usa ponderação técnica com predominância bovina.

---

### 6.2 Administração Pública (AAPP)

**Peso no VAB de 2020: 45,01%** — *o componente mais importante do IAET-RR.* Inclui administração, defesa, educação e saúde públicas e seguridade social.

#### Justificativa: despesa com pessoal como proxy primária

O IBGE mensura o produto de AAPP nas Contas Regionais pela **abordagem de custo** (*non-market services*): VAB ≈ remuneração do trabalho no setor público + consumo intermediário + consumo de capital fixo. O componente dominante é a despesa com pessoal. Por isso, a folha observada é uma aproximação diretamente ancorada no insumo central usado no cálculo do VAB de Administração Pública.

#### Fontes de dados

| Esfera | Fonte | Endpoint / Arquivo | Cobertura |
|---|---|---|---|
| Federal (SIAPE) | Portal da Transparência — arquivos mensais .zip | Download manual; cache: `data/raw/siape_rr_mensal.csv` | 2020–2026T1 |
| Estadual | FIPLAN / SEPLAN-RR — FIP 855 | Arquivos `.xls` manuais em `bases_baixadas_manualmente/dados_folha_rr_fip855/`; cache: `data/raw/folha_estadual_rr_mensal.csv` | 2020–2025 (72 meses) |
| Municipal (15 municípios) | SICONFI/STN — RREO Anexo 06 | Mesmo endpoint, `id_ente` = código IBGE de cada município | 30–37 bimestres por município |

#### Escopo da variável observada

No componente estadual, a série é extraída do **FIP 855 — Resumo Mensal da Despesa Liquidada** do FIPLAN/SEPLAN-RR e construída como a soma das rubricas `3190.1100` (Vencimentos e Vantagens Fixas - Pessoal Civil), `3190.1200` (Vencimentos e Vantagens Fixas - Pessoal Militar) e `3190.1300` (Obrigações Patronais). Nos municípios, a série segue extraída do SICONFI/STN, **RREO Anexo 06**, conta `RREO6PessoalEEncargosSociais`, coluna **DESPESAS LIQUIDADAS**.

#### Conversão mensal e bimestral → trimestral

No estado, a série do FIPLAN já é mensal, então a conversão consiste em agregar os meses por trimestre. Nos municípios, o RREO é publicado em bimestres acumulados. O procedimento municipal de conversão é:

1. Diferença entre bimestres consecutivos → valor incremental por bimestre (2 meses).
2. Distribuição uniforme entre os 2 meses do bimestre → valor mensal estimado.
3. Agregação por trimestre (3 meses) → valor trimestral nominal.

#### Deflação e construção do índice de volume

$$\text{Índice de volume}_t = \frac{\text{Folha nominal}_t \;/\; \text{IPCA}_t}{\text{Folha nominal}_{2020} \;/\; \text{IPCA}_{2020}} \times 100$$

IPCA nacional: SIDRA Tab. 1737, variável 2266 (variação mensal). O script constrói o índice encadeado de preços com base jan/2020 = 1.

> ✅ **Validação perfeita contra Contas Regionais — índice de volume (2021–2023)**  
> 2021: +3,19% (projeto) = +3,19% (CR IBGE volume) ✓  
> 2022: +4,12% = +4,12% ✓  
> 2023: +2,37% = +2,37% ✓  
>
> *Após a reforma metodológica de 2026-04-13, o benchmark do Denton passou a usar o índice de volume das CR (não o VAB nominal). As taxas de crescimento refletem crescimento real da folha deflacionada.*

---

### 6.3 Indústria

**Peso no VAB de 2020: 11,63%.** O bloco industrial é composto por três subsetores com pesos internos derivados do VAB nominal de 2020 das Contas Regionais.

| Subsetor | VAB 2020 (R\$ mi) | Peso interno | Peso no total |
|---|---|---|---|
| SIUP (energia, gás, água, esgoto) | R\$ 799 mi | 47,4% | 5,51% |
| Construção civil | — | 42,8% | 4,98% |
| Indústria de Transformação | — | 9,9% | 1,15% |

#### SIUP — Eletricidade, Gás, Água, Esgoto e Resíduos

**[Proxy forte]** Proxy: soma mensal do consumo de energia elétrica (kWh) de todas as classes de consumo em Roraima.

**Fonte:** ANEEL SAMP, API CKAN do portal de dados abertos da ANEEL.

Detalhes técnicos da API:
- Dataset ID: `3e153db4-a503-4093-88be-75d31b002dcf`
- Endpoint: `dadosabertos.aneel.gov.br/api/3/action/datastore_search`
- Filtros: `SigAgenteDistribuidora = "BOA VISTA"`, `NomTipoMercado = "Sistema Isolado - Regular"`, `DscDetalheMercado = "Energia TE (kWh)"`
- Roraima opera em **sistema isolado** (separado do SIN); distribuidor: **Roraima Energia S.A.**
- Reaproveitamento: classes "Comercial" → proxy de Comércio; "Industrial" → proxy de Ind. de Transformação

#### Construção Civil

**[Proxy aceitável]** Proxy principal: estoque acumulado de emprego formal (CAGED, seção CNAE F).

O Novo CAGED (2020+) não está disponível em SIDRA nem via API com filtro por UF. O script baixa o arquivo nacional `CAGEDMOV{yearmonth}.7z` do FTP MTE (`ftp.mtps.gov.br`), extrai com 7-Zip local, filtra `uf == 14` (Roraima) com `data.table::fread`, agrega por seção CNAE e apaga os arquivos grandes. Volume: ~2,5 GB de download na primeira execução (72 meses × ~35 MB); idempotente.

**Estoque acumulado:** o CAGED publica fluxo mensal (admissões − desligamentos = saldo). Para usar como indicador Denton (que requer série de nível), acumula-se o saldo a partir de base 1000 (Jan/2020). O Denton calibra o nível absoluto; apenas o perfil temporal importa.

#### Indústria de Transformação

**[Proxy aceitável]** Sem PIM-PF para Roraima. Proxy composta com pesos otimizados:

| Componente | Fonte | Tipo | Peso ótimo |
|---|---|---|---|
| Energia industrial (kWh) | ANEEL SAMP — classe "Industrial" | Volume físico | **55%** |
| Emprego CAGED C | FTP MTE — seção C | Insumo (estoque) | **45%** |

Os pesos foram otimizados pelo critério de variância do Denton (ver Seção 7): os pesos ad hoc originais (70%/30%) foram revisados para 55%/45%, com melhoria de 59,9% na função-objetivo.

---

### 6.4 Serviços Privados

**Peso no VAB de 2020: 36,46%.** O bloco de serviços agrega seis subsetores com pesos derivados dinamicamente do VAB nominal de 2020.

#### Comércio e Reparação de Veículos (12,25% do VAB 2023)

**[Proxy aceitável]** Proxy composta com pesos otimizados:

| Componente | Fonte | Tipo | Peso adotado |
|---|---|---|---|
| PMC-RR | IBGE/SIDRA — índice de volume do comércio varejista | Volume | **70%** |
| Energia comercial (kWh) | ANEEL SAMP — classe "Comercial" | Volume físico | **10%** |
| ICMS comércio (deflacionado) | SEFAZ-RR — por atividade econômica | Valor nominal deflacionado | **10%** |
| Emprego CAGED G | FTP MTE — seção G | Insumo (estoque) | **10%** |

**Nota sobre ICMS:** séries baseadas em ICMS requerem monitoramento contínuo de alterações de alíquota, benefícios fiscais e mudanças de regime tributário (Decretos SEFAZ-RR). Cada quebra estrutural identificada deve receber variável dummy no script.

#### Transportes, Armazenagem e Correio (1,92% do VAB 2023)

Proxy composta — pesos ad hoc 40%/30%/30% revisados para 55%/0%/45%:

| Componente | Fonte | Tipo | Peso adotado |
|---|---|---|---|
| Passageiros ANAC (SBBV) | Microdados ANAC, aeroporto de Boa Vista | Volume físico | **55%** |
| Carga aérea ANAC (SBBV) | Microdados ANAC | Volume físico | **0%** (eliminada) |
| Vendas de diesel ANP (RR) | ANP — dados abertos por UF | Volume físico | **45%** |

**Por que carga aérea foi eliminada?** A movimentação de carga no SBBV é dominada por eventos esporádicos (operações humanitárias, fretamentos) que não refletem o nível regular de atividade do setor. O critério de variância do Denton confirmou quantitativamente a eliminação. O diesel captura transporte rodoviário; passageiros captam o segmento aéreo.

#### Atividades Financeiras (2,78% do VAB 2023)

Proxy composta. Pesos ad hoc originais (70% concessões / 30% depósitos) foram *invertidos* pelo critério Denton, com melhoria de 90,5%:

| Componente | Fonte | Tipo | Peso adotado |
|---|---|---|---|
| Carteira de crédito ativa (deflacionada) | BCB SCR — dados abertos agregados por UF | Estoque deflacionado | **40%** |
| Depósitos bancários (deflacionado) | BCB Estban — verbetes 420 (poupança) + 432 (CDB/RDB) | Estoque deflacionado | **60%** |

> ⚠️ **Verbetes do Estban:** a variável usada é a soma dos verbetes 420 (depósitos de poupança) e 432 (depósitos a prazo). O verbete 160 — que aparece em descrições anteriores — refere-se a operações de crédito (ativo bancário), não a depósitos.
>
> **BCB SCR:** a série usada é `carteira_ativa` (estoque total de crédito em RR), extraída dos ZIPs de dados agregados do SCR. Concessões (fluxo) não estão disponíveis neste conjunto de dados na granularidade necessária; o estoque de crédito é usado como proxy de atividade financeira, em simetria ao uso de depósitos no Estban.

Ambas as séries são deflacionadas pelo IPCA nacional. A carteira ativa recebe suavização por média móvel de 3 meses (alta volatilidade mensal).

#### Atividades Imobiliárias (7,68% do VAB 2023)

**[Proxy ainda indireta, mas melhorada]** Em grande parte representa **aluguel imputado de imóveis próprios** nas Contas Nacionais — variável sem proxy observável perfeita de alta frequência. No desenho atual, o subsetor usa **número de consumidores residenciais da ANEEL** como indicador temporal e aplica **Denton-Cholette** contra os benchmarks anuais das Contas Regionais.

#### Outros Subsetores

| Subsetor | Proxy | Fonte |
|---|---|---|
| Outros serviços (7,63%) | PMS-RR geral + CAGED I + CAGED M+N + CAGED P+Q | IBGE–PMS / FTP MTE |
| Informação e comunicação (1,01%) | PMS-RR geral + CAGED J | IBGE–PMS / FTP MTE |
| Indústrias extrativas (0,05%) | Benchmark anual CR + Denton-Cholette trimestral (sem proxy própria) | IBGE CR |

---

## 7. Otimização de Pesos — Critério de Variância do Denton

Seis setores do IAET-RR usam proxies compostas: Indústria de Transformação, Comércio, Outros Serviços, Informação e Comunicação, Transportes e Financeiro. O script `R/05b_sensibilidade_pesos.R` substituiu o julgamento puramente qualitativo por um **critério quantitativo objetivo, interno à metodologia e consistente com o Denton-Cholette**.

### Por que não usar regressão?

A abordagem de mínimos quadrados é inviável: com apenas 4 observações anuais de benchmark (2020–2023) e 2–3 regressores por setor, qualquer combinação de pesos produz *R*² = 1. O OLS sobreajusta trivialmente sem discriminar combinações.

### Critério adotado

Os **pesos ótimos são aqueles que minimizam a função-objetivo do Denton** calculada sobre o período de benchmark 2020–2023 (16 trimestres):

$$\underset{w_1,\ldots,w_k}{\arg\min} \sum_{t=2}^{T} \left(\frac{p_t(w)}{x_t(w)} - \frac{p_{t-1}(w)}{x_{t-1}(w)}\right)^2 \quad \text{com} \quad \sum_i w_i = 1\,,\quad w_i \geq 0$$

onde $x_t(w) = \sum_i w_i \cdot \tilde{c}_{it}$ é a proxy composta com pesos $w$ e $p_t(w)$ é a série Denton resultante.

### Procedimento de busca em grade

Passo de 5 pontos percentuais: 21 combinações para 2 componentes, 231 para 3 componentes e 1.771 para 4 componentes. **Total: 3.836 combinações avaliadas** nos 6 setores. Para cada combinação: constrói proxy → aplica Denton → calcula objetivo.

### Resultados

| Setor | Pesos anteriores (ad hoc) | Pesos ótimos | Pesos adotados | Melhoria | Decisão |
|---|---|---|---|---|---|
| Ind. Transformação | Energia 70% / CAGED C 30% | Energia 55% / CAGED C 45% | **55% / 45%** | **59,9%** | ✅ Aplicado |
| Comércio | Energia 35% / PMC 25% / ICMS 20% / CAGED G 20% | Energia 0% / PMC 95% / ICMS 5% / CAGED G 0% | **10% / 70% / 10% / 10%** | **59,7%** | ✅ Aplicado (piso de 10%) |
| Outros Serviços | CAGED I 25% / M+N 30% / P+Q 20% / PMS 25% | CAGED I 35% / M+N 0% / P+Q 0% / PMS 65% | **20% / 10% / 10% / 60%** | **70,3%** | ✅ Aplicado (piso de 10%) |
| InfoCom | CAGED J 50% / PMS 50% | CAGED J 0% / PMS 100% | **10% / 90%** | **27,4%** | ✅ Aplicado (piso de 10%) |
| Transportes | Pax 40% / Carga 30% / Diesel 30% | Pax 55% / Carga 0% / Diesel 45% | **55% / 0% / 45%** | **41,7%** | ✅ Aplicado |
| Financeiro | Concessões 70% / Depósitos 30% | Concessões 40% / Depósitos 60% | **40% / 60%** | **90,5%** | ✅ Aplicado |

> ⚠️ **Limitação do critério**  
> O critério de variância do Denton é *interno à metodologia* — mede a consistência da proxy com o benchmark anual, não sua relação causal com o fenômeno econômico. Uma proxy "lisa" pode ser menos informativa que uma mais volátil. O critério complementa, não substitui, o julgamento econômico.  
>
> **Agenda de revisão:** re-rodar `05b_sensibilidade_pesos.R` quando as CR 2024 forem publicadas (previsão: outubro de 2026), expandindo o período de benchmark de 4 para 5 anos.

---

## 8. PIB Nominal Trimestral

O PIB nominal trimestral de Roraima é construído em duas etapas: (1) geração do VAB nominal trimestral; (2) adição dos impostos líquidos sobre produtos (ILP).

### VAB Nominal Trimestral — `05f_vab_nominal.R`

$$\text{Índice nominal}_t = \text{Índice real}_t \times \frac{\text{Deflator implícito}_t}{100}$$

O deflator implícito anual do total é extraído diretamente das Contas Regionais do IBGE:

$$\text{Deflator anual} = \frac{\text{Índice nominal total (CR)}}{\text{Índice real total (CR)}}$$

e desagregado para frequência trimestral via Denton-Cholette (`conversion = "sum"`), usando o IPCA como proxy trimestral do deflator.

> ✅ **Fechamento anual exato com as Contas Regionais em 2020–2023**  
> Após reforma do script (uso do deflator implícito direto do VAB total em vez de média ponderada de deflatores setoriais), o VAB nominal anual do projeto fecha com erro numérico inferior a 0,01 R\$ mi em todos os anos com benchmark.

### VAB Nominal Setorial — `05h_vab_nominal_setorial.R`

Para os 4 blocos analíticos (Agropecuária, AAPP, Indústria, Serviços), o VAB nominal trimestral é gerado pelo procedimento:

1. Benchmark nominal anual por bloco (soma das atividades correspondentes nas CR).
2. Índice anual de volume por bloco (agregado com pesos de 2020 dentro do bloco).
3. Deflator anual implícito por bloco: índice nominal / índice real.
4. Denton-Cholette (`conversion = "mean"`) para o deflator trimestral, usando IPCA como proxy.
5. Denton-Cholette (`conversion = "sum"`) para distribuir o VAB nominal anual em R\$ milhões.

### Impostos Líquidos sobre Produtos (ILP) — `05g_pib_nominal.R`

#### Benchmark anual — identidade contábil

O ILP anual é obtido diretamente por diferença, sem estimação:

$$\text{ILP}_j = \text{PIB}_j^{\text{SIDRA}} - \text{VAB}_j^{\text{CR IBGE}}$$

onde $\text{PIB}_j^{\text{SIDRA}}$ é lido da Tabela 5938 do SIDRA (variável 37, em R\$ mil, convertida para milhões) e $\text{VAB}_j^{\text{CR IBGE}}$ é a atividade "Total das Atividades" de `contas_regionais_RR_serie.csv`. Nos anos com benchmark (2020–2023), o fechamento é exato por construção.

Valores de referência:

| Ano | PIB (R\$ mi) | VAB (R\$ mi) | ILP (R\$ mi) | ICMS (R\$ mi) | ICMS/ILP |
|---|---|---|---|---|---|
| 2020 | 16.024 | 14.524 | 1.500 | 1.240 | 82,7% |
| 2021 | 18.203 | 16.310 | 1.893 | 1.569 | 82,9% |
| 2022 | 21.095 | 19.117 | 1.978 | 1.597 | 80,7% |
| 2023 | 25.125 | 23.003 | 2.122 | 1.707 | 80,5% |

#### Extrapolação para anos sem benchmark (2024–2025)

Para os anos sem CR publicada, o ILP anual é extrapolado pela taxa de variação do ICMS anual:

$$\text{ILP}_j = \text{ILP}_{j-1} \times \frac{\text{ICMS}_j}{\text{ICMS}_{j-1}}$$

Isso pressupõe que o crescimento relativo do ICMS é uma boa aproximação do crescimento do ILP total — válido enquanto a participação do ICMS no ILP permanecer estável (~80–83%).

#### Desagregação trimestral — Denton-Cholette

O ICMS estadual total (em valores nominais, sem deflação) é usado como proxy do perfil intra-anual do ILP:

```r
td(ILP_anual ~ 0 + ICMS_trimestral, method = "denton-cholette", conversion = "sum")
```

O `conversion = "sum"` garante que a soma dos quatro trimestres de cada ano reproduza exatamente o ILP anual benchmark. Os ~17–20% do ILP não cobertos pelo ICMS são distribuídos pelo Denton de forma proporcional ao ICMS — o resíduo é absorvido sem distorção do perfil sazonal.

O ICMS trimestral vem de `icms_sefaz_rr_trimestral.csv` (coluna `icms_total_mi`), gerado por `00b_icms_sefaz_atividade.R` a partir dos arquivos mensais da SEFAZ-RR.

#### Por que apenas ICMS — exclusão do ISS e dos tributos federais

> ⚠️ **Objetivo do ILP nas Contas Regionais**: aproximar apenas os *impostos sobre produtos* — tributos que incidem sobre produção, circulação, vendas ou disponibilização de bens e serviços. Tributos sobre renda, folha, patrimônio ou lucro não entram nessa categoria.

**ISS municipal excluído.** O ISS municipal foi investigado via Siconfi/MSC para os 15 municípios de Roraima. Boa Vista concentrou 54% do ISS anual de 2023 em janeiro (R\$ 77 mi vs. média de R\$ 4–6 mi nos demais meses), com segundo pico atípico em junho. Trata-se de artefato de lançamento em lote no Siconfi, não de sazonalidade econômica real. Usar essa série como proxy no Denton inflaria artificialmente o 1º trimestre. O ISS pode ser reincorporado em versão futura caso seja obtido por fonte com distribuição mensal uniforme (SEFAZ municipal, NFS-e ou suavização explícita).

**Tributos federais excluídos** (IPI, II, PIS/Cofins, CIDE). Três razões:

1. **Cobertura truncada.** Os arquivos da Receita Federal por estado cobrem apenas até maio/2022. Para o período seguinte não há dado por UF publicado.
2. **Problema de imputação territorial.** PIS/Cofins é registrado no domicílio fiscal do contribuinte. Como Roraima importa a maior parte dos bens tributados de outros estados (AM, SP), a arrecadação federal atribuída a RR subestima sistematicamente a carga real sobre a economia local — criando viés estrutural.
3. **Magnitude negligenciável.** IPI e II somam menos de R\$ 1 mi/ano para RR. CIDE-Combustíveis = zero (sem refinaria ou distribuidora-base no estado).

**Fonte do ICMS: SEFAZ-RR (não Siconfi).** O Siconfi/MSC apresentou lacuna de 15 meses (jan/2022–mar/2023) por transição de classificadores contábeis — exatamente o período com benchmark CR disponível. A fonte adotada são os arquivos mensais do Portal de Arrecadação da SEFAZ-RR, com 75 observações mensais sem lacunas (jan/2020–mar/2026). Nenhum outlier detectado (z-score > 2,5). Limitação: atualização manual; sem API pública.

#### Identidade final

$$\text{PIB nominal}_t = \text{VAB nominal}_t + \text{ILP}_t$$

A série anual de PIB usada no benchmark é mantida em cache local (`data/raw/sidra/pib_rr_anual_sidra_5938.csv`) e reutilizada por padrão; a atualização online do SIDRA fica reservada a execuções com `atualizar_sidra <- TRUE`.

---

## 9. PIB Real Trimestral

O PIB real trimestral de Roraima é gerado pelo script `05i_pib_real.R` em R\$ milhões de 2020, com ancoragem ao benchmark anual oficial do PIB real das Contas Regionais em 2020–2023.

$$\text{PIB real}_t = \frac{\text{Índice PIB real}_t}{100} \times \text{PIB real médio anual}_{2020}$$

O índice do PIB real é construído como o IAET-RR, mas com benchmark das **taxas de crescimento real oficiais do PIB** das Contas Regionais. A ancoragem anual via Denton-Cholette garante que a taxa de crescimento real anual do projeto coincida exatamente com a taxa oficial do IBGE nos anos com benchmark.

### PIB Real Anual — `pib_real_anual_rr.csv`

| Ano | PIB Real RR (%) | Tipo |
|---|---|---|
| 2021 | +8,4% | Ancorado (CR IBGE) |
| 2022 | +11,3% | Ancorado (CR IBGE) |
| 2023 | +4,2% | Ancorado (CR IBGE) |
| 2024 | +6,9% | Preliminar (sem benchmark) |
| 2025 | +7,2% | Preliminar (sem benchmark) |

---

## 10. Resultados de Validação

### VAB nominal total vs. Contas Regionais

| Ano | Projeto (R\$ mi) | CR IBGE (R\$ mi) | Diferença |
|---|---|---|---|
| 2020 | 14.524,24 | 14.524,24 | −0,000001 ✓ |
| 2021 | 16.309,70 | 16.309,70 | 0,000000 ✓ |
| 2022 | 19.117,27 | 19.117,27 | 0,000000 ✓ |
| 2023 | 23.003,07 | 23.003,07 | +0,000001 ✓ |

### VAB real total — taxa de crescimento

| Ano | Projeto (%) | CR IBGE (%) | Diferença (p.p.) |
|---|---|---|---|
| 2021 | 8,19% | 8,19% | 0,00 ✓ |
| 2022 | 10,86% | 10,72% | +0,15 |
| 2023 | 4,34% | 3,92% | +0,42 |

A diferença residual em 2022–2023 é compatível com a operação em blocos trimestrais e ancoragem anual.

### PIB real — taxa de crescimento anual

| Ano | Projeto (%) | CR IBGE (%) | Diferença (p.p.) |
|---|---|---|---|
| 2021 | 8,40% | 8,40% | 0,00 ✓ |
| 2022 | 11,30% | 11,30% | 0,00 ✓ |
| 2023 | 4,20% | 4,20% | 0,00 ✓ |

### Validação setorial (variação real anual — 2021–2023)

| Bloco | Ano | Projeto (%) | CR IBGE (%) | Dif. (p.p.) |
|---|---|---|---|---|
| **Agropecuária** | 2021 | 24,81% | 24,81% | 0,00 ✓ |
| | 2022 | 28,03% | 28,03% | 0,00 ✓ |
| | 2023 | 17,49% | 17,49% | 0,00 ✓ |
| **AAPP** | 2021 | 3,19% | 3,19% | 0,00 ✓ |
| | 2022 | 4,12% | 4,12% | 0,00 ✓ |
| | 2023 | 2,37% | 2,37% | 0,00 ✓ |
| **Indústria** | 2021 | 10,62% | 10,62% | 0,00 ✓ |
| | 2022 | 20,59% | 20,59% | 0,00 ✓ |
| | 2023 | 9,43% | 9,43% | 0,00 ✓ |
| **Serviços** | 2021 | 10,54% | 10,45% | +0,08 |
| | 2022 | 12,25% | 12,26% | −0,01 |
| | 2023 | 2,81% | 2,61% | +0,21 |

---

## 11. Qualidade das Proxies e Cobertura

| Atividade | % VAB 2023 | Proxy principal | Qualidade |
|---|---|---|---|
| Adm. Pública | 46,21% | Folha observada de pessoal (SIAPE + estadual + municipal) | **Forte** |
| Comércio | 12,25% | PMC-RR (70%) + energia comercial (10%) + ICMS comércio (10%) + CAGED G (10%) | Aceitável |
| Agropecuária | 8,87% | PAM/LSPA + coef. de colheita + abate + ovos | **Forte** |
| Atividades imobiliárias | 7,68% | Consumidores residenciais ANEEL + Denton-Cholette | Fraca mas melhorada |
| Outros serviços | 7,63% | PMS-RR geral (60%) + CAGED I (20%) + CAGED M+N (10%) + CAGED P+Q (10%) | Aceitável |
| SIUP | 5,40% | Energia elétrica total distribuída (kWh), ANEEL SAMP | **Forte** |
| Construção | 4,89% | Estoque acumulado CAGED F | Aceitável |
| Financeiro | 2,78% | Concessões BCB (40%) + Depósitos Estban (60%) | Aceitável |
| Transportes | 1,92% | Passageiros ANAC SBBV (55%) + Diesel ANP (45%) | Aceitável |
| Ind. de Transformação | 1,31% | Energia industrial ANEEL (55%) + CAGED C (45%) | Aceitável |
| Informação e comunicação | 1,01% | PMS-RR geral (90%) + CAGED J (10%) | Aceitável |
| Ind. extrativas | 0,05% | Benchmark CR + Denton-Cholette trimestral (na indústria) | Fraca mas necessária |

---

## 12. Ciclo de Manutenção Trimestral

A Fase 6 do pipeline formaliza a rotina de atualização trimestral e separa explicitamente *disponibilidade de dados* de *publicação oficial*. O trimestre publicado só avança quando o responsável técnico confirmar um checklist de seis itens — garantindo que nenhum dado preliminar seja divulgado como oficial sem comunicação prévia à imprensa e aprovação interna.

### Fluxo trimestral

```
1. source("R/06_coleta_fontes.R")
   → Atualiza SIDRA, ANP e ANEEL automaticamente.
   → No SIDRA, inclui PAM, LSPA, abate bovino, ovos, PMC, PMS, IPCA e PIB anual.
   → Imprime relatório de cobertura: mostra o que ainda falta por fonte.

2. [Manual] Baixar SIAPE, FIPLAN, ANAC, BCB Estban/SCR e ICMS SEFAZ-RR.
   → Colocar nas pastas bases_baixadas_manualmente/ corretas.

3. source("R/run_all.R")
   → Pipeline completo. Exportação filtrada até o trimestre_publicado atual.
   → Usar para inspeção interna, informativos e rascunho da nota técnica.

4. [Preparação] Informativos internos + comunicação à imprensa.

5. source("R/06_avanca_publicacao.R")
   → Checklist interativo (6 itens). Avança config/release.R. Commit + tag git.

6. source("R/run_all.R")
   → Agora exporta oficialmente o novo trimestre.
```

### Gate de publicação — detalhes técnicos

`config/release.R` define `trimestre_publicado <- "AAAATQ"`. Ao avançar de `2025T4` para `2026T1`, o script `06_avanca_publicacao.R`:

1. Reescreve `config/release.R` com o novo valor.
2. Executa `git add config/release.R && git commit -m "Avança publicação para 2026T1"`.
3. Cria a tag git `v2026-Q1` (registrada no histórico do repositório).

O histórico de avanços fica versionado no git, garantindo rastreabilidade de qual trimestre estava publicado em cada data.

### Fontes automatizáveis vs. manuais

| Tipo | Fontes | Comando |
|---|---|---|
| Automatizável | SIDRA (PAM, LSPA, abate, ovos, PMC, PMS, IPCA, PIB), ANP diesel, ANEEL | `06_coleta_fontes.R` |
| Manual | SIAPE, FIPLAN estadual, ANAC Boa Vista, BCB Estban, BCB SCR, ICMS SEFAZ-RR | Download nas pastas `bases_baixadas_manualmente/` |

---

## 13. Limitações e Agenda de Revisão

### Limitações estruturais

1. **Ausência de IPCA estadual:** o IPCA nacional é usado como deflator de todas as séries nominais. Diferenças entre inflação de Roraima e inflação nacional podem introduzir viés de deflação, especialmente em serviços.
2. **Ausência de PIM-PF:** a indústria de transformação usa proxies de segundo grau (energia industrial + emprego). Com peso de 1,31% no VAB total, o impacto no índice agregado é limitado.
3. **Benchmark reduzido (2020–2023):** quatro anos de benchmark para estimação de pesos e validação. As decisões metodológicas ganharão maior robustez à medida que novas Contas Regionais forem publicadas.
4. **Descontinuidade do CAGED:** a adoção do Novo CAGED pós-eSocial (2020) cria uma descontinuidade com as séries anteriores, impedindo a extensão da cobertura temporal para antes de 2020.
5. **SIAPE sem automação plena:** o endpoint do Portal da Transparência não sustenta download automatizado. A folha federal requer processamento local de arquivos mensais ZIP.
6. **Volatilidade do SIUP em RR:** o VAB do SIUP em Roraima é estruturalmente volátil (reflexo das mudanças na geração e distribuição de energia), o que amplifica a variância do índice industrial.

### Agenda de revisão

| Evento | Previsão | Ação |
|---|---|---|
| Publicação CR 2024 (IBGE) | Outubro de 2026 | Substituir extrapolações 2024; re-ancorar índices via Denton; re-rodar otimização de pesos com benchmark 2020–2024; atualizar pesos Laspeyres |
| Publicação CR 2025 (IBGE) | Outubro de 2027 | Idem para 2025; pesos ótimos mais robustos para setores com 3 componentes |
| 2 anos de ICMS por atividade (2022+) | Contínuo | Re-avaliar peso do ICMS no Comércio; verificar quebras tributárias (Decretos SEFAZ-RR) |

---

## 14. Referências

- Cholette, P. A.; Dagum, E. B. (2006). *Benchmarking, Temporal Distribution, and Reconciliation Methods for Time Series.* Springer.
- Denton, F. T. (1971). Adjustment of monthly or quarterly series to annual totals: An approach based on quadratic minimization. *Journal of the American Statistical Association*, 66(333), 99–102.
- IBGE. *Contas Regionais do Brasil.* Edições 2020–2023 (publicadas out/2025). Instituto Brasileiro de Geografia e Estatística.
- IBGE. *Metodologia das Contas Nacionais do Brasil.* Série Relatórios Metodológicos, vol. 24. Rio de Janeiro: IBGE.
- Banco Central do Brasil. *Nota Metodológica do IBCR — Índice de Atividade Econômica Regional.*
- Sax, C.; Steiner, P. (2023). *tempdisagg: Methods for Temporal Disaggregation and Interpolation of Time Series.* R package version 1.1.1.
- Findley, D. F. et al. (1998). New Capabilities and Methods of the X-12-ARIMA Seasonal-Adjustment Program. *Journal of Business & Economic Statistics*, 16(2), 127–152.
- U.S. Census Bureau. *X-13ARIMA-SEATS Reference Manual*. Version 1.1. Washington, DC.

---

*Secretaria de Planejamento e Orçamento de Roraima — SEPLAN/RR*  
*Coordenação-Geral de Estudos Econômicos e Sociais — CGEES · Divisão de Estudos e Análises Sociais — DIEAS*  
*Yuri Cesar de Lima e Silva · Coordenador da Equipe do PIB do Estado de Roraima*  
*Versão 1.1 · Abril de 2026*
