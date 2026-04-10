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

#### 1a. Lavouras — metodologia de desagregação mensal (PAM + LSPA)

**Hierarquia das fontes de produção anual:**

A PAM (Produção Agrícola Municipal) é o **dado consolidado e definitivo** de produção de lavouras,
publicada anualmente pelo IBGE com defasagem de aproximadamente um ano (ex: PAM 2023 publicada em
2024). A LSPA (Levantamento Sistemático da Produção Agrícola), por sua vez, publica **revisões
mensais da projeção de produção anual** — ela é o canal de atualização corrente antes da PAM ser
publicada. De fato, o valor da LSPA de dezembro de cada ano converge para o valor que será
consolidado na PAM.

**Regra de uso das fontes:**

- **Anos com PAM disponível**: usar a quantidade produzida da PAM como valor anual de referência —
  é o dado mais preciso e revisado.
- **Ano mais recente sem PAM disponível**: usar o **valor de dezembro da LSPA** daquele ano como
  estimativa provisória da produção anual. Quando a PAM for publicada, substituir automaticamente.

**Método de desagregação intra-anual (igual para PAM e LSPA):**

A produção anual — seja de fonte PAM ou LSPA — não tem desagregação mensal publicada. Para obter
um fluxo mensal/trimestral de produção, aplica-se o seguinte procedimento em ambos os casos:

1. Tomar a **produção anual por cultura** (PAM consolidada ou LSPA dezembro do ano corrente)
2. Obter a **estrutura sazonal de colheita** do **Censo Agropecuário 2006** (tabelas de época de
   colheita por cultura e por estado — última publicação com essa granularidade)
3. Aplicar os coeficientes mensais do Censo como pesos de distribuição da produção anual ao longo
   dos 12 meses → produção mensal estimada por cultura
4. Agregar meses em trimestres
5. Aplicar Denton-Cholette contra o VAB agropecuário anual das Contas Regionais

**Nota**: Os coeficientes de 2006 são a melhor aproximação disponível e refletem o calendário
agroclimático de Roraima, que é relativamente estável. Verificar se o Censo 2017 publicou tabela
equivalente de época de colheita — se sim, atualizar os coeficientes.

**Lavouras cobertas e fontes:**

| Cultura | Fonte (anos consolidados) | Fonte (ano corrente) | SIDRA | Uso no índice |
|---|---|---|---|---|
| Arroz — quantidade produzida | PAM | LSPA (dez) | Tab. 5457 / 6588 | Volume; peso = VBP PAM |
| Feijão — quantidade produzida | PAM | LSPA (dez) | Tab. 5457 / 6588 | Volume; peso = VBP PAM |
| Milho — quantidade produzida | PAM | LSPA (dez) | Tab. 5457 / 6588 | Volume; peso = VBP PAM |
| Soja — quantidade produzida | PAM | LSPA (dez) | Tab. 5457 / 6588 | Volume; peso = VBP PAM |
| Banana — quantidade produzida | PAM | LSPA (dez) | Tab. 5558 / 6588 | Volume; peso = VBP PAM |
| Cacau — quantidade produzida | PAM | LSPA (dez) | Tab. 5558 / 6588 | Volume; peso = VBP PAM |
| Cana-de-açúcar — quantidade produzida | PAM | LSPA (dez) | Tab. 5457 / 6588 | Volume; peso = VBP PAM |
| Laranja — quantidade produzida | PAM | LSPA (dez) | Tab. 5558 / 6588 | Volume; peso = VBP PAM |
| Mandioca — quantidade produzida | PAM | LSPA (dez) | Tab. 5457 / 6588 | Volume; peso = VBP PAM |
| Tomate — quantidade produzida | PAM | LSPA (dez) | Tab. 5457 / 6588 | Volume; peso = VBP PAM |
| Pesos (VBP por cultura) | PAM | PAM (último ano disponível) | Tab. 5457 / 5558 | Estrutura Laspeyres |
| Coefic. sazonais de colheita | Censo Agropecuário 2006 | Censo 2006 | — | Distribuição intra-anual |

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

| Proxy | Fonte | Frequência | Tipo de medida |
|---|---|---|---|
| Vínculos ativos na construção (CNAE F) | CAGED novo (a partir de 2020) | Mensal | Insumo (emprego) |
| ICMS sobre materiais de construção | SEFAZ-RR (por atividade econômica) | Mensal | Valor nominal |
| Vendas de cimento (RR) | SNIC — Sindicato Nacional da Indústria do Cimento | Mensal | Volume físico |

**Nota sobre cimento**: O SNIC publica vendas de cimento por estado em frequência mensal — proxy
física direta de atividade construtiva, usada em diversas metodologias estaduais de PIB trimestral
(inclusive como referência do IBCR). É o único insumo com dado físico de alta frequência disponível
para RR. Deflação não necessária (já é volume). Classificação de qualidade: **forte**.

---

### 4. SIUP — Eletricidade, gás, água, esgoto e resíduos (5,40% do VAB)

| Proxy | Fonte | Frequência | Tipo de medida |
|---|---|---|---|
| Consumo de energia elétrica — residencial (RR) | ANEEL (por classe de consumo) | Mensal | Volume |
| Consumo de energia elétrica — comercial (RR) | ANEEL (por classe de consumo) | Mensal | Volume |
| Consumo de energia elétrica — industrial (RR) | ANEEL (por classe de consumo) | Mensal | Volume |
| Consumo de energia elétrica — poder público (RR) | ANEEL (por classe de consumo) | Mensal | Volume |

**Nota sobre desagregação**: a ANEEL disponibiliza consumo por classe de consumidor e por UF na
mesma consulta, sem custo adicional de coleta. Coletar desagregado desde o início permite: (a)
construir um índice composto ponderado para o SIUP; (b) reaproveitar a série de **energia
comercial** no setor de Comércio e a série de **energia industrial** na Indústria de Transformação,
sem necessidade de coleta adicional. O consumo residencial é mais influenciado por fatores
populacionais e climáticos do que pela atividade econômica — recebe peso menor no índice do SIUP.
Classificação de qualidade do bloco: **forte**.

---

### 5. Indústria de Transformação (1,31% do VAB)

| Proxy | Fonte | Frequência | Tipo de medida |
|---|---|---|---|
| Consumo de energia industrial (RR) | ANEEL (classe industrial — coletado no SIUP) | Mensal | Volume |
| Vínculos na indústria de transformação (CNAE C) | CAGED | Mensal | Insumo (emprego) |
| ICMS sobre bens industriais | SEFAZ-RR (por atividade econômica) | Mensal | Valor nominal |

**Nota**: Sem PIM-PF para RR. Peso de 1,31% minimiza o impacto de proxies menos precisas. A
energia industrial é o componente mais próximo de volume físico e recebe peso prioritário no índice
composto. ICMS requer deflação e atenção a quebras tributárias. A série de energia industrial é
obtida sem coleta adicional, como subproduto da coleta do SIUP.

---

### 6. Comércio e reparação de veículos automotores e motocicletas (12,25% do VAB)

| Proxy | Fonte | Frequência | Tipo de medida | Qualidade |
|---|---|---|---|---|
| ICMS sobre comércio (por atividade econômica) | SEFAZ-RR | Mensal | Valor nominal | Aceitável |
| Vínculos no comércio (CNAE G) | CAGED | Mensal | Insumo (emprego) | Aceitável |
| Consumo de energia comercial (RR) | ANEEL (classe comercial — coletado no SIUP) | Mensal | Volume | Forte |

**Composição do índice**: índice composto com pesos explícitos a calibrar (sugestão inicial:
energia comercial 40%, ICMS deflacionado 40%, CAGED 20%). A energia comercial é o componente
mais robusto por medir volume físico independente de preço ou alíquota.

**Regra para quebras tributárias**: toda vez que houver alteração de alíquota, benefício fiscal
ou mudança de regime tributário que afete a arrecadação de ICMS do comércio, documentar a data
e inserir variável de ajuste de nível (dummy) no script. Isso protege a série contra saltos
artificiais. Monitorar os Decretos da SEFAZ-RR periodicamente.

---

### 7. Transporte, armazenagem e correio (1,92% do VAB)

| Proxy | Fonte | Frequência | Cobertura |
|---|---|---|---|
| Passageiros embarcados/desembarcados (Boa Vista) | ANAC | Mensal | Aéreo de passageiros |
| Carga aérea (Boa Vista) | ANAC | Mensal | Aéreo de cargas |
| Vendas de óleo diesel (RR) | ANP (por UF) | Mensal | Frete rodoviário |

**Composição do índice**: composto ponderado com pesos explícitos a calibrar (sugestão inicial:
passageiros ANAC 40%, carga aérea ANAC 30%, diesel ANP 30%). O diesel recebe peso menor por ser
uma proxy contaminada — abastece também máquinas agrícolas, de construção e geração térmica, além
do frete rodoviário. O diesel é usado **exclusivamente neste setor** e nunca duplicado em
agropecuária ou construção. A sobreposição e o peso reduzido do diesel devem ser documentados na
nota técnica.

---

### 8. Informação e comunicação (1,01% do VAB)

| Proxy | Fonte | Frequência |
|---|---|---|
| Vínculos em TI, telecom e mídia (CNAE J) | CAGED | Mensal |

---

### 9. Atividades financeiras, de seguros e serviços relacionados (2,78% do VAB)

| Proxy | Fonte | Frequência | Tipo de medida | Qualidade |
|---|---|---|---|---|
| Concessões de crédito (RR) | BCB — Nota de Crédito por UF | Mensal | Fluxo (volume corrente) | Aceitável |
| Depósitos bancários (RR) | BCB Estban | Mensal | Estoque | Fraca mas necessária |

**Nota metodológica**: o BCB Estban fornece *saldos* (estoque) de crédito e depósitos — variáveis
de estado que podem crescer mesmo com atividade corrente estável ou em queda. As **concessões de
crédito** (Nota de Crédito do BCB, disponível por UF) medem o *fluxo* de novos créditos
concedidos a cada mês — muito mais próximo da atividade corrente do setor. Usar concessões como
componente principal e saldo de depósitos como componente secundário. Ambos devem ser deflacionados
pelo IPCA nacional para obter volume. Aplicar suavização (média móvel de 3 meses) antes de
calcular o índice, pois concessões têm volatilidade mensal alta.

---

### 10. Atividades imobiliárias (7,68% do VAB)

| Proxy | Fonte | Frequência |
|---|---|---|
| Tendência suavizada (interpolação linear entre benchmarks IBGE) | Contas Regionais IBGE | Anual |

**Nota metodológica importante**: atividades imobiliárias em grande parte representa **aluguel
imputado de imóveis próprios** (imputação de aluguel nas Contas Nacionais), o que não possui
proxy observable de alta frequência. O componente é relativamente estável e será tratado como
tendência linear interpolada entre os valores anuais do IBGE. Não requer dado mensal próprio.

---

### 11. Outros serviços (7,63% do VAB)

Inclui: alojamento e alimentação, atividades profissionais e científicas, atividades administrativas,
saúde e educação privadas, artes, cultura e esporte, serviços domésticos.

| Proxy | Fonte | Frequência |
|---|---|---|
| Vínculos em saúde e educação privadas (CNAE P+Q) | CAGED | Mensal |
| Vínculos em alojamento e alimentação (CNAE I) | CAGED | Mensal |
| Vínculos em atividades profissionais e admin. (CNAE M+N) | CAGED | Mensal |

---

### 12. Indústrias extrativas (0,05% do VAB — negligenciável)

Peso inferior a 0,1% — absorvida no componente "Outros" ou mantida com interpolação linear
entre benchmarks anuais do IBGE. Não justifica proxy específico.

---

## Mapa de pesos e prioridades

Pesos extraídos das **Contas Regionais do IBGE — Roraima 2023** (VAB a preços correntes,
publicação IBGE out/2025). VAB total = R$ 23,0 bilhões.

| Atividade (IBGE) | % VAB 2023 | VAB (R$ mi) | Qualidade do proxy | Prioridade |
|---|---|---|---|---|
| Adm., defesa, educação e saúde públicas | 46,21% | 10.629 | Alta (SIAPE + folha estadual) | **2ª fase** |
| Comércio e reparação de veículos | 12,25% | 2.817 | Média-alta (ICMS + CAGED + energia comercial) | 4ª fase |
| Agropecuária | 8,87% | 2.040 | Alta (PAM/LSPA + Censo + abate) | **1ª fase** |
| Atividades imobiliárias | 7,68% | 1.767 | Baixa (tendência suavizada) | 4ª fase |
| Outros serviços | 7,63% | 1.756 | Média (CAGED por subgrupo CNAE) | 4ª fase |
| SIUP | 5,40% | 1.243 | Alta (ANEEL por classe de consumo) | 3ª fase |
| Construção | 4,89% | 1.125 | Média-alta (CAGED + ICMS + cimento SNIC) | 3ª fase |
| Atividades financeiras e seguros | 2,78% | 639 | Média (BCB concessões + depósitos) | 4ª fase |
| Transporte, armazenagem e correio | 1,92% | 441 | Média (ANAC passag./carga + diesel ponderado) | 4ª fase |
| Indústrias de transformação | 1,31% | 301 | Média (energia industrial + CAGED + ICMS) | 3ª fase |
| Informação e comunicação | 1,01% | 233 | Fraca mas necessária (CAGED TI/telecom) | 4ª fase |
| Indústrias extrativas | 0,05% | 12 | — (negligenciável) | Absorvida |

---

## Sequência de implementação

### Fase 1 — Agropecuária

**Etapa 1.0 — Análise de cobertura (entrega de transparência):**
- Puxar PAM via `sidrar` (tabelas 5457/5558 — lavouras temporárias e permanentes) para Roraima
- Calcular VBP total de todas as lavouras
- Calcular VBP das 10 culturas incluídas no índice (Arroz, Feijão, Milho, Soja, Banana, Cacau,
  Cana-de-açúcar, Laranja, Mandioca, Tomate)
- Gerar tabela: participação % de cada cultura + cobertura total do VBP de lavouras
- Este número de cobertura vai constar na nota técnica final

**Etapa 1.1 — Estrutura sazonal do Censo Agropecuário:**
- Localizar tabelas de "época de colheita" do Censo 2006 (e verificar se Censo 2017 publicou equivalente)
- Construir matriz: cultura × mês → coeficiente de colheita (soma = 1 por cultura)
- Verificar razoabilidade com calendário agroclimático de RR (período chuvoso dez–abr, seco mai–set)

**Etapa 1.2 — Série mensal de produção de lavouras:**
- Para cada ano com PAM disponível: usar quantidade produzida da PAM (tabelas 5457/5558) como valor anual
- Para o ano mais recente sem PAM: usar valor de dezembro da LSPA (tabela 6588) como estimativa provisória
  - Ao ser publicada a PAM do período, substituir o valor da LSPA automaticamente
- Aplicar coeficientes do Censo → produção mensal por cultura (mesmo procedimento para PAM e LSPA)
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
- Construção: CAGED + ICMS materiais + cimento SNIC (índice composto com pesos explícitos)
- SIUP: ANEEL desagregado por classe de consumo (residencial, comercial, industrial, público)
- Transformação: energia industrial (da coleta SIUP) + CAGED + ICMS industrial

### Fase 4 — Serviços privados (Comércio + Transportes + Outros)
- Comércio: energia comercial (da coleta SIUP) + ICMS deflacionado + CAGED (índice composto)
- Transportes: ANAC passageiros + ANAC carga + ANP diesel (composto ponderado, diesel com peso menor)
- Outros serviços: CAGED por subgrupo CNAE (I, M+N, P+Q) com pesos explícitos
- Financeiro: concessões de crédito BCB + depósitos BCB Estban

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

## Padrões de implementação (boas práticas obrigatórias)

Estes padrões aplicam-se a todos os scripts e à nota técnica, independentemente do setor.

### Classificação de qualidade de cada proxy

Todo componente deve ser classificado em uma de três categorias na nota técnica:

| Categoria | Critério |
|---|---|
| **Forte** | Mede diretamente volume físico ou é conceitualmente a mesma variável usada pelo IBGE |
| **Aceitável** | Correlacionada com a atividade do setor, mas contaminada por preço, estoque ou informalidade |
| **Fraca mas necessária** | Melhor opção disponível para RR, com limitações documentadas |

### Tipologia das proxies

Cada proxy deve ter seu tipo documentado explicitamente:

| Tipo | Exemplos no projeto |
|---|---|
| **Volume físico** | Cimento (t), energia elétrica (MWh), produção agrícola (t) |
| **Valor nominal** | ICMS (R$) — requer deflação pelo IPCA |
| **Fluxo** | Concessões de crédito (R$), emissão de notas fiscais |
| **Estoque** | Saldo de depósitos, vínculos de emprego (CAGED acumulado) |
| **Insumo** | Vínculos ativos CAGED (proxy de emprego, não de produção) |

### Pesos explícitos dentro de cada setor

Quando um setor usa mais de uma proxy (índice composto), os pesos devem ser definidos
explicitamente no script — nunca implícitos. Os pesos iniciais seguem o critério de qualidade
(proxies mais fortes recebem peso maior) e podem ser revisados se os testes de sensibilidade
indicarem instabilidade.

### Regra de quebras tributárias (ICMS)

Para toda série baseada em ICMS (Comércio, Construção, Indústria de Transformação):
1. Manter um registro de datas de alteração de alíquota, regime ou benefício fiscal da SEFAZ-RR
2. No script, criar variável dummy para cada quebra estrutural identificada
3. Ajustar a série ou documentar o impacto na nota técnica trimestral
4. Monitorar: Diário Oficial de RR e Decretos da SEFAZ-RR

### Teste de sensibilidade

Na Fase 5 (agregação), gerar duas versões do índice:
- **Versão A**: proxies e pesos conforme definidos no plano
- **Versão B**: variação de hipótese (ex: calendário agrícola alternativo, pesos diferentes nos
  compostos, excluindo uma proxy de qualidade mais fraca)
- Comparar e documentar a diferença. Se a divergência for pequena, reforça a robustez do índice.

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

1. **PAM como fonte primária, LSPA como substituto temporário**: para anos com PAM disponível, usa-se
   a quantidade produzida da PAM (dado consolidado). Para o ano corrente ainda não coberto pela PAM,
   usa-se o valor de dezembro da LSPA (estimativa provisória). Quando a PAM for publicada, o valor
   é substituído. A distribuição intra-anual é feita da mesma forma em ambos os casos: coeficientes
   de colheita do Censo Agropecuário 2006.
2. **LSPA não é fluxo mensal**: a LSPA publica revisões mensais da projeção de produção anual —
   não a produção mês a mês. A desagregação mensal é sempre derivada dos coeficientes do Censo.
3. **Cobertura das culturas no índice**: X% do VBP total de lavouras de Roraima (calculado via PAM,
   ver Etapa 1.0).
4. **Ausência de PIM-PF**: compensada por CAGED + ICMS industrial; peso < 3%.
5. **Ausência de IPCA estadual**: IPCA nacional usado para deflacionar séries nominais.
6. **Início em 2020**: descontinuidade do CAGED inviabiliza séries anteriores baseadas em emprego.
7. **ICMS como proxy de volume**: requer deflação e monitoramento de mudanças legislativas.
8. **Diesel para transportes**: proxy de frete rodoviário; não duplicado em agropecuária/construção.
9. **Benchmarking Denton**: assegura consistência anual com IBGE.
10. **Pesos anuais**: revisados conforme publicação das Contas Regionais (tipicamente 2 anos de defasagem).

---

## Validação

- Variação anual do índice vs. crescimento do PIB estadual IBGE (Contas Regionais)
- Perfil de ciclo vs. IBC-BR / IBCR Norte do Banco Central
- Correlação com arrecadação tributária total de RR
- Comportamento em 2020 (COVID): queda comparável a estados vizinhos
- Consistência interna: Fase 2 (AAPP) deve reproduzir bem o benchmark anual → teste da metodologia Denton
