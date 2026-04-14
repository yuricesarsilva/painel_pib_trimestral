# Checklist da Reforma de Impostos — ILP e PIB nominal trimestral

> Referência: [`plano_reforma_impostos.md`](plano_reforma_impostos.md)
>
> Este checklist rastreia a implementação da frente de impostos sobre produtos, ILP trimestral e
> PIB nominal trimestral de Roraima. Atualizar imediatamente sempre que uma etapa for concluída ou
> revista.

---

## Etapa A — Delimitação conceitual e desenho metodológico

- [x] **A.1** Formalizar que o objetivo é medir `ILP = impostos líquidos sobre produtos`, e não arrecadação tributária total
- [x] **A.2** Registrar que o núcleo inicial recomendado é `ICMS + ISS`
- [x] **A.3** Registrar que `IPI` sozinho não é suficiente como proxy federal
- [x] **A.4** Definir bloco federal ampliado recomendado: `IPI + II + PIS/Pasep + Cofins + CIDE`
- [x] **A.5** Registrar `ITBI` como candidato secundário e `IOF` como item opcional sujeito a teste
- [x] **A.6** Criar `plano_reforma_impostos.md`

---

## Etapa B — Mapeamento e coleta das fontes subnacionais

### B.1 — Estado de Roraima
- [x] Identificar a extração reproduzível do `ICMS` estadual no Siconfi/MSC/RREO
- [ ] Confirmar periodicidade disponível e cobertura mínima 2020–presente
- [x] Validar a natureza de receita correta e documentar o código utilizado
- [ ] Construir série mensal padronizada do `ICMS`

Observação atual: a rota limpa já gera série mensal com 59 observações (`2020-01` a `2026-02`),
mas ainda há lacuna em `2022-01` a `2023-03`, o que impede marcar a cobertura mínima
2020–presente como concluída.

### B.2 — Municípios de Roraima
- [ ] Identificar a extração reproduzível do `ISS` nos 15 municípios via Siconfi/MSC/RREO
- [ ] Definir rotina de agregação municipal para o total de RR
- [ ] Validar consistência temporal e cobertura mínima 2020–presente
- [ ] Testar `ITBI` como série complementar opcional

---

## Etapa C — Mapeamento e coleta das fontes federais

- [ ] Identificar dataset reproduzível da Receita Federal com arrecadação por UF
- [ ] Confirmar disponibilidade para `IPI`
- [ ] Confirmar disponibilidade para `II`
- [ ] Confirmar disponibilidade para `PIS/Pasep`
- [ ] Confirmar disponibilidade para `Cofins`
- [ ] Confirmar disponibilidade para `CIDE-Combustíveis`
- [ ] Verificar se `IOF` vale a pena como complemento
- [ ] Padronizar série mensal federal por UF = RR

---

## Etapa D — Construção do benchmark anual

- [ ] Obter PIB nominal anual de RR via SIDRA/IBGE
- [ ] Validar a consistência com o VAB nominal anual já processado
- [ ] Calcular `ILP anual = PIB anual - VAB anual`
- [ ] Gerar série anual consolidada 2020–2023 (e ampliar conforme disponibilidade)

---

## Etapa E — Construção das proxies trimestrais

### E.1 — Versão MVP
- [ ] Construir proxy trimestral `ICMS + ISS`
- [ ] Definir regra inicial de normalização/pesos
- [ ] Testar estabilidade trimestral da série combinada

### E.2 — Versão ampliada
- [ ] Construir bloco federal agregado
- [ ] Integrar bloco federal ao agregado subnacional
- [ ] Comparar versão `MVP` vs. `ampliada`
- [ ] Medir sensibilidade das variações trimestrais

---

## Etapa F — Script de produção

- [ ] Criar `R/05g_pib_nominal.R`
- [ ] Escalar o VAB nominal trimestral para `R$ milhões`
- [ ] Aplicar Denton-Cholette ao ILP anual com proxy trimestral
- [ ] Calcular `PIB nominal trimestral = VAB nominal trimestral + ILP trimestral`
- [ ] Salvar `data/output/pib_nominal_rr.csv`
- [ ] Integrar o novo produto ao `R/05e_exportacao.R`

---

## Etapa G — Validação e documentação

- [ ] Validar se a soma dos quatro trimestres reproduz o ILP anual
- [ ] Verificar coerência do PIB nominal trimestral com o PIB anual do IBGE
- [ ] Testar comportamento em anos com maior inflação e/ou arrecadação atípica
- [ ] Documentar metodologia e limitações na nota técnica
- [ ] Registrar no `historico_simples.md`
- [ ] Atualizar `README.md`, `plano_projeto.md` e `checklist.md` quando a implementação começar

---

## Etapa H — Versionamento

- [x] Commit em português
- [x] Push para o GitHub

---

## Status geral

| Etapa | Status | Observação |
|---|---|---|
| A — Delimitação e desenho metodológico | 🟢 Concluída | Plano e checklist criados; recomendação metodológica registrada |
| B — Fontes subnacionais | 🟡 Em andamento | Rota do ICMS estadual mapeada via MSC; harmonização histórica e ISS municipal ainda pendentes |
| C — Fontes federais | ⚪ Não iniciada | Receita Federal por UF ainda não integrada |
| D — Benchmark anual | ⚪ Não iniciada | Estrutura conhecida, mas não automatizada nesta frente |
| E — Proxies trimestrais | ⚪ Não iniciada | MVP e versão ampliada ainda não implementados |
| F — Script de produção | ⚪ Não iniciada | `R/05g_pib_nominal.R` ainda não criado |
| G — Validação e documentação | ⚪ Não iniciada | Depende da implementação |
| H — Versionamento | 🟢 Concluída | Criação documental da frente registrada e versionada |
