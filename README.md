# Indicador de Atividade Econômica Trimestral — Roraima (IAET-RR)

Desenvolvido pela **Secretaria de Estado do Planejamento e Desenvolvimento de Roraima (SEPLAN/RR)** como proxy do PIB estadual trimestral, o IAET-RR mede a atividade econômica de Roraima com frequência trimestral a partir de 2020, em termos reais (base média de 2020 = 100).

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
| Sensibilidade do calendário (`05b_sensibilidade_calendario.R`) | ✅ Operacional | 2020T1–2025T4 |
| Ajuste sazonal (`05c_ajuste_sazonal.R`) | ✅ Operacional | 2020T1–2025T4 |
| Validação final (`05d_validacao.R`) | ✅ Operacional | 2020T1–2025T4 |
| Exportação (`05e_exportacao.R`) | ✅ Operacional | 2020T1–2025T4 |
| VAB Nominal trimestral (`05f_vab_nominal.R`) | ✅ Operacional | 2020T1–2025T4 |
| Dashboard interativo (`dashboard/app.R`) | ✅ Operacional | — |
| Nota técnica | ⬜ Não iniciada | — |

**Últimas taxas de crescimento do IAET-RR (real, base 2020 = 100):**

| Ano | IAET-RR (real) | IBCR Norte | IBC-Br |
|---|---|---|---|
| 2021 | +8,2% | +7,2% | +4,2% |
| 2022 | +10,9% | −1,2% | +2,8% |
| 2023 | +4,3% | +1,7% | +2,7% |
| 2024 | +7,7% *(extrapolado)* | +4,1% | +3,7% |
| 2025 | +9,2% *(extrapolado)* | +1,7% | +2,5% |

> Os anos 2024–2025 são extrapolados com tendência geométrica dos últimos dois anos de benchmark disponível (CR IBGE 2023). Serão substituídos pelos valores definitivos quando as Contas Regionais 2024 forem publicadas (previsão IBGE: outubro de 2026).

---

## Próximos passos

| Prioridade | Tarefa | Dependência |
|---|---|---|
| 🔴 Alta | Incorporar CR IBGE 2024 quando publicada (out/2026): substituir extrapolações 2024 por dados reais | Publicação IBGE |
| 🔴 Alta | Obter ICMS por atividade econômica da SEFAZ-RR e incorporar ao bloco Comércio | SEFAZ-RR |
| 🟡 Média | Testar responsividade e publicar o dashboard Shiny em ambiente institucional | Infraestrutura SEPLAN/RR ou Shinyapps.io |
| 🟡 Média | Redigir nota técnica metodológica (`notas/nota_tecnica.qmd`) | — |
| 🟡 Média | Avaliar correlação IAET-RR × arrecadação tributária total de RR | ICMS anual SEFAZ-RR |
| 🟢 Baixa | Revisão periódica do calendário de colheita SEADI-RR (sensibilidade alta à soja) | SEADI-RR |
| 🟢 Baixa | Incorporar cimento SNIC como segunda proxy de Construção | SNIC |

---

## Sobre o projeto

O Brasil não dispõe de estimativas oficiais do PIB estadual em frequência trimestral. As **Contas Regionais do IBGE**, referência metodológica deste projeto, são publicadas apenas anualmente e com defasagem de cerca de dois anos. O IAET-RR preenche essa lacuna, permitindo o acompanhamento da conjuntura econômica estadual em tempo próximo ao real.

A metodologia é convergente com a do **Índice de Atividade Econômica Regional (IBCR)** do Banco Central do Brasil, adaptada às especificidades de Roraima — estado com estrutura econômica singular, alta participação do setor público (46% do VAB) e disponibilidade limitada de pesquisas estatísticas desagregadas.

---

## Metodologia

### Fórmula do índice

**Índice de Laspeyres encadeado por volume** — padrão das Contas Nacionais do IBGE:
- Período base: média de 2020 = 100
- Pesos setoriais: participação no VAB nominal de **2020** (ano base), calculados dinamicamente das Contas Regionais IBGE
- Desagregação trimestral: **Denton-Cholette** (`tempdisagg`) — a média dos quatro trimestres de cada ano reproduz o benchmark anual das Contas Regionais
- Ajuste sazonal: **X-13ARIMA-SEATS** (`seasonal`)

Nos subblocos, o projeto distingue dois tipos de ponderação:
- pesos contábeis de agregação entre setores/subsetores, alinhados ao ano-base de 2020 sempre que disponíveis nas Contas Regionais;
- pesos técnicos entre proxies de um mesmo subsetor, definidos pragmaticamente pela qualidade e disponibilidade dos dados.

### Benchmark do Denton-Cholette

O benchmark anual utiliza o **índice encadeado de volume** das Contas Regionais do IBGE (arquivo `Especiais_2002_2023_xls.zip`, aba `tab05.xls`, série base 2002 = 100, rebaseada para 2020 = 100) — e não o VAB a preços correntes (nominal).

> **Por que volume e não nominal?** As proxies trimestrais são indicadores de volume (emprego, energia, passageiros). Usar o VAB nominal como benchmark introduz inflação setorial no índice, gerando crescimentos artificialmente elevados. Com o benchmark de volume, as taxas anuais refletem crescimento real e são diretamente comparáveis ao IBCR do Banco Central.

### Estrutura setorial e proxies

| Atividade | % VAB 2023¹ | Proxy principal | Fonte |
|---|---|---|---|
| Adm., defesa, educação e saúde públicas e seguridade social | 46,21% | Folha de pagamento (federal + estadual + municipal) | SIAPE / SEPLAN-RR / SICONFI |
| Comércio e reparação de veículos | 12,25% | Energia comercial ANEEL (67%) + emprego CAGED G (33%)² | ANEEL / MTE |
| Agropecuária | 8,87% | Produção física lavouras (PAM/LSPA) + pecuária (PPM/abate) | IBGE SIDRA |
| Atividades imobiliárias | 7,68% | Interpolação linear entre benchmarks CR IBGE | CR IBGE |
| Outros serviços | 7,63% | Emprego formal — seções I, M+N, P+Q (CAGED) | MTE |
| Eletricidade, gás, água, esgoto e resíduos (SIUP) | 5,40% | Consumo de energia elétrica por classe | ANEEL |
| Construção | 4,89% | Estoque acumulado de emprego CAGED F | MTE |
| Atividades financeiras e de seguros | 2,78% | Concessões de crédito BCB (70%) + depósitos Estban (30%) | BCB |
| Transporte, armazenagem e correio | 1,92% | Passageiros ANAC (40%) + carga ANAC (30%) + diesel ANP (30%) | ANAC / ANP |
| Indústrias de transformação | 1,31% | Energia industrial ANEEL (70%) + emprego CAGED C (30%) | ANEEL / MTE |
| Informação e comunicação | 1,01% | Emprego em TI/telecom (CAGED J) | MTE |
| Indústrias extrativas | 0,05% | Interpolação linear CR IBGE (peso negligenciável) | CR IBGE |

¹ Participações de referência informativa (CR IBGE 2023). Os **pesos efetivos do índice** usam participações de 2020 (ano base Laspeyres), calculados dinamicamente de `contas_regionais_RR_serie.csv`.  
² ICMS por atividade (SEFAZ-RR) ainda não disponível; será incorporado quando obtido (altera pesos do bloco Comércio para energia 40% + ICMS 40% + CAGED 20%).

### Produto derivado — VAB Nominal Trimestral

O script `R/05f_vab_nominal.R` gera um índice do VAB nominal trimestral (preços correntes, base 2020 = 100) como produto derivado:

```
Índice nominal = Índice real × Deflator implícito / 100
```

O deflator implícito anual é calculado diretamente das Contas Regionais (VAB nominal / VAB real) e desagregado para frequência trimestral via Denton-Cholette com o IPCA como proxy.

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
│   ├── 05b_sensibilidade_*.R     # testes de sensibilidade (calendário agrícola)
│   ├── 05c_ajuste_sazonal.R      # X-13ARIMA-SEATS
│   ├── 05d_validacao.R           # validação: CR IBGE, IBCR Norte, IBC-Br
│   ├── 05e_exportacao.R          # exportação Excel e CSVs de publicação
│   ├── 05f_vab_nominal.R         # deflator implícito e índice nominal trimestral
│   └── exploratorio/             # scripts históricos de inspeção de dados
├── data/
│   └── referencias/              # calendários de colheita e referências versionadas
│   (raw/, processed/, output/ — mantidos localmente, não versionados)
├── logs/
│   └── fontes_utilizadas.csv     # rastreabilidade das fontes por release
├── plano_projeto.md              # plano metodológico detalhado
├── plano_reforma_indicador_real.md  # plano da reforma de ancoragem ao volume real
├── checklist.md                  # checklist geral do projeto
├── checklist_reforma.md          # checklist da reforma metodológica (abr/2026)
├── historico_simples.md          # histórico do projeto em linguagem acessível
└── regras.md                     # protocolo obrigatório de sessão e manutenção
```

---

## Saídas de dados

Salvas em `data/output/` (não versionadas — disponíveis mediante solicitação):

| Arquivo | Conteúdo |
|---|---|
| `IAET_RR_series.xlsx` | Excel com 6 abas: Índice Geral, Componentes, Dessazonalizado, Fatores Sazonais, Metadados, VAB Nominal |
| `indice_geral_rr.csv` | Índice geral trimestral NSA (2020T1–2025T4) |
| `indice_geral_rr_sa.csv` | Índice geral dessazonalizado (SA) + componentes |
| `fatores_sazonais.csv` | Fatores sazonais aditivos por componente |
| `indice_nominal_rr.csv` | Índice nominal (real × deflator implícito) |
| `validacao_relatorio.csv` | Relatório de validação (4 eixos) |

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
| IBGE Contas Regionais | VAB nominal e índice de volume por atividade — Roraima | FTP IBGE |
| IBGE / SIDRA | LSPA, PAM, PPM, Abate, Leite, Ovos | API SIDRA (`sidrar`) |
| Portal da Transparência | Folha federal (SIAPE) por UF | API pública |
| SEPLAN-RR | Folha estadual de Roraima | Interno |
| STN / SICONFI | Folha municipal estimada | Portal SOF |
| BCB SGS / Estban / SCR | IPCA, crédito, depósitos bancários por UF | BCB open data |
| ANEEL (SAMP) | Consumo de energia elétrica por classe e UF | API CKAN ANEEL |
| MTE / CAGED | Microdados de emprego formal por CNAE (UF=14) | FTP MTE |
| ANAC | Passageiros e carga — aeroporto de Boa Vista (SBBV) | Portal ANAC |
| ANP | Vendas de diesel por UF | Portal ANP |

---

## Instituição e autoria

**Secretaria de Estado do Planejamento e Desenvolvimento de Roraima — SEPLAN/RR**  
Coordenação-Geral de Estudos Econômicos e Sociais — CGEES

**Yuri Cesar de Lima e Silva**  
Chefe da Divisão de Estudos e Análises Sociais — DIEAS  
Coordenador da Equipe do PIB do Estado de Roraima — SEPLAN/RR
