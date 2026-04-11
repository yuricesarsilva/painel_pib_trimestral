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

### 1. Agropecuária (8,87% do VAB) — detalhamento especial

#### 1a. Lavouras — metodologia de desagregação mensal (PAM + LSPA)

**Hierarquia das fontes de produção anual:**

A PAM (Produção Agrícola Municipal) é o **dado consolidado e definitivo** de produção de lavouras,
publicada anualmente pelo IBGE com defasagem de aproximadamente um ano (ex: PAM 2024 publicada em
2025). A LSPA (Levantamento Sistemático da Produção Agrícola), por sua vez, publica **revisões
mensais da projeção de produção anual** — ela é o canal de atualização corrente antes da PAM ser
publicada. De fato, o valor da LSPA de dezembro de cada ano converge para o valor que será
consolidado na PAM.

**Regra de uso das fontes:**

- **Anos com PAM disponível**: usar a quantidade produzida da PAM como valor anual de referência
  (dado mais preciso e revisado). A PAM cobre Roraima até **2024** (confirmado via SIDRA).
- **Ano mais recente sem PAM disponível**: usar o **valor de dezembro da LSPA** daquele ano como
  estimativa provisória. Quando a PAM for publicada, o script substitui automaticamente.
  Atualmente: LSPA usada para **2025**.

**Método de desagregação intra-anual (igual para PAM e LSPA):**

A produção anual não tem desagregação mensal publicada. Para obter um fluxo trimestral:

1. Tomar a **produção anual por cultura** (PAM ou LSPA dezembro)
2. Aplicar **coeficientes mensais de colheita** do **Censo Agropecuário 2006** como pesos de
   distribuição ao longo dos 12 meses → produção mensal estimada por cultura
3. Agregar meses em trimestres
4. Calcular índice de Laspeyres com pesos VBP (médio 2018–2022)
5. Aplicar Denton-Cholette contra o VAB agropecuário anual das Contas Regionais

**Nota sobre o Censo 2017**: não publicou tabela equivalente de época de colheita. Os coeficientes
do Censo 2006 permanecem como referência — refletem o calendário agroclimático de Roraima, que
é relativamente estável.

**Fontes SIDRA — lavouras:**

| Fonte | Tabela SIDRA | Classificação | Observação |
|---|---|---|---|
| PAM (todas as lavouras, temp. + perm.) | Tab. 5457 | c782 | Uma única consulta cobre todas as culturas |
| LSPA (projeção anual, dezembro) | Tab. 6588 | c48 | Período no formato texto "dezembro AAAA" |
| VBP por cultura (pesos Laspeyres) | Tab. 5457 | c782, v215 | Mesmo endpoint da PAM |

**Nota sobre Tab. 5457**: a classificação c782 ("Produto das lavouras temporárias e permanentes")
cobre lavouras temporárias e permanentes numa única consulta — elimina a necessidade de consultar
a Tab. 5558 (lavouras permanentes) separadamente.

**Nota sobre LSPA multi-safra**: feijão (3 safras) e milho (2 safras) na Tab. 6588 retornam
linhas separadas por safra. O script agrega por ano antes de usar os valores.

**Lavouras cobertas e cobertura de VBP:**

| Cultura | SIDRA PAM/LSPA | Cobertura do VBP total de RR |
|---|---|---|
| Soja | Tab. 5457 / 6588 | ~48% |
| Milho | Tab. 5457 / 6588 | ~11% |
| Arroz | Tab. 5457 / 6588 | ~11% |
| Banana | Tab. 5457 / 6588 | ~10% |
| Mandioca | Tab. 5457 / 6588 | ~5% |
| Laranja | Tab. 5457 / 6588 | ~2% |
| Feijão | Tab. 5457 / 6588 | ~2% |
| Cana-de-açúcar | Tab. 5457 / 6588 | ~1% |
| Tomate | Tab. 5457 / 6588 | <1% |
| Cacau | Tab. 5457 / 6588 | <1% |
| **Total coberto** | | **~90,4% do VBP de lavouras** |

#### 1b. Pecuária — disponibilidade verificada para RR

| Proxy | Fonte | SIDRA | Frequência | Status RR |
|---|---|---|---|---|
| Abate de animais (bovinos, suínos, aves) | IBGE Abate | Tab. 1092 | Trimestral | **Disponível** (290 obs.) |
| Produção de ovos de galinha | IBGE Ovos | Tab. 915 | Trimestral | **Disponível** (57 obs.) |
| Produção de leite | IBGE Leite | Tab. 74 | Trimestral | **Indisponível para RR** — excluída |
| VBP por produto animal (pesos Laspeyres) | PPM | Tab. 74, v215 | Anual | **Disponível** |

**Nota sobre pesos pecuários**: o VBP por produto animal vem da Tab. 74 v215 (valor da produção
animal). A Tab. 3939 (PPM efetivo de rebanhos) não contém a variável de valor necessária para
ponderação.

**Estrutura de pesos lavouras × pecuária** (VBP médio 2018–2022):
- Lavouras: **93,0%**
- Pecuária: **7,0%** (abate + ovos; leite excluído por falta de série para RR)

---

### 2. Administração Pública (46,21% do VAB) ★ setor mais importante

| Proxy | Fonte | API / Endpoint | Frequência | Status |
|---|---|---|---|---|
| Folha estadual — pessoal ativo (elemento 31) | SICONFI/STN — RREO Anexo 06 | `apidatalake.tesouro.gov.br/ords/siconfi/tt/rreo` | Bimestral acumulado | **Disponível** |
| Folha municipal — pessoal ativo (15 municípios) | SICONFI/STN — RREO Anexo 06 | Mesmo endpoint, id_ente = cod IBGE município | Bimestral acumulado | **Disponível** |
| Folha federal (SIAPE) | Portal da Transparência | `/remuneracao-servidores-ativos` | Mensal | **Indisponível via API** (HTTP 403) |

**Justificativa metodológica (por que folha de pessoal > PNADC):**
O IBGE mensura o produto de Administração Pública nas Contas Regionais pela **abordagem de custo**
(non-market services): VAB ≈ remuneração dos empregados ativos + consumo intermediário + consumo de
capital fixo. O componente dominante é a folha de pessoal ativo. A folha é, portanto, **a mesma
variável que o IBGE usa como insumo de cálculo** — não um proxy, mas o próprio dado de base.

**Escopo do elemento 31 (pessoal ativo):**
O RREO Anexo 06 registra despesas com pessoal e encargos sociais. O alinhamento com a metodologia
do IBGE exige usar apenas o pessoal ativo (elemento 31) — aposentados e pensionistas são
*transferências*, não remuneração de fator de produção, e não entram no VAB de AAPP nas Contas
Nacionais. A conta utilizada no SICONFI é `RREO6PessoalEEncargosSociais`, coluna "DESPESAS
LIQUIDADAS" (valor acumulado do bimestre).

**Procedimento de conversão bimestral → trimestral:**
O RREO é publicado em bimestres acumulados (bimestre 1 = jan+fev acumulado, bimestre 2 = jan+abr
acumulado, etc.). O processo de conversão é:
1. Diferença entre bimestres consecutivos → valor incremental por bimestre
2. Distribuição uniforme dos 2 meses do bimestre → valor mensal estimado
3. Agregação por trimestre (3 meses) → valor trimestral

**Situação do SIAPE (folha federal):**
O endpoint `/remuneracao-servidores-ativos` do Portal da Transparência retorna HTTP 403 para o
cadastro padrão da API — independentemente do header ou parâmetros utilizados. O componente
federal está, contudo, implicitamente incluído no índice via Denton-Cholette: o benchmark anual
utilizado (VAB AAPP das Contas Regionais IBGE) já engloba o setor público federal. O perfil
trimestral é derivado de estado + municípios e calibrado para o total correto pelo Denton.
Alternativa futura: download manual dos arquivos `.zip` mensais do portal, com filtro por
`uf_exercicio = 'RR'`.

**Deflação**: IPCA nacional (SIDRA tab. 1737, v2266 — variação mensal) aplicado à folha nominal →
índice encadeado de preços, base jan/2020 = 1 → série de volume.

**Resultado da implementação**: validação perfeita contra Contas Regionais (2021–2023):

| Ano | Variação do índice | VAB AAPP IBGE |
|---|---|---|
| 2021 | +9,7% | +9,7% ✓ |
| 2022 | +25,6% | +25,6% ✓ |
| 2023 | +18,0% | +18,0% ✓ |

Série de saída: `data/output/indice_adm_publica.csv`, 16 observações (2020T1–2023T4).

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
| Adm., defesa, educação e saúde públicas | 46,21% | 10.629 | Alta (folha estadual + municipal via SICONFI; federal implícito via Denton) | **2ª fase** ✅ |
| Comércio e reparação de veículos | 12,25% | 2.817 | Média-alta (ICMS + CAGED + energia comercial) | 4ª fase |
| Agropecuária | 8,87% | 2.040 | Alta (PAM/LSPA + Censo 2006 + abate + ovos) | **1ª fase** ✅ |
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

### Fase 1 — Agropecuária ✅ Concluída

**Script**: `R/01_agropecuaria.R`
**Saídas**: `data/output/indice_agropecuaria.csv` (56 obs., 2010T1–2023T4)

**Etapa 1.0 — Análise de cobertura** ✅
- PAM via `sidrar` Tab. 5457 (c782) — cobre todas as lavouras temp. e perm. numa única consulta
- Cobertura calculada: **90,4% do VBP total de lavouras** de RR coberto pelas 10 culturas
- Soja (48%) domina; os demais em ordem: milho, arroz, banana, mandioca, laranja, feijão
- Arquivo: `data/processed/cobertura_lspa_pam.csv`

**Etapa 1.1 — Estrutura sazonal** ✅
- Censo Agropecuário 2006 — única publicação com tabela de época de colheita por cultura e estado
- Censo 2017 não publicou tabela equivalente (confirmado)
- Matriz 10 × 12 construída; cada linha soma 1,0 por cultura
- Arquivo: `data/processed/coef_sazonais_colheita.csv`

**Etapa 1.2 — Série de lavouras** ✅
- PAM: Tab. 5457, c782 → cobre RR até 2024
- LSPA: Tab. 6588, c48, filtrar `grepl("^dezembro", mes_txt)` → provisório para 2025
- Feijão (3 safras) e milho (2 safras) na LSPA: agregar por ano antes de usar
- Índice de Laspeyres, pesos VBP PAM médio 2018–2022
- Arquivo: `data/processed/serie_lavouras_trimestral.csv`

**Etapa 1.3 — Pecuária** ✅
- Abate (Tab. 1092): disponível para RR, trimestral — incluído
- Ovos (Tab. 915): disponível para RR, trimestral — incluído
- Leite (Tab. 74, trimestral): **sem cobertura para RR** — excluído
- Pesos VBP: Tab. 74 v215 (valor da produção animal)
- Resultado: lavouras 93%, pecuária 7% no índice agropecuário total
- Arquivo: `data/processed/serie_pecuaria_trimestral.csv`

**Etapa 1.4 — Denton-Cholette** ✅
- `tempdisagg::td(benchmark ~ 0 + indicador, conversion = "mean")` — fórmula sem intercepto obrigatória
- `conversion = "mean"`: a média dos 4 trimestres deve igualar o benchmark anual (índice, não soma)
- Validação: variações anuais coincidem com Contas Regionais em todos os 13 anos (2011–2023)

---

### Fase 2 — Administração Pública ✅ Concluída

**Script**: `R/02_adm_publica.R`
**Saídas**: `data/output/indice_adm_publica.csv` (16 obs., 2020T1–2023T4)

**Etapa 2.1 — Folha federal (SIAPE)** — indisponível
- API `portaldatransparencia.gov.br/api-de-dados/remuneracao-servidores-ativos`: retorna HTTP 403
  para o cadastro padrão da API, independentemente do token ou parâmetros
- Componente federal está implicitamente incluído via Denton (ver decisão metodológica na seção 2)

**Etapa 2.2 — Folha estadual** ✅
- SICONFI: `GET apidatalake.tesouro.gov.br/ords/siconfi/tt/rreo`
- Parâmetros: `an_exercicio`, `nr_periodo` (bimestre 1–6), `no_anexo="RREO-Anexo 06"`, `id_ente=14`
- Conta: `cod_conta = "RREO6PessoalEEncargosSociais"`, `coluna = "DESPESAS LIQUIDADAS"`
- Cobertura: 2020–2026T1 (37 bimestres)
- Arquivo: `data/raw/folha_estadual_rr_mensal.csv`

**Etapa 2.3 — Folha municipal** ✅
- Mesmo endpoint SICONFI, `id_ente` = cod IBGE de cada município (15 municípios de RR)
- Cobertura: 30–37 bimestres por município (variação por data de início dos relatórios no SICONFI)
- Arquivo: `data/raw/folha_municipal_rr.csv`

**Etapa 2.4 — Volume e benchmarking** ✅
- Deflação: IPCA (SIDRA Tab. 1737 v2266), índice encadeado base jan/2020 = 1
- Denton-Cholette: 2020–2023 (4 anos, 16 trimestres)
- Validação perfeita: 2021 +9,7% / 2022 +25,6% / 2023 +18,0%

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
   é substituído. A distribuição intra-anual é feita da mesma forma: coeficientes do Censo 2006.
2. **LSPA não é fluxo mensal**: a LSPA publica revisões mensais da projeção de produção anual —
   não a produção mês a mês. A desagregação mensal é sempre derivada dos coeficientes do Censo.
3. **Cobertura das culturas no índice agropecuário**: **90,4%** do VBP total de lavouras de
   Roraima (calculado via PAM, média 2018–2022). Soja representa 48% do VBP.
4. **Leite excluído da pecuária**: a pesquisa de produção de leite (IBGE, Tab. 74) não tem
   cobertura trimestral para Roraima. O índice pecuário cobre abate (Tab. 1092) e ovos (Tab. 915).
5. **Pesos lavouras × pecuária**: 93% e 7% respectivamente, com base no VBP médio 2018–2022.
   Leite excluído não distorce — seu peso seria incorporado via ponderação Laspeyres com zero.
6. **Denton-Cholette — fórmula sem intercepto obrigatória**: `td(bench ~ 0 + indicador)`. A
   fórmula com intercepto (`~ indicador`) cria matriz RHS que o algoritmo Denton rejeita. O
   parâmetro `conversion = "mean"` é obrigatório para índices (a média dos 4 trimestres deve
   igualar o benchmark anual, não a soma).
7. **Elemento 31 (pessoal ativo) para AAPP**: alinhado com a metodologia do IBGE — aposentados
   e pensionistas são transferências, não remuneração de fator, e não integram o VAB de AAPP nas
   Contas Nacionais. O SICONFI (RREO Anexo 06) é a fonte oficial para estado e municípios.
8. **SIAPE indisponível via API**: o endpoint `/remuneracao-servidores-ativos` do Portal da
   Transparência retorna HTTP 403. O componente federal está implicitamente incluído via Denton-Cholette:
   o benchmark IBGE engloba todo o VAB de AAPP. O perfil trimestral de estado + municípios é
   calibrado para o total correto (inclusive federal).
9. **RREO bimestral acumulado → trimestral**: diferença entre bimestres consecutivos → valor
   incremental; distribuição uniforme em 2 meses; agregação por trimestre.
10. **Ausência de PIM-PF**: compensada por CAGED + ICMS industrial + energia industrial; peso < 3%.
11. **Ausência de IPCA estadual**: IPCA nacional usado para deflacionar séries nominais.
12. **Início em 2020**: descontinuidade do CAGED inviabiliza séries anteriores baseadas em emprego.
13. **ICMS como proxy de volume**: requer deflação e monitoramento de mudanças legislativas.
14. **Diesel para transportes**: proxy de frete rodoviário; não duplicado em agropecuária/construção.
15. **Benchmarking Denton**: assegura consistência anual com IBGE.
16. **Pesos anuais**: revisados conforme publicação das Contas Regionais (tipicamente 2 anos de defasagem).

---

## Validação

- Variação anual do índice vs. crescimento do PIB estadual IBGE (Contas Regionais)
- Perfil de ciclo vs. IBC-BR / IBCR Norte do Banco Central
- Correlação com arrecadação tributária total de RR
- Comportamento em 2020 (COVID): queda comparável a estados vizinhos
- Consistência interna: Fase 2 (AAPP) deve reproduzir bem o benchmark anual → teste da metodologia Denton
