# PIB Trimestral de Roraima

> **[Dashboard interativo](https://yuricesar.shinyapps.io/pib-trimestral-rr/)** · **[Nota Metodológica](https://yuricesarsilva.github.io/painel_pib_trimestral/metodologia.html)**

Desenvolvido pela **Secretaria de Estado do Planejamento e Desenvolvimento de Roraima (SEPLAN/RR)**, este projeto produz as **estimativas trimestrais do PIB de Roraima** — em termos reais e nominais — a partir de 2020.

O produto central é o **PIB nominal trimestral** (VAB + ILP, em R$ milhões) e o **PIB real** (índice e taxa de crescimento, base média de 2020 = 100). O instrumento metodológico que sustenta essas estimativas é o **Indicador de Atividade Econômica Trimestral de Roraima (IAET-RR)**, um índice encadeado de volume construído com proxies setoriais e ancorado anualmente nas Contas Regionais do IBGE via Denton-Cholette.

---

## Documentação técnica

> [**Nota Metodológica completa**](https://yuricesarsilva.github.io/painel_pib_trimestral/metodologia.html) — arquitetura do sistema, fórmulas, proxies setoriais, otimização de pesos e resultados de validação.

---

## Estado atual do projeto

**Pipeline de produção: operacional e atualizado.**

| Componente | Status | Cobertura |
|---|---|---|
| Agropecuária (`01_agropecuaria.R`) | ✅ Operacional | 2020T1–2025T4 |
| Administração Pública (`02_adm_publica.R`) | ✅ Operacional | 2020T1–2025T4 |
| Indústria (`03_industria.R`) | ✅ Operacional | 2020T1–2025T4 |
| Serviços Privados (`04_servicos.R`) | ✅ Operacional | 2020T1–2025T4 |
| Índice Geral agregado (`05_agregacao.R`) | ✅ Operacional | 2020T1–2025T4 |
| Ajuste sazonal (`05c_ajuste_sazonal.R`) | ✅ Operacional | 2020T1–2025T4 |
| Validação final (`05d_validacao.R`) | ✅ Operacional | 2020T1–2025T4 |
| Exportação (`05e_exportacao.R`) | ✅ Operacional | 2020T1–2025T4 |
| VAB Nominal trimestral (`05f_vab_nominal.R`) | ✅ Operacional | 2020T1–2025T4 |
| PIB Nominal trimestral (`05g_pib_nominal.R`) | ✅ Operacional | 2020T1–2025T4 |
| VAB Nominal setorial (`05h_vab_nominal_setorial.R`) | ✅ Operacional | 2020T1–2023T4 |
| PIB Real anual (`05i_pib_real.R`) | ✅ Operacional | 2020–2025 |
| Dashboard interativo (`dashboard/app.R`) | ✅ [Publicado](https://yuricesar.shinyapps.io/pib-trimestral-rr/) | — |
| Nota técnica | ⬜ Não iniciada | — |

**Últimas taxas de crescimento do PIB real de Roraima (base 2020 = 100):**

| Ano | PIB Real — RR (%) | IBCR Norte | IBC-Br |
|---|---|---|---|
| 2021 | +8,4% | +7,2% | +4,2% |
| 2022 | +11,3% | −1,2% | +2,8% |
| 2023 | +4,2% | +1,7% | +2,7% |
| 2024 | +6,9% *(sem benchmark oficial)* | +4,1% | +3,7% |
| 2025 | +7,2% *(sem benchmark oficial)* | +1,7% | +2,5% |

> As taxas de 2021–2023 são ancoradas ao **PIB real das Contas Regionais do IBGE** via Denton-Cholette. As taxas de 2024–2025 derivam da série preliminar do projeto (sem benchmark oficial disponível) e serão substituídas quando as Contas Regionais 2024 forem publicadas (previsão IBGE: outubro de 2026).

---

## Próximos passos

| Prioridade | Tarefa | Dependência |
|---|---|---|
| 🔴 Alta | Incorporar CR IBGE 2024 quando publicada (out/2026): substituir extrapolações 2024 por dados reais | Publicação IBGE |
| 🔴 Alta | Migrar dashboard para ambiente institucional (shinyapps.io free: 25 h/mês) | Infraestrutura SEPLAN/RR |
| 🟡 Média | Redigir nota técnica metodológica (`notas/nota_tecnica.qmd`) | — |
| 🟡 Média | Re-estimar pesos ótimos das proxies compostas após publicação das CR 2024 (out/2026) — re-rodar `R/05b_sensibilidade_pesos.R` com benchmark 2020–2024 | Publicação IBGE |
| 🟢 Baixa | Revisão periódica do calendário de colheita SEADI-RR (sensibilidade alta à soja) | SEADI-RR |

---

## Sobre o projeto

O Brasil não dispõe de estimativas oficiais do PIB estadual em frequência trimestral. As **Contas Regionais do IBGE**, referência metodológica deste projeto, são publicadas apenas anualmente e com defasagem de cerca de dois anos.

Este projeto preenche essa lacuna produzindo o **PIB trimestral de Roraima** em duas dimensões:

- **PIB real** — obtido pela deflação do PIB nominal com o deflator implícito das Contas Regionais e ancorado ao benchmark oficial do PIB real do IBGE (2020–2023); cobertura trimestral 2020T1–2025T4 e anual 2020–2025. O instrumento que gera o perfil intra-anual é o IAET-RR (índice encadeado de volume do VAB, base 2020 = 100);
- **PIB nominal** — VAB trimestral a preços correntes + impostos líquidos sobre produtos (ILP), em R$ milhões, com cobertura 2020T1–2025T4.

A metodologia do IAET-RR é convergente com a do **Índice de Atividade Econômica Regional (IBCR)** do Banco Central do Brasil, adaptada às especificidades de Roraima — estado com estrutura econômica singular, alta participação do setor público (46% do VAB) e disponibilidade limitada de pesquisas estatísticas desagregadas.

---

## Metodologia

### Fórmula do IAET-RR

**Índice de Laspeyres encadeado por volume** — padrão das Contas Nacionais do IBGE:
- Período base: média de 2020 = 100
- Pesos setoriais: participação no VAB nominal de **2020** (ano base), calculados dinamicamente das Contas Regionais IBGE
- Desagregação trimestral: **Denton-Cholette** (`tempdisagg`) — a média dos quatro trimestres de cada ano reproduz o benchmark anual das Contas Regionais
- Ajuste sazonal: **X-13ARIMA-SEATS** (`seasonal`)

Nos subblocos, o projeto distingue dois tipos de ponderação:
- **pesos contábeis** de agregação entre setores/subsetores, alinhados ao ano-base de 2020 sempre que disponíveis nas Contas Regionais;
- **pesos técnicos** entre proxies de um mesmo subsetor — otimizados pelo **critério de variância do Denton**: os pesos ótimos são aqueles que minimizam `Σ(p[t]/x[t] − p[t−1]/x[t−1])²` sobre o período de benchmark 2020–2023, ou seja, a combinação de proxies que, antes mesmo da ancoragem, já apresenta o perfil sazonal mais próximo do comportamento real do setor. A busca é feita por grade com passo de 5 p.p. (`R/05b_sensibilidade_pesos.R`); os resultados e decisões estão documentados em `notas/otimizacao_pesos_proxies.md`.

### Benchmark do Denton-Cholette

O benchmark anual utiliza o **índice encadeado de volume** das Contas Regionais do IBGE (arquivo `Especiais_2002_2023_xls.zip`, aba `tab05.xls`, série base 2002 = 100, rebaseada para 2020 = 100) — e não o VAB a preços correntes (nominal).

> **Por que volume e não nominal?** As proxies trimestrais são indicadores de volume (emprego, energia, passageiros). Usar o VAB nominal como benchmark introduz inflação setorial no índice, gerando crescimentos artificialmente elevados. Com o benchmark de volume, as taxas anuais refletem crescimento real e são diretamente comparáveis ao IBCR do Banco Central.

### Estrutura setorial e proxies

| Atividade | % VAB 2023¹ | Proxy principal | Fonte |
|---|---|---|---|
| Adm., defesa, educação e saúde públicas e seguridade social | 46,21% | Folha de pagamento observada (federal SIAPE + estadual + municipal) | Portal da Transparência / STN–SICONFI |
| Comércio e reparação de veículos | 12,25% | Energia comercial ANEEL (60%) + ICMS comércio SEFAZ-RR deflacionado (20%) + emprego CAGED G (20%) | ANEEL / SEFAZ-RR / MTE–CAGED |
| Agropecuária | 8,87% | Produção física lavouras (PAM/LSPA, com pesos VBP da janela PAM 2021–2024) + pecuária (PPM/abate) | IBGE/SIDRA |
| Atividades imobiliárias | 7,68% | Interpolação linear entre benchmarks CR IBGE | IBGE – CR |
| Outros serviços | 7,63% | Emprego formal — seções I, M+N, P+Q (CAGED) | MTE–CAGED |
| Eletricidade, gás, água, esgoto e resíduos (SIUP) | 5,40% | Consumo de energia elétrica por classe | ANEEL (SAMP) |
| Construção | 4,89% | Estoque acumulado de emprego CAGED F | MTE–CAGED |
| Atividades financeiras e de seguros | 2,78% | Depósitos Estban BCB (60%) + concessões de crédito BCB (40%) | BCB (Estban / SCR) |
| Transporte, armazenagem e correio | 1,92% | Passageiros ANAC (55%) + diesel ANP (45%) | ANAC / ANP |
| Indústrias de transformação | 1,31% | Energia industrial ANEEL (55%) + emprego CAGED C (45%) | ANEEL (SAMP) / MTE–CAGED |
| Informação e comunicação | 1,01% | Emprego em TI/telecom (CAGED J) | MTE–CAGED |
| Indústrias extrativas | 0,05% | Interpolação linear CR IBGE (peso negligenciável) | IBGE – CR |

¹ Participações de referência informativa (CR IBGE 2023). Os **pesos efetivos do índice** usam participações de 2020 (ano base Laspeyres), calculados dinamicamente de `contas_regionais_RR_serie.csv`.

### PIB Nominal Trimestral — VAB e ILP

O script `R/05g_pib_nominal.R` gera o **PIB nominal trimestral** de Roraima (VAB + ILP, em R$ milhões), principal produto de divulgação do projeto.

O VAB nominal trimestral (`R/05f_vab_nominal.R`) é calculado como:

```
Índice nominal = Índice real × Deflator implícito / 100
```

O deflator implícito anual do total é extraído diretamente das Contas Regionais do IBGE
(`índice nominal total / índice real total`) e desagregado para frequência trimestral via
Denton-Cholette com o IPCA como proxy. Nos anos com benchmark publicado (`2020–2023`), o
`VAB nominal` anual fecha exatamente com o total das Contas Regionais.

O script `R/05h_vab_nominal_setorial.R` detalha o VAB nominal trimestral por bloco setorial
(`Agropecuária`, `AAPP`, `Indústria` e `Serviços`) para o período `2020–2023`. O script
`R/05i_pib_real.R` gera o **PIB real** tanto em série trimestral (`pib_real_rr.csv`) quanto
em resumo anual (`pib_real_anual_rr.csv`), em R$ milhões de 2020 e taxa de crescimento, com
ancoragem ao benchmark oficial do PIB real das Contas Regionais em `2020–2023`.

---

## Estrutura do repositório

```
├── R/
│   ├── utils.R                   # funções auxiliares: denton(), validar_serie()
│   ├── run_all.R                 # orquestrador do pipeline completo
│   ├── 00_dados_referencia.R     # CR IBGE: pesos nominais e benchmarks de volume
│   ├── 01_agropecuaria.R         # lavouras (PAM/LSPA) e pecuária
│   ├── 02_adm_publica.R          # folha pública federal + estadual + municipal
│   ├── 03_industria.R            # construção, SIUP, transformação
│   ├── 04_servicos.R             # comércio, transportes, financeiro, outros
│   ├── 05_agregacao.R            # índice geral (Laspeyres + Denton)
│   ├── 05b_sensibilidade_pesos.R # otimização dos pesos das proxies compostas (critério Denton)
│   ├── 05b_sensibilidade_*.R     # demais testes de sensibilidade (calendário agrícola)
│   ├── 05c_ajuste_sazonal.R      # X-13ARIMA-SEATS
│   ├── 05d_validacao.R           # validação: CR IBGE, IBCR Norte, IBC-Br
│   ├── 05e_exportacao.R          # exportação Excel e CSVs de publicação
│   ├── 05f_vab_nominal.R         # deflator implícito e índice nominal trimestral
│   ├── 05g_pib_nominal.R         # ILP trimestral via ICMS e PIB nominal trimestral
│   ├── 05h_vab_nominal_setorial.R # VAB nominal trimestral dos 4 blocos (2020–2023)
│   ├── 05i_pib_real.R            # PIB real trimestral e anual em R$ 2020 (ancorado ao CR IBGE)
│   └── exploratorio/             # scripts históricos de inspeção de dados
├── data/
│   └── referencias/              # calendários de colheita e referências versionadas
│   (raw/, processed/, output/ — mantidos localmente, não versionados)
├── logs/
│   └── fontes_utilizadas.csv     # rastreabilidade das fontes por release
├── plano_projeto.md              # plano metodológico detalhado
├── plano_reforma_indicador_real.md  # plano da reforma de ancoragem ao volume real
├── plano_reforma_impostos.md     # plano do ILP e do PIB nominal trimestral
├── checklist.md                  # checklist geral do projeto
├── checklist_reforma.md          # checklist da reforma metodológica (abr/2026)
├── checklist_reforma_impostos.md # checklist da frente de impostos e PIB nominal
├── historico_simples.md          # histórico do projeto em linguagem acessível
├── notas/
│   ├── relatorio_comparacao_projeto_vs_cr.md # comparação rápida do projeto com as CR
│   └── otimizacao_pesos_proxies.md           # metodologia, resultados e decisões da otimização dos pesos
└── regras.md                     # protocolo obrigatório de sessão e manutenção
```

---

## Saídas de dados

Salvas em `data/output/` (não versionadas — disponíveis mediante solicitação):

| Arquivo | Conteúdo |
|---|---|
| `IAET_RR_series.xlsx` | Excel com 8 abas: Índice Geral, Componentes, Dessazonalizado, Fatores Sazonais, Metadados, VAB Nominal, PIB Nominal, PIB Real |
| `indice_geral_rr.csv` | Índice geral trimestral NSA (2020T1–2025T4) |
| `indice_geral_rr_sa.csv` | Índice geral dessazonalizado (SA) + componentes |
| `fatores_sazonais.csv` | Fatores sazonais aditivos por componente |
| `indice_nominal_rr.csv` | Índice nominal (real × deflator implícito) |
| `pib_nominal_rr.csv` | PIB nominal trimestral em R$ milhões (VAB + ILP) |
| `vab_nominal_setorial_rr.csv` | VAB nominal trimestral dos 4 blocos do projeto (2020–2023) |
| `vab_nominal_setorial_anual_rr.csv` | Fechamento anual do VAB nominal setorial vs. benchmark das CR |
| `pib_real_rr.csv` | PIB real trimestral em R$ milhões de 2020 e índice (2020T1–2025T4) |
| `pib_real_anual_rr.csv` | PIB real anual em R$ milhões de 2020 e taxa de crescimento (2020–2025) |
| `validacao_relatorio.csv` | Relatório de validação (4 eixos) |
| `notas/relatorio_comparacao_projeto_vs_cr.md` | Relatório rápido comparando projeto e Contas Regionais |

---

## Pacotes R utilizados

| Pacote | Finalidade |
|---|---|
| `sidrar` | Acesso ao SIDRA/IBGE (LSPA, PAM, PPM, Abate, Leite, Ovos) |
| `tempdisagg` | Desagregação temporal Denton-Cholette |
| `seasonal` | Ajuste sazonal X-13ARIMA-SEATS |
| `dplyr` / `tidyr` / `readr` | Manipulação de dados |
| `openxlsx` | Exportação em Excel |
| `httr2` / `jsonlite` | Coleta via APIs (BCB, ANEEL, ANP, Portal da Transparência) |
| `readxl` | Leitura dos arquivos XLS das Contas Regionais |

---

## Fontes de dados

| Fonte | Dado | Acesso |
|---|---|---|
| IBGE Contas Regionais | VAB nominal e índice de volume por atividade — Roraima (2002–2023) | FTP IBGE — download automático (`00_dados_referencia.R`) |
| IBGE / SIDRA | Agropecuária: PAM (tab. 5457), LSPA (tab. 6588), PPM/abate/ovos (tabs. 74, 1092, 915); IPCA (tab. 1737); PIB anual RR (tab. 5938) | API SIDRA via `sidrar` |
| Portal da Transparência | Folha federal (SIAPE) — arquivos mensais ZIP por UF | Download manual; `bases_baixadas_manualmente/dados_siape_portal_transparencia/` |
| STN / SICONFI | Folha estadual e municipal — RREO Anexo 06 (pessoal ativo, elemento 31), 16 entes de RR | API pública `apidatalake.tesouro.gov.br` (sem autenticação) |
| ANEEL (SAMP) | Consumo de energia elétrica por classe — Roraima Energia S.A. (sistema isolado) | API CKAN `dadosabertos.aneel.gov.br` — download automático |
| MTE / CAGED | Microdados de emprego formal por seção CNAE (UF=14) | FTP MTE `ftp.mtps.gov.br` — download automático (~2,5 GB) |
| ANAC | Passageiros e carga aérea — aeroporto de Boa Vista (SBBV) | Download manual de ZIPs mensais; `bases_baixadas_manualmente/microdados_anac_mensal_.../` |
| ANP | Vendas de diesel por UF | Download automático — CSV dados abertos `gov.br/anp` |
| BCB Estban | Depósitos bancários totais em RR (verbete 160) | Download manual de ZIPs; `bases_baixadas_manualmente/dados_estban_bcb/` |
| BCB SCR | Carteira de crédito ativa em RR (dados abertos agregados) | Download manual de ZIPs; `bases_baixadas_manualmente/dados_bcb_src_2020_2025/` |
| SEFAZ-RR | ICMS estadual mensal (proxy do ILP) e ICMS por atividade trimestral (componente do bloco Comércio) | Download manual; `data/processed/icms_sefaz_rr_mensal.csv` e `icms_sefaz_rr_trimestral.csv` |

---

## Instituição e autoria

**Secretaria de Planejamento e Orçamento de Roraima — SEPLAN/RR**  
Coordenação-Geral de Estudos Econômicos e Sociais — CGEES

**Yuri Cesar de Lima e Silva**  
Chefe da Divisão de Estudos e Análises Sociais — DIEAS  
Coordenador da Equipe do PIB do Estado de Roraima — SEPLAN/RR
