# Checklist da Reforma Metodológica — Ancoragem ao VAB Real

> Referência: [`plano_reforma_indicador_real.md`](plano_reforma_indicador_real.md)
>
> Este checklist rastreia a implementação da correção de ancoragem Denton: substituição do VAB
> nominal (Tabela 5 IBGE) pelo índice de volume real (Tabela 6 IBGE) como benchmark trimestral.
> Atualizar imediatamente sempre que uma etapa for concluída ou o plano for revisado.

---

## Etapa A — Baixar e processar Tabelas 6 e 7 (`R/00_dados_referencia.R`)

- [ ] **A.1** Adicionar download de `tabela6.zip` ao `R/00_dados_referencia.R` (URL: `https://ftp.ibge.gov.br/Contas_Regionais/2023/xls/tabela6.zip`)
- [ ] **A.2** Adicionar download de `tabela7.zip` ao `R/00_dados_referencia.R`
- [ ] **A.3** Inspecionar a estrutura real das Tabelas 6 e 7 (abas, colunas, formato de UF e atividade)
- [ ] **A.4** Confirmar mapeamento entre atividades da Tabela 6 e os setores do projeto (ver tabela em `plano_reforma_indicador_real.md`)
- [ ] **A.5** Implementar função `processar_tabela_volume()`:
  - [ ] Parsear Excel e filtrar para Roraima
  - [ ] Encadear índice de ano anterior = 100 para base fixa 2020 = 100
  - [ ] Verificar cobertura temporal (espera-se 2002–2023)
- [ ] **A.6** Salvar `data/processed/contas_regionais_RR_volume.csv` com colunas `ano`, `atividade`, `vab_volume_rebased`
- [ ] **A.7** Implementar processamento equivalente para a Tabela 7 (deflator implícito)
- [ ] **A.8** Salvar `data/processed/contas_regionais_RR_deflator.csv` com colunas `ano`, `atividade`, `deflator_rebased`
- [ ] **A.9** Rodar `R/00_dados_referencia.R` e confirmar ausência de erros e NAs inesperados

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
| A — Download e processamento Tabelas 6 e 7 | ⚪ Não iniciada | |
| B — Atualização do benchmark nos scripts | ⚪ Não iniciada | |
| C — Reexecução do pipeline | ⚪ Não iniciada | |
| D — Validação pós-reforma | ⚪ Não iniciada | |
| E — VAB nominal trimestral (Ponto 2) | ⚪ Não iniciada | Secundário, após D |
| F — Documentação e commit | ⚪ Não iniciada | |
