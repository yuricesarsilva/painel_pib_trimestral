# Otimização dos Pesos das Proxies Compostas — IAET-RR

**Data:** 2026-04-15  
**Responsável:** Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)  
**Scripts:** `R/05b_sensibilidade_pesos.R`, `R/03_industria.R`, `R/04_servicos.R`  
**Resultados completos:** `data/output/sensibilidade/pesos_otimos.csv`, `grid_completo.csv`

---

## 1. Motivação

O IAET-RR utiliza proxies compostas em quatro setores — Indústria de Transformação, Comércio, Transportes e Financeiro. Em cada um deles, dois ou três indicadores são combinados com pesos ponderados para formar um único índice trimestral. Até 2026-04-14, esses pesos eram **definidos ad hoc**, com base em julgamento qualitativo sobre a relevância econômica de cada componente (por exemplo: "energia tem mais peso que emprego na indústria de transformação").

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
3. Para cada combinação: constrói a proxy composta → aplica Denton-Cholette com benchmarks CR → calcula o objetivo.
4. Identifica a combinação com menor objetivo.

**Total avaliado:** 504 combinações (21 + 231 + 231 + 21).

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
| Componentes | Energia comercial ANEEL · ICMS comércio SEFAZ-RR · CAGED G |
| Pesos ad hoc | 40% / 40% / 20% |
| **Pesos ótimos (Denton)** | **100% / 0% / 0%** |
| Objetivo ad hoc | 0,034204 |
| Objetivo ótimo | 0,002200 |
| **Melhoria** | **93,6%** |

**Interpretação e ressalva:** O resultado sugere que a energia comercial sozinha produz o menor ruído de Denton no período 2020–2023. Contudo, esse resultado deve ser interpretado com cautela:

- O ICMS por atividade só está disponível a partir de 2020 (exatamente o início do período de benchmark). Com apenas 4 pontos anuais de ancoragem, o critério tem baixo poder discriminatório entre combinações que incluam ICMS.
- O ICMS de comércio é deflacionado pelo IPCA, o que pode introduzir defasagem metodológica nos primeiros anos da série (base de referência instável logo após a pandemia).
- A energia comercial é um proxy de volume físico (kWh distribuídos), tipo "forte" na classificação metodológica do projeto. Faz sentido que domine.

**Decisão conservadora:** ⚠️ **Pesos ajustados para 60%/20%/20%** — aumenta o peso da energia (sinal mais limpo), reduz o ICMS (histórico curto), mantém CAGED G (sinal independente de emprego). Não se adota 100% energia para preservar a diversificação de fontes e permitir que o ICMS ganhe peso gradualmente conforme a série histórica se expande.

**Revisão futura:** quando os benchmarks das CR 2024 forem publicados (previsão IBGE: outubro de 2026), re-rodar `05b_sensibilidade_pesos.R` com 5 anos de benchmark (2020–2024). O resultado provavelmente divergirá do atual 100%.

---

### 3.3 Transportes

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

### 3.4 Financeiro

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
| Comércio | energia 40% / ICMS 40% / CAGED G 20% | **energia 60% / ICMS 20% / CAGED G 20%** | ⚠️ Conservador (ótimo = 100% energia, mas ICMS tem histórico curto) |
| Transportes | pax 40% / carga 30% / diesel 30% | **pax 55% / carga 0% / diesel 45%** | ✅ Aplicado (carga aérea eliminada) |
| Financeiro | concessões 70% / depósitos 30% | **concessões 40% / depósitos 60%** | ✅ Aplicado (inversão justificada) |

---

## 5. Limitações e Agenda de Revisão

### 5.1 Limitações do critério

O critério de variância do Denton é **interno à metodologia** — mede apenas a consistência da proxy com o benchmark anual, não a sua relação causal com o fenômeno econômico. É possível que uma proxy muito "lisa" (baixo ruído de Denton) seja menos informativa sobre a atividade econômica real do que uma proxy mais volátil. O critério complementa, não substitui, o julgamento econômico.

### 5.2 Tamanho da amostra

O período de benchmark (2020–2023) é curto. Com apenas 4 observações anuais (16 trimestrais), os resultados dos setores com 3 componentes (Comércio e Transportes) têm menor confiabilidade do que os setores com 2 componentes. À medida que as Contas Regionais forem cobrindo anos mais recentes, os pesos ótimos devem ser re-estimados.

### 5.3 Agenda de revisão

| Evento | Ação |
|---|---|
| Publicação CR 2024 (previsão: out/2026) | Re-rodar `05b_sensibilidade_pesos.R` com benchmark 2020–2024 |
| Publicação CR 2025 (previsão: out/2027) | Re-rodar novamente; resultado mais robusto para 3 componentes |
| 2 anos de ICMS por atividade (2022+) | Re-avaliar peso do ICMS no Comércio |

### 5.4 Outros setores

Este exercício cobre apenas os setores com pesos definidos ad hoc. Outros setores têm pesos derivados de dados objetivos (agropecuária: VBP PAM; AAPP: folha estadual + municipal + federal; outros serviços: estoque de emprego 2020) e não são objeto desta análise.

---

## 6. Referências

- Cholette, P. A.; Dagum, E. B. (2006). *Benchmarking, Temporal Distribution, and Reconciliation Methods for Time Series.* Springer.
- Denton, F. T. (1971). Adjustment of monthly or quarterly series to annual totals: An approach based on quadratic minimization. *Journal of the American Statistical Association*, 66(333), 99–102.
- Sax, C.; Steiner, P. (2023). *tempdisagg: Methods for Temporal Disaggregation and Interpolation of Time Series*. R package version 1.1.1.
