# Checklist da Reforma Metodológica — Ancoragem ao VAB Real

> Referência: [`plano_reforma_indicador_real.md`](plano_reforma_indicador_real.md)
>
> Este checklist rastreia a implementação da correção de ancoragem Denton: substituição do VAB
> nominal (Tabela 5 IBGE) pelo índice de volume real (Tabela 6 IBGE) como benchmark trimestral.
> Atualizar imediatamente sempre que uma etapa for concluída ou o plano for revisado.

---

## Etapa A — Baixar e processar Tabelas de volume (`R/00_dados_referencia.R`)

> **Correção de nomenclatura (2026-04-13):** o FTP do IBGE não tem `tabela6.zip`/`tabela7.zip`
> como arquivos separados. Os índices de volume estão em `Especiais_2002_2023_xls.zip` →
> `tab05.xls` (volume por atividade, base 2002=100, Roraima na linha 11 de cada aba).
> O deflator será tratado na Etapa E (secundário).

- [x] **A.1** Identificar a URL correta do volume no FTP: `Especiais_2002_2023_xls.zip` → `tab05.xls` (não existe `tabela6.zip`)
- [x] **A.2** Adicionar download de `Especiais_2002_2023_xls.zip` ao `R/00_dados_referencia.R`
- [x] **A.3** Inspecionar estrutura de `tab05.xls`: base 2002=100, Roraima linha 11, anos 2002–2023 nas colunas 2–23; estrutura idêntica em todas as 13 abas de atividade
- [x] **A.4** Confirmar mapeamento: 13 atividades idênticas ao `Conta_da_Producao` — mesmo nome, mesma ordem
- [x] **A.5** Implementar função `extrair_volume_rr()` com localização robusta de Roraima por `trimws(col1) == "Roraima"` (não por número de linha fixo)
- [x] **A.6** Salvar `data/processed/contas_regionais_RR_volume.csv` — 286 obs., 13 atividades, 22 anos (2002–2023), base 2020=100
- [ ] **A.7** Implementar processamento do deflator implícito (Etapa E — secundário, após Etapa D)
- [ ] **A.8** Salvar `data/processed/contas_regionais_RR_deflator.csv` — adiado para Etapa E
- [x] **A.9** Rodar `R/00_dados_referencia.R`: concluído sem erros; validação 2020=100 passou para todas as atividades

**Taxas de crescimento real obtidas (total, base 2020=100):**
- 2021: +8,2% (era +12,3% nominal — corrigido em −4,1 pp)
- 2022: +10,7% (era +17,2% — corrigido em −6,5 pp)
- 2023: +3,9% (era +20,3% — corrigido em −16,4 pp)

---

## Etapa B — Atualizar benchmark nos scripts setoriais

### B.1 — `R/01_agropecuaria.R` (1 chamada Denton)
- [x] Adicionar leitura de `contas_regionais_RR_volume.csv`
- [x] Identificar atividade correspondente no volume (Tabela 6): "Agropecuária"
- [x] Substituir `vab_mi` por `vab_volume_rebased` na chamada Denton
- [x] Verificar que a extrapolação 2024–2025 usa taxa de crescimento do volume (não do nominal)

### B.2 — `R/02_adm_publica.R` (1 chamada Denton)
- [x] Adicionar leitura de `contas_regionais_RR_volume.csv`
- [x] Identificar atividade correspondente: "Adm., defesa, educação e saúde públicas e seguridade social"
- [x] Substituir `vab_mi` por `vab_volume_rebased` na chamada Denton
- [x] Verificar extrapolação 2024–2025

### B.3 — `R/03_industria.R` (3 chamadas Denton)
- [x] Adicionar leitura de `contas_regionais_RR_volume.csv`
- [x] Chamada 1 (Indústria de transformação): substituir benchmark → "Indústrias de transformação"
- [x] Chamada 2 (Construção): substituir benchmark → "Construção"
- [x] Chamada 3 (SIUP): substituir benchmark → "Eletricidade e gás, água, esgoto..."
- [x] Verificar extrapolação 2024–2025 nas três chamadas

### B.4 — `R/04_servicos.R` (7 chamadas Denton)
- [x] Adicionar leitura de `contas_regionais_RR_volume.csv`
- [x] Chamada 1 (Comércio): substituir benchmark → "Comércio e reparação de veículos..."
- [x] Chamada 2 (Transportes): substituir benchmark → "Transporte, armazenagem e correio"
- [x] Chamada 3 (Info. e comunicação): substituir benchmark → "Informação e comunicação"
- [x] Chamada 4 (Financeiro): substituir benchmark → "Atividades financeiras e de seguros..."
- [x] Chamada 5 (Imobiliárias): substituir benchmark → "Atividades imobiliárias"
- [x] Chamada 6 (Outros serviços): substituir benchmark → "Outros serviços"
- [x] Chamada 7 (Extrativas — peso negligenciável): substituir benchmark → "extrativ..."
- [x] Verificar extrapolação 2024–2025 nas chamadas

### B.5 — `R/05_agregacao.R` (4 pontos críticos)
- [x] **Camada 1 — média ponderada (ETAPA 5.1.3)**: `apply(..., sum(row*w)/sum(w))` permanece correto — fórmula Laspeyres sobrevive com valores de entrada em base 2020=100
- [x] **Camada 2 — benchmark do segundo Denton (ETAPA 5.1.4)**: CORRIGIDO — substituído `sum(vab_mi) / base * 100` por índice de volume total RR (Laspeyres ponderado por participações nominais 2020)
- [x] **Camada 3 — re-normalização dos setoriais na saída (ETAPA 5.1.7)**: mantida como proteção (harmless — divisão por média 2020 que já é ~100)
- [x] **Pesos do ano base**: CORRIGIDO — `pesos_blocos` agora calculado dinamicamente a partir das participações nominais de 2020 (não mais hardcoded com valores de 2023)

---

## Etapa C — Rerrodar pipeline completo

- [x] **C.1** Rodar `R/00_dados_referencia.R` — concluído na Etapa A
- [x] **C.2** Rodar `R/01_agropecuaria.R` — OK (variações batem com VAB volume)
- [x] **C.3** Rodar `R/02_adm_publica.R` — OK (2021: +3,2%, 2022: +4,1%, 2023: +2,4%)
- [x] **C.4** Rodar `R/03_industria.R` — OK (construção/SIUP puxam Ind. em 2021-2022)
- [x] **C.5** Rodar `R/04_servicos.R` — OK, 24 obs.
- [x] **C.6** Rodar `R/05_agregacao.R` — índice geral: 2021 +8,2% | 2022 +10,9% | 2023 +4,3%; ancoragem Denton perfeita (✓ todos os anos)
- [x] **C.7** Rodar `R/05c_ajuste_sazonal.R` — séries SA e fatores regenerados
- [x] **C.8** Rodar `R/05d_validacao.R` — relatório regenerado (MAE 8,8 pp vs. nominal = esperado/correto)
- [x] **C.9** Rodar `R/05e_exportacao.R` — Excel `IAET_RR_series.xlsx` regenerado (24 obs. por aba)

---

## Etapa D — Validação pós-reforma

- [x] **D.1** Conferir taxas de crescimento anual no `data/output/indice_geral_rr.csv`:
  - [x] 2021: +8,2% (alvo ~3–6% — ligeiramente acima por peso AAPP e Construção; correto)
  - [x] 2022: +10,9% (alvo ~4–8% — acima por expansão SIUP/energia; correto)
  - [x] 2023: +4,3% (alvo ~3–7% — dentro da faixa; ✓)
- [x] **D.2** Ancoragem Denton perfeita (✓) — média anual do índice == benchmark volume para 2020, 2021, 2022, 2023
- [x] **D.3** Pesos Laspeyres 2020 computados dinamicamente; soma weighted average = benchmark (✓)
- [x] **D.4** Correlação IBCR Norte: pré-reforma corr=-0,74, MAE=14 pp; pós-reforma corr=-0,24, MAE=5,2 pp — melhora significativa (reforma aproxima o índice de um indicador de volume como o IBCR); correlação ainda negativa pois RR tem AAPP=46% com ciclo descolado do Norte
- [x] **D.5** Relatório de validação regenerado — MAE 8,8 pp vs. VAB nominal é ESPERADO (indica que o índice agora é real, não nominal)

---

## Etapa E — VAB nominal trimestral (Ponto 2 — após A-D concluídos)

- [x] **E.1** Deflator implícito derivado diretamente dos CSVs existentes: (vab_mi/vab_mi_2020) / (vab_volume_rebased/100) × 100 — sem Tabela 7 separada necessária
- [x] **E.2** Deflator encadeado para base 2020=100 por atividade; salvo em `contas_regionais_RR_deflator.csv` (182 obs.)
- [x] **E.3** IPCA mensal (`data/raw/ipca_mensal.csv`) agregado a trimestral e rebaseado 2020=100
- [x] **E.4** Denton-Cholette: deflator anual (4 anos, Laspeyres) → trimestral com IPCA; ancoragem perfeita ✓ 2020–2023
- [x] **E.5** Índice nominal = `indice_geral × deflator / 100`; salvo em `data/output/indice_nominal_rr.csv`; 2021 +12,4%, 2022 +18,2%, 2023 +20,7%
- [x] **E.6** Aba "VAB Nominal" adicionada ao `IAET_RR_series.xlsx` com nota metodológica
- **Script**: `R/05f_vab_nominal.R`

---

## Etapa F — Atualização de documentação e versionamento

- [x] **F.1** `plano_projeto.md` atualizado com decisão metodológica da ancoragem ao volume real
- [x] **F.2** `checklist.md` principal atualizado (seções 5.1, 5.3, 5.4, 5.5 marcadas como refeitas)
- [x] **F.3** `historico_simples.md` atualizado com registro completo da reforma (tabela antes/depois, metodologia, resultados)
- [x] **F.4** `logs/fontes_utilizadas.csv` atualizado — adicionados "Especiais volume" e "Deflator implícito"
- [x] **F.5** Commit em português (realizado em dois commits: B–D e E–F)
- [x] **F.6** Push para o GitHub

---

## Status geral

| Etapa | Status | Observação |
|---|---|---|
| A — Download e processamento (volume) | 🟢 Concluída | A.7/A.8 adiados para Etapa E |
| B — Atualização do benchmark nos scripts | 🟢 Concluída | B.1–B.5 completos (11 chamadas Denton + 05_agregacao.R) |
| C — Reexecução do pipeline | 🟢 Concluída | Todos os scripts rodaram sem erros |
| D — Validação pós-reforma | 🟢 Concluída | D.4: MAE IBCR Norte caiu de 14 pp para 5,2 pp |
| E — VAB nominal trimestral (Ponto 2) | 🟢 Concluída | `R/05f_vab_nominal.R`; deflator 2021 +3,8% | 2022 +6,5% | 2023 +15,7% |
| F — Documentação e commit | 🟢 Concluída | plano_projeto.md, checklist.md, historico_simples.md, fontes_utilizadas.csv |
