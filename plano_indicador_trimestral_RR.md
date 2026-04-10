# Plano: Indicador de Atividade Econômica Trimestral de Roraima

## Contexto

A SEPLAN/RR precisa de um indicador da produção trimestral de Roraima como proxy do PIB estadual,
ancorado metodologicamente nas Contas Regionais do IBGE. Os principais obstáculos são a ausência de
PIM-PF, ausência de IPCA estadual em qualquer período, e cobertura limitada das pesquisas do IBGE
para estados pequenos (sem PMC, sem PMS). A solução é construir um **índice encadeado de volume**
(sem unidade monetária) — convergente com a metodologia do IBCR do Banco Central — usando proxies
disponíveis para Roraima e ancorando os totais anuais às Contas Regionais do IBGE via Denton-Cholette.

- **Produto**: Índice de atividade econômica trimestral + nota técnica periódica + dashboard interativo (com download CSV/XLSX)
- **Ferramenta**: R
- **Cobertura**: 2020 em diante (início condicionado à consistência do CAGED pós-eSocial)
- **Deflação de séries nominais**: IPCA nacional (não existe IPCA estadual em nenhum período)

---

## Arquitetura metodológica

### Fórmula do índice

Índice de Laspeyres encadeado por volume — padrão das Contas Nacionais do IBGE:
- Pesos setoriais = participação no VAB da Conta Regional anual mais recente disponível
- Recomposição anual dos pesos conforme novas Contas Regionais forem publicadas (tipicamente 2 anos de defasagem)
- Período base: média de 2020 = 100

### Desagregação temporal (benchmarking anual → trimestral)

Método de **Denton-Cholette** (`tempdisagg::td()`) para garantir que a média dos quatro trimestres
de cada ano reproduza o índice anual implícito das Contas Regionais. Essencial para credibilidade
frente ao referencial oficial do IBGE.

### Ajuste sazonal

X-13ARIMA-SEATS via pacote `seasonal`. Publicar série com e sem ajuste sazonal.

---

## Estrutura setorial e proxies disponíveis para Roraima

### 1. Agropecuária (~6% do VAB) — detalhamento especial

#### 1a. Lavouras — metodologia de desagregação mensal da LSPA

**Problema central**: A LSPA não publica produção mensal — ela publica **revisões mensais da
projeção de produção anual** (ex: "em março projetamos 10.000 t de arroz para 2024"). Para obter
um fluxo mensal/trimestral de produção, é necessário:

1. Usar o **valor final (dezembro) da LSPA** de cada ano como produção anual de referência
2. Obter a **estrutura sazonal de colheita** do **Censo Agropecuário 2006** (tabelas de época de
   colheita por cultura e por estado — última publicação com essa granularidade)
3. Aplicar os coeficientes mensais do censo como pesos de distribuição da produção anual ao longo
   dos 12 meses → produção mensal estimada por cultura
4. Agregar meses em trimestres
5. Aplicar Denton-Cholette contra o VAB agropecuário anual das Contas Regionais

**Nota**: Os coeficientes de 2006 são a melhor aproximação disponível e refletem o calendário
agroclimático de Roraima, que é relativamente estável. Verificar se o Censo 2017 publicou tabela
equivalente de época de colheita — se sim, atualizar os coeficientes.

**Lavouras cobertas pela LSPA em Roraima:**

| Proxy (cultura) | Fonte | SIDRA | Frequência | Uso no índice |
|---|---|---|---|---|
| Arroz — quantidade produzida | LSPA | Tab. 6588 | Mensal (proj. anual) | Volume; peso = VBP PAM |
| Feijão — quantidade produzida | LSPA | Tab. 6588 | Mensal (proj. anual) | Volume; peso = VBP PAM |
| Milho — quantidade produzida | LSPA | Tab. 6588 | Mensal (proj. anual) | Volume; peso = VBP PAM |
| Soja — quantidade produzida | LSPA | Tab. 6588 | Mensal (proj. anual) | Volume; peso = VBP PAM |
| Banana — quantidade produzida | LSPA | Tab. 6588 | Mensal (proj. anual) | Volume; peso = VBP PAM |
| Cacau — quantidade produzida | LSPA | Tab. 6588 | Mensal (proj. anual) | Volume; peso = VBP PAM |
| Cana-de-açúcar — quantidade produzida | LSPA | Tab. 6588 | Mensal (proj. anual) | Volume; peso = VBP PAM |
| Laranja — quantidade produzida | LSPA | Tab. 6588 | Mensal (proj. anual) | Volume; peso = VBP PAM |
| Mandioca — quantidade produzida | LSPA | Tab. 6588 | Mensal (proj. anual) | Volume; peso = VBP PAM |
| Tomate — quantidade produzida | LSPA | Tab. 6588 | Mensal (proj. anual) | Volume; peso = VBP PAM |
| Pesos (VBP por cultura) | PAM | Tab. 5457 / 5558 | Anual | Estrutura Laspeyres |
| Coefic. sazonais de colheita | Censo Agropecuário 2006 | — | Fixo (anual) | Distribuição intra-anual |

**Análise de cobertura (entrega obrigatória):**
Calcular via PAM o percentual do VBP total de lavouras em Roraima coberto pelas 10 culturas acima.
Esse número deve constar na nota técnica como indicador de transparência.

#### 1b. Pecuária

| Proxy | Fonte | SIDRA | Frequência | Status |
|---|---|---|---|---|
| Abate de bovinos (quantidade) | IBGE Abate | Tab. 1092 | Trimestral | Verificar disponibilidade para RR |
| Abate de suínos e aves | IBGE Abate | Tab. 1092 | Trimestral | Verificar disponibilidade para RR |
| Produção de leite (litros) | IBGE Leite | Tab. 74 | Trimestral | Verificar disponibilidade para RR |
| Produção de ovos de galinha | IBGE Ovos | Tab. 915 | Trimestral | Verificar disponibilidade para RR |
| Peso de cada produto pecuário | PPM (VBP) | Tab. 3939 | Anual | Confirmado |

**Nota**: Disponibilidade de cada série para RR deve ser verificada via SIDRA antes de incluir.
Os que não tiverem cobertura para RR são excluídos da versão inicial. Os pesos (PPM) garantem que
produtos sem proxy trimestral recebam participação zero no índice ou sejam interpolados linearmente.

---

### 2. Administração Pública (~32% do VAB) ★ setor mais importante

| Proxy | Fonte | Frequência |
|---|---|---|
| Folha de pagamento federal bruta (servidores lotados em RR) | Portal da Transparência (API) | Mensal |
| Folha estadual (SEPLAN/SEFAZ-RR) | SEPLAN-RR | Mensal |
| Folha municipal (estimada via SICONFI) | STN | Trimestral |

**Justificativa metodológica (por que SIAPE > PNADC para este setor):**
O IBGE mensura o produto de Administração Pública nas Contas Regionais pela **abordagem de custo**
(non-market services): VAB ≈ remuneração dos empregados + consumo intermediário + consumo de capital
fixo. O componente dominante é a folha salarial. Portanto, o SIAPE não é apenas um proxy — é
**a mesma variável que o IBGE usa como insumo de cálculo**. Ao aplicar Denton-Cholette com a folha
como indicador de distribuição trimestral, a série quarterly se alinhará ao benchmark anual
naturalmente, pois proxy e benchmark compartilham base conceitual idêntica. A PNADC captura estoque
de empregos (não o valor da folha), sofre de erro amostral para RR, e não reflete reajustes salariais
nem mudanças de lotação — todos capturados pelo SIAPE.

**Deflação**: IPCA nacional aplicado à folha nominal → série de volume.

---

### 3. Construção Civil (~8% do VAB)

| Proxy | Fonte | Frequência |
|---|---|---|
| Vínculos ativos na construção (CNAE F) | CAGED novo (a partir de 2020) | Mensal |
| ICMS sobre materiais de construção | SEFAZ-RR (por atividade econômica) | Mensal |

---

### 4. SIUP — Serviços de Utilidade Pública (~3% do VAB)

| Proxy | Fonte | Frequência |
|---|---|---|
| Consumo total de energia elétrica (RR) | ANEEL / EPE / BEN | Mensal |

---

### 5. Indústria de Transformação (~2% do VAB)

| Proxy | Fonte | Frequência |
|---|---|---|
| Vínculos na indústria de transformação (CNAE C) | CAGED | Mensal |
| ICMS sobre bens industriais | SEFAZ-RR (por atividade econômica) | Mensal |

**Nota**: Sem PIM-PF para RR. Peso < 3% minimiza o impacto de uma proxy menos precisa.

---

### 6. Comércio (~12% do VAB)

| Proxy | Fonte | Frequência | Qualidade |
|---|---|---|---|
| ICMS sobre comércio (por atividade econômica) | SEFAZ-RR | Mensal | Primário |
| Vínculos no comércio (CNAE G) | CAGED | Mensal | Controle de consistência |

**Nota sobre ICMS**: deflacionar pelo IPCA nacional para obter volume. Atentar a mudanças de
alíquota e regimes especiais. Usar como proxy primário; CAGED como verificação.

---

### 7. Transportes (~4% do VAB)

| Proxy | Fonte | Frequência | Cobertura |
|---|---|---|---|
| Passageiros embarcados/desembarcados (Boa Vista) | ANAC | Mensal | Aéreo de passageiros |
| Carga aérea (Boa Vista) | ANAC | Mensal | Aéreo de cargas |
| Vendas de óleo diesel (RR) | ANP (por UF) | Mensal | Frete rodoviário |

**Nota sobre diesel**: Proxy razoável para frete rodoviário em Roraima (BR-174, abastecimento de
Boa Vista). Limitação: diesel também abastece máquinas agrícolas e de construção. Por isso, o
diesel é usado **exclusivamente neste setor** como componente de índice composto ponderado com ANAC
— nunca duplicado em agropecuária ou construção. A sobreposição deve ser documentada na nota técnica.

---

### 8. Outros serviços / saúde / educação (~13% do VAB)

| Proxy | Fonte | Frequência |
|---|---|---|
| Vínculos em saúde e educação privadas (CNAE P+Q) | CAGED | Mensal |
| Operações de crédito (RR) | BCB Estban | Mensal |
| Depósitos bancários (RR) | BCB Estban | Mensal |

---

## Mapa de pesos e prioridades

| Setor | % VAB RR | Qualidade do proxy | Prioridade |
|---|---|---|---|
| Adm. Pública | ~32% | Alta (SIAPE) | 2ª fase |
| Comércio | ~12% | Média-alta (ICMS+CAGED) | 4ª fase |
| Construção | ~8% | Média (CAGED+ICMS) | 3ª fase |
| Agropecuária | ~6% | Alta (LSPA+Censo) | **1ª fase** |
| Transportes | ~4% | Média (ANAC+diesel) | 4ª fase |
| SIUP | ~3% | Alta (ANEEL) | 3ª fase |
| Ind. Transformação | ~2% | Média (CAGED+ICMS) | 3ª fase |
| Outros serviços | ~13% | Média (CAGED+BCB) | 4ª fase |
| Intermediação financeira | ~3% | Média (BCB Estban) | 4ª fase |

---

## Sequência de implementação

### Fase 1 — Agropecuária

**Etapa 1.0 — Análise de cobertura da LSPA (entrega de transparência):**
- Puxar PAM via `sidrar` (tabelas 5457/5558 — lavouras temporárias e permanentes) para Roraima
- Calcular VBP total de todas as lavouras
- Calcular VBP das 10 culturas cobertas pela LSPA (Arroz, Feijão, Milho, Soja, Banana, Cacau,
  Cana-de-açúcar, Laranja, Mandioca, Tomate)
- Gerar tabela: participação % de cada cultura + cobertura total
- Este número de cobertura vai constar na nota técnica final

**Etapa 1.1 — Estrutura sazonal do Censo Agropecuário:**
- Localizar tabelas de "época de colheita" do Censo 2006 (e verificar se Censo 2017 publicou equivalente)
- Construir matriz: cultura × mês → coeficiente de colheita (soma = 1 por cultura)
- Verificar razoabilidade com calendário agroclimático de RR (período chuvoso dez–abr, seco mai–set)

**Etapa 1.2 — Série mensal de produção de lavouras:**
- Puxar LSPA (valor final anual por cultura) via `sidrar`
- Aplicar coeficientes do Censo → produção mensal por cultura
- Calcular índice de Laspeyres de quantidade com pesos PAM (VBP)
- Agregar em trimestres

**Etapa 1.3 — Pecuária:**
- Verificar disponibilidade para RR via SIDRA:
  - Tab. 1092: abate de bovinos, suínos, aves
  - Tab. 74: produção de leite (litros)
  - Tab. 915: produção de ovos de galinha
- Para cada série disponível: calcular índice de volume trimestral
- Agregar com lavouras usando pesos PPM (tab. 3939) como estrutura de ponderação
- Documentar quais séries pecuárias não têm cobertura para RR (transparência metodológica)

**Etapa 1.4 — Benchmarking:**
- Aplicar Denton-Cholette (`tempdisagg::td()`) contra VAB agropecuário anual das Contas Regionais
- Validar: variação anual do índice vs. Contas Regionais

---

### Fase 2 — Administração Pública (maior peso, dados excelentes)
- Coletar SIAPE via API do Portal da Transparência (filtro UG lotação RR)
- Incorporar folha estadual da SEPLAN-RR
- Deflacionar pelo IPCA nacional → série de volume
- Denton-Cholette contra VAB AAPP anual

### Fase 3 — Indústria composta (Construção + SIUP + Transformação)
- CAGED construção + ICMS construção + ANEEL
- CAGED transformação + ICMS industrial

### Fase 4 — Serviços privados (Comércio + Transportes + Outros)
- ICMS comércio + CAGED comércio
- ANAC passageiros/carga + ANP diesel (composto ponderado)
- CAGED serviços + BCB Estban

### Fase 5 — Agregação, ajuste sazonal e publicação
- Laspeyres encadeado com pesos das Contas Regionais
- X-13ARIMA-SEATS
- Outputs: CSV/XLSX, dashboard Shiny/flexdashboard, nota técnica Quarto

---

## Estrutura de pastas do projeto

```
PIB Trimestral - Projeto 2026/
├── data/
│   ├── raw/           # downloads brutos (APIs, portais, SEPLAN)
│   ├── processed/     # séries limpas por setor
│   └── output/        # índice final + componentes
├── R/
│   ├── utils.R                  # Denton wrapper, encadeamento, deflação
│   ├── 01_agropecuaria.R        # inclui análise de cobertura PAM
│   ├── 02_adm_publica.R
│   ├── 03_industria.R
│   ├── 04_servicos.R
│   └── 05_agregacao.R
├── dashboard/
│   └── app.R
├── notas/
│   └── nota_tecnica.qmd
└── Base metodológica/
```

---

## Pacotes R principais

| Pacote | Uso |
|---|---|
| `sidrar` | LSPA, Abate, PAM, PPM via SIDRA/IBGE |
| `tempdisagg` | Denton-Cholette |
| `seasonal` | X-13ARIMA-SEATS |
| `dplyr` / `tidyr` / `lubridate` | Manipulação |
| `ggplot2` | Visualização |
| `writexl` / `openxlsx` | Excel |
| `quarto` | Nota técnica PDF |
| `shiny` / `flexdashboard` | Dashboard |
| `httr2` / `jsonlite` | APIs (Transparência, BCB, ANEEL, ANP) |

---

## Decisões metodológicas a documentar na nota técnica

1. **LSPA é projeção anual, não fluxo mensal**: distribuição intra-anual feita via coeficientes de
   colheita do Censo Agropecuário 2006 (melhor aproximação disponível).
2. **Cobertura da LSPA**: X% do VBP total de lavouras de Roraima (calculado via PAM, ver Etapa 1.0).
3. **Ausência de PIM-PF**: compensada por CAGED + ICMS industrial; peso < 3%.
4. **Ausência de IPCA estadual**: IPCA nacional usado para deflacionar séries nominais.
5. **Início em 2020**: descontinuidade do CAGED inviabiliza séries anteriores baseadas em emprego.
6. **ICMS como proxy de volume**: requer deflação e monitoramento de mudanças legislativas.
7. **Diesel para transportes**: proxy de frete rodoviário; não duplicado em agropecuária/construção.
8. **Benchmarking Denton**: assegura consistência anual com IBGE.
9. **Pesos anuais**: revisados conforme publicação das Contas Regionais (tipicamente 2 anos de defasagem).

---

## Validação

- Variação anual do índice vs. crescimento do PIB estadual IBGE (Contas Regionais)
- Perfil de ciclo vs. IBC-BR / IBCR Norte do Banco Central
- Correlação com arrecadação tributária total de RR
- Comportamento em 2020 (COVID): queda comparável a estados vizinhos
- Consistência interna: Fase 2 (AAPP) deve reproduzir bem o benchmark anual → teste da metodologia Denton
