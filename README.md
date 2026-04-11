# Painel PIB Trimestral — Roraima

Indicador de Atividade Econômica Trimestral do Estado de Roraima, desenvolvido pela **Secretaria de Estado do Planejamento e Desenvolvimento de Roraima (SEPLAN/RR)** como proxy do PIB estadual trimestral.

---

## Sobre o projeto

O Brasil não dispõe de estimativas oficiais do PIB estadual em frequência trimestral. As **Contas Regionais do IBGE**, referência metodológica deste projeto, são publicadas apenas anualmente e com defasagem de cerca de dois anos. Este indicador preenche essa lacuna para Roraima, permitindo o acompanhamento da conjuntura econômica estadual em tempo mais próximo ao real.

A metodologia é convergente com a do **Índice de Atividade Econômica Regional (IBCR)** do Banco Central do Brasil, adaptada às especificidades de Roraima — um estado com estrutura econômica singular, alta participação do setor público e disponibilidade limitada de pesquisas estatísticas desagregadas.

---

## Metodologia resumida

O indicador é um **índice encadeado de volume** (sem unidade monetária), com período base médio de 2020 = 100. Não requer deflator estadual — o que resolve o principal obstáculo metodológico para estados sem IPCA próprio.

### Estrutura setorial e proxies

Pesos calculados a partir do **VAB a preços correntes das Contas Regionais do IBGE — Roraima 2023**
(publicação IBGE out/2025, VAB total = R$ 23,0 bilhões).

| Atividade (nomenclatura IBGE) | % VAB 2023 | VAB 2023 (R$ mi) | Proxy principal | Fonte |
|---|---|---|---|---|
| Adm., defesa, educação e saúde públicas e seguridade social | 46,21% | 10.629 | Folha de pagamento (federal + estadual) | SIAPE / SEPLAN-RR |
| Comércio e reparação de veículos automotores e motocicletas | 12,25% | 2.817 | ICMS por atividade econômica | SEFAZ-RR |
| Agropecuária | 8,87% | 2.040 | Produção física de lavouras e pecuária | LSPA / IBGE SIDRA |
| Atividades imobiliárias | 7,68% | 1.767 | Estoque de domicílios (tendência suavizada) | IBGE Censo / PNAD |
| Outros serviços | 7,63% | 1.756 | Emprego formal em serviços | CAGED |
| Eletricidade, gás, água, esgoto e resíduos (SIUP) | 5,40% | 1.243 | Consumo de energia elétrica | ANEEL / EPE |
| Construção | 4,89% | 1.125 | Estoque acumulado de emprego (CAGED F) + cimento SNIC (condicional) | CAGED / SNIC |
| Atividades financeiras, de seguros e serviços relacionados | 2,78% | 639 | Concessões de crédito (primária) + depósitos bancários (secundária) | BCB Nota de Crédito / Estban |
| Transporte, armazenagem e correio | 1,92% | 441 | Passageiros aéreos + vendas de diesel | ANAC / ANP |
| Indústrias de transformação | 1,31% | 301 | Energia industrial ANEEL (70%) + emprego CAGED C (30%) | ANEEL / CAGED |
| Informação e comunicação | 1,01% | 233 | Emprego em TI e telecom | CAGED |
| Indústrias extrativas | 0,05% | 12 | Peso negligenciável — absorvida em "Outros" | — |

### Principais escolhas metodológicas

- **Desagregação temporal**: método de Denton-Cholette (`tempdisagg`) — garante que a média dos quatro trimestres de cada ano reproduza o VAB anual das Contas Regionais do IBGE
- **Ajuste sazonal**: X-13ARIMA-SEATS (`seasonal`) — séries publicadas com e sem ajuste
- **LSPA**: como a pesquisa publica projeções anuais revisadas mensalmente (não fluxo mensal), a distribuição intra-anual é feita com coeficientes de época de colheita do Censo Agropecuário 2006
- **Pesos setoriais**: participação no VAB das Contas Regionais, revisados anualmente
- **Deflação de séries nominais**: IPCA nacional (não existe IPCA estadual para Roraima)
- **Cobertura temporal**: a partir de 2020 (início condicionado pela consistência do CAGED pós-eSocial)

---

## Estrutura do repositório

```
├── R/
│   ├── utils.R              # funções auxiliares: Denton, encadeamento, deflação
│   ├── 01_agropecuaria.R    # Fase 1: lavouras (LSPA) e pecuária
│   ├── 02_adm_publica.R     # Fase 2: administração pública (SIAPE + folha estadual)
│   ├── 03_industria.R       # Fase 3: construção, SIUP, indústria de transformação
│   ├── 04_servicos.R        # Fase 4: comércio, transportes, outros serviços
│   └── 05_agregacao.R       # Fase 5: agregação, ajuste sazonal, exportação
├── dashboard/
│   └── app.R                # dashboard interativo (Shiny / flexdashboard)
├── notas/
│   └── nota_tecnica.qmd     # nota técnica metodológica (Quarto → PDF)
├── Base metodológica/
│   └── *.pdf                # referências metodológicas (IBCR, IBC-Br e experiências estaduais)
├── plano_projeto.md                   # plano metodológico detalhado
└── README.md
```

> **Nota**: a pasta `data/` (dados brutos, processados e outputs) é mantida localmente e não é versionada.

---

## Pacotes R utilizados

| Pacote | Finalidade |
|---|---|
| `sidrar` | Acesso ao SIDRA/IBGE (LSPA, PAM, PPM, Abate, Leite, Ovos) |
| `tempdisagg` | Desagregação temporal Denton-Cholette |
| `seasonal` | Ajuste sazonal X-13ARIMA-SEATS |
| `tidyverse` | Manipulação e visualização de dados |
| `writexl` / `openxlsx` | Exportação em Excel |
| `httr2` / `jsonlite` | Coleta via APIs (Portal da Transparência, BCB, ANEEL, ANP) |
| `quarto` | Nota técnica em PDF |
| `shiny` / `flexdashboard` | Dashboard interativo |

---

## Fontes de dados

| Fonte | Dado | Acesso |
|---|---|---|
| IBGE / SIDRA | LSPA, PAM, PPM, Abate, Leite, Ovos, Contas Regionais | sidrar / API SIDRA |
| Portal da Transparência | Folha federal (SIAPE) por UF | API pública |
| SEPLAN-RR | Folha estadual | Interno |
| SEFAZ-RR | ICMS por atividade econômica | Interno |
| STN / SICONFI | Folha municipal estimada | Portal SOF |
| BCB Estban | Crédito e depósitos por UF | BCB open data |
| ANEEL (SAMP) | Consumo de energia elétrica por classe de consumidor (RR) | API CKAN dadosabertos.aneel.gov.br |
| MTE / CAGED | Microdados de emprego formal por seção CNAE (UF=14) | FTP ftp.mtps.gov.br |
| ANAC | Passageiros e carga — aeroporto de Boa Vista | Portal ANAC |
| ANP | Vendas de diesel por UF | Portal ANP |

---

## Produto final

- **Índice trimestral**: série histórica a partir de 2020, com e sem ajuste sazonal, em CSV e XLSX
- **Dashboard interativo**: visualização da série geral e por componentes setoriais, com download dos dados
- **Nota técnica**: publicada a cada trimestre com análise conjuntural e metodologia

---

## Instituição

**Secretaria de Planejamento e Orçamento de Roraima — SEPLAN/RR**  
Coordenação-Geral de Estudos e Econômicos e Sociais - CGEES
## Autoria do projeto

**Yuri Cesar de Lima e Silva**  
Chefe da Divisão de Estudos e Análises Sociais - DIEAS  
Coordenador da Equipe do PIB do Estado de Roraima - SEPLAN/RR


