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

> **Decisão metodológica (reforma de 2026-04-13):** O benchmark anual do Denton-Cholette utiliza
> o **índice encadeado de volume** das Contas Regionais (arquivo `Especiais_2002_2023_xls.zip`,
> `tab05.xls`), e não o VAB nominal (Tabela 5 / `Conta_da_Producao_2002_2023_xls.zip`).
> Motivação: as proxies trimestrais são indicadores de volume (emprego, energia, passageiros, etc.)
> — ancorá-las ao VAB nominal introduzia inflação setorial no índice real, gerando crescimentos
> artificialmente elevados (+20% em 2023 vs. +4% real). Com a ancoragem ao volume, as taxas anuais
> passaram a refletir crescimento real: 2021 +8,2%, 2022 +10,9%, 2023 +4,3%.
> Referência completa: `plano_reforma_indicador_real.md` e `checklist_reforma.md`.

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
2. Aplicar **coeficientes mensais de colheita** como pesos de distribuição ao longo dos 12 meses
   → produção mensal estimada por cultura
3. Agregar meses em trimestres
4. Calcular índice de Laspeyres com pesos VBP (médio 2018–2022)
5. Aplicar Denton-Cholette contra o VAB agropecuário anual das Contas Regionais

**Fonte dos coeficientes de colheita — três versões disponíveis (parâmetro `versao_calendario`):**

| Versão | Fonte | Arquivo | Status |
|---|---|---|---|
| A — **SEADI-RR** (produção) | Calendário Agrícola oficial da Secretaria de Agricultura do Estado de RR | `data/referencias/calendario_colheita_seadi_rr.csv` | Ativo |
| B — Censo 2006 (área) | Censo Agropecuário 2006, tabelas de época de colheita por UF, ponderação por área colhida | `data/referencias/calendario_colheita_censo2006_area_rr.csv` | Candidato Fase 5.2 |
| C — Censo 2006 (estabelecimentos) | Idem, ponderação por número de estabelecimentos | `data/referencias/calendario_colheita_censo2006_estabelecimentos_rr.csv` | Candidato Fase 5.2 |

A **versão A (SEADI-RR)** é adotada como padrão de produção por ser mais aderente ao ciclo
atual das culturas em Roraima. As versões B e C, derivadas das tabelas de época principal de
colheita do Censo Agropecuário 2006, são mantidas para o teste de sensibilidade da Fase 5.2.
Para culturas sem mensalização oficial no Censo (banana, cacau, laranja, cana, tomate), as
versões B/C usam distribuição uniforme de 1/12.

**Nota sobre o Censo 2017**: não publicou tabela equivalente de época de colheita. As versões
B/C do Censo 2006 são mantidas como referência metodológica secundária para o teste A/B.

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
| Folha federal (SIAPE) | Portal da Transparência | Arquivos mensais `.zip` processados localmente | Mensal | **Obrigatória em produção** |

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
O endpoint `/remuneracao-servidores-ativos` do Portal da Transparência não sustenta o fluxo
automatizado direto do projeto. A solução operacional adotada foi o processamento local dos
arquivos mensais `.zip` do portal, com filtro para servidores federais vinculados a Roraima.
Na versão atual do projeto, o componente federal é **obrigatório**: sem SIAPE observado, o script
`R/02_adm_publica.R` interrompe a execução com erro explícito.

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

### 3. Construção Civil (4,89% do VAB)

| Proxy | Fonte | Frequência | Tipo de medida | Qualidade |
|---|---|---|---|---|
| Estoque acumulado CAGED F (construção) | FTP MTE — CAGEDMOV {yearmonth}.7z | Mensal | Insumo (emprego) | Média-alta |
| Vendas de cimento (RR) | SNIC — download manual, snic.org.br | Mensal | Volume físico | Forte (se disponível) |

**Fonte CAGED — detalhamento técnico:**
O Novo CAGED (2020+) não está disponível em SIDRA nem via API com filtros por UF. O script
baixa o arquivo nacional `CAGEDMOV{yearmonth}.7z` do FTP `ftp.mtps.gov.br/pdet/microdados/NOVO
CAGED/{ano}/{yearmonth}/`, extrai com 7-Zip, filtra `uf == 14` (Roraima) e agrega o saldo
(`saldomovimentação`) por seção CNAE. O arquivo grande é apagado após processamento; o
agregado RR (<1 KB/mês) é mantido em `data/raw/caged/caged_rr_{yearmonth}.csv`. A coleta
cobre todas as seções CNAE — útil também para Fase 4 (Comércio, Transportes, Outros Serviços)
sem novo download. 1ª execução: ~2,5 GB de download total (72 meses × 35 MB); idempotente.

**CAGED como estoque acumulado:**
O CAGED publica fluxo mensal (admissões − desligamentos = saldo). Para construir uma série
de nível usável como indicador Denton, acumula-se o saldo a partir de base 1000 (Jan 2020).
O nível inicial é arbitrário — o Denton-Cholette calibra o nível correto ao benchmark anual
do IBGE. A série resultante capta a trajetória relativa do emprego formal na construção.

**SNIC cimento — indisponível via API:**
O snic.org.br não responde a requisições automatizadas (timeout). O dado requer download manual
da planilha mensal e salvamento em `data/raw/snic_cimento_rr.csv` (colunas: ano, mes, vendas_ton).
Se o arquivo estiver presente, o índice de Construção usa composição CAGED F 60% + SNIC 40%.
Sem o arquivo, Construção usa apenas CAGED F (metodologicamente válido).

**ICMS de materiais de construção:** excluído — SEFAZ-RR não publica ICMS desagregado por seção
CNAE de forma automatizável. Mantido como opção futura caso a SEFAZ-RR disponibilize dados.

**Agregação trimestral:** média do estoque mensal (variável de nível, não fluxo).
**Benchmark:** VAB Construção das Contas Regionais IBGE (Tab. 5.6).

---

### 4. SIUP — Eletricidade, gás, água, esgoto e resíduos (5,40% do VAB)

| Proxy | Fonte | Frequência | Tipo de medida |
|---|---|---|---|
| Consumo de energia elétrica — todas as classes (RR) | ANEEL SAMP via API CKAN | Mensal | Volume (kWh) |

**Fonte ANEEL SAMP — detalhamento técnico:**
O SAMP (Sistema de Acompanhamento do Mercado de Energia Elétrica) é publicado pela ANEEL no
portal de dados abertos. O CSV anual tem ~200 MB (todo o Brasil). A estratégia adotada é a
**API CKAN com filtros pré-aplicados** — retorna apenas ~800 registros/ano para RR, sem download
do arquivo completo.

- Dataset ID: `3e153db4-a503-4093-88be-75d31b002dcf`
- Endpoint: `dadosabertos.aneel.gov.br/api/3/action/datastore_search`
- Filtros aplicados na API: `SigAgenteDistribuidora = "BOA VISTA"`,
  `NomTipoMercado = "Sistema Isolado - Regular"`,
  `DscDetalheMercado = "Energia TE (kWh)"`
- Campos coletados: `DatCompetencia` (formato YYYY-MM-01), `DscClasseConsumoMercado`, `VlrMercado`
- Separador CSV original: `;` — decimal: `,` (formato brasileiro)
- Roraima opera em **sistema isolado** — separado do SIN (Sistema Interligado Nacional)
- Distribuidor de RR: **"BOA VISTA"** (Roraima Energia S.A.)
- Resource IDs por ano: 2020=`29f9fec9`, 2021=`84906f77`, 2022=`7e097631`, 2023=`b9ad890b`,
  2024=`ff80dd21`, 2025=`6fac5605`, 2026=`56f1c242`

**Classes disponíveis para RR:** Residencial, Comercial, Industrial, Poder público, Rural,
Serviço público, Iluminação pública, Consumo próprio. Cada classe pode ter múltiplas
sub-tarifas por mês (ex: Branca, Convencional, Verde) — o script soma todas por mês e classe.

**Proxy do SIUP:** soma mensal de energia TE de todas as classes (kWh total distribuído).
Justificativa: o VAB do SIUP nas Contas Nacionais mede o valor adicionado pelos distribuidores,
proporcional ao volume distribuído. Total kWh é o proxy de volume natural.

**Reaproveitamento na Fase 4:**
- Classe `"Comercial"` → proxy de Comércio (seção 6)
- Classe `"Industrial"` → proxy de Ind. de Transformação (seção 5)

**Agregação trimestral:** soma dos três meses (fluxo).
**Benchmark:** VAB SIUP das Contas Regionais IBGE (Tab. 5.5).
Classificação de qualidade: **forte**.

---

### 5. Indústria de Transformação (1,31% do VAB)

| Proxy | Fonte | Frequência | Tipo de medida | Peso no índice | Qualidade |
|---|---|---|---|---|---|
| Energia industrial (kWh) | ANEEL SAMP — classe "Industrial" | Mensal | Volume físico | 70% | Forte |
| Estoque acumulado CAGED C | FTP MTE — CAGEDMOV | Mensal | Insumo (emprego) | 30% | Aceitável |

**Sem PIM-PF para RR.** O IBGE publica a PIM-PF apenas para estados com ≥ 0,5% da produção
industrial nacional. RR não está incluído. As proxies disponíveis são limitadas, mas o peso de
1,31% no VAB total minimiza o impacto na precisão do índice agregado.

**Proxy composta:** energia industrial ANEEL (70%) + emprego CAGED C (30%).
- Energia industrial = classe `"Industrial"` do ANEEL SAMP (coletada gratuitamente no SIUP)
- Emprego CAGED C = estoque acumulado de saldos mensais (mesma metodologia do CAGED F)
- Ambas normalizadas para base 2020 = 100 antes da combinação por pesos

**ICMS industrial:** excluído — SEFAZ-RR não publica ICMS desagregado por CNAE
de forma automatizável. A disponibilidade futura pode melhorar esta proxy.

**Agregação trimestral:** média dos três meses (proxy de nível).
**Benchmark:** VAB Ind. de Transformação das Contas Regionais IBGE (Tab. 5.4).

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
| SIUP | 5,40% | 1.243 | Alta (ANEEL SAMP por classe — energia TE, kWh) | 3ª fase ✅ |
| Construção | 4,89% | 1.125 | Média-alta (CAGED F acumulado + SNIC condicional) | 3ª fase ✅ |
| Atividades financeiras e seguros | 2,78% | 639 | Média (BCB concessões + depósitos) | 4ª fase |
| Transporte, armazenagem e correio | 1,92% | 441 | Média (ANAC passag./carga + diesel ponderado) | 4ª fase |
| Indústrias de transformação | 1,31% | 301 | Média (energia industrial 70% + CAGED C 30%) | 3ª fase ✅ |
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
- Versão ativa: **Calendário SEADI-RR** — `data/referencias/calendario_colheita_seadi_rr.csv`
- Versões candidatas para teste A/B (Fase 5.2): Censo 2006 área e Censo 2006 estabelecimentos
- Parâmetro `versao_calendario` em `01_agropecuaria.R` controla qual versão é carregada
- Normalização automática de cada linha (rowSums); NA → 0 (meses sem colheita registrada)
- Matriz ativa: 10 culturas × 12 meses; cada linha soma 1,0
- Arquivo com versão ativa: `data/processed/coef_sazonais_colheita.csv`

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

**Etapa 2.1 — Folha federal (SIAPE)** ✅
- Componente processado a partir dos arquivos mensais `.zip` do Portal da Transparência
- Cache operacional: `data/raw/siape_rr_mensal.csv`
- O script falha explicitamente se a base federal não existir

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

### Fase 3 — Indústria composta (SIUP + Construção + Transformação) ✅

**SIUP:**
- Fonte: API CKAN ANEEL SAMP, filtros pré-aplicados (BOA VISTA + Sistema Isolado + Energia TE)
- Proxy: soma mensal de energia TE de todas as classes (kWh total distribuído em RR)
- Arquivo: `data/raw/aneel/aneel_energia_rr.csv`

**Construção:**
- Fonte: CAGED microdata FTP MTE (`CAGEDMOV{yearmonth}.7z`), seção F, UF=14
- Proxy: estoque acumulado (base 1000 + saldos mensais CAGED F)
- SNIC cimento: condicional (download manual — instrução no script)
- Composição se SNIC disponível: CAGED F 60% + SNIC 40%
- Arquivo mensal RR: `data/raw/caged/caged_rr_{yearmonth}.csv`

**Transformação:**
- Fonte: ANEEL SAMP (classe Industrial, reaproveitada do SIUP) + CAGED C FTP MTE
- Proxy: energia industrial 70% + CAGED C 30%
- ICMS industrial: indisponível de forma automatizável

**Índice composto industrial:** pesos das Contas Regionais 2020 (SIUP 5,51 / Const. 4,98 /
Transf. 1,15). Pesos relativos internos calculados no script a partir do VAB 2020.

**Coleta CAGED reutilizável:** o script baixa e agrega TODAS as seções CNAE para RR
— economiza ~2,5 GB de re-download na Fase 4 (Comércio, Transportes, Outros Serviços).

**Tratamento de meses sem movimentação CAGED:** seções com zero admissões e zero demissões
em determinado mês não geram linha no microdado. O script completa o grid mensal com saldo=0
antes de calcular o estoque acumulado, evitando que trimestres com mês "vazio" sejam
descartados pelo filtro de trimestres completos.

**Resultado:**
- `data/output/indice_industria.csv` — 24 trimestres (2020T1–2025T4, base 2020=100)
- Variações anuais do índice composto:

| Ano | Variação |
|---|---|
| 2021 | +10,6% |
| 2022 | +20,6% |
| 2023 | +9,4% |
| 2024 | +17,5% |
| 2025 | +19,2% |

**Nota sobre SIUP:** o VAB do setor nas Contas Regionais é extremamente volátil em RR
(R$799M em 2020 → R$369M em 2022 → R$1.243M em 2023), reflexo das mudanças estruturais
na geração e distribuição de energia do estado (conexão ao SIN, revisão tarifária). A
volatilidade do índice composto em 2023 é fiel ao dado do IBGE — não é artefato do script.
Para 2024–2025 (sem benchmark), o script usa o indicador bruto.

### Fase 4 — Serviços privados (Comércio + Transportes + Outros) ✅

**Script**: `R/04_servicos.R`
**Saída**: `data/output/indice_servicos.csv` (24 obs., 2020T1–2025T4)

**Decisão de implementação (Opção A — sem ICMS):**
ICMS por atividade econômica (SEFAZ-RR) não disponível nesta versão. Comércio calculado
com energia comercial (67%) + CAGED G (33%). Ao obter o ICMS: pesos → energia 40%, ICMS 40%, CAGED 20%.

**Componentes:**
- Comércio: energia comercial ANEEL (67%) + CAGED G (33%) — Denton vs. CR Comércio
- Transportes: ANAC microdados mensais SBBV pax 40% + carga 30% + ANP diesel 30% — Denton vs. CR
  - ANAC: microdados baixados manualmente (74 ZIPs, jan/2020–fev/2026), pasta
    `bases_baixadas_manualmente/microdados_anac_mensal_2020.1_2026.2_basico/`
- Financeiro: BCB concessões de crédito (70%) + BCB Estban depósitos (30%), ambos
  deflacionados pelo IPCA e suavizados (MM3 em concessões) — Denton vs. CR Financeiro
  - BCB Estban: 72 ZIPs baixados manualmente, pasta `bases_baixadas_manualmente/dados_estban_bcb/`
  - BCB SCR concessões: 7 ZIPs baixados manualmente, pasta `bases_baixadas_manualmente/dados_bcb_src_2020_2025/`
  - IPCA: variável SIDRA 2266 = nível do índice (base dez/1993=100); deflator calculado como
    `indice_preco = indice_nivel / indice_nivel[jan/2020]`
- Imobiliário: interpolação linear entre benchmarks CR anuais + extrapolação tendência 2024–2025
- Outros serviços: CAGED I + M+N + P+Q, pesos dinâmicos por estoque de emprego 2020 — Denton
- Informação e comunicação: CAGED J — Denton vs. CR Info/Com
- Extrativas (0,05%): interpolação linear CR (sem proxy específico)
- Composto final: Laspeyres com pesos dos subsetores calculados a partir do VAB nominal de 2020
  (ano-base do índice geral), preservando coerência com a base do sistema

**Resultado:**
- `data/output/indice_servicos.csv` — 24 trimestres (2020T1–2025T4, base 2020=100)
- Variações anuais: 2021 +19,0% / 2022 +7,7% / 2023 +12,0% / 2024 +11,8% / 2025 +10,8%
- Denton âncora exatamente os 4 anos com benchmark CR (2020–2023)

**Nota metodológica sobre pesos internos:**
O bloco de serviços agora usa pesos dos subsetores derivados dinamicamente das Contas Regionais de
2020, alinhando o nível interno do bloco ao mesmo ano-base Laspeyres do índice geral. Os pesos de
composição entre proxies dentro de cada subsetor (por exemplo, 67/33 no Comércio ou 40/30/30 em
Transportes) continuam sendo pesos técnicos, definidos pela qualidade e disponibilidade das fontes,
e não pesos contábeis das Contas Regionais.

### Fase 5 — Agregação, ajuste sazonal e publicação

**Fase 5.1 — Índice geral agregado** ✅

**Script**: `R/05_agregacao.R`
**Saída**: `data/output/indice_geral_rr.csv` (24 obs., 2020T1–2025T4, base 2020=100)

**Pesos setoriais efetivos do índice (Laspeyres, base 2020):**

| Bloco | Peso efetivo 2020 |
|---|---|
| Agropecuária | 6,89% |
| Administração Pública | 45,01% |
| Indústria (SIUP + Const. + Transf.) | 11,63% |
| Serviços Privados | 36,46% |

**Tratamento de AAPP e Agropecuária para 2024–2025:**
Os índices de AAPP e Agropecuária têm benchmark CR apenas até 2023 (CR publicado out/2025).
Para 2024–2025, o script extrapola com tendência geométrica do bieênio 2022–2023:
- Agropecuária: +12,0%/ano (com calendário SEADI-RR)
- AAPP: +20,0%/ano

Atualizar quando CR 2024 for publicado (previsão IBGE: out/2026).

**Ancoragem Denton-Cholette:** benchmark = índice de volume total de RR das Contas Regionais
(série real agregada a partir de `contas_regionais_RR_volume.csv` com pesos nominais de 2020).

**Variações anuais do índice geral (média anual, base 2020=100):**

| Ano | Variação | Tipo |
|---|---|---|
| 2021 | +8,2% | Ancorado (CR) |
| 2022 | +10,9% | Ancorado (CR) |
| 2023 | +4,3% | Ancorado (CR) |
| 2024 | +7,7% | Extrapolado |
| 2025 | +9,2% | Extrapolado |

**Fase 5.2 — Sensibilidade do calendário** ✅  
Script: `R/05b_sensibilidade_calendario.R`. Teste A/B/C executado; as médias anuais permanecem
idênticas por construção do Denton, mas a sazonalidade intra-anual varia muito. A versão
SEADI-RR foi mantida como padrão de produção.

**Fase 5.3 — Ajuste sazonal** ✅  
Script: `R/05c_ajuste_sazonal.R`. X-13ARIMA-SEATS aplicado ao índice geral e aos quatro blocos
setoriais. Saídas: `indice_geral_rr_sa.csv` e `fatores_sazonais.csv`.

**Fase 5.4 — Validação final** ✅  
Script: `R/05d_validacao.R`. Validação contra Contas Regionais, IBC-Br, IBCR Norte,
comportamento na COVID e consistência interna.

**Fase 5.5 — Exportação** ✅  
Script: `R/05e_exportacao.R`. Gera `IAET_RR_series.xlsx` e os CSVs de publicação.

**Fase 5.6 — Dashboard** ✅  
Script: `dashboard/app.R`. Dashboard Shiny implementado, com abas para índice geral,
componentes, VAB nominal, dados e metadados. O app aceita execução pela raiz do projeto ou pela
pasta `dashboard/`, com resolução robusta do diretório `data/output`, e usa apenas fontes locais
no tema para evitar dependência de rede na inicialização. Pendências remanescentes: testes de
responsividade e publicação.

**Fase 5.7 — Nota técnica** ⏳  
Ainda não iniciada. É a principal pendência documental do projeto.

**Fase 5.9 — VAB nominal setorial trimestral** ✅  
Script: `R/05h_vab_nominal_setorial.R`. O projeto passa a gerar a trimestralização do
`VAB nominal` dos quatro blocos analíticos (`Agropecuária`, `AAPP`, `Indústria` e `Serviços`)
para os anos com benchmark das Contas Regionais (`2020–2023`). O procedimento usa:

- benchmark nominal anual por bloco, obtido pela soma das atividades correspondentes nas CR;
- índice anual de volume por bloco, agregado com pesos de 2020 dentro de cada bloco;
- deflator anual por bloco, calculado como `índice nominal / índice real`;
- Denton-Cholette com `conversion = "mean"` para o deflator trimestral, usando IPCA como proxy;
- Denton-Cholette com `conversion = "sum"` para distribuir o `VAB nominal` anual em R$ milhões
  a partir do indicador nominal trimestral (`índice real × deflator trimestral / 100`).

Essa etapa fecha a comparação nominal por bloco com o IBGE sem depender apenas do
`VAB nominal total`.

**Ajuste metodológico recente no produto nominal:**  
O `05f_vab_nominal.R` deixou de agregar o deflator total por média ponderada de deflatores
setoriais e passou a usar o deflator implícito direto do `VAB total` das Contas Regionais
(`índice nominal total / índice real total`). Com isso, o `VAB nominal` anual do projeto passou
a fechar exatamente com o benchmark anual do IBGE em `2020–2023`, e o `PIB nominal` do `05g`
passou a herdar esse fechamento nos anos com benchmark.

---

## Estrutura de pastas do projeto

```
PIB Trimestral - Projeto 2026/
├── data/
│   ├── raw/           # downloads brutos (APIs, portais, SEPLAN) — local, não versionado
│   ├── processed/     # séries limpas por setor — local, não versionado
│   ├── output/        # índice final + componentes — local, não versionado
│   └── referencias/   # arquivos de referência versionados (calendários de colheita, etc.)
├── R/
│   ├── utils.R                  # Denton wrapper, encadeamento, deflação
│   ├── run_all.R                # orquestrador do pipeline completo
│   ├── 00_dados_referencia.R    # Contas Regionais (pesos e benchmarks)
│   ├── 01_agropecuaria.R        # Fase 1: lavouras (LSPA/PAM) e pecuária
│   ├── 02_adm_publica.R         # Fase 2: SIAPE + folha estadual e municipal
│   ├── 03_industria.R           # Fase 3: SIUP, Construção, Transformação
│   ├── 04_servicos.R            # Fase 4: Comércio, Transportes, Serviços
│   ├── 05_agregacao.R           # Fase 5.1: índice geral agregado
│   ├── 05b_sensibilidade_calendario.R  # Fase 5.2: teste A/B/C do calendário agrícola
│   ├── 05c_ajuste_sazonal.R     # Fase 5.3: X-13ARIMA-SEATS
│   ├── 05d_validacao.R          # Fase 5.4: validação final
│   ├── 05e_exportacao.R         # Fase 5.5: Excel e CSVs de publicação
│   ├── 05f_vab_nominal.R        # Fase 5.6 complementar: VAB nominal trimestral
│   ├── 05g_pib_nominal.R        # Fase 5.8: PIB nominal trimestral
│   └── 05h_vab_nominal_setorial.R # Fase 5.9: VAB nominal setorial trimestral
├── dashboard/
│   └── app.R
├── notas/
│   └──  # reservado para a futura nota_tecnica.qmd
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
8. **SIAPE obrigatório na produção**: o endpoint `/remuneracao-servidores-ativos` do Portal da
   Transparência não sustenta o fluxo automatizado direto. O projeto usa os arquivos mensais do
   Portal processados localmente e o script de AAPP falha explicitamente se a base federal não existir.
9. **RREO bimestral acumulado → trimestral**: diferença entre bimestres consecutivos → valor
   incremental; distribuição uniforme em 2 meses; agregação por trimestre.
10. **Ausência de PIM-PF**: compensada por CAGED C + energia industrial ANEEL; peso < 2% no total.
11. **Ausência de IPCA estadual**: IPCA nacional usado para deflacionar séries nominais.
12. **Início em 2020**: descontinuidade do CAGED inviabiliza séries anteriores baseadas em emprego.
13. **ICMS como proxy de volume**: requer deflação e monitoramento de mudanças legislativas.
14. **Diesel para transportes**: proxy de frete rodoviário; não duplicado em agropecuária/construção.
15. **Benchmarking Denton**: assegura consistência anual com IBGE.
16. **Pesos anuais**: revisados conforme publicação das Contas Regionais (tipicamente 2 anos de defasagem).
17. **ANEEL SAMP via API CKAN (não CSV completo)**: arquivo CSV anual tem 201 MB (todo o Brasil).
    A API CKAN do portal de dados abertos aceita filtros em `datastore_search` — retorna apenas
    os ~800 registros/ano de BOA VISTA (RR), evitando download pesado. Paginação a cada 500 registros.
18. **CAGED via FTP MTE (microdata nacional)**: Novo CAGED (2020+) não está em SIDRA nem tem API
    com filtro por UF. Script baixa CAGEDMOV {yearmonth}.7z, extrai com 7-Zip local
    (`C:/Program Files/7-Zip/7z.exe`), filtra `uf == 14` com `data.table::fread`, agrega por
    seção CNAE e apaga os arquivos grandes. Todas as seções CNAE são salvas (não só F e C)
    para reaproveitamento na Fase 4 sem re-download.
19. **CAGED como estoque acumulado**: o saldo mensal (admissões − desligamentos) é um fluxo.
    Para uso como indicador Denton (que requer série de nível), acumula-se o saldo a partir de
    base 1000 em Jan 2020. O Denton calibra o nível absoluto; apenas o perfil temporal importa.
20. **SNIC cimento indisponível via API**: snic.org.br não responde a requisições automáticas.
    O script aceita `data/raw/snic_cimento_rr.csv` como insumo de download manual. Se presente:
    Construção = CAGED F 60% + SNIC 40%. Se ausente: Construção = CAGED F 100%.
21. **ICMS excluído do bloco industrial (Fase 3)**: SEFAZ-RR não publica ICMS por seção CNAE
    de forma automatizável. Construção e Transformação usam apenas CAGED + energia. ICMS
    incorporado na Fase 4 (Comércio) onde o total de ICMS (sem disagregação) já é a proxy padrão.
22. **Pesos internos do bloco industrial**: calculados a partir do VAB 2020 das Contas Regionais
    (SIUP 5,51 + Construção 4,98 + Transformação 1,15 = 11,64% do VAB total). Normalizados
    para soma 100% dentro do bloco. O bloco total recebe peso 11,64% no índice agregado (Fase 5).

---

## Validação

- Variação anual do índice vs. crescimento do PIB estadual IBGE (Contas Regionais)
- Perfil de ciclo vs. IBC-BR / IBCR Norte do Banco Central
- Correlação com arrecadação tributária total de RR
- Comportamento em 2020 (COVID): queda comparável a estados vizinhos
- Consistência interna: Fase 2 (AAPP) deve reproduzir bem o benchmark anual → teste da metodologia Denton
