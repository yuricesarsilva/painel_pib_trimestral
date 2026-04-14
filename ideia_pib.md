# Ideia: PIB Nominal Trimestral de RR

> **Este documento foi supersedido por [`plano_reforma_impostos.md`](plano_reforma_impostos.md).**
>
> Registrado em 2026-04-13. Mantido apenas como referência histórica e pela tabela de ILP anual.
>
> Atualizações relevantes em relação ao que estava planejado aqui:
> - **Opção A (ICMS CONFAZ)** substituída pela SEFAZ-RR como fonte primária: série completa
>   jan/2020–mar/2026, sem lacunas, sem necessidade de scraping.
> - **Opção B (ratio fixo)** não adotada — Denton-Cholette com proxy ICMS é superior.
> - **ISS** investigado e descartado como proxy mensal: artefato de lançamento em lote no
>   Siconfi concentra 54% do ISS anual em janeiro.
> - **Bloco federal** investigado e descartado: dados por UF só até mai/2022; problema de
>   imputação territorial (domicílio do contribuinte ≠ local de consumo).
> - **Gatilho de implementação já atingido:** ICMS disponível e processado em
>   `data/processed/icms_sefaz_rr_mensal.csv`.

> Registrado em 2026-04-13.

## O que queremos gerar

Três séries derivadas do pipeline atual:

1. **VAB nominal trimestral em R$ milhões** — já implementado em `05f_vab_nominal.R` como índice; basta escalar pelo VAB de 2020.
2. **ILP (Impostos Líquidos sobre Produtos) trimestral** — diferença entre PIB e VAB nas CR IBGE, desagregada trimestralmente via Denton.
3. **PIB nominal trimestral em R$ milhões** = VAB nominal + ILP trimestral.

## Dados já disponíveis

- **VAB nominal anual RR (2010–2023)**: `data/processed/contas_regionais_RR_serie.csv` → coluna `vab_mi`, atividade "Total das Atividades"
- **PIB nominal anual RR (2010–2023)**: SIDRA Tabela 5938, variável 37, UF=14 (Roraima) — já consultado e confirmado
- **ILP anual RR (2010–2023)**: calculado diretamente como PIB − VAB

| Ano | PIB (R$ mi) | VAB (R$ mi) | ILP (R$ mi) | ILP/VAB |
|-----|-------------|-------------|-------------|---------|
| 2020 | 16.024 | 14.524 | 1.500 | 10,3% |
| 2021 | 18.203 | 16.310 | 1.893 | 11,6% |
| 2022 | 21.095 | 19.117 | 1.978 | 10,3% |
| 2023 | 25.125 | 23.003 | 2.122 |  9,2% |

- **VAB nominal 2020** (base de escala): R$ 14.524 milhões anuais → R$ 3.631 milhões/trimestre médio
- **Índice nominal trimestral**: já em `data/output/indice_nominal_rr.csv` (base 2020=100)

## Opções para o proxy intra-anual do ILP

### Opção A — ICMS CONFAZ (recomendada)
- Fonte: Boletim de Arrecadação do ICMS — CONFAZ (mensal por UF, público)
- ICMS representa ~70–80% do ILP de RR
- Problema: publicado em PDF/Excel por período, sem API estruturada — requer download manual ou scraping
- Custo estimado: 4–8h

### Opção B — Ratio fixo interpolado (primeira versão simples)
- `ILP_trim_t = VAB_nom_trim_t × ratio_ILP_VAB_t`
- `ratio_ILP_VAB_t` interpolado linearmente entre os anos com CR disponível
- Não captura sazonalidade intra-anual dos impostos
- Custo estimado: 1–2h
- **Recomendado como ponto de partida** até obter ICMS granular

### Opção C — ICMS SEFAZ-RR + tributos federais (completa)
- ICMS por atividade (SEFAZ-RR) — já previsto no `checklist.md`
- Tributos federais por UF: IPI, PIS, COFINS — Receita Federal (API ou download)
- ISS municipal: não disponível de forma estruturada — aproximar por proporção
- Custo estimado: 2–3 dias

## Script a criar

`R/05g_pib_nominal.R`

Estrutura prevista:
1. Carregar `indice_nominal_rr.csv` e escalar para R$ mi (VAB base 2020)
2. Baixar PIB anual RR via SIDRA (tab. 5938) → calcular ILP anual
3. Desagregar ILP para trimestral via Denton-Cholette (proxy: ICMS ou ratio)
4. PIB_trim = VAB_nom_trim + ILP_trim
5. Salvar `data/output/pib_nominal_rr.csv`
6. Adicionar aba "PIB Nominal" ao `IAET_RR_series.xlsx`

## Gatilho para implementar

Implementar quando **pelo menos uma** das condições for atendida:
- ICMS mensal total de RR obtido da SEFAZ-RR **ou** baixado do CONFAZ
- Decisão de publicar o PIB nominal como produto oficial do IAET-RR
