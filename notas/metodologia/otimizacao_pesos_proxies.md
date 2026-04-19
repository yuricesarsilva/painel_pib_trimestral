# Otimização dos Pesos das Proxies Compostas — IAET-RR

**Data:** 2026-04-18  
**Responsável:** Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)  
**Scripts:** `R/05b_sensibilidade_pesos.R`, `R/03_industria.R`, `R/04_servicos.R`  
**Resultados completos:** `data/output/sensibilidade/pesos_otimos.csv`, `grid_completo.csv`

---

## 1. Motivação

O IAET-RR utiliza proxies compostas em seis setores — Indústria de Transformação, Comércio, Outros Serviços, Informação e Comunicação, Transportes e Financeiro. Em cada um deles, dois a quatro indicadores são combinados com pesos ponderados para formar um único índice trimestral. Parte desses pesos era originalmente **definida ad hoc**, com base em julgamento qualitativo sobre a relevância econômica de cada componente.

A ausência de um critério quantitativo explícito representa uma limitação metodológica. Pesos mal calibrados podem introduzir ruído desnecessário na série composta e exigir correções maiores do Denton-Cholette para que a proxy ancorada bata os benchmarks oficiais. O objetivo desta análise foi substituir o julgamento ad hoc por um critério objetivo, interno e consistente com a metodologia já adotada.

---

## 2. Metodologia: Critério de Variância do Denton

### 2.1 Por que não usar regressão?

A alternativa mais natural seria estimar os pesos por regressão (OLS), regredindo o VAB anual das Contas Regionais sobre as proxies anualizadas. Essa abordagem é inviável aqui por dois motivos:

1. **Série temporal curta:** os benchmarks disponíveis cobrem apenas 2020–2023 (4 observações anuais). Com 2–3 regressores por setor, o OLS sobreajusta trivialmente — qualquer combinação de pesos produz R² = 1.
2. **Coleta recente:** a maioria das proxies foi implementada a partir de 2020 (ANEEL SAMP, CAGED Novo, BCB via download manual). Não existe série histórica longa o suficiente para estimação.

### 2.2 O critério adotado

O método Denton-Cholette (Cholette & Dagum, 2006) distribui um total anual em frequência menor minimizando a seguinte função-objetivo:

$$\text{Objetivo} = \sum_{t=2}^{T} \left( \frac{p_t}{x_t} - \frac{p_{t-1}}{x_{t-1}} \right)^2$$

onde $p_t$ é o valor trimestral estimado (output do Denton) e $x_t$ é a proxy no trimestre $t$.

**Interpretação:** quando a proxy é perfeita — isto é, captura exatamente o perfil intra-anual da variável de interesse — a razão $p_t / x_t$ é constante ao longo do tempo (igual ao fator de escala anual). Nesse caso, o objetivo vale zero e o Denton não precisa fazer nenhuma correção. Quanto maior o objetivo, mais o Denton precisou "sacolejar" a série para bater o benchmark anual.

**Critério adotado:** os **pesos ótimos são aqueles que minimizam o valor da função-objetivo do Denton** calculada sobre o período de benchmark (2020–2023, 16 trimestres). Isso é equivalente a escolher a proxy composta que, antes mesmo da ancoragem, já apresenta o perfil sazonal mais próximo do comportamento real do setor.

### 2.3 Procedimento de busca em grade

Para cada setor com pesos ad hoc, o script `05b_sensibilidade_pesos.R` executa:

1. Lê os componentes brutos (pré-Denton), salvos pelos scripts de produção em `data/output/sensibilidade/`.
2. Gera todas as combinações de pesos com passo de 5 pontos percentuais e soma igual a 100%.
   - 2 componentes: 21 combinações
   - 3 componentes: 231 combinações
   - 4 componentes: 1.771 combinações
3. Para cada combinação: constrói a proxy composta → aplica Denton-Cholette com benchmarks CR → calcula o objetivo.
4. Identifica a combinação com menor objetivo.

**Total avaliado:** 3.836 combinações.

---

## 3. Resultados por Setor

### 3.1 Indústria de Transformação

| Parâmetro | Valor |
|---|---|
| Componentes | Energia industrial ANEEL · CAGED C (Transformação) |
| Pesos ad hoc | 70% / 30% |
| **Pesos ótimos** | **55% / 45%** |
| Objetivo ad hoc | 0,002118 |
| Objetivo ótimo | 0,000849 |
| **Melhoria** | **59,9%** |

**Interpretação:** O CAGED C contribui mais para o perfil sazonal da indústria de transformação de Roraima do que o peso inicial supunha. O setor de transformação em RR é fortemente influenciado pelo nível de emprego formal (que sobe no primeiro semestre e cai no quarto trimestre, padrão típico de economias com indústria leve e sazonal). A energia industrial, embora um indicador de volume, apresenta padrão sazonal mais plano nesta UF. O resultado de 55%/45% é robusto e economicamente interpretável.

**Decisão:** ✅ **Pesos atualizados** para 55%/45%.

---

### 3.2 Comércio

| Parâmetro | Valor |
|---|---|
| Componentes | Energia comercial ANEEL · PMC-RR · ICMS comércio SEFAZ-RR · CAGED G |
| Pesos de partida | 35% / 25% / 20% / 20% |
| **Pesos ótimos (Denton)** | **0% / 95% / 5% / 0%** |
| **Pesos conservadores adotados** | **10% / 70% / 10% / 10%** |
| Objetivo de partida | 0,031074 |
| Objetivo ótimo irrestrito | 0,000910 |
| Objetivo conservador | 0,012530 |
| **Melhoria do conservador** | **59,7%** |

**Interpretação e ressalva:** O resultado sugere dominância muito forte da PMC-RR no perfil sazonal do comércio de Roraima, com contribuição marginal do ICMS e peso nulo para energia e CAGED G no ótimo irrestrito. Contudo, esse resultado deve ser interpretado com cautela:

- A PMC-RR é uma proxy direta de volume do varejo e faz sentido econômico que passe a liderar o bloco.
- O ICMS por atividade tem histórico curto e já entra após deflação, o que recomenda cautela antes de deixá-lo residual demais.
- Energia comercial e CAGED G continuam trazendo sinais diferentes do varejo e, metodologicamente, é desejável preservar informação multifuente.

**Decisão conservadora:** ⚠️ **Pesos ajustados para 10% energia / 70% PMC / 10% ICMS / 10% CAGED G.** A regra adotada na produção passou a ser manter **pelo menos 10% em cada proxy ativa**, preservando informação e evitando que a solução ótima irrestrita desligue completamente séries potencialmente úteis.

**Revisão futura:** quando os benchmarks das CR 2024 forem publicados (previsão IBGE: outubro de 2026), re-rodar `05b_sensibilidade_pesos.R` com 5 anos de benchmark (2020–2024) e reavaliar se o piso de 10% ainda faz sentido.

---

### 3.3 Outros Serviços

| Parâmetro | Valor |
|---|---|
| Componentes | CAGED I · CAGED M+N · CAGED P+Q · PMS-RR geral |
| Pesos de partida | 25% / 30% / 20% / 25% |
| **Pesos ótimos (Denton)** | **35% / 0% / 0% / 65%** |
| **Pesos conservadores adotados** | **20% / 10% / 10% / 60%** |
| Objetivo de partida | 0,015055 |
| Objetivo ótimo irrestrito | 0,000803 |
| Objetivo conservador | 0,004467 |
| **Melhoria do conservador** | **70,3%** |

**Interpretação:** A PMS geral da UF melhora muito o comportamento intra-anual do subsetor, mas o ótimo irrestrito praticamente elimina M+N e P+Q. Para a produção, isso foi considerado agressivo demais.

**Decisão conservadora:** ⚠️ **Pesos ajustados para 20% CAGED I / 10% CAGED M+N / 10% CAGED P+Q / 60% PMS**, preservando todas as proxies com participação mínima positiva.

---

### 3.4 Informação e Comunicação

| Parâmetro | Valor |
|---|---|
| Componentes | CAGED J · PMS-RR geral |
| Pesos de partida | 50% / 50% |
| **Pesos ótimos (Denton)** | **0% / 100%** |
| **Pesos conservadores adotados** | **10% / 90%** |
| Objetivo de partida | 0,020462 |
| Objetivo ótimo irrestrito | 0,013926 |
| Objetivo conservador | 0,014846 |
| **Melhoria do conservador** | **27,4%** |

**Interpretação:** A PMS geral explica melhor o perfil sazonal do subsetor, mas o CAGED J ainda fornece sinal temático específico de TI/telecom.

**Decisão conservadora:** ⚠️ **Pesos ajustados para 10% CAGED J / 90% PMS.**

---

### 3.5 Transportes

| Parâmetro | Valor |
|---|---|
| Componentes | Passageiros ANAC · Carga ANAC · Diesel ANP |
| Pesos ad hoc | 40% / 30% / 30% |
| **Pesos ótimos** | **55% / 0% / 45%** |
| Objetivo ad hoc | 0,035024 |
| Objetivo ótimo | 0,020417 |
| **Melhoria** | **41,7%** |

**Interpretação:** A carga aérea (ANAC) obteve peso zero no ótimo. Economicamente, isso é justificável: a movimentação de carga no aeroporto de Boa Vista (SBBV) é muito volátil e dominada por eventos esporádicos (operações humanitárias, fretamentos), que não refletem o nível regular de atividade do setor de transportes. Passageiros e diesel ANP, por outro lado, acompanham o ritmo econômico trimestral de forma mais estável.

A proporção 55%/45% entre passageiros e diesel é coerente: passageiros captam o segmento aéreo (fortemente influenciado pelas viagens de servidores públicos federais — categoria dominante em RR), e diesel ANP captura o transporte rodoviário (carga e transporte de pessoas por ônibus).

**Decisão:** ✅ **Pesos atualizados** para 55% pax / 0% carga / 45% diesel. A carga aérea é removida do cálculo (peso zero — equivalente a eliminar o componente).

---

### 3.6 Financeiro

| Parâmetro | Valor |
|---|---|
| Componentes | Concessões de crédito BCB (SCR) · Depósitos bancários BCB (Estban) |
| Pesos ad hoc | 70% / 30% |
| **Pesos ótimos** | **40% / 60%** |
| Objetivo ad hoc | 0,002532 |
| Objetivo ótimo | 0,000240 |
| **Melhoria** | **90,5%** |

**Interpretação:** A inversão de peso entre concessões e depósitos é o resultado mais significativo da análise. O peso ad hoc original (70% concessões) foi baseado na premissa de que o fluxo de novos créditos reflete melhor a atividade financeira corrente do que o estoque de depósitos. O critério Denton contradiz essa premissa:

- **Concessões BCB (SCR):** série altamente volátil, com picos em determinados trimestres que não correspondem a variações reais na atividade econômica local (o SCR captura a carteira ativa total do sistema bancário em RR, incluindo repasses de bancos com sede fora do estado que fazem operações sazonais).
- **Depósitos Estban:** série mais suave, reflete o nível de recursos disponíveis no sistema bancário local e acompanha melhor o ciclo de renda de RR (influenciado pelos repasses federais trimestrais e pela folha do setor público).

A melhoria de 90,5% indica que os pesos estavam significativamente invertidos em relação ao comportamento real dos dados.

**Decisão:** ✅ **Pesos atualizados** para 40% concessões / 60% depósitos.

---

## 4. Resumo das Decisões

| Setor | Pesos anteriores | Pesos adotados | Decisão |
|---|---|---|---|
| Ind. Transformação | energia 70% / CAGED C 30% | **energia 55% / CAGED C 45%** | ✅ Aplicado (resultado robusto) |
| Comércio | energia 35% / PMC 25% / ICMS 20% / CAGED G 20% | **energia 10% / PMC 70% / ICMS 10% / CAGED G 10%** | ⚠️ Conservador com piso de 10% |
| Outros Serviços | CAGED I 25% / M+N 30% / P+Q 20% / PMS 25% | **CAGED I 20% / M+N 10% / P+Q 10% / PMS 60%** | ⚠️ Conservador com piso de 10% |
| InfoCom | CAGED J 50% / PMS 50% | **CAGED J 10% / PMS 90%** | ⚠️ Conservador com piso de 10% |
| Transportes | pax 40% / carga 30% / diesel 30% | **pax 55% / carga 0% / diesel 45%** | ✅ Aplicado (carga aérea eliminada) |
| Financeiro | concessões 70% / depósitos 30% | **concessões 40% / depósitos 60%** | ✅ Aplicado (inversão justificada) |

---

## 5. Limitações e Agenda de Revisão

### 5.1 Limitações do critério

O critério de variância do Denton é **interno à metodologia** — mede apenas a consistência da proxy com o benchmark anual, não a sua relação causal com o fenômeno econômico. É possível que uma proxy muito "lisa" (baixo ruído de Denton) seja menos informativa sobre a atividade econômica real do que uma proxy mais volátil. O critério complementa, não substitui, o julgamento econômico.

### 5.2 Tamanho da amostra

O período de benchmark (2020–2023) é curto. Com apenas 4 observações anuais (16 trimestrais), os resultados dos setores com 3 e 4 componentes ainda têm confiabilidade limitada. À medida que as Contas Regionais forem cobrindo anos mais recentes, os pesos ótimos devem ser re-estimados.

### 5.3 Agenda de revisão

| Evento | Ação |
|---|---|
| Publicação CR 2024 (previsão: out/2026) | Re-rodar `05b_sensibilidade_pesos.R` com benchmark 2020–2024 |
| Publicação CR 2025 (previsão: out/2027) | Re-rodar novamente; resultado mais robusto para 3 componentes |
| Ampliação do benchmark anual (CR 2024+) | Reavaliar o piso conservador de 10% nas proxies de Comércio, Outros Serviços e InfoCom |

### 5.4 Outros setores

Este exercício cobre os setores com proxies compostas explícitas. Blocos como agropecuária e AAPP seguem regras metodológicas próprias e não são objeto desta análise.

---

## 6. Referências

- Cholette, P. A.; Dagum, E. B. (2006). *Benchmarking, Temporal Distribution, and Reconciliation Methods for Time Series.* Springer.
- Denton, F. T. (1971). Adjustment of monthly or quarterly series to annual totals: An approach based on quadratic minimization. *Journal of the American Statistical Association*, 66(333), 99–102.
- Sax, C.; Steiner, P. (2023). *tempdisagg: Methods for Temporal Disaggregation and Interpolation of Time Series*. R package version 1.1.1.
