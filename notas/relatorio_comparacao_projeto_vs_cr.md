# Relatório Rápido — Projeto x Contas Regionais do IBGE

Data: 14 de abril de 2026

## Escopo

Este relatório compara as séries anuais do projeto com as Contas Regionais do IBGE no que já está
disponível localmente e validado no repositório:

- `VAB nominal total`
- `VAB nominal por bloco setorial do projeto` (`Agropecuária`, `AAPP`, `Indústria`, `Serviços`)
- `PIB nominal`
- `taxas de crescimento real do VAB total`
- `taxas de crescimento real do VAB por bloco setorial`

Observação importante:

- a comparação nominal setorial ainda é feita no nível dos `4 blocos do projeto`, não nas `12 atividades`
  individuais das Contas Regionais;
- a comparação de `PIB real` ainda não entra aqui, porque o acervo local do projeto não mantém uma
  série anual oficial de `PIB em volume` comparável às Contas Regionais no mesmo fluxo em que hoje
  já mantém `VAB em volume` e `PIB nominal`.

---

## 1. VAB nominal total

Após a correção do `05f_vab_nominal.R`, o `VAB nominal total` do projeto passou a fechar
exatamente com o benchmark anual das Contas Regionais em `2020–2023`.

| Ano | Projeto (R$ mi) | CR IBGE (R$ mi) | Diferença |
|---|---:|---:|---:|
| 2020 | 14.524,239159 | 14.524,239160 | -0,000001 |
| 2021 | 16.309,699524 | 16.309,699524 | 0,000000 |
| 2022 | 19.117,273469 | 19.117,273469 | 0,000000 |
| 2023 | 23.003,072346 | 23.003,072345 | 0,000001 |

Leitura:

- o fechamento anual do `VAB nominal total` está resolvido;
- o desvio residual é apenas numérico, sem relevância econômica.

---

## 2. VAB nominal por bloco setorial

Com a criação do `05h_vab_nominal_setorial.R`, o projeto passou a gerar séries trimestrais de
`VAB nominal` para os `4 blocos` e, por construção, o fechamento anual bate com as Contas Regionais
em `2020–2023`.

### 2.1 2023 — comparação por bloco

| Bloco | Projeto (R$ mi) | CR IBGE (R$ mi) | Diferença |
|---|---:|---:|---:|
| AAPP | 10.629,326951 | 10.629,326951 | 0,000000 |
| Agropecuária | 2.040,141475 | 2.040,141475 | 0,000000 |
| Indústria | 2.668,810059 | 2.668,810059 | 0,000000 |
| Serviços | 7.664,793861 | 7.664,793861 | 0,000000 |

### 2.2 Leitura por ano

| Ano | Situação |
|---|---|
| 2020 | Fechamento anual exato |
| 2021 | Fechamento anual exato |
| 2022 | Fechamento anual exato |
| 2023 | Fechamento anual exato |

Leitura:

- o lado nominal setorial agora está fechado no nível em que o projeto opera analiticamente;
- isso permite comparar `nominal total` e `nominal por bloco` sem depender apenas do total.

---

## 3. PIB nominal

O `PIB nominal` trimestral do projeto, derivado de `VAB nominal + ILP`, também ficou reconciliado
ao benchmark anual usado no `05g_pib_nominal.R`.

| Ano | Projeto (R$ mi) | Benchmark anual (R$ mi) | Diferença |
|---|---:|---:|---:|
| 2020 | 16.024,275999 | 16.024,276000 | -0,000001 |
| 2021 | 18.202,579000 | 18.202,579000 | 0,000000 |
| 2022 | 21.095,342000 | 21.095,342000 | 0,000000 |
| 2023 | 25.124,805001 | 25.124,805000 | 0,000001 |

Leitura:

- o `PIB nominal` anual está consistente com o benchmark implícito usado pelo projeto;
- o ganho recente foi eliminar o pequeno desvio que antes ainda existia no lado nominal.

---

## 4. Taxa de crescimento real do VAB total

A comparação do índice geral do projeto com a linha `Total das Atividades` das Contas Regionais
mostra aderência alta, com pequenas diferenças residuais em `2022–2023`.

| Ano | Projeto (%) | CR IBGE (%) | Diferença (p.p.) |
|---|---:|---:|---:|
| 2021 | 8,19 | 8,19 | 0,00 |
| 2022 | 10,86 | 10,72 | 0,15 |
| 2023 | 4,34 | 3,92 | 0,42 |

Leitura:

- `2021` bate praticamente exato;
- `2022` e `2023` mantêm diferença pequena, mas não nula;
- isso é compatível com o fato de o índice geral operar a partir de blocos trimestrais e ancoragem anual.

---

## 5. Taxa de crescimento real do VAB por bloco setorial

A comparação anual entre o projeto e as Contas Regionais por bloco ficou assim:

| Ano | Bloco | Projeto (%) | CR IBGE (%) | Diferença (p.p.) |
|---|---|---:|---:|---:|
| 2021 | Agropecuária | 24,81 | 24,81 | 0,00 |
| 2022 | Agropecuária | 28,03 | 28,03 | 0,00 |
| 2023 | Agropecuária | 17,49 | 17,49 | 0,00 |
| 2021 | AAPP | 3,19 | 3,19 | 0,00 |
| 2022 | AAPP | 4,12 | 4,12 | 0,00 |
| 2023 | AAPP | 2,37 | 2,37 | 0,00 |
| 2021 | Indústria | 10,62 | 10,62 | 0,00 |
| 2022 | Indústria | 20,59 | 20,59 | 0,00 |
| 2023 | Indústria | 9,43 | 9,43 | 0,00 |
| 2021 | Serviços | 10,54 | 10,45 | 0,08 |
| 2022 | Serviços | 12,25 | 12,26 | -0,01 |
| 2023 | Serviços | 2,81 | 2,61 | 0,21 |

Leitura:

- `Agropecuária`, `AAPP` e `Indústria` batem exatamente nos anos com benchmark;
- `Serviços` segue com pequenas diferenças residuais, mas ainda em faixa baixa.

---

## 6. PIB real

Esta nota não traz uma tabela de comparação do `PIB real`, porque essa série anual oficial em
volume não está mantida localmente no projeto no mesmo padrão em que já estão mantidos:

- `VAB nominal`
- `VAB em volume`
- `PIB nominal`

Leitura:

- hoje a comparação robusta e já reproduzível está fechada para `VAB real`, `VAB nominal` e `PIB nominal`;
- para incluir `PIB real`, o próximo passo é incorporar ao fluxo local uma série anual oficial de
  `PIB em volume` ou sua taxa oficial de crescimento.

---

## Conclusão rápida

O quadro atual é este:

- o `lado nominal` está resolvido no total e nos `4 blocos` do projeto;
- o `PIB nominal` anual também está reconciliado;
- o `lado real` está muito bem alinhado por bloco, com diferença pequena apenas em `Serviços`;
- a diferença remanescente mais visível está no `VAB real total` em `2022–2023`, mas ainda em nível baixo;
- a principal lacuna comparativa restante é a ausência de uma rotina local formal para `PIB real`.
