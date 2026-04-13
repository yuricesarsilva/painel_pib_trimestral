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
- [ ] Adicionar leitura de `contas_regionais_RR_volume.csv`
- [ ] Identificar atividade correspondente no volume (Tabela 6): "Agropecuária"
- [ ] Substituir `vab_mi` por `vab_volume_rebased` na chamada `td()`
- [ ] Verificar que a extrapolação 2024–2025 usa taxa de crescimento do volume (não do nominal)

### B.2 — `R/02_adm_publica.R` (1 chamada Denton)
- [ ] Adicionar leitura de `contas_regionais_RR_volume.csv`
- [ ] Identificar atividade correspondente: "Administração, defesa, educação e saúde públicas..."
- [ ] Substituir `vab_mi` por `vab_volume_rebased` na chamada `td()`
- [ ] Verificar extrapolação 2024–2025

### B.3 — `R/03_industria.R` (3 chamadas Denton)
- [ ] Adicionar leitura de `contas_regionais_RR_volume.csv`
- [ ] Chamada 1 (Indústria de transformação): substituir benchmark → "Indústrias de transformação"
- [ ] Chamada 2 (Construção): substituir benchmark → "Construção"
- [ ] Chamada 3 (SIUP): substituir benchmark → "Eletricidade e gás, água, esgoto..."
- [ ] Verificar extrapolação 2024–2025 nas três chamadas

### B.4 — `R/04_servicos.R` (7 chamadas Denton)
- [ ] Adicionar leitura de `contas_regionais_RR_volume.csv`
- [ ] Chamada 1 (Comércio): substituir benchmark → "Comércio e reparação de veículos..."
- [ ] Chamada 2 (Transportes): substituir benchmark → "Transporte, armazenagem e correio"
- [ ] Chamada 3 (Info. e comunicação): substituir benchmark → "Informação e comunicação"
- [ ] Chamada 4 (Financeiro): substituir benchmark → "Atividades financeiras e de seguros..."
- [ ] Chamada 5 (Imobiliárias): substituir benchmark → "Atividades imobiliárias"
- [ ] Chamada 6 (Outros serviços): substituir benchmark → agregar atividades residuais
- [ ] Chamada 7 (Turismo / Alojamento): substituir benchmark → "Alojamento e alimentação"
- [ ] Verificar extrapolação 2024–2025 nas sete chamadas

### B.5 — `R/05_agregacao.R` (4 pontos críticos)
- [ ] **Camada 1 — média ponderada (ETAPA 5.1.3)**: confirmar que `apply(..., sum(row*w)/sum(w))` permanece correto; os valores de entrada mudam de escala mas a fórmula de Laspeyres sobrevive
- [ ] **Camada 2 — benchmark do segundo Denton (ETAPA 5.1.4)**: ⚠ CORRIGIR — substituir `sum(vab_mi) / base * 100` pelo índice de volume total de RR da Tabela 6 (não se soma VAB nominal para obter benchmark de volume)
- [ ] **Camada 3 — re-normalização dos setoriais na saída (ETAPA 5.1.7)**: verificar se `agro_vals / mean(agro_vals[ano==2020]) * 100` continua necessária após a reforma (setoriais já entregam base 2020=100)
- [ ] **Pesos do ano base**: verificar se `pesos_blocos` usa participações de 2020 (correto para Laspeyres) ou 2023 — corrigir para 2020 se necessário

---

## Etapa C — Rerrodar pipeline completo

- [ ] **C.1** Rodar `R/00_dados_referencia.R` (inclui download das Tabelas 6 e 7)
- [ ] **C.2** Rodar `R/01_agropecuaria.R` — verificar série de saída
- [ ] **C.3** Rodar `R/02_adm_publica.R` — verificar série de saída
- [ ] **C.4** Rodar `R/03_industria.R` — verificar série de saída
- [ ] **C.5** Rodar `R/04_servicos.R` — verificar série de saída
- [ ] **C.6** Rodar `R/05_agregacao.R` — gerar `indice_geral_rr.csv`
- [ ] **C.7** Rodar `R/05c_ajuste_sazonal.R` — regenerar séries SA e fatores sazonais
- [ ] **C.8** Rodar `R/05d_validacao.R` — regenerar relatório de validação
- [ ] **C.9** Rodar `R/05e_exportacao.R` — regenerar Excel `IAET_RR_series.xlsx`

---

## Etapa D — Validação pós-reforma

- [ ] **D.1** Conferir taxas de crescimento anual no `data/output/indice_geral_rr.csv`:
  - [ ] 2021: deve ser ~3–6% (não ~12%)
  - [ ] 2022: deve ser ~4–8% (não ~17%)
  - [ ] 2023: deve ser ~3–7% (não ~20%)
- [ ] **D.2** Comparar média anual dos trimestres com a Tabela 6 IBGE para RR (tolerância < 0,5%)
- [ ] **D.3** Verificar que a soma ponderada dos setoriais reproduz o índice geral (erro < 0,1%)
- [ ] **D.4** Avaliar correlação com IBCR Norte antes e depois da reforma (espera-se melhora)
- [ ] **D.5** Conferir relatório de validação (`validacao_relatorio.csv`) — todas as bandeiras verdes

---

## Etapa E — VAB nominal trimestral (Ponto 2 — após A-D concluídos)

- [ ] **E.1** Verificar cobertura e estrutura da Tabela 7 (deflator implícito por atividade/UF)
- [ ] **E.2** Implementar encadeamento do deflator para base fixa 2020 = 100
- [ ] **E.3** Usar IPCA mensal (já em `data/processed/`) como proxy trimestral
- [ ] **E.4** Aplicar Denton-Cholette para gerar deflator trimestral por setor
- [ ] **E.5** Calcular VAB nominal trimestral = `indice_real × deflator / 100`
- [ ] **E.6** Adicionar ao Excel (`IAET_RR_series.xlsx`) como coluna adicional em "Componentes"

---

## Etapa F — Atualização de documentação e versionamento

- [ ] **F.1** Atualizar `plano_projeto.md` com a decisão metodológica (ancoragem ao volume real)
- [ ] **F.2** Atualizar `checklist.md` principal (marcar etapas afetadas como refeitas)
- [ ] **F.3** Atualizar `historico_simples.md` com o registro da reforma
- [ ] **F.4** Atualizar `logs/fontes_utilizadas.csv` — adicionar Tabelas 6 e 7 como fontes
- [ ] **F.5** Commit de todos os arquivos modificados em português
- [ ] **F.6** Push para o GitHub

---

## Status geral

| Etapa | Status | Observação |
|---|---|---|
| A — Download e processamento (volume) | 🟢 Concluída | A.7/A.8 adiados para Etapa E |
| B — Atualização do benchmark nos scripts | ⚪ Não iniciada | |
| C — Reexecução do pipeline | ⚪ Não iniciada | |
| D — Validação pós-reforma | ⚪ Não iniciada | |
| E — VAB nominal trimestral (Ponto 2) | ⚪ Não iniciada | Secundário, após D |
| F — Documentação e commit | ⚪ Não iniciada | |
