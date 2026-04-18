# Correção metodológica: ancoragem Denton ao VAB real + VAB nominal trimestral

## Contexto

O indicador atual ancora todos os Denton-Cholette ao VAB **nominal** (preços correntes) das Contas
Regionais IBGE (Tabela 5), mas as proxies utilizadas são **indicadores de volume** (emprego, energia,
passageiros, etc.). Isso cria uma inconsistência fundamental: o ajuste Denton força séries de volume
a seguir a trajetória nominal, que inclui inflação setorial.

**Magnitude do problema**: Em 2021 (IPCA ~10,1%), a série atual superestima o crescimento real em
~8-10 pp; em 2022 (IPCA ~5,8%) em ~5 pp. As taxas de crescimento anual atuais (+12,3% em 2021,
+17,2% em 2022, +20,3% em 2023) são predominantemente nominais — contrário ao objetivo do projeto.

**O IBGE publica**, nas Contas Regionais (mesmo FTP, mesmo ano), dois dados ainda não baixados:
- **Tabela 6**: Índice encadeado de volume (ano anterior = 100), por atividade e UF
- **Tabela 7**: Deflator implícito (ano anterior = 100), por atividade e UF

URL pattern: `https://ftp.ibge.gov.br/Contas_Regionais/2023/xls/tabelaN.zip`

---

## Melhor estratégia: Ponto 1 — Ancoragem ao VAB real (CRÍTICO)

### O que fazer

Substituir o benchmark do Denton-Cholette: em vez de usar `vab_mi` (VAB nominal, Tabela 5),
usar o **índice de volume encadeado** da Tabela 6 rebaseado para 2020 = 100.

### Por que essa é a estratégia correta

- Alinhamento conceitual: proxies de volume (emprego, energia, passageiros) → benchmark de volume
- O resultado final será um **índice de atividade real** (série encadeada a preços de 2020)
- Equivale metodologicamente ao que o IBGE usa para calcular o PIB trimestral a preços constantes
- A Tabela 6 já está calculada pelo IBGE com deflação implícita adequada por atividade —
  muito superior a deflacionar o VAB nominal com IPCA agregado (que seria nossa única alternativa)

### Como processar a Tabela 6

A Tabela 6 dá o índice encadeado **ano t / ano t-1 = 100** (ou seja, taxas de crescimento em forma
de índice base ano anterior). Para converter a base fixa 2020 = 100:

```
vol_2020 = 100 (referência)
vol_2021 = vol_2020 × (Tab6_2021 / 100)
vol_2022 = vol_2021 × (Tab6_2022 / 100)
vol_2023 = vol_2022 × (Tab6_2023 / 100)
# Para anos anteriores a 2020:
vol_2019 = vol_2020 / (Tab6_2020 / 100)
vol_2018 = vol_2019 / (Tab6_2019 / 100)
# etc.
```

Isso produz uma série `vab_volume_rebased` para cada atividade e UF, base 2020 = 100.

### Extrapolação 2024–2025

A Tabela 6 cobre até 2023 (última edição das Contas Regionais). Para 2024 e 2025, mantemos a
mesma lógica atual de extrapolação geométrica — mas aplicada ao volume, não ao nominal. A taxa
de tendência usada deve ser derivada dos últimos 3 anos do volume (2021–2023), não do nominal.

### Escopo da mudança nos scripts

**11 chamadas Denton** precisam mudar — todas substituem `vab_mi` por `vab_volume_rebased`:

| Script | Chamadas | Setores |
|---|---|---|
| `R/01_agropecuaria.R` | 1 | Agropecuária |
| `R/02_adm_publica.R` | 1 | AAPP |
| `R/03_industria.R` | 3 | Indústria transf. + construção + SIUP |
| `R/04_servicos.R` | 7 | Comércio, transportes, info/com, financeiro, imob., outros, turismo |
| `R/05_agregacao.R` | 1 (indireto) | Índice geral (agrega os setoriais) |

A estrutura do Denton (`td()` do pacote `tempdisagg`) não muda — apenas o vetor `y` (benchmark
anual) muda de `vab_mi` para `vab_volume_rebased`.

---

## Melhor estratégia: Ponto 2 — VAB nominal trimestral (SECUNDÁRIO)

### O que é e para que serve

Produto derivado: **VAB nominal trimestral** = índice real trimestral × deflator implícito trimestral.
Não corrige o indicador principal (que deve ser real), mas pode ser publicado como série complementar
para análises de arrecadação, comparação com PIB nominal, etc.

### Como construir o deflator trimestral

1. Baixar a Tabela 7 (deflator implícito anual, base ano anterior = 100)
2. Rebasear para base fixa 2020 = 100 (mesma lógica da Tabela 6)
3. Usar IPCA mensal (já disponível em `data/processed/`) como indicador trimestral
4. Aplicar **Denton-Cholette** do deflator anual com IPCA como proxy → deflator trimestral
5. VAB nominal trimestral = `índice_real_trimestral × deflator_implícito_trimestral / 100`

### Prioridade

**Implementar após** o Ponto 1 estar concluído e validado. Não é bloqueante para o indicador
principal. Pode ser incluído como coluna adicional no Excel final (tab "Componentes").

---

## Problemas criados para a etapa atual

### 1. Todos os outputs precisam ser regerados

A mudança de benchmark no Denton altera todas as séries trimestrais. Impacto em cascata:

| Arquivo | Impacto |
|---|---|
| `data/output/indice_*.csv` (7 arquivos setoriais) | Regerados pelos scripts 01–04 |
| `data/output/indice_geral_rr.csv` | Regerado pelo 05_agregacao.R |
| `data/output/indice_geral_rr_sa.csv` | Regerado pelo 05c_ajuste_sazonal.R |
| `data/output/fatores_sazonais.csv` | Regerado pelo 05c |
| `data/output/validacao_relatorio.csv` | Regerado pelo 05d |
| `data/output/IAET_RR_series.xlsx` | Regerado pelo 05e |
| `data/output/sensibilidade/` | Regerado pelo 05b (opcional) |

### 2. Formato da Tabela 6 exige pré-processamento adicional

A Tabela 6 virá em formato Excel similar à Tabela 5, mas com estrutura de taxa (não nível).
Será necessário:
- Parsear a aba correta (provavelmente "BR e GR" ou equivalente para UF)
- Filtrar para Roraima e para as atividades que correspondem aos setores do projeto
- Aplicar o encadeamento para base fixa 2020 = 100
- Fazer o join com a estrutura atual de `contas_regionais_RR_serie.csv`

Esse pré-processamento vai em `R/00_dados_referencia.R`, como nova função, antes do join com os
scripts setoriais.

### 3. Atividades no IBGE × setores do projeto

A Tabela 6 tem atividades no nível de agregação das Contas Regionais (não desagrega tanto quanto
o CAGED). Precisamos mapear:

| Setor do projeto | Atividade Tabela 6 (provável) |
|---|---|
| Agropecuária | "Agropecuária" |
| AAPP + saúde/educ. pública | "Administração, defesa, educação e saúde públicas e seguridade social" |
| Indústria de transformação | "Indústrias de transformação" |
| Construção | "Construção" |
| SIUP | "Eletricidade e gás, água, esgoto e gestão de resíduos" |
| Comércio | "Comércio e reparação de veículos automotores e motocicletas" |
| Transportes + outros | "Transporte, armazenagem e correio" + outros |
| Financeiro | "Atividades financeiras, de seguros e serviços relacionados" |
| Imobiliárias | "Atividades imobiliárias" |
| Informação e comunicação | "Informação e comunicação" |
| Outros serviços | "Outras atividades de serviços" + "Alojamento e alimentação" + outros |

O mapeamento exato depende da estrutura real da Tabela 6 para RR — verificar ao baixar.

### 4. Cobertura temporal

A Tabela 6 provavelmente cobre o mesmo período da Tabela 5 (2002–2023 na edição 2023).
O rebaseamento para 2020 = 100 funcionará corretamente desde que 2020 esteja na série.

### 5. Taxas de crescimento esperadas após correção

Com ancoragem ao volume real, espera-se que as taxas anuais caiam substancialmente:
- 2021: de ~+12% para ~+3 a +6% (crescimento real, sem inflação)
- 2022: de ~+17% para ~+4 a +8%
- 2023: de ~+20% para ~+3 a +7%

Isso é metodologicamente correto — o índice passará a comparar com o IBCR de forma mais coerente.

---

## Sequência de implementação recomendada

### Etapa A — Baixar e processar Tabelas 6 e 7 (`R/00_dados_referencia.R`)
1. Adicionar download de `tabela6.zip` e `tabela7.zip` ao script
2. Implementar função `processar_tabela_volume()`: parsear Excel → filtrar RR → encadear → base 2020
3. Salvar `data/processed/contas_regionais_RR_volume.csv` (com `vab_volume_rebased` por atividade/ano)
4. Salvar `data/processed/contas_regionais_RR_deflator.csv` (com `deflator_rebased` — para Ponto 2)

### Etapa B — Atualizar join nos scripts setoriais (01–04)
- Cada script que faz Denton busca o benchmark de `contas_regionais_RR_serie.csv`
- Adicionar leitura de `contas_regionais_RR_volume.csv` e substituir `vab_mi` por `vab_volume_rebased`
- Verificar mapeamento de atividade por setor

### Etapa C — Rerrodar pipeline completo (01 → 02 → 03 → 04 → 05)
- Verificar saídas setoriais: taxas anuais devem agora refletir crescimento real
- Rerrodar 05_agregacao.R, 05c, 05d, 05e

### Etapa D — Validação (opcional mas recomendado)
- Comparar novas taxas com as antigas: diferença deve corresponder à inflação setorial
- Verificar se correlação com IBCR Norte melhora (esperado, pois IBCR é índice de volume)

### Etapa E — Ponto 2 (VAB nominal trimestral) — após A-D concluídos
- Implementar Denton do deflator com IPCA como proxy
- Calcular VAB nominal trimestral como produto
- Adicionar ao Excel exportado

---

## Atenção: agregação em `05_agregacao.R` — não pode continuar aditiva

O script de agregação tem **duas camadas** que são afetadas de formas distintas pela reforma:

### Camada 1 — Média ponderada setorial (ETAPA 5.1.3) — sobrevive à reforma ✓

```r
indice_composto_raw <- apply(indices_matrix, 1, function(row) {
  sum(row[ok] * w[ok]) / sum(w[ok])
})
```

Esta fórmula já é uma **média ponderada de Laspeyres** por linha (trimestre), com pesos
fixos do ano base. É metodologicamente correta para agregar índices de volume. Não precisa
mudar estruturalmente — apenas os valores de entrada (sectoriais) mudarão de escala.

### Camada 2 — Benchmark do segundo Denton (ETAPA 5.1.4) — DEVE MUDAR ✗

```r
vab_anual <- cr |> group_by(ano) |> summarise(vab_total = sum(vab_mi)) |> ...
bench_cr  <- vab_anual$vab_total / base_vab_2020 * 100
```

**Este é o problema**: o benchmark é construído somando VAB nominal (`vab_mi`) e
normalizando para 2020=100. **Isso não produz um índice de volume** — é uma taxa de
crescimento nominal disfarçada de índice.

Após a reforma, o benchmark do segundo Denton deve ser o **índice de volume total da
economia de RR da Tabela 6**, que o IBGE já calcula corretamente com deflação por atividade.
Não se deriva um índice de volume somando valores nominais.

**Correção**: ler `vab_volume_rebased` total de `contas_regionais_RR_volume.csv` (ou somar
ponderadamente os `vab_volume_rebased` setoriais com os pesos VAB 2020).

### Camada 3 — Re-normalização dos setoriais na saída (ETAPA 5.1.7) — verificar

```r
indice_agropecuaria = round(agro_vals / mean(agro_vals[grid_completo$ano == 2020]) * 100, 6)
```

Após a reforma, os scripts setoriais já entregam índices em base 2020=100. Esta
re-normalização deve ser verificada — se os setoriais já estiverem em base correta, ela
é idempotente (não causa dano, mas é redundante). Se houver discrepância de escala, corrigir.

### Pesos do ano base

`pesos_blocos` usa participação de 2023. Para um índice de Laspeyres puro, os pesos devem
ser do **ano base 2020**. Verificar se as participações de 2020 e 2023 diferem
significativamente — se sim, trocar para 2020.

---

## Arquivos críticos a modificar

- [`R/00_dados_referencia.R`](R/00_dados_referencia.R) — adicionar download e processamento das Tabelas 6 e 7
- [`R/01_agropecuaria.R`](R/01_agropecuaria.R) — trocar benchmark no Denton
- [`R/02_adm_publica.R`](R/02_adm_publica.R) — trocar benchmark no Denton
- [`R/03_industria.R`](R/03_industria.R) — trocar benchmark nas 3 chamadas Denton
- [`R/04_servicos.R`](R/04_servicos.R) — trocar benchmark nas 7 chamadas Denton
- [`R/05_agregacao.R`](R/05_agregacao.R) — verificar se agrega corretamente após mudança

## Verificação

Após rerrodar o pipeline:
1. Abrir `data/output/indice_geral_rr.csv` — taxas de crescimento anual devem estar na faixa de crescimento real (~3-8% ao ano, não 12-20%)
2. Comparar com Tabela 6 do IBGE para RR: média anual dos trimestres deve coincidir com o índice anual encadeado (tolerância < 0,5%)
3. Verificar que as séries setoriais somam corretamente para o índice geral (pesos VAB nominal de 2020 como referência)
