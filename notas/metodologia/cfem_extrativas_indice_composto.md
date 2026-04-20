# CFEM e Extrativas: indice composto exploratorio e versao robusta

Gerado em 2026-04-19 19:28:42 pelo script `R/99_explora_cfem_extrativas.R`.

## O que foi feito

1. Baixada e consolidada a base da CFEM da ANM para Roraima.
2. Agregacao mensal por substancia mineral.
3. Construcao de um indice de quantidade por substancia, sempre comparando cada substancia com sua propria base de 2020.
4. Combinacao das substancias por pesos fixos de valor recolhido medio em 2020-2023.
5. Montagem de uma proxy complementar com CAGED secao B.
6. Otimizacao da combinacao CFEM + CAGED B por grade, minimizando a variancia do ajuste Denton no benchmark anual 2020-2023.
7. Criado um diagnostico de robustez por substancia para isolar bases fisicas muito pequenas e series desproporcionais.
8. Construida uma versao robusta da CFEM para comparacao com a versao exploratoria.

## Formula do indice por substancia

Para cada substancia s e periodo t:

`indice_s,t = quantidade_s,t / media_2020_s * 100`

A quantidade nao e somada entre substancias. Cada serie e normalizada dentro da propria unidade fisica.

## Formula do indice composto CFEM

Com pesos fixos `w_s` obtidos da participacao media do `ValorRecolhido` em 2020-2023:

`indice_cfem_t = soma( w_s * indice_s,t )`

## Peso otimo encontrado na grade exploratoria

- CFEM: 0%
- CAGED B: 100%

## Regras da versao robusta

A versao robusta manteve apenas as substancias que passaram simultaneamente nestes filtros:

1. base trimestral positiva em 2020;
2. pelo menos 8 trimestres com quantidade positiva entre 2020T1 e 2023T4;
3. participacao minima de 1% no valor recolhido total de 2020-2023;
4. razao entre o percentil 95 da quantidade trimestral (2021-2025) e a base trimestral de 2020 menor ou igual a 20.

A quarta regra foi criada para evitar o problema de series com base 2020 muito pequena e explosao artificial do indice composto.

## Peso otimo encontrado na grade robusta

- CFEM robusto: 0%
- CAGED B: 100%

---

## Decisao metodologica: por que a CFEM foi rejeitada

A exploracao acima levou a uma decisao explicita de **nao utilizar a CFEM como indicador de atividade** no pipeline do PIB trimestral de Roraima. Os motivos sao os seguintes:

### 1. Timing irregular de recolhimento

A CFEM e uma royalty calculada sobre o valor das vendas minerais. O recolhimento pode ocorrer com defasagem de semanas ou meses em relacao a producao fisica. Uma queda brusca em um trimestre pode refletir atraso de pagamento, nao reducao de atividade. Isso introduz ruido sistematico sem relacao com o ciclo de producao.

### 2. Distorcao pela base 2020 pequena

O ano de 2020 e o ano-base da serie (indice = 100). Diversas substancias tiveram recolhimento muito baixo ou nulo em 2020 — por ser ano atipico (pandemia, interrupcao de lavras), ou por ciclo natural da atividade. Quando a base e proxima de zero, qualquer retomada posterior gera indices explosivos (ex.: CFEM robusto = 667 em 2025, contra benchmark = 165). Mesmo apos os filtros de robustez, o indice composto permanece sem aderencia ao benchmark anual (CR/IBGE).

### 3. Concentracao em minerais de baixo valor agregado no VAB

As tres substancias que passaram nos filtros de robustez sao:

| Substancia | Participacao no valor recolhido |
|------------|--------------------------------|
| Granito    | 75,6%                          |
| Laterita   | 18,2%                          |
| Argila     |  6,2%                          |

Granito e laterita sao tipicamente usados em construcao civil, nao em extracao mineral propriamente dita (CNAE B). Sua inclusao no indice distorce a representacao da industria extrativa mineral.

### 4. Resultado da otimizacao: peso zero para CFEM

A busca em grade sobre o intervalo [0, 1] para o peso da CFEM, minimizando a variancia do ajuste Denton-Cholette ao benchmark anual 2020-2023, convergiu para peso 0% em ambas as versoes (exploratoria e robusta). Isso significa que a combinacao que melhor reproduz o benchmark ja conhecido e a que ignora completamente a CFEM. O resultado nao e ambiguo: a funcao-objetivo e monotonamente crescente a partir do ponto (CFEM=0, CAGED B=1).

### 5. Extrapolar 2024-2025 com CFEM seria arriscado

Para os anos pos-benchmark (2024-2025), o pipeline usa o indicador como guia da evolucao trimestral. Um indicador com volatilidade extrema (indice CFEM robusto variou entre 241 e 667 entre 2022 e 2025) produziria perfis trimestrais implausíveis dentro de cada ano, mesmo apos o ajuste Denton.

---

## Decisao adotada: CAGED secao B como unico indicador de extrativas

O CAGED (estoque de empregos formais na secao B — Industrias Extrativas) foi adotado como proxy exclusiva pelos seguintes motivos:

1. **Consistencia metodologica** com as demais secoes industriais e de servicos, que tambem usam estoque CAGED como indicador de volume.
2. **Menor ruido de timing**: o emprego formal responde com atraso menor e de forma mais suavizada ao ciclo de atividade do que royalties financeiras.
3. **Cobertura continua**: o CAGED tem cobertura mensal sem lacunas a partir de 2020, com atualizacao rapida e revisoes pequenas.
4. **Extrapolacao plausível**: a evolucao do estoque de empregos em 2024-2025 produz perfis trimestrais dentro do benchmark esperado (comparacao anual mostrou combinado robusto = 159-165 em 2024-2025, compatível com a tendencia).
5. **Resultado da otimizacao**: peso 100% confirmado empiricamente na minimizacao da distancia ao benchmark.

A implementacao esta em `R/03_industria.R`, ETAPA 3.6b. O estoque e calculado como:

```
estoque_t = 1000 + cumsum(saldo_mensal)   # base arbitraria, cancela no rebase
indice_caged_b_t = mean_trim(estoque) / mean_trim_2020 * 100
```

O valor 1000 e uma base arbitraria para evitar estoque negativo; ele cancela completamente no rebaseamento para 2020=100.

---

## Arquivos para enxergar o processo por dentro

- `data/output/extrativas_cfem/cfem_rr_diagnostico_robustez.csv`
- `data/output/extrativas_cfem/cfem_rr_substancias_robustas.csv`
- `data/output/extrativas_cfem/cfem_rr_substancias_excluidas_robustas.csv`
- `data/output/extrativas_cfem/cfem_rr_trimestral_substancias_robustas.csv`
- `data/output/extrativas_cfem/indice_cfem_extrativas_robusto_trimestral.csv`
- `data/output/extrativas_cfem/otimizacao_cfem_robusto_caged_b.csv`
- `data/output/extrativas_cfem/indice_extrativas_robusto_trimestral.csv`
- `data/output/extrativas_cfem/comparacao_anual_cfem_robusto_caged_benchmark.csv`
- `data/output/extrativas_cfem/cfem_top_substancias_robustas.png`
- `data/output/extrativas_cfem/cfem_caged_indice_robusto.png`
- `data/output/extrativas_cfem/cfem_caged_otimizacao_robusta.png`

## Arquivos gerados

- `data/output/extrativas_cfem/cfem_rr_resumo_substancias.csv`
- `data/output/extrativas_cfem/cfem_rr_substancias_incluidas.csv`
- `data/output/extrativas_cfem/cfem_rr_mensal_substancias.csv`
- `data/output/extrativas_cfem/cfem_rr_trimestral_substancias.csv`
- `data/output/extrativas_cfem/indice_cfem_extrativas_trimestral.csv`
- `data/output/extrativas_cfem/caged_b_extrativas_trimestral.csv`
- `data/output/extrativas_cfem/otimizacao_cfem_caged_b.csv`
- `data/output/extrativas_cfem/indice_extrativas_exploratorio_trimestral.csv`
- `data/output/extrativas_cfem/comparacao_anual_cfem_caged_benchmark.csv`
- `data/output/extrativas_cfem/cfem_top_substancias.png`
- `data/output/extrativas_cfem/cfem_caged_indice_exploratorio.png`
- `data/output/extrativas_cfem/cfem_caged_otimizacao.png`
- `data/output/extrativas_cfem/cfem_top_substancias_robustas.png`
- `data/output/extrativas_cfem/cfem_caged_indice_robusto.png`
- `data/output/extrativas_cfem/cfem_caged_otimizacao_robusta.png`
