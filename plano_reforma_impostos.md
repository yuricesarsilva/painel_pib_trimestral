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

O projeto já dispõe de quatro insumos críticos:

- `data/output/indice_nominal_rr.csv` — índice trimestral do VAB nominal, base 2020 = 100;
- `data/processed/contas_regionais_RR_serie.csv` — VAB nominal anual por atividade;
- `data/processed/icms_sefaz_rr_mensal.csv` — série mensal de ICMS, jan/2020–mar/2026 (**já disponível**);
- `ideia_pib.md` — registro inicial da proposta (supersedido por este plano).

O benchmark anual do PIB nominal de Roraima é obtido no SIDRA/IBGE (Tabela 5938), e o ILP anual
é calculado diretamente como:

```text
ILP anual = PIB anual - VAB anual
```

Valores de referência (CR IBGE):

| Ano | PIB (R$ mi) | VAB (R$ mi) | ILP (R$ mi) | ICMS (R$ mi) | ICMS/ILP |
|-----|-------------|-------------|-------------|--------------|----------|
| 2020 | 16.024 | 14.524 | 1.500 | 1.240 | 82,7% |
| 2021 | 18.203 | 16.310 | 1.893 | 1.569 | 82,9% |
| 2022 | 21.095 | 19.117 | 1.978 | 1.597 | 80,7% |
| 2023 | 25.125 | 23.003 | 2.122 | 1.707 | 80,5% |

---

## Princípio metodológico

O objetivo desta reforma **não** é medir carga tributária total, arrecadação total nem resultado
fiscal do setor público. O objetivo é aproximar o componente de **impostos sobre produtos** das
Contas Regionais, pois é esse termo que fecha a identidade:

```text
PIB = VAB + impostos líquidos sobre produtos
```

Portanto:

- tributos sobre renda, folha, patrimônio ou lucro **não entram** neste proxy;
- a seleção das proxies deve priorizar tributos que incidam sobre produção, circulação, vendas,
  importação ou disponibilização de bens e serviços;
- a sazonalidade trimestral importa mais do que a aderência perfeita em nível mensal.

---

## Decisão: proxy único com ICMS

Após investigação empírica das três fontes candidatas (ICMS, ISS e bloco federal), a decisão é
usar **exclusivamente o ICMS estadual** como proxy trimestral do ILP.

O ICMS explica **80–83% do ILP anual** nos anos com benchmark disponível. A parcela restante
(~17–20%) é tratada como resíduo anual distribuído pelo Denton-Cholette usando o próprio ICMS
como indicador de movimento — o que é metodologicamente aceitável para uma primeira versão.

### Por que ISS não foi incluído

O ISS municipal de Roraima foi investigado via Siconfi MSC para todos os 15 municípios em 2023.

**Achados:**
- Total ISS 2023 (15 municípios): R$ 162,6 mi — coerente com ~7,7% do ILP.
- Rota de extração confirmada: MSC MSCC, `natureza_receita LIKE '1112%'`,
  `natureza_conta = 'C'`.

**Motivo da exclusão:**
Boa Vista concentrou **54% do ISS anual em janeiro/2023** (R$ 77 mi em janeiro vs. média de
R$ 4–6 mi nos meses seguintes), e apresentou um segundo pico atípico em junho (R$ 19,7 mi).
Isso é um artefato de lançamento em lote no Siconfi, não sazonalidade econômica real. Usar essa
série como proxy mensal no Denton inflaria artificialmente o Q1. Sem suavização prévia, o ISS
via Siconfi não serve como indicador de movimento intra-anual.

**Condição de reabertura:** o ISS pode ser reincorporado na versão ampliada se for obtido por
fonte alternativa com distribuição mensal uniforme (ex.: SEFAZ municipal, nota fiscal de
serviços eletrônica ou suavização explícita da série Siconfi com filtro de Hodrick-Prescott).

### Por que o bloco federal não foi incluído

Os tributos federais sobre produtos (IPI, II, PIS/Pasep, Cofins, CIDE) foram investigados via
Receita Federal — "Arrecadação por Estado".

**Achados para RR (amostra: dez/2021):**

| Tributo | Valor/mês | Relevância |
|---------|-----------|------------|
| PIS/Pasep | R$ 11,2 mi | Média |
| Cofins | R$ 17,1 mi | Média |
| IPI | R$ 60 mil | **Negligenciável** |
| II | R$ 25 mil | **Negligenciável** |
| CIDE-Combustíveis | R$ 0 | **Não aplicável a RR** |

**Motivos da exclusão:**

1. **Cobertura insuficiente.** Os arquivos por estado da Receita Federal cobrem apenas
   jan/2000–mai/2022. Para jun/2022 em diante não há dado por UF publicado. O arquivo de série
   histórica nacional (1994–2025) não tem desagregação por estado.

2. **Problema metodológico de imputação territorial.** PIS/Cofins é registrado no domicílio
   fiscal do contribuinte (onde a empresa tem sede e paga o tributo), não no local de consumo.
   Roraima importa a maior parte dos bens tributados de outros estados (AM, SP, etc.) — logo a
   arrecadação de PIS/Cofins atribuída a RR subestima sistematicamente a carga federal real
   sobre a economia local. Usar esse dado como proxy criaria um viés estrutural.

3. **Magnitude pequena relativa.** IPI e II somam menos de R$ 1 mi/ano para RR — abaixo do
   nível de ruído do proxy.

4. **CIDE-Combustíveis = zero para RR.** Roraima não possui refinaria nem distribuidora-base
   que justifique CIDE coletada no estado.

**Condição de reabertura:** o bloco federal pode ser reincorporado se a Receita Federal
publicar dados por UF para 2022 em diante, ou se for desenvolvida uma metodologia de imputação
territorial baseada em dados de consumo (ex.: matriz insumo-produto regional).

---

## Fonte do ICMS: SEFAZ-RR (não Siconfi)

A fonte do ICMS foi revisada. O Siconfi/MSC havia sido validado como rota de extração, mas
apresentou **lacuna de 15 meses (jan/2022–mar/2023)** por transição de classificadores
contábeis — exatamente no período com benchmark CR IBGE disponível.

**Fonte adotada:** arquivos Excel mensais do **Portal de Arrecadação da SEFAZ-RR**
(`https://www.sefaz.rr.gov.br/m-arrecadacao-mensal`), baixados manualmente.

**Características da série:**
- Cobertura: jan/2020–mar/2026 (**75 observações mensais, sem lacunas**).
- Colunas disponíveis: Mês, Ano, ICMS, IPVA, ITCD, IRRF, Taxas, Outras Receitas, Total.
- Unidade: R$ 1,00 (convertida para R$ milhões no script).
- Armazenamento: `bases_baixadas_manualmente/dados_arrecadacao_rr_2020.1_2026.3/`
- Série processada: `data/processed/icms_sefaz_rr_mensal.csv`
- Script de leitura: `R/exploratorio/icms_sefaz_rr.R`

**Nenhum outlier detectado** (z-score > 2,5) na série mensal de ICMS. A sazonalidade é
coerente: picos em agosto–dezembro, baixa em fevereiro–março.

**Limitação:** a série depende de atualização manual. A SEFAZ-RR atualiza o portal com defasagem
de 1–2 meses. Não há API pública disponível — a tentativa de acesso programático retornou
apenas o esqueleto HTML (conteúdo JavaScript dinâmico).

---

## Estrutura metodológica adotada

### Etapa 1 — Escalar o VAB nominal trimestral para R$ milhões

Partir de `indice_nominal_rr.csv` e escalar pelo VAB nominal anual de 2020:

```text
VAB_nom_trim_R$ = indice_nominal_trim / 100 × (VAB_nominal_2020 / 4)
```

### Etapa 2 — Construir o ILP anual

```text
ILP_anual = PIB_anual (SIDRA tab. 5938) - VAB_anual (CR IBGE já processado)
```

### Etapa 3 — Construir a proxy trimestral do ILP

Agregar a série mensal de ICMS para frequência trimestral:

```text
ICMS_trim = soma dos três meses de cada trimestre
proxy_ILP_trim = ICMS_trim  (normalizado para média = 1 ou em nível, conforme td())
```

O ICMS captura 80–83% do ILP anual e tem sazonalidade coerente. O resíduo (~17–20%) não é
observável mensalmente e será distribuído pelo próprio Denton de forma proporcional ao ICMS.

### Etapa 4 — Desagregar o ILP anual via Denton-Cholette

```r
td(ILP_anual ~ ICMS_trim, method = "denton-cholette", conversion = "sum")
```

- `y` = vetor do ILP anual (2020–2023 com benchmark; extrapolado para 2024–2025);
- `x` = série trimestral do ICMS (2020T1–2026T1);
- A média dos quatro trimestres de cada ano reproduz o ILP anual.

### Etapa 5 — Fechar o PIB nominal trimestral

```text
PIB_nom_trim = VAB_nom_trim + ILP_trim
```

**Outputs esperados:**
- `data/output/pib_nominal_rr.csv`
- nova aba "PIB Nominal" no `IAET_RR_series.xlsx`;
- eventual aba no dashboard se o produto for adotado oficialmente.

---

## Decisões metodológicas registradas

| # | Decisão | Justificativa |
|---|---------|---------------|
| 1 | Proxy = ICMS exclusivamente | Cobre 80–83% do ILP; série limpa e completa (75 obs.) |
| 2 | ISS excluído da proxy | Artefato de lançamento em lote no Siconfi (54% do ISS em janeiro); não representa sazonalidade real |
| 3 | Bloco federal excluído | Dados por UF só até mai/2022; imputação territorial inadequada para RR; IPI+II+CIDE negligenciáveis |
| 4 | Fonte do ICMS = SEFAZ-RR | Siconfi MSC tinha lacuna 15 meses (jan/2022–mar/2023); SEFAZ-RR tem série completa |
| 5 | Resíduo tratado pelo Denton | Parcela não coberta pelo ICMS (~17–20%) distribuída proporcionalmente via Denton-Cholette |
| 6 | Pesos futuros calibrados por dados | Qualquer versão ampliada deve usar participações observadas, não pesos heurísticos fixos |

---

## Riscos e cuidados

### 1. Atualização manual do ICMS

A série depende de download manual do portal SEFAZ-RR. Não há automação disponível. Risco de
defasagem se o portal não for atualizado ou se a estrutura do Excel mudar.

### 2. Extrapolação do ILP pós-2023

O benchmark CR IBGE cobre até 2023. Para 2024–2025, o ILP anual será extrapolado pela mesma
lógica geométrica usada no índice real — e portanto carrega a mesma incerteza dos anos sem CR.

### 3. Quebras na série ICMS

Reformas tributárias (ex.: reforma do ICMS em curso) podem alterar a base de cálculo e produzir
quebra estrutural na série a partir de 2026. Monitorar.

### 4. Receita tributária total ≠ ILP

Os arquivos SEFAZ-RR incluem IRRF, IPVA, ITCD e outras receitas. Para o proxy de ILP, usar
**exclusivamente a coluna ICMS**. IRRF em abril/2021 apresentou pico extraordinário (R$ 256 mi
vs. média de R$ 20 mi) — não afeta ICMS, mas confirma que as demais colunas têm ruído elevado.

---

## Script implementado

### `R/05g_pib_nominal.R`

Escopo:

1. Ler `data/processed/icms_sefaz_rr_mensal.csv`;
2. Agregar ICMS para frequência trimestral;
3. Carregar `vab_nominal_rr_reais.csv` como base do VAB nominal trimestral em R$ milhões;
4. Obter PIB anual RR via SIDRA (tab. 5938) → calcular ILP anual;
5. Aplicar Denton-Cholette: `ILP_trim ~ ICMS_trim`;
6. Calcular `PIB_nom_trim = VAB_nom_trim + ILP_trim`;
7. Salvar `data/output/pib_nominal_rr.csv`;
8. Atualizar diretamente o `IAET_RR_series.xlsx` com a aba "PIB Nominal".

**Estado atual da implementação (2026-04-14):**

- o script já gera `data/output/ilp_rr_trimestral.csv` e `data/output/pib_nominal_rr.csv`;
- o PIB anual do SIDRA é convertido de `Mil Reais` para `R$ milhões` antes do cálculo do ILP;
- o ILP anual de 2024–2025 é extrapolado pela taxa anual do ICMS da SEFAZ-RR;
- o Denton-Cholette é aplicado com `conversion = "sum"` para preservar a soma anual do ILP;
- a aba "PIB Nominal" já é adicionada ao `IAET_RR_series.xlsx`.

---

## Critério de pronta-implementação

**Condição atendida e concluída:** a série de ICMS estava disponível e processada, e a
implementação de `R/05g_pib_nominal.R` foi concluída em 2026-04-14.

---

## Resultado esperado ao final da reforma

Ao final desta frente, o projeto passa a ter três camadas complementares:

- **IAET-RR real** — indicador principal de atividade econômica trimestral;
- **VAB nominal trimestral** — já implementado em `R/05f_vab_nominal.R`;
- **PIB nominal trimestral** — novo produto derivado, construído com ILP trimestral explícito via proxy ICMS.
