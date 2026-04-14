# Reforma de impostos e PIB nominal trimestral de RR

## Objetivo

Esta frente de trabalho tem como objetivo transformar o produto hoje existente de **VAB nominal
trimestral** em um produto mais completo:

1. **ILP trimestral** — impostos líquidos sobre produtos, em frequência trimestral;
2. **PIB nominal trimestral de RR** = VAB nominal trimestral + ILP trimestral;
3. **Série publicável** em `R$ milhões`, compatível com a lógica das Contas Regionais do IBGE.

O script-alvo desta etapa é `R/05g_pib_nominal.R`.

---

## Ponto de partida já existente

O projeto já dispõe de três insumos críticos:

- `data/output/indice_nominal_rr.csv` — índice trimestral do VAB nominal, base 2020 = 100;
- `data/processed/contas_regionais_RR_serie.csv` — VAB nominal anual por atividade;
- `ideia_pib.md` — registro inicial da proposta de evolução para ILP e PIB nominal.

Além disso, o benchmark anual do PIB nominal de Roraima pode ser obtido no SIDRA/IBGE, e o ILP
anual é calculado diretamente como:

```text
ILP anual = PIB anual - VAB anual
```

---

## Princípio metodológico

O objetivo desta reforma **não** é medir carga tributária total, arrecadação total nem resultado
fiscal do setor público. O objetivo é aproximar o componente de **impostos sobre produtos** das
Contas Regionais, pois é esse termo que fecha a identidade:

```text
PIB = VAB + impostos líquidos sobre produtos
```

Portanto:

- tributos sobre renda, folha, patrimônio ou lucro **não entram automaticamente** só por serem
  arrecadação tributária;
- a seleção das proxies deve priorizar tributos que incidam sobre produção, circulação, vendas,
  importação ou disponibilização de bens e serviços;
- a sazonalidade trimestral importa mais do que a aderência perfeita em nível mensal.

---

## Recomendação central

### Versão inicial recomendada (MVP)

Construir o ILP trimestral com dois blocos:

1. **Bloco subnacional observado**
   - `ICMS` do Estado de Roraima;
   - `ISS` agregado dos municípios de Roraima.

2. **Bloco residual anual**
   - parcela do ILP anual não explicada por `ICMS + ISS`;
   - desagregada por Denton-Cholette usando como proxy o próprio bloco observado.

Essa é a melhor relação entre qualidade, custo e prazo para a primeira versão do `PIB nominal
trimestral`.

### Versão ampliada recomendada

Após o MVP, incorporar um bloco federal por UF com os tributos mais próximos do conceito de
impostos sobre produtos:

- `IPI`
- `II` (Imposto de Importação)
- `PIS/Pasep`
- `Cofins`
- `CIDE-Combustíveis`

`IOF` entra como item opcional e só deve ser incorporado após teste empírico de aderência.

### Recomendação explícita

**Não usar apenas IPI como proxy federal.**  
O `IPI` sozinho é insuficiente para representar o componente federal do ILP, especialmente em um
estado pequeno como Roraima, onde ele pode ser baixo e volátil. `PIS/Cofins` tendem a carregar
parte mais relevante da arrecadação ligada ao consumo e à circulação.

---

## Fontes recomendadas

### 1. Subnacional — núcleo do MVP

#### Estado de Roraima

**Fonte prioritária:** Siconfi / MSC / RREO  
Uso pretendido:

- arrecadação de `ICMS`;
- eventual abertura complementar de `IPVA`, `ITCMD` e outras receitas, apenas para inspeção.

**Regra metodológica:** para o ILP, o tributo estadual principal é o `ICMS`. Os demais tributos
estaduais só entram se houver justificativa conceitual forte e ganho mensurável.

#### Municípios de Roraima

**Fonte prioritária:** Siconfi / MSC / RREO  
Uso pretendido:

- arrecadação de `ISS`;
- `ITBI` como candidato secundário, a ser testado em etapa posterior.

**Regra metodológica:** para o ILP municipal, o núcleo é o `ISS`. `ITBI` pode ser testado como
complemento, mas não é necessário para a primeira versão.

### 2. Federal — bloco ampliado

**Fonte prioritária:** Receita Federal, dados abertos de arrecadação por estado.  
Tributos-alvo:

- `IPI`
- `II`
- `PIS/Pasep`
- `Cofins`
- `CIDE-Combustíveis`

**Uso pretendido:** construir um agregado mensal federal por UF e, depois, trimestralizar/ancorar
ao ILP anual de RR.

---

## Estrutura metodológica proposta

### Etapa 1 — Escalar o VAB nominal trimestral para R$ milhões

Partir de `indice_nominal_rr.csv` e escalar pelo VAB nominal anual de 2020:

```text
VAB_nom_trim_R$ = indice_nominal_trim / 100 × VAB_nominal_médio_2020
```

Onde:

- `VAB_nominal_médio_2020 = VAB nominal anual 2020 / 4`.

### Etapa 2 — Construir o ILP anual

Obter:

- `PIB nominal anual RR` via SIDRA/IBGE;
- `VAB nominal anual RR` via Contas Regionais já processadas.

Calcular:

```text
ILP_anual = PIB_anual - VAB_anual
```

### Etapa 3 — Construir a proxy trimestral do ILP

#### Opção operacional A — MVP recomendado

```text
proxy_ilp_trim = w1 × ICMS_trim + w2 × ISS_trim
```

Pesos iniciais recomendados:

- `w1 = 0,85`
- `w2 = 0,15`

Esses pesos são heurísticos de partida e devem ser revistos depois de inspecionar a participação
relativa das arrecadações anualizadas.

#### Opção operacional B — versão ampliada

```text
proxy_ilp_trim = w_subnac × (ICMS + ISS) + w_fed × (IPI + II + PIS + Cofins + CIDE)
```

Regra recomendada:

- não fixar pesos arbitrários permanentes antes de ver a escala relativa dos dados;
- preferir normalizar cada bloco e calibrar os pesos com base nas participações médias observadas
  no período com benchmark anual;
- manter uma versão simplificada comparável ao MVP para teste de sensibilidade.

### Etapa 4 — Desagregar o ILP anual via Denton-Cholette

Usar `tempdisagg::td()` com:

- `y` = ILP anual;
- `x` = proxy trimestral do ILP;
- método compatível com a lógica já usada no projeto.

### Etapa 5 — Fechar o PIB nominal trimestral

```text
PIB_nom_trim = VAB_nom_trim + ILP_trim
```

Outputs esperados:

- `data/output/pib_nominal_rr.csv`
- nova aba no Excel final;
- eventual aba própria no dashboard, se o produto for adotado oficialmente.

---

## Estratégia recomendada de implementação

### Fase A — MVP com ICMS + ISS

Esta é a fase recomendada para começar.

**Por quê:**

- alta chance de disponibilidade no Siconfi;
- aderência conceitual boa ao ILP;
- custo baixo de coleta;
- permite publicar uma primeira versão do PIB nominal trimestral sem depender de uma solução
  federal completa.

**Resultado esperado:** primeira série trimestral utilizável de `ILP` e `PIB nominal`.

### Fase B — Federal por UF

Implementar depois da Fase A estabilizada.

**Por quê:**

- aumenta a aderência conceitual do ILP;
- reduz o risco de o componente federal ficar “escondido” no residual anual;
- melhora a narrativa metodológica da nota técnica.

### Fase C — Refino e validação

- testar inclusão de `ITBI`;
- testar `IOF` como opcional;
- comparar versões `MVP` vs. `ampliada`;
- documentar sensibilidade e estabilidade das variações trimestrais.

---

## Decisões metodológicas já recomendadas

1. O núcleo inicial do ILP trimestral deve usar `ICMS + ISS`.
2. `IPI` sozinho não deve ser usado como representante do bloco federal.
3. O bloco federal ampliado deve priorizar `IPI + II + PIS + Cofins + CIDE`.
4. `ITBI` é opcional e secundário; não bloqueia a primeira versão.
5. `IOF` só entra após teste empírico de aderência.
6. Se a fonte federal por UF atrasar, o projeto pode publicar um PIB nominal trimestral com
   `ICMS + ISS + residual anual ancorado`, desde que isso seja explicitado na nota técnica.

---

## Riscos e cuidados

### 1. Siconfi não resolve sozinho o bloco federal

O Siconfi é excelente para `estado + municípios`, mas não substitui uma fonte federal territorial
adequada por UF.

### 2. Receita tributária total não é o mesmo que ILP

Evitar misturar no mesmo agregado:

- IR,
- taxas diversas,
- contribuições sem aderência ao conceito de produto,
- receitas patrimoniais ou transferências.

### 3. Quebras institucionais e contábeis

Mudanças de classificação contábil, parcelamentos ou eventos atípicos podem produzir picos
artificiais. Isso exige inspeção de outliers, como já ocorre com as demais proxies do projeto.

### 4. Sazonalidade municipal

O `ISS` municipal pode ter ruído elevado em municípios pequenos. Agregar os 15 municípios de RR
antes da trimestralização é preferível a modelar cada um separadamente.

---

## Script a criar

### `R/05g_pib_nominal.R`

Escopo previsto:

1. carregar `indice_nominal_rr.csv`;
2. escalar VAB nominal trimestral para `R$ milhões`;
3. obter PIB anual RR via SIDRA;
4. calcular ILP anual;
5. ler e tratar proxies trimestrais (`ICMS`, `ISS` e, depois, bloco federal);
6. aplicar Denton-Cholette no ILP;
7. calcular `PIB nominal trimestral`;
8. salvar outputs e atualizar exportação.

---

## Critério de pronta-implementação

Esta reforma pode começar oficialmente quando pelo menos uma das condições abaixo for atendida:

- `ICMS estadual` e `ISS municipal agregado` estiverem acessíveis de forma reproduzível;
- houver decisão institucional de publicar o `PIB nominal trimestral` mesmo com bloco federal
  ainda residual;
- a fonte federal por UF estiver identificada e testada para `IPI`, `II`, `PIS`, `Cofins` e
  `CIDE`.

---

## Resultado esperado ao final da reforma

Ao final desta frente, o projeto passa a ter três camadas complementares:

- **IAET-RR real** — indicador principal de atividade;
- **VAB nominal trimestral** — já implementado;
- **PIB nominal trimestral** — novo produto derivado, construído com ILP trimestral explícito.
