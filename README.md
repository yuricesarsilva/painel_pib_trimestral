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

| Setor | Peso aprox. | Proxy principal | Fonte |
|---|---|---|---|
| Administração Pública | ~32% | Folha de pagamento (federal + estadual) | SIAPE / SEPLAN-RR |
| Outros serviços | ~13% | Emprego formal setorial + crédito | CAGED / BCB Estban |
| Comércio | ~12% | ICMS por atividade econômica | SEFAZ-RR |
| Construção Civil | ~8% | Emprego na construção | CAGED |
| Agropecuária | ~6% | Produção física de lavouras e pecuária | LSPA + IBGE Abate / SIDRA |
| Transportes | ~4% | Passageiros aéreos + vendas de diesel | ANAC / ANP |
| SIUP | ~3% | Consumo de energia elétrica | ANEEL / EPE |
| Intermediação financeira | ~3% | Depósitos e operações de crédito | BCB Estban |
| Indústria de transformação | ~2% | Emprego industrial + ICMS industrial | CAGED / SEFAZ-RR |

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
| ANEEL / EPE | Consumo de energia elétrica por UF | Portal ANEEL / BEN |
| ANAC | Passageiros e carga — aeroporto de Boa Vista | Portal ANAC |
| ANP | Vendas de diesel por UF | Portal ANP |

---

## Produto final

- **Índice trimestral**: série histórica a partir de 2020, com e sem ajuste sazonal, em CSV e XLSX
- **Dashboard interativo**: visualização da série geral e por componentes setoriais, com download dos dados
- **Nota técnica**: publicada a cada trimestre com análise conjuntural e metodologia

---

## Instituição responsável

**Secretaria de Estado do Planejamento e Desenvolvimento de Roraima — SEPLAN/RR**  
Diretoria de Estudos e Pesquisas Econômicas
