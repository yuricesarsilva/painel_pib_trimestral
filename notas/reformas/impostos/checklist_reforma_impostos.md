# Checklist da Reforma de Impostos — ILP e PIB nominal trimestral

> Referência: [`plano_reforma_impostos.md`](./plano_reforma_impostos.md)
>
> Este checklist rastreia a implementação da frente de impostos sobre produtos, ILP trimestral e
> PIB nominal trimestral de Roraima. Atualizar imediatamente sempre que uma etapa for concluída ou
> revista.

---

## Etapa A — Delimitação conceitual e desenho metodológico

- [x] **A.1** Formalizar que o objetivo é medir `ILP = impostos líquidos sobre produtos`, e não arrecadação tributária total
- [x] **A.2** Registrar que o núcleo inicial seria `ICMS + ISS`
- [x] **A.3** Registrar que `IPI` sozinho não é suficiente como proxy federal
- [x] **A.4** Investigar bloco federal ampliado: `IPI + II + PIS/Pasep + Cofins + CIDE`
- [x] **A.5** Registrar `ITBI` como candidato secundário e `IOF` como item opcional
- [x] **A.6** Criar `plano_reforma_impostos.md`
- [x] **A.7** **Decisão final de proxy:** usar exclusivamente ICMS estadual (SEFAZ-RR)

---

## Etapa B — Mapeamento e coleta do ICMS estadual

### B.1 — Estado de Roraima (SEFAZ-RR)

- [x] Identificar fonte primária: Portal de Arrecadação da SEFAZ-RR (`/m-arrecadacao-mensal`)
- [x] Confirmar estrutura dos arquivos: Excel mensal, colunas Mês | Ano | ICMS | IPVA | ITCD | IRRF | Taxas | Outras | Total
- [x] Confirmar cobertura: jan/2020–mar/2026 (75 observações, sem lacunas)
- [x] Validar ausência de outliers na série de ICMS (z-score < 2,5 em todos os meses)
- [x] Escrever script de leitura: `R/exploratorio/icms_sefaz_rr.R`
- [x] Exportar série processada: `data/processed/icms_sefaz_rr_mensal.csv`

**Nota:** o Siconfi/MSC foi investigado como fonte alternativa, mas apresentou lacuna de 15 meses
(jan/2022–mar/2023) por transição de classificadores contábeis. A SEFAZ-RR foi adotada como
fonte primária por ter série completa e sem lacunas.

**Limitação documentada:** atualização manual (sem API pública). Frequência de atualização do
portal: ~1–2 meses de defasagem.

---

## Etapa C — ISS municipal (descartado como proxy)

- [x] Identificar rota de extração via Siconfi MSC MSCC (`natureza_receita LIKE '1112%'`, `natureza_conta = 'C'`)
- [x] Confirmar que rota funciona para todos os 15 municípios de RR
- [x] Extrair série de ISS 2023 para todos os municípios
- [x] **Diagnóstico:** Boa Vista concentrou 54% do ISS anual em janeiro/2023 (R$ 77 mi vs. média de R$ 4–6 mi nos demais meses); segundo pico em junho (R$ 19,7 mi)
- [x] **Decisão documentada:** ISS excluído do proxy por artefato de lançamento em lote no Siconfi — não representa sazonalidade econômica real

**Condição de reabertura:** ISS pode ser reincorporado na versão ampliada se obtido por fonte
alternativa com distribuição mensal uniforme (ex.: SEFAZ municipal, NFS-e, ou suavização
explícita com filtro HP).

---

## Etapa D — Bloco federal (descartado como proxy)

- [x] Identificar fonte: Receita Federal — "Arrecadação por Estado" (arquivos ODS mensais por UF)
- [x] Confirmar cobertura: jan/2000–**mai/2022** (dados por UF encerrados; série nacional vai até 2025 mas sem desagregação por estado)
- [x] Inspecionar estrutura e valores para RR (amostra: dez/2021):
  - IPI: R$ 60 mil/mês → negligenciável
  - II: R$ 25 mil/mês → negligenciável
  - PIS/Pasep: R$ 11,2 mi/mês → potencialmente relevante
  - Cofins: R$ 17,1 mi/mês → potencialmente relevante
  - CIDE-Combustíveis: R$ 0 → não aplicável a RR
- [x] **Diagnóstico:** dois problemas estruturais identificados:
  1. Cobertura encerrada em mai/2022 — impossibilidade de série completa para o projeto
  2. Imputação territorial inadequada: PIS/Cofins registrado no domicílio do contribuinte, não no local de consumo; RR importa a maior parte dos bens tributados de outros estados → subestimação sistemática da carga federal real sobre a economia local
- [x] **Decisão documentada:** bloco federal excluído do proxy

**Condição de reabertura:** bloco federal pode ser reincorporado se a Receita Federal publicar
dados por UF para 2022 em diante, ou mediante metodologia de imputação territorial baseada em
dados de consumo.

---

## Etapa E — Construção da proxy trimestral (ICMS)

- [x] Agregar série mensal de ICMS para frequência trimestral em `R/05g_pib_nominal.R`
- [x] Verificar sazonalidade trimestral da série (coerência intra-anual)

---

## Etapa F — Script de produção

- [x] Criar `R/05g_pib_nominal.R`
- [x] Escalar VAB nominal trimestral para `R$ milhões`
- [x] Obter PIB anual RR via SIDRA (tab. 5938)
- [x] Calcular `ILP anual = PIB anual - VAB anual`
- [x] Aplicar Denton-Cholette: `ILP_trim ~ ICMS_trim`
- [x] Calcular `PIB nominal trimestral = VAB nominal trimestral + ILP trimestral`
- [x] Salvar `data/output/pib_nominal_rr.csv`
- [x] Atualizar `IAET_RR_series.xlsx` com a nova aba "PIB Nominal"

---

## Etapa G — Validação e documentação

- [x] Validar se a soma dos quatro trimestres reproduz o ILP anual (tolerância < 0,1%)
- [x] Verificar coerência do PIB nominal trimestral com o PIB anual do IBGE
- [ ] Documentar metodologia e limitações na nota técnica
- [x] Registrar no `historico_simples.md`
- [x] Atualizar `README.md` e `checklist.md`

---

## Etapa H — Versionamento

- [x] Commit inicial da frente em português
- [x] Push para o GitHub
- [ ] Commit final após implementação do `R/05g_pib_nominal.R`

---

## Status geral

| Etapa | Status | Observação |
|---|---|---|
| A — Delimitação e desenho metodológico | 🟢 Concluída | Proxy definido: ICMS exclusivamente |
| B — ICMS estadual (SEFAZ-RR) | 🟢 Concluída | Série completa jan/2020–mar/2026; CSV gerado |
| C — ISS municipal | 🟢 Descartado | Artefato de sazonalidade no Siconfi; documentado |
| D — Bloco federal | 🟢 Descartado | Cobertura insuficiente + problema territorial; documentado |
| E — Proxy trimestral | 🟢 Concluída | ICMS trimestral agregado e usado no Denton |
| F — Script de produção | 🟢 Concluída | `R/05g_pib_nominal.R` implementado e rodado com sucesso |
| G — Validação e documentação | 🟡 Em andamento | Nota técnica ainda pendente |
| H — Versionamento | 🟡 Em andamento | Commit final pendente |
