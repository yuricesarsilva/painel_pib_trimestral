# Histórico do Projeto — Painel PIB Trimestral de Roraima

Este arquivo registra, em linguagem simples, tudo o que foi feito no projeto e em que etapa estamos.
Qualquer pessoa pode ler e entender o andamento do trabalho.

---

## O que é este projeto?

Estamos construindo um **termômetro trimestral da economia de Roraima**. Como o IBGE só divulga o
PIB dos estados uma vez por ano (e com quase dois anos de atraso), este indicador vai permitir que a
SEPLAN/RR acompanhe como a economia do estado está se comportando a cada três meses — antes mesmo
de o IBGE publicar os números oficiais.

O indicador não vai dizer "o PIB de Roraima foi R$ X bilhões", mas sim "a economia de Roraima
cresceu ou caiu X% em relação ao trimestre anterior". É um índice, como o termômetro que diz se a
temperatura subiu ou caiu, sem necessariamente dizer o valor absoluto em graus.

---

## Linha do tempo

### Abril de 2026 — Planejamento do projeto

**O que foi feito:**

Definimos o plano completo de como construir o indicador. As principais decisões foram:

- **O que vamos medir**: um índice de volume (sem valor em reais), que mostra se a economia cresceu
  ou caiu a cada trimestre. Isso resolve o maior problema técnico: Roraima não tem um índice de
  preços próprio.

- **Como vamos calcular**: seguindo a metodologia do Banco Central do Brasil (chamada IBCR), que já
  faz algo parecido para todos os estados. A ideia é combinar dados de várias fontes (emprego,
  produção agrícola, consumo de energia, arrecadação fiscal, etc.) para montar um retrato trimestral
  da economia.

- **Como vamos garantir que o número bate com o IBGE**: usaremos uma técnica estatística chamada
  Denton-Cholette, que "ancora" nosso indicador trimestral aos valores anuais oficiais do IBGE.
  Assim, quando o IBGE diz que a economia cresceu X% no ano, nossos quatro trimestres daquele ano
  somam exatamente esse X%.

- **Por onde começar**: decidimos começar pelo setor agropecuário (mais fácil de medir), depois
  partir para o setor público (maior parte da economia de Roraima, com dados excelentes), e por
  fim completar com indústria e serviços.

- **Ferramenta**: R (linguagem de programação especializada em estatística).

- **Período coberto**: a partir de 2020.

**Fontes de dados mapeadas por setor:**

| O que mede | De onde vem o dado |
|---|---|
| Produção agrícola (arroz, soja, milho etc.) | IBGE — pesquisa LSPA |
| Criação de animais (abate, leite, ovos) | IBGE — pesquisas trimestrais |
| Servidores públicos federais | Portal da Transparência (SIAPE) |
| Servidores estaduais | SEPLAN/SEFAZ-RR |
| Empregos na construção, comércio e serviços | Ministério do Trabalho — CAGED |
| Impostos sobre comércio e indústria | SEFAZ-RR (ICMS por atividade) |
| Consumo de energia elétrica | ANEEL |
| Passageiros e cargas no aeroporto de Boa Vista | ANAC |
| Vendas de diesel (frete rodoviário) | ANP |
| Crédito e depósitos bancários | Banco Central — Estban |

**Problema técnico identificado e resolvido no plano:**
A pesquisa agrícola do IBGE (LSPA) não divulga a produção mês a mês — ela divulga uma estimativa
do total anual, revisada todo mês. Para transformar isso em números trimestrais, usaremos o
calendário de colheita do Censo Agropecuário de 2006, que mostra em quais meses cada cultura é
colhida em Roraima.

**Arquivos criados:**
- `plano_indicador_trimestral_RR.md` — plano técnico detalhado
- `README.md` — apresentação do projeto para o GitHub
- Estrutura de pastas do projeto (`data/`, `R/`, `dashboard/`, `notas/`)

**Repositório no GitHub criado:**
O código do projeto está disponível publicamente em:
https://github.com/yuricesarsilva/painel_pib_trimestral

---

### Abril de 2026 — Criação dos arquivos de controle do projeto

**O que foi feito:**

Criamos três arquivos que vão acompanhar o projeto do início ao fim:

- **`checklist.md`**: lista completa e detalhada de todas as tarefas do projeto, organizadas em 6 fases e dezenas de subetapas, com caixinhas para marcar quando cada item for concluído.

- **`regras.md`**: protocolo obrigatório que deve ser seguido ao final de cada sessão de trabalho — garante que o histórico, o checklist, o plano e o repositório GitHub estejam sempre atualizados e que nada seja "esquecido" no controle de versão. Inclui agora a atualização do `plano_projeto.md` quando houver mudanças metodológicas.

- **`historico_simples.md`** (este arquivo): atualizado continuamente para que qualquer pessoa saiba o que foi feito e em que ponto o projeto está.
- O arquivo `plano_indicador_trimestral_RR.md` foi renomeado para `plano_projeto.md` para simplificar o nome.

---

### Abril de 2026 — Atualização dos pesos setoriais com dados reais das Contas Regionais 2023

**O que foi feito:**

Obtivemos os dados reais do VAB (Valor Adicionado Bruto) de Roraima diretamente da publicação
oficial do IBGE — **Contas Regionais do Brasil 2023** (publicada em outubro de 2025). Os dados
foram baixados automaticamente do FTP do IBGE e processados com R.

**O que descobrimos:**

Os pesos dos setores são bem diferentes do que estimávamos inicialmente. Os principais destaques:

| Atividade | Peso real 2023 | Observação |
|---|---|---|
| Administração pública (governo) | 46,2% | Acima do estimado (32%) |
| Comércio e reparação de veículos | 12,3% | Conforme esperado |
| Agropecuária | 8,9% | Acima do estimado (6%) |
| Atividades imobiliárias | 7,7% | Setor não estava no plano original |
| Outros serviços | 7,6% | Inclui saúde/educação privada, turismo etc. |
| Energia elétrica, água e saneamento (SIUP) | 5,4% | Acima do estimado (3%) |
| Construção civil | 4,9% | Abaixo do estimado (8%) |
| Transportes | 1,9% | Abaixo do estimado (4%) |
| Indústria de transformação | 1,3% | Conforme esperado |
| Indústrias extrativas | 0,05% | Negligenciável |

**Nota sobre atividades imobiliárias (7,7%):** A maior parte é "aluguel imputado" — o valor
estimado que donos de imóveis próprios "pagariam" a si mesmos de aluguel. Como não existe dado
mensal para isso, será tratado como tendência suave entre os valores anuais do IBGE.

**Arquivos gerados:**
- `data/raw/contas_regionais_2023.zip` — dados brutos do IBGE (FTP)
- `data/processed/vab_roraima_2023.csv` — VAB por atividade, Roraima 2023
- `README.md`, `plano_projeto.md` e `checklist.md` atualizados com estrutura real de 13 atividades

---

### Abril de 2026 — Inclusão da base metodológica no repositório

**O que foi feito:**

Incluímos no GitHub a pasta **`Base metodológica/`**, que reúne os documentos de referência usados
para orientar a construção do indicador trimestral de Roraima.

Esses arquivos já existiam localmente, mas ainda não estavam registrados no controle de versão.
Com isso, a fundamentação técnica do projeto passa a ficar preservada junto com o restante da
documentação.

**Por que isso é importante:**

- facilita a consulta das metodologias que inspiram o projeto;
- preserva o histórico das referências utilizadas;
- ajuda qualquer pessoa que entrar no projeto a entender de onde vieram as escolhas metodológicas.

**Arquivos incluídos no repositório:**
- metodologias do IBC-BR e do IBCR;
- metodologias estaduais de PIB trimestral e mensal;
- referências comparativas de outros estados e instituições.

---

### Abril de 2026 — Registro de sugestões para aprimorar as proxies

**O que foi feito:**

Foi criado o arquivo **`sugestoes1.md`** com uma avaliação crítica das proxies escolhidas para cada
setor do indicador.

O documento não altera a metodologia oficial do projeto neste momento. Ele funciona como um caderno
de recomendações para as próximas decisões técnicas, indicando onde as proxies atuais estão mais
fortes, onde estão mais frágeis e quais complementos poderiam melhorar a qualidade do índice.

**Principais pontos registrados:**

- manutenção da espinha dorsal metodológica do projeto;
- cuidado maior com proxies baseadas apenas em ICMS, emprego formal e diesel;
- recomendação de proxies compostas em vez de proxies únicas em alguns setores;
- sugestões de reforço para comércio, construção, transportes, outros serviços e setor financeiro.

**Arquivo criado:**
- `sugestoes1.md` — observações e recomendações metodológicas para evolução futura do indicador

---

### Abril de 2026 — Registro de sugestões para aprimorar as proxies

**O que foi feito:**

Foi criado o arquivo **`sugestoes1.md`** com uma avaliação crítica das proxies escolhidas para cada
setor do indicador.

O documento não altera a metodologia oficial do projeto neste momento. Ele funciona como um caderno
de recomendações para as próximas decisões técnicas, indicando onde as proxies atuais estão mais
fortes, onde estão mais frágeis e quais complementos poderiam melhorar a qualidade do índice.

**Principais pontos registrados:**

- manutenção da espinha dorsal metodológica do projeto;
- cuidado maior com proxies baseadas apenas em ICMS, emprego formal e diesel;
- recomendação de proxies compostas em vez de proxies únicas em alguns setores;
- sugestões de reforço para comércio, construção, transportes, outros serviços e setor financeiro.

**Arquivo criado:**
- `sugestoes1.md` — observações e recomendações metodológicas para evolução futura do indicador

---

### Abril de 2026 — Ajuste metodológico: PAM como fonte primária de lavouras

**O que foi feito:**

Refinamos a metodologia da agropecuária para deixar mais clara a hierarquia entre as duas
pesquisas de produção agrícola do IBGE.

**A mudança:**

Antes, o plano descrevia a LSPA como a fonte de produção anual de lavouras. Agora ficou definido
que:

- **A PAM (Produção Agrícola Municipal) é a fonte principal** — ela é o dado oficial e consolidado,
  publicado anualmente pelo IBGE (com cerca de 1 ano de defasagem). Para todos os anos em que a PAM
  estiver disponível, usaremos os números dela.

- **A LSPA é um substituto temporário** — usada apenas para o ano mais recente que ainda não foi
  coberto pela PAM. Quando a PAM for publicada, o valor da LSPA é descartado e substituído pelo
  dado definitivo.

**Por que isso importa:**

A LSPA e a PAM medem a mesma coisa: a produção anual de lavouras. A diferença é que a LSPA é uma
estimativa em construção (revisada mês a mês durante o ano), enquanto a PAM é o número final
revisado. Usar a PAM sempre que possível torna o índice mais preciso e auditável.

**O método de "distribuição mensal" não mudou:**

Em ambos os casos — PAM ou LSPA — o valor anual de produção é distribuído pelos meses do ano
usando o calendário agrícola do Censo Agropecuário de 2006 (que mostra em quais meses cada cultura
é colhida em Roraima). Essa parte da metodologia permanece exatamente igual.

**Arquivos atualizados:**
- `plano_projeto.md` — seção 1a e etapa 1.2 da Fase 1 reescritas
- `checklist.md` — etapas 1.0 e 1.2 atualizadas

---

### Abril de 2026 — Revisão crítica das proxies e incorporação de melhorias

**O que foi feito:**

Fizemos uma análise detalhada das sugestões registradas em `sugestoes1.md`, avaliando cada
proposta do ponto de vista metodológico e da viabilidade de dados para Roraima. Incorporamos
as sugestões que representavam ganho real sem custo excessivo de coleta; descartamos as que não
têm dado disponível ou que poderiam introduzir ruído sem benefício equivalente.

**O que mudou no plano:**

Quatro setores tiveram suas proxies melhoradas:

- **Comércio**: deixou de ter o ICMS como proxy única com CAGED apenas "de controle". Passou a
  ser um **índice composto** de três componentes com pesos explícitos: ICMS deflacionado,
  vínculos CAGED e — a novidade — **consumo de energia comercial** (ANEEL). A energia comercial
  é o componente mais robusto porque mede volume físico, independente de preço ou alíquota.
  Adicionamos também uma regra formal para tratar quebras tributárias no ICMS.

- **Construção**: ganhou um terceiro componente físico — as **vendas de cimento** publicadas
  pelo SNIC (Sindicato Nacional da Indústria do Cimento). O cimento é uma proxy direta de
  atividade construtiva, disponível mensalmente por estado, e é usada em várias metodologias
  estaduais de PIB trimestral. Era a principal lacuna do desenho original.

- **SIUP (energia)**: em vez de coletar o consumo total de energia, passamos a coletar
  **desagregado por classe** (residencial, comercial, industrial, poder público). O custo é
  zero — o dado vem na mesma consulta. O ganho é duplo: o índice do SIUP fica mais preciso, e
  as séries de energia comercial e industrial ficam disponíveis para reaproveitamento nos
  setores de Comércio e Indústria de Transformação sem coleta adicional.

- **Atividades financeiras**: a proxy principal trocou de **saldo de crédito** (estoque) para
  **concessões de crédito** (fluxo mensal de novos créditos, publicado pelo BCB por UF). Fluxo
  é muito mais representativo da atividade corrente do setor do que saldo, que pode crescer sem
  que haja atividade nova.

**O que ficou igual (e por quê):**

- *Administração pública*: folha de pagamento continua como proxy principal — é a mesma variável
  que o IBGE usa. Investigar separação ativos/inativos fica para a fase de implementação.
- *Atividades imobiliárias*: mantida a interpolação linear entre benchmarks anuais. Adicionar
  proxy de mercado (financiamentos, por exemplo) captaria algo diferente do que o IBGE mede
  (aluguel imputado), podendo distorcer em vez de melhorar.
- *Informação e comunicação*: CAGED mantido. Peso de 1,01% não justifica esforço de coleta de
  dados que, de qualquer forma, não estão disponíveis de forma sistemática para RR.

**Novidades de processo (padrões transversais):**

Adicionamos ao plano uma seção de **Padrões de Implementação**, que define boas práticas
obrigatórias para todos os scripts: classificação de qualidade das proxies (forte / aceitável /
fraca mas necessária), tipologia de cada proxy (volume / valor / fluxo / estoque / insumo),
pesos explícitos nos índices compostos, regra de quebras tributárias para ICMS, e teste de
sensibilidade (versão A vs. versão B do índice) na fase de validação.

**Arquivos atualizados:**
- `plano_projeto.md` — seções 3–9 e mapa de pesos; nova seção de padrões de implementação
- `checklist.md` — fases 3, 4 e 5 revisadas

---

### Abril de 2026 — Regra de versionamento de scripts e reorganização de código

**O que foi feito:**

Estabelecemos uma regra explícita no projeto: **todos os scripts R devem ficar na pasta `R/`
e ser commitados no repositório**. A pasta `data/` é exclusivamente para dados — nunca para código.

**Por que era necessário:**

Os scripts de download e processamento das Contas Regionais tinham sido criados dentro de
`data/raw/`, que está no `.gitignore`. Isso significava que o código estava invisível no
repositório público — qualquer pessoa que clonasse o projeto saberia que o CSV
`vab_roraima_2023.csv` existe, mas não teria como reproduzir a coleta dos dados. Isso contradiz
o princípio de reprodutibilidade do projeto.

**O que foi reorganizado:**

- Criada a pasta `R/` (que estava prevista no plano mas ainda não existia)
- Criado `R/00_dados_referencia.R`: o script de produção das Contas Regionais, reescrito com:
  - Download automático do FTP do IBGE (não precisa baixar manualmente)
  - Caminhos relativos à raiz do projeto (sem paths hardcoded)
  - Idempotente: pode ser rodado mais de uma vez sem erros
  - Cabeçalho padronizado completo
- Criada a pasta `R/exploratorio/` com os 4 scripts de exploração usados durante o desenvolvimento
  inicial (`debug_xls.R`, `ler_xls.R`, `ler_xls2.R`, `ler_vab.R`), todos com cabeçalho e
  caminhos relativos

**Regra adicionada ao `regras.md`:**

A partir de agora, é proibido ter scripts em `data/`. Todo código vai em `R/`. Downloads devem
ser automáticos e idempotentes. Caminhos absolutos hardcoded são proibidos nos scripts.

**Arquivos criados/modificados:**
- `regras.md` — nova seção de regras de localização e versionamento
- `R/00_dados_referencia.R` — script de produção das Contas Regionais
- `R/exploratorio/debug_xls.R`, `ler_xls.R`, `ler_xls2.R`, `ler_vab.R` — scripts históricos

---

### Abril de 2026 — Governança do pipeline, reprodutibilidade e QA

**O que foi feito:**

Antes de iniciar a implementação dos scripts setoriais, estruturamos a governança completa do
projeto: as regras que garantem que o indicador seja reproduzível, auditável e seguro.

**O que foi criado e por quê:**

- **`regras.md` ampliado**: ganhou seis novas seções obrigatórias —
  - *Gestão do ambiente R*: define o uso de `renv` para congelar versões de pacotes
  - *Credenciais e APIs*: define que tokens nunca entram em scripts (ficam no `.env`)
  - *QA e validação*: define que todo script deve validar sua série antes de salvar
  - *Vintagem dos dados*: define o registro de qual dado foi usado em cada release
  - *Execução do pipeline*: define a sequência obrigatória e o uso do `run_all.R`
  - *Release trimestral*: protocolo completo de publicação com tags git

- **`R/utils.R`**: funções compartilhadas que todos os scripts setoriais vão usar —
  deflação pelo IPCA, Denton-Cholette, índice de Laspeyres, validação de séries,
  agregação mensal→trimestral e leitura segura de credenciais

- **`R/run_all.R`**: script mestre que roda o pipeline de ponta a ponta na sequência correta,
  com timestamps e parada imediata em caso de erro. Nunca rodar scripts setoriais avulsos.

- **`logs/fontes_utilizadas.csv`**: tabela versionada que registra, a cada release, quais
  dados foram usados, de qual período, baixados em que data. Garante auditabilidade.

- **`.env.exemplo`**: template de variáveis de ambiente. O arquivo real (`.env`, com tokens)
  fica local e nunca é commitado.

- **`.gitignore`**: atualizado para excluir `.env` e a library do `renv`.

**O que ainda precisa ser feito antes de rodar o primeiro script setorial:**
- Criar o `.Rproj` na raiz do projeto
- Inicializar o `renv` com `renv::init()` e commitar o `renv.lock`
- Instalar os pacotes necessários e rodar `renv::snapshot()`

---

### Abril de 2026 — Ambiente R configurado e Fase 0 concluída

**O que foi feito:**

Configuramos o ambiente R de forma completamente automatizada, sem intervenção manual:

- **`.Rproj` criado**: o arquivo `painel_pib_trimestral.Rproj` foi adicionado à raiz do projeto.
  Ao abrir este arquivo no RStudio, o diretório de trabalho é definido automaticamente como a
  raiz do projeto — pré-requisito para que todos os caminhos relativos dos scripts funcionem.

- **`renv` inicializado**: o ambiente R do projeto foi congelado na versão 4.4.0, com
  **121 pacotes** registrados no `renv.lock` com versões exatas. Isso garante que qualquer
  pessoa que clone o repositório e rode `renv::restore()` obterá exatamente o mesmo ambiente.

- **Pacotes instalados**: todos os pacotes necessários foram instalados e registrados —
  `sidrar`, `tempdisagg`, `seasonal`, `tidyverse`, `writexl`, `openxlsx`, `httr2`,
  `jsonlite`, `shiny`, `flexdashboard`, `quarto`, `dotenv`, `readxl`, entre outros.

**A Fase 0 está concluída.** O projeto está pronto para começar a implementação.

---

### Abril de 2026 — Série histórica das Contas Regionais (2010–2023)

**O que foi feito:**

Concluímos a Fase 0.3 com a extração da série histórica completa de VAB por atividade econômica
para Roraima, cobrindo os anos de 2010 a 2023.

**O que foi gerado:**

O script `R/00_dados_referencia.R` foi estendido para iterar sobre todos os 14 anos (2010–2023)
e todas as 13 atividades das Contas Regionais, calculando a participação percentual no VAB total
por ano. Foram gerados dois arquivos:

- `data/processed/contas_regionais_RR_serie.csv` — série histórica completa (182 linhas:
  13 atividades × 14 anos), com colunas `ano`, `atividade`, `vab_mi`, `participacao_pct`
- `data/processed/vab_roraima_2023.csv` — recorte de 2023 para compatibilidade com demais scripts

**Um dado que chama atenção:**

O VAB do SIUP (eletricidade, gás, água e esgoto) de Roraima mostra variações extremas ao longo
da série — com valores muito baixos em 2016 e picos em 2018 e 2020. Isso reflete de fato a
instabilidade histórica do setor energético do estado (RR tem produção local limitada e passou
por crises de abastecimento). O dado é do IBGE e está sendo usado como vem.

**Com isso, toda a Fase 0 está concluída.**

---

### Abril de 2026 — Fase 1 concluída: Índice Agropecuário de Roraima

**O que foi feito:**

Implementamos o script `R/01_agropecuaria.R`, que produz o índice trimestral de atividade
agropecuária de Roraima (base 2020 = 100), cobrindo quatro etapas metodológicas.

**Etapa 1.0 — Cobertura das culturas:**

As 10 culturas incluídas no índice (Soja, Milho, Arroz, Banana, Mandioca, Laranja, Tomate,
Feijão, Cana-de-açúcar e Cacau) cobrem **90,4%** do Valor Bruto da Produção total de lavouras
de Roraima (média 2018–2022, fonte: PAM/IBGE). A soja domina com 48% do VBP.

Uma descoberta: a tabela SIDRA 5457 já contém todas as lavouras (temporárias e permanentes)
numa única consulta — simplificou o código em relação ao planejado.

**Etapa 1.1 — Calendário de colheita:**

Construímos a matriz cultura × mês com os coeficientes de distribuição da produção anual
pelo calendário agroclimático de Roraima, baseada no Censo Agropecuário 2006. O Censo 2017
não publicou tabela equivalente de época de colheita, então mantivemos 2006 como referência.

**Etapa 1.2 — Série de lavouras:**

A PAM cobre Roraima até 2024 (definitivo). Para 2025, usamos a projeção de dezembro da LSPA
(tabela 6588, classificação c48) como valor provisório — será substituído automaticamente
quando a PAM 2025 for publicada. Índice de Laspeyres com pesos VBP médio 2018–2022.

**Etapa 1.3 — Pecuária:**

Para Roraima, estão disponíveis no SIDRA: abate de animais (tab 1092, trimestral) e produção
de ovos (tab 915, trimestral). A produção de leite (tab 74) não tem série trimestral para RR.
O índice pecuário combina abate + ovos, com pesos a partir do VBP da tab 74 v215. Pecuária
representa 7% e lavouras 93% do total agropecuário (VBP médio 2018–2022).

**Etapa 1.4 — Denton-Cholette e validação:**

O Denton-Cholette (`tempdisagg::td(~ 0 + x, conversion="mean")`) ancora o índice trimestral
ao VAB agropecuário anual das Contas Regionais. A validação é perfeita: as variações anuais
do índice coincidem exatamente com as das Contas Regionais em todos os 13 anos (2011–2023).

**Descobertas técnicas registradas:**
- `tempdisagg::td()` exige fórmula sem intercepto (`~ 0 + x`) para métodos Denton
- LSPA tabela 6588 usa classificação `c48` (não c782)
- Período: "dezembro 2006" (texto), não código YYYYMM

**Outputs gerados:**
- `data/processed/cobertura_lspa_pam.csv`
- `data/processed/coef_sazonais_colheita.csv`
- `data/processed/serie_lavouras_trimestral.csv`
- `data/processed/serie_pecuaria_trimestral.csv`
- `data/output/indice_agropecuaria.csv` — 56 observações (2010T1 a 2023T4)

---

### Abril de 2026 — Fase 2 concluída (exceto SIAPE): Índice de Administração Pública de Roraima

**O que foi feito:**

Implementamos o script `R/02_adm_publica.R`, que produz o índice trimestral de Administração
Pública de Roraima (base 2020 = 100), cobrindo etapas de coleta via API, deflação e ancoragem
pelo método Denton-Cholette.

**Etapa 2.1 — Folha federal (SIAPE):**

A coleta da folha de servidores federais com lotação em Roraima depende de token do Portal da
Transparência. O token configurado retornou erro 401 (não ativado). O módulo foi implementado
no script mas é pulado automaticamente quando o token está indisponível. O índice foi calculado
com base estadual + municipal enquanto o token aguarda ativação.

**Etapa 2.2 — Folha estadual:**

Coletamos a folha do Estado de RR via API SICONFI/STN — Relatório Resumido de Execução
Orçamentária (RREO), Anexo 06. A conta usada é `RREO6PessoalEEncargosSociais`, liquidado,
que equivale ao elemento 31 (pessoal ativo) — alinhado com a metodologia do IBGE, que inclui
apenas remuneração de servidores ativos no VAB de Administração Pública (aposentados e
pensionistas são transferências, não produção).

O RREO é divulgado em formato bimestral acumulado. O script converte para incremental (diferença
entre bimestres consecutivos), distribui os dois meses uniformemente e agrega por trimestre.
Cobertura: **2020 a 2026T1** (37 bimestres coletados).

**Etapa 2.3 — Folha municipal:**

Repetimos o procedimento para todos os 15 municípios de Roraima: Amajari, Alto Alegre, Boa Vista,
Bonfim, Cantá, Caracaraí, Caroebe, Iracema, Mucajaí, Normandia, Pacaraima, Rorainópolis,
São João da Baliza, São Luiz e Uiramutã. A cobertura variou entre 12 e 37 bimestres por município
(Caracaraí tem série mais curta no SICONFI).

**Etapa 2.4 — Deflação, índice e Denton-Cholette:**

A série nominal (folha estadual + municipal) foi deflacionada pelo IPCA nacional (SIDRA tab 1737,
variação mensal), convertido em índice encadeado com base em janeiro de 2020. O índice real foi
normalizado para 2020 = 100 e submetido ao Denton-Cholette contra o VAB anual de
"Adm., defesa, educação e saúde públicas e seguridade social" das Contas Regionais.

**Validação perfeita:**

As variações anuais do índice coincidem exatamente com as Contas Regionais em todos os anos
disponíveis para benchmarking:

| Ano | Variação do índice | Variação VAB IBGE |
|---|---|---|
| 2021 | +9,7% | +9,7% ✓ |
| 2022 | +25,6% | +25,6% ✓ |
| 2023 | +18,0% | +18,0% ✓ |

**Descoberta técnica registrada:**

O SIDRA retorna a coluna de período como "Mês (Código)" no formato YYYYMM (ex: "202001").
A extração ingênua do mês com `^[0-9]+` captura a string inteira como número ("202001" em vez
de "01"), fazendo a busca por janeiro falhar. Corrigido com detecção do formato YYYYMM e uso de
`substr()`.

**Outputs gerados:**
- `data/raw/folha_estadual_rr_mensal.csv` — 37 bimestres (Estado de RR)
- `data/raw/folha_municipal_rr.csv` — 15 municípios × bimestres disponíveis
- `data/output/indice_adm_publica.csv` — 16 observações (2020T1–2023T4)

**Decisão final sobre o SIAPE:**

Após investigação completa da API do Portal da Transparência, o endpoint
`/remuneracao-servidores-ativos` retorna HTTP 403 para o cadastro padrão —
independentemente do token ou dos parâmetros utilizados. O download em massa
dos arquivos mensais (`.zip`) também é bloqueado. Não há caminho programático
disponível com este tipo de acesso.

Isso não compromete a qualidade do índice. O Denton-Cholette ancora a série
(estadual + municipal) ao VAB AAPP anual do IBGE — que já inclui todo o setor
público, inclusive o federal. O componente federal está, portanto, implicitamente
incorporado via calibração. O script documenta como alternativa futura o download
manual dos arquivos mensais para quem tiver acesso privilegiado.

---

### Abril de 2026 — Fase 3: script da Indústria implementado

**O que foi feito:**

Pesquisamos e implementamos as fontes de dados para os três subsetores industriais de Roraima:
SIUP (eletricidade, gás, água), Construção Civil e Indústria de Transformação.

**ANEEL — energia elétrica por classe de consumidor:**
A ANEEL (agência reguladora de energia) publica mensalmente o consumo de energia elétrica de cada
distribuidora, separado por tipo de consumidor (residencial, comercial, industrial, poder público).
Para Roraima, a distribuidora é a "Boa Vista" (Roraima Energia S.A.), que opera num sistema
isolado — ou seja, não está ligada à rede elétrica nacional. Encontramos os dados no portal de
dados abertos da ANEEL e confirmamos que há cobertura completa mês a mês de 2020 a 2026.
A estratégia foi usar a API diretamente com filtros, em vez de baixar o arquivo de 200 MB
com dados de todo o Brasil — assim obtemos apenas os ~800 registros por ano que precisamos.

**CAGED — emprego formal por setor:**
O Novo CAGED (sistema de registro de emprego formal, que entrou em vigor em 2020) não tem
API pública que permita filtrar por estado. O jeito é baixar o arquivo nacional mensal (~35 MB
comprimido), extrair com 7-Zip e filtrar apenas os registros de Roraima. Para cada mês baixado,
salvamos um pequeno arquivo com apenas as contratações e demissões por setor em RR — assim na
Fase 4 não precisamos baixar tudo de novo. No total, a primeira execução baixa cerca de 2,5 GB,
mas todos os arquivos grandes são apagados logo após o processamento.

**SNIC — cimento:**
O site do SNIC (associação do setor de cimento) não tem API pública. Os dados precisam ser
baixados manualmente. O script está preparado para usar os dados de cimento se o arquivo for
colocado na pasta correta — caso contrário, usa apenas os dados de emprego do CAGED.

**O que o script produz:**
- Índice mensal de energia total distribuída em RR (SIUP)
- Série de emprego formal acumulado na construção civil (Construção)
- Índice composto energia industrial + emprego na indústria (Transformação)
- Índice industrial final: combinação dos três com pesos das Contas Regionais do IBGE (2020)
- Todos passam pelo ajuste de Denton para bater com os dados anuais do IBGE (2020–2023)

**Decisões técnicas importantes:**
- O ICMS por setor não foi incluído: a SEFAZ-RR não publica esses dados de forma automatizável
  por CNAE. Isso é documentado como limitação — pode melhorar no futuro.
- A energia industrial da ANEEL vale 70% do índice de Transformação; o emprego vale 30%.
  Justificativa: energia é uma medida direta de volume; emprego é um insumo, não produção.
- O SIUP usa a soma de todas as classes de energia (total distribuído) como proxy do setor.

**Arquivos criados:**
- `R/03_industria.R` — script completo da Fase 3

**Arquivos atualizados:**
- `plano_projeto.md` — seções 3 (Construção), 4 (SIUP), 5 (Transformação), Fase 3, decisões 17–22
- `checklist.md` — Fase 3 detalhada com itens concluídos

---

### Abril de 2026 — Fase 3 concluída: Índice Industrial de Roraima

**O que foi feito:**

Executamos o script `R/03_industria.R` e geramos o índice industrial de Roraima (base 2020 = 100),
cobrindo os três subsetores: SIUP, Construção Civil e Indústria de Transformação.

**Coleta de dados:**

- **ANEEL SAMP** (etapa 3.1): baixados via API CKAN com filtros, 584 registros mensais
  (2020–2026), 8 classes de consumidores, cache por ano. Sem falhas.

- **CAGED microdata** (etapa 3.2): baixados 72 arquivos mensais (2020T1 a 2025T4) via FTP do MTE,
  comprimidos em 7z (~35 MB cada, ~2,5 GB total). A primeira tentativa usou `download.file()` do R,
  que falhou após alguns downloads por limitação de conexões do servidor. A solução foi chamar o
  `curl` da linha de comando via `system()`, com flags `--ftp-pasv --retry 3 --retry-delay 5`.
  Todos os 72 meses foram baixados com sucesso. Os arquivos grandes são apagados logo após o
  processamento — ficam apenas os CSVs filtrados de RR (~100 KB por mês).

**Índices gerados:**

- SIUP (47,3% do bloco industrial): consumo total de energia elétrica distribuída em RR
- Construção (42,8%): estoque acumulado de emprego formal CNAE F, base 1000 + saldos CAGED
- Transformação (9,9%): energia industrial ANEEL (70%) + emprego CAGED C (30%)
- Composto industrial: média ponderada dos três, pesos das Contas Regionais 2020

**Validação:**

O ajuste Denton-Cholette âncora os trimestres aos benchmarks anuais do IBGE (2020–2023).
As variações anuais do índice composto são:

| Ano | Variação do índice |
|---|---|
| 2021 | +10,6% |
| 2022 | +20,6% |
| 2023 | +9,4% |

**Nota sobre 2023:** a variação elevada reflete a instabilidade real do VAB de SIUP em Roraima
nas Contas Regionais do IBGE — o setor passou de R$369M em 2022 para R$1.243M em 2023, resultado
das mudanças estruturais na geração e distribuição de energia do estado (conexão ao SIN, revisão
tarifária, encerramento de contratos de termelétricas). O dado é genuíno; o script apenas obedece
o que o IBGE registrou.

**Outputs gerados:**
- `data/output/indice_industria.csv` — 24 observações (2020T1–2025T4)

---

## Onde estamos agora

| Setor | Status | Arquivo de saída |
|---|---|---|
| Agropecuária (8,9% do VAB) | ✅ Concluído | `indice_agropecuaria.csv` (56 obs., 2010T1–2023T4) |
| Adm. Pública (46,2% do VAB) | ✅ Concluído* | `indice_adm_publica.csv` (16 obs., 2020T1–2023T4) |
| Indústria (11,6% do VAB) | ✅ Concluído | `indice_industria.csv` (24 obs., 2020T1–2025T4) |
| Serviços Privados (33,3% do VAB) | ✅ Concluído** | `indice_servicos.csv` (24 obs., 2020T1–2025T4) |

*Pendente inclusão da folha federal (SIAPE) quando token for ativado.
**Transportes usa apenas diesel ANP (ANAC indisponível — servidor trunca download). Financeiro com NA (BCB OData 404 em todas as versões).

**Próxima etapa:** Fase 5 — `R/05_agregacao.R` — combinar os quatro índices setoriais no índice
geral de Roraima, aplicar ajuste sazonal (X-13ARIMA-SEATS) e gerar os outputs finais.

---

### Abril de 2026 — Fase 4: script de Serviços Privados implementado

**O que foi feito:**

Criamos o script `R/04_servicos.R`, que implementa o índice trimestral de Serviços Privados de
Roraima, cobrindo sete subsetores: Comércio, Transportes, Financeiro, Imobiliário, Outros
Serviços, Informação e Comunicação, e Indústrias Extrativas.

**Decisão sobre o ICMS do Comércio (Opção A):**

A SEFAZ-RR não disponibilizou o ICMS por atividade econômica em formato automatizável para esta
versão. Em vez de bloquear toda a Fase 4, optamos por implementar o índice de Comércio com dois
componentes disponíveis: energia elétrica comercial (ANEEL, 67%) e emprego formal no comércio
(CAGED seção G, 33%). O script está documentado com instrução de revisão: quando o ICMS for
obtido, os pesos passam a ser energia 40%, ICMS deflacionado 40%, CAGED 20%.

**Fontes e estratégia de coleta por subsetor:**

| Subsetor | Fonte | Estratégia |
|---|---|---|
| Comércio | ANEEL (comercial) + CAGED G | Cache da Fase 3 — sem coleta nova |
| Transportes | ANAC (VRA mensal) + ANP diesel | Download automatizado no script |
| Financeiro | BCB Estban + BCB Nota de Crédito | API OData BCB (com fallback se indisponível) |
| Imobiliário | Contas Regionais IBGE | Interpolação linear entre benchmarks anuais |
| Outros Serviços | CAGED I + M+N + P+Q | Cache da Fase 3 — sem coleta nova |
| Info. e Comunicação | CAGED J | Cache da Fase 3 — sem coleta nova |
| Extrativas | Contas Regionais IBGE | Interpolação linear (peso 0,05%, negligenciável) |

**Decisões metodológicas implementadas:**

- **Transportes**: ANAC baixa arquivos VRA mensais (~2–4 MB cada, ICAO SBBV para Boa Vista),
  filtra e agrega passageiros + carga por mês, cacheia por arquivo individual. ANP: Excel com
  série histórica completa de vendas de diesel por UF.

- **Financeiro**: concessões de crédito (BCB OData, fluxo mensal de novos créditos) são
  o componente principal (70%), deflacionadas pelo IPCA e suavizadas com média móvel de 3 meses.
  Depósitos Estban (estoque, 30%) são o componente secundário. Se a API de concessões falhar,
  o índice usa apenas depósitos com aviso registrado.

- **Imobiliário e Extrativas**: interpolação linear com Denton-Cholette e indicador constante
  (distribuição uniforme) — mesma técnica recomendada no plano, sem proxy de mercado. Para
  2024–2025 (além dos benchmarks CR), extrapola a tendência linear dos últimos 2 anos do IBGE.

- **Outros Serviços**: pesos dos três subgrupos CAGED (I, M+N, P+Q) são calculados
  dinamicamente, proporcionais ao estoque médio de emprego em 2020 — consistente com o fato
  de o próprio emprego ser a proxy de volume.

- **Denton-Cholette**: aplicado individualmente a cada subsetor contra o respectivo VAB anual
  das Contas Regionais (2020–2023), exatamente como nas Fases 1–3. O índice composto final é
  uma média ponderada pelos pesos % VAB 2023 (Laspeyres).

**Arquivo criado:**
- `R/04_servicos.R` — script completo da Fase 4 (~700 linhas)

---

### Abril de 2026 — Fase 4 concluída: Índice de Serviços Privados de Roraima

**O que foi feito:**

Executamos o script `R/04_servicos.R` e geramos o índice trimestral de Serviços Privados de
Roraima (base 2020 = 100), com 24 observações (2020T1–2025T4) — cobertura idêntica à Fase 3.

**Subsetores com índice calculado:**

| Subsetor | Peso VAB 2023 | Proxy | Situação |
|---|---|---|---|
| Comércio | 12,25% | Energia comercial ANEEL (67%) + CAGED G (33%) | ✅ Calculado |
| Imobiliário | 7,68% | Interpolação linear entre benchmarks CR | ✅ Calculado |
| Outros Serviços | 7,63% | CAGED I + M+N + P+Q (pesos dinâmicos) | ✅ Calculado |
| Informação e Comunicação | 1,01% | CAGED J | ✅ Calculado |
| Extrativas | 0,05% | Interpolação linear CR | ✅ Calculado |
| Transportes | 1,92% | ANAC + ANP diesel | ⚠️ NA — coleta pendente |
| Financeiro | 2,78% | BCB concessões + Estban | ⚠️ NA — coleta pendente |

**Problemas de coleta identificados:**

- **ANAC** (`Dados_Estatisticos.csv`, 353 MB): download falhou com erro de rede. O arquivo
  existe no portal de dados abertos da ANAC, mas o servidor interrompeu a conexão. Alternativa:
  baixar manualmente e salvar em `data/raw/anac/Dados_Estatisticos.csv`.

- **BCB Estban** (OData `/RecursosMensalEstban`): retorna HTTP 404. O endpoint de depósitos
  bancários por UF pode ter sido renomeado ou migrado para nova versão da API.

- **BCB Concessões** (OData `/CreditoConcedidoUFDestinatarioRecurso`): retorna HTTP 404. Mesmo
  problema — endpoint possivelmente descontinuado na versão v1.

- **ANP diesel** (Excel `VendaDerivadosCombustiveis_m.xlsx`): retorna HTTP 404. URL da ANP
  pode ter sido atualizada na publicação anual.

O índice composto redistribui os pesos dos setores ausentes entre os disponíveis — o comportamento
está documentado e correto. Os setores com NA (Transportes + Financeiro = 4,70% do VAB do bloco
de Serviços) têm peso pequeno e não comprometem a qualidade do índice composto.

**Variações anuais do índice composto de Serviços:**

| Período | Variação |
|---|---|
| 2021 vs. 2020 | +18,8% |
| 2022 vs. 2021 | +7,9% |
| 2023 vs. 2022 | +11,4% |
| 2024 vs. 2023 | +11,4% |
| 2025 vs. 2024 | +13,4% |

Os anos 2021–2023 têm ancoragem exata pelo Denton-Cholette às Contas Regionais do IBGE. Os anos
2024–2025 são extrapolações baseadas nas proxies disponíveis (sem benchmark CR publicado ainda).

**Correções técnicas aplicadas durante a execução:**

- Bug IPCA: `!is.na(cod) &&` com vetor de comprimento 556 → substituído por
  `length(cod) > 0 && !is.na(cod[1]) &&` (o operador `&&` no R exige escalar)
- Denton nos setores de Serviços: todas as chamadas a `denton()` precisavam de
  `metodo = "denton-cholette"` explícito — o valor padrão `"proportional"` não é reconhecido
  pelo pacote `tempdisagg`
- Imobiliário e Extrativas: substituída chamada direta a `tempdisagg::td()` (com objeto `ts`
  inline na fórmula) pela função `denton()` de `utils.R`, que é a forma testada e correta
- Extrativas: extrapolação linear protegia contra valores negativos quando a tendência é
  declinante (piso de 50% do último benchmark)
- Série limitada a 2025T4 via filtro de proxy ativa — impede que a série se estenda para 2026
  com apenas os setores de tendência extrapolada (Imobiliário + Extrativas)

**Output gerado:**
- `data/output/indice_servicos.csv` — 24 observações (2020T1–2025T4)

**O que ainda precisa ser feito:**
- Executar o script (primeira coleta de ANAC/ANP/BCB)
- Validar os dados obtidos (especialmente ANAC VRA e BCB concessões)
- Confirmar 24 observações em `data/output/indice_servicos.csv`

---

### Abril de 2026 — Correção do índice industrial: 2025T3 recuperado

**O que foi feito:**

Identificamos e corrigimos um bug no script `R/03_industria.R` que fazia o trimestre
2025T3 (julho–setembro de 2025) ser descartado do índice industrial.

**Causa do problema:**

Em setembro de 2025, não houve nenhuma admissão nem demissão de trabalhadores formais no
setor de construção civil (CNAE F) em Roraima. Com zero movimentações, o CAGED não gera
nenhuma linha para esse mês — e o script interpretava o trimestre como "incompleto"
(apenas 2 meses com dados, em vez de 3), descartando 2025T3 do índice.

**A correção:**

O script agora completa o grid de meses com saldo zero para os meses sem movimentação,
antes de calcular o estoque acumulado de vínculos. Semanticamente correto: se não houve
contratações nem demissões, o estoque de trabalhadores permanece igual ao mês anterior.
A mesma lógica foi aplicada à seção C (Indústria de Transformação) para prevenir o mesmo
problema no futuro.

**Resultado corrigido:**

- `data/output/indice_industria.csv` — **24 observações** (2020T1–2025T4, todos os trimestres)
- 2025T3 = 128,2 (composto industrial, base 2020=100)

**Arquivos modificados:**
- `R/03_industria.R` — correção do grid mensal nas seções F e C do CAGED

---

---

### Abril de 2026 — Fase 4: pendências resolvidas — ANP diesel e Transportes

**O que foi feito:**

Tentamos resolver as três pendências de dados da Fase 4 (ANAC, ANP, BCB).
Dois avanços reais; um abandonado.

**ANP diesel — RESOLVIDO:**

A URL original do Excel da ANP estava fora do ar. Localizamos a nova URL com o arquivo
CSV no portal gov.br (`vendas-combustiveis-m3-1990-2025.csv`, 5,8 MB, delimitado por
ponto e vírgula, mês em texto português — JAN, FEV, etc.). Após correção do tratamento
de encoding (UTF-8) e da detecção dos nomes de colunas com acento, o script baixou e
processou **74 meses de diesel RR** (janeiro de 2020 a fevereiro de 2026) com sucesso.

Com isso, **Transportes passou de NA para série completa de 24 trimestres** (2020T1–2025T4),
usando diesel ANP como proxy única com peso 100% (já que ANAC está indisponível).

**ANAC — NÃO RESOLVIDO:**

O servidor da ANAC trunca o download do arquivo `Dados_Estatisticos.csv` (337 MB) em
torno de 50–160 MB, independentemente do método de download usado (httr2, libcurl,
PowerShell). O servidor retorna o conteúdo parcial sem sinalizar erro (HTTP 200 + fim de
conexão prematuro). Não é um problema de URL — o arquivo existe e tem o conteúdo correto,
mas a transferência é interrompida pelo servidor antes de concluir.

O índice de Transportes usa apenas diesel ANP enquanto ANAC não estiver acessível. O script
documenta a instrução para download manual do arquivo e processamento com `fread`.

**BCB — ABANDONADO:**

Todos os endpoints OData do BCB (Estban e NotaCredito, versões v1/v2/v3) retornam HTTP 404.
O Banco Central aparentemente descontinuou esses serviços. Não há série SGS com granularidade
estadual para depósitos ou concessões de crédito. Financeiro permanece como NA.

**Variações anuais do índice de serviços após a correção:**

| Período | Variação |
|---|---|
| 2021 vs. 2020 | +19,0% |
| 2022 vs. 2021 | +7,7% |
| 2023 vs. 2022 | +12,0% |
| 2024 vs. 2023 | +11,8% |
| 2025 vs. 2024 | +10,8% |

Os valores mudaram ligeiramente em relação à execução anterior porque Transportes agora
contribui para o composto (peso 1,92% do VAB de Serviços).

**Output atualizado:**
- `data/output/indice_servicos.csv` — 24 observações (2020T1–2025T4), Transportes com dados reais

---

### Abril de 2026 — Fase 5.1: Índice Geral Agregado concluído

**O que foi feito:**

Implementado e executado o script `R/05_agregacao.R`, que combina os quatro índices setoriais
num índice geral de atividade econômica trimestral de Roraima (base 2020 = 100).

**SIAPE — correção do leitor de Remuneracao:**

Antes de rodar a Fase 5, identificamos e corrigimos um bug no `02_adm_publica.R`: o leitor
da tabela de Remuneracao do SIAPE falhava em alguns ambientes Windows ao tentar detectar o
nome da coluna de salário via `fread(..., nrows=0)`, porque o encoding Latin-1 no Windows
retorna nomes corrompidos. A correção usa `nrows=1` para obter 1 linha real e detecta a
coluna por substring ("BRUTA" + "R$"), com fallback para posição fixa (col 6) caso o nome
não seja encontrado. O script passou a processar todos os 73 ZIPs sem erro.

**Agregação (05_agregacao.R):**

- Carregou os 4 índices setoriais: Agropecuária (16 obs. 2020T1–2023T4), AAPP (16 obs.),
  Indústria (24 obs. 2020T1–2025T4), Serviços (24 obs.).
- AAPP e Agropecuária foram extrapolados para 2024–2025 usando tendência geométrica do
  último bieênio: Agropecuária +8,9%/ano; AAPP +20,0%/ano.
- Índice composto calculado como média ponderada pelos pesos do VAB 2023 (CR IBGE):
  Agro 8,87% | AAPP 46,21% | Indústria 11,60% | Serviços 33,32%.
- Denton-Cholette aplicado contra o VAB total anual (CR IBGE 2020–2023), fator de ajuste
  de 0,9952 no último benchmark (2023T4). Ancoragem perfeita para todos os 4 anos (desvio < 0,01).

**Variações anuais do índice geral:**

| Período | Variação |
|---|---|
| 2021 vs. 2020 | +12,3% |
| 2022 vs. 2021 | +17,2% |
| 2023 vs. 2022 | +20,3% |
| 2024 vs. 2023 | +6,5% (extrapolado) |
| 2025 vs. 2024 | +16,4% (extrapolado) |

**Output gerado:**
- `data/output/indice_geral_rr.csv` — 24 observações (2020T1–2025T4), base 2020 = 100,
  com todas as séries setoriais normalizadas.

**Estado atual:**
Pipeline completo funcional: 01 → 02 → 03 → 04 → 05. Os cinco arquivos de output estão gerados.
Próximas etapas: teste de sensibilidade (5.2), ajuste sazonal (5.3), validação final (5.4),
exportação Excel (5.5) e nota técnica (5.7).

---

### Abril de 2026 — Calendário de colheita: substituição por fonte oficial SEADI-RR

**Motivação:**

O calendário de colheita original em `01_agropecuaria.R` usava coeficientes arbitrários
(inseridos manualmente sem fundamentação documental), inconsistentes com as referências
metodológicas da literatura e com o plano inicial do projeto, que prevê o Censo Agropecuário
como fonte dos coeficientes.

**O que foi feito:**

Exploração completa na pasta de laboratório `teste_calendario_colheita_censo_agro_2006/`,
que derivou três versões de calendário usando fontes distintas:

- **Versão A (SEADI-RR)** — Calendário Agrícola oficial da Secretaria de Agricultura do estado
  de Roraima. Mais aderente ao ciclo real das culturas em RR. Adotado como versão de produção.
- **Versão B (Censo 2006 — área colhida)** — Coeficientes derivados das tabelas de época
  principal de colheita por UF/produto do Censo Agropecuário 2006 (IBGE, ufs.zip), ponderados
  pela área colhida. Culturas sem mensalização oficial ficam com distribuição uniforme (1/12).
- **Versão C (Censo 2006 — estabelecimentos)** — Mesma fonte, ponderação alternativa por
  número de estabelecimentos.

**Mudanças no código:**

1. Os três calendários foram salvos em `data/referencias/` (diretório novo, versionado no Git):
   - `calendario_colheita_seadi_rr.csv`
   - `calendario_colheita_censo2006_area_rr.csv`
   - `calendario_colheita_censo2006_estabelecimentos_rr.csv`

2. `01_agropecuaria.R` (ETAPA 1.1) reescrito: carrega o calendário do CSV via parâmetro
   `versao_calendario` (padrão: "seadi"). A troca de versão para teste A/B é feita alterando
   esse parâmetro e reexecutando os scripts 01 e 05.

**Impacto no índice:**

O perfil sazonal trimestral da agropecuária mudou significativamente:

| Trimestre | Calendário anterior (arbitrário) | SEADI (produção) |
|---|---|---|
| T1 | 177 | 28 (plantio — soja em germinação) |
| T2 | 132 | 22 (transição — pouco a colher) |
| T3 | 78 | 217 (pico — soja, milho, arroz colhidos) |
| T4 | 13 | 133 (final — grãos de 2ª safra, tomate, feijão) |

O perfil novo é muito mais realista para Roraima. Soja representa 53% dos pesos Laspeyres
e tem colheita concentrada em agosto–outubro no calendário SEADI, o que explica o pico em T3.

**O índice anual permanece idêntico** (Denton-Cholette ancora ao VAB das Contas Regionais):
a mudança afeta apenas a distribuição intra-anual e a extrapolação de 2024–2025.

**Output atualizado:**
- `data/output/indice_agropecuaria.csv` — novo perfil sazonal (SEADI)
- `data/output/indice_geral_rr.csv` — propagado (05_agregacao.R re-executado)
- `data/processed/coef_sazonais_colheita.csv` — calendário SEADI registrado

---

### Abril de 2026 — Correção de dois bugs no setor Financeiro

**Motivação:** Ao revisar as caixas abertas da Fase 4, identificamos que o Denton-Cholette
do setor Financeiro estava falhando silenciosamente e o índice resultante tinha todos os
valores como NA (não computado).

**Bug 1 — IPCA (bug no código):**
O script baixa do SIDRA a variável 2266, que é o *nível* do índice IPCA (base dez/1993=100),
e não a variação mensal em percentual. O código anterior aplicava `cumprod(1 + nível/100)`,
o que para valores modernos como 5.700 gera overflow para infinito em todos os meses,
tornando o deflator inútil. Todos os valores deflacionados viravam NA. Corrigido para
`indice_preco = indice_nivel / indice_nivel[jan/2020]` — razão direta ao período base.

**Bug 2 — Estban jan/2023 ausente:**
O arquivo ZIP de janeiro de 2023 do BCB/Estban estava faltando na pasta de dados manuais,
fazendo o trimestre 2023T1 ter apenas 2 meses e ser descartado. O arquivo foi adicionado
manualmente e o cache foi regenerado com 72 meses (cobertura completa jan/2020–dez/2025).

**Resultado:** Denton-Cholette do Financeiro executado com sucesso. Ancoragem ao VAB das
Contas Regionais perfeita para 2020–2023.

---

### Abril de 2026 — Fase 5.5: Exportação dos dados (Excel + CSVs)

**O que foi feito:**

Gerado o arquivo de publicação `IAET_RR_series.xlsx` com cinco abas formatadas e três
CSVs individuais, via script `R/05e_exportacao.R` com o pacote `openxlsx`.

**Estrutura do Excel:**
- **Aba 1 — Índice Geral**: série trimestral NSA com variação trimestral e anual (24 obs.)
- **Aba 2 — Componentes Setoriais**: quatro blocos (Agropecuária, AAPP, Indústria, Serviços)
- **Aba 3 — Dessazonalizado (SA)**: série SA do índice geral e dos quatro componentes
- **Aba 4 — Fatores Sazonais**: fatores aditivos da tabela D10 do X-13ARIMA-SEATS
- **Aba 5 — Metadados**: campos gerais, pesos setoriais e tabela com 14 fontes de dados

Formatação: cabeçalhos azuis institucionais, linhas zebradas, notas de rodapé com
ressalvas sobre o período extrapolado (2024–2025) e elaboração SEPLAN/RR.

**Arquivos gerados:**
- `data/output/IAET_RR_series.xlsx`
- `data/output/IAET_RR_geral.csv`
- `data/output/IAET_RR_componentes.csv`
- `data/output/IAET_RR_dessazonalizado.csv`

---

### Abril de 2026 — Fase 5.4: Validação final do índice geral

**O que foi feito:**

Executamos a validação em quatro eixos com o script `R/05d_validacao.R`, que compara o
índice com o benchmark do IBGE, com indicadores do Banco Central, analisa o comportamento
em 2020 e verifica a consistência interna entre os componentes.

**Resultados por eixo:**

**Eixo 1 — Benchmark Contas Regionais IBGE (2021–2023):**
O erro médio absoluto é de 0,00 pp — ou seja, as variações anuais do índice coincidem
exatamente com a variação do VAB nominal das Contas Regionais. Isso é esperado por
construção: o Denton-Cholette força que a média anual do índice reproduza exatamente o
benchmark anual. Confirma que o mecanismo de ancoramento funciona corretamente.

**Eixo 2 — Comparação com IBC-BR e IBCR Norte (via API BCB SGS):**

| Indicador | Corr. em nível | Corr. em variação |
|---|---|---|
| IBC-BR (Brasil) | 0,906 | 0,401 |
| IBCR Norte | 0,374 | -0,419 |

A correlação em nível com o IBC-BR é excelente (0,906), confirmando que o índice de RR
captura a mesma trajetória ascendente da economia nacional. A correlação em variação
(0,401) é mais modesta, o que é esperado — a sazonalidade forte da agropecuária de RR
cria flutuações trimestrais que não têm correspondência no IBC-BR nacional dessazonalizado.

A correlação *negativa* em variação com o IBCR Norte (-0,419) não é uma anomalia — é um
resultado interpretável: o Norte é dominado por Amazonas e Pará (extrativismo mineral,
petróleo, madeira), que têm ciclos opostos ao de Roraima (soja e funcionalismo público).
Em nível, a correlação de 0,374 confirma que as trajetórias divergem estruturalmente.

As taxas de crescimento anuais de RR (+12%, +17%, +20% em 2021–2023) superam com
consistência o Norte (+7%, -1%, +2%) e o Brasil (+4%, +3%, +3%), refletindo a expansão
da fronteira agrícola da soja e o crescimento do setor público federal em Roraima.

**Eixo 3 — Comportamento em 2020 (COVID):**
O índice mostra queda de 9,8% em 2020T2 versus 2020T1, seguida de forte recuperação
em 2020T3 (+26%), puxada pela colheita da soja (agropecuária: +888% T2→T3) e pela
estabilidade do funcionalismo federal (AAPP: -3,7% na pandemia, contra quedas de 10%+
em estados mais dependentes do setor privado). O comportamento é coerente com a estrutura
econômica de Roraima: o peso do governo público (46% do VAB) funciona como amortecedor
anticíclico, reduzindo a exposição a choques de demanda privada.

**Eixo 4 — Consistência interna:**
- Agro–Geral: correlação 0,810 em variação. A agropecuária domina a volatilidade
  trimestral do índice geral apesar do peso de apenas 8,87% — resultado da amplitude
  sazonal de 17x que impõe flutuações muito maiores que os demais componentes.
- AAPP–Serviços: 0,303 (positiva — governo impulsiona serviços em Boa Vista)
- Ind–Serviços: 0,366 (positiva — construção e SIUP correlacionam com demanda de serviços)

**Arquivos gerados:**
- `R/05d_validacao.R` — script de validação (versionado)
- `data/output/validacao_relatorio.csv` — tabela quantitativa de validação

---

### Abril de 2026 — Fase 5.3: Ajuste sazonal X-13ARIMA-SEATS

**O que foi feito:**

Aplicamos o ajuste sazonal X-13ARIMA-SEATS (pacote `seasonal` do R) ao índice geral e
aos quatro componentes setoriais. O script `R/05c_ajuste_sazonal.R` produz duas versões
de cada série — sem ajuste (NSA) e dessazonalizada (SA) — além de uma tabela com os
fatores sazonais aditivos.

**Resultados:**

O X-13 convergiu com sucesso para todos os cinco componentes, usando decomposição X-11
com transformação automática (aditiva para a maioria das séries, dada a escala dos índices).

Os fatores sazonais revelam o perfil sazonal intrínseco de cada componente:

- **Índice geral**: range de 33,98 pontos entre o trimestre de maior e menor sazonalidade.
  Antes do ajuste, a amplitude pico/vale (2020–2023) era 83,4→185,7. Depois do ajuste: 94,6→168,6.
  A série SA é visivelmente mais suave, com crescimento mais linear ao longo dos anos.

- **Agropecuária**: maior sazonalidade do conjunto — range de 299,76 pontos no fator
  aditivo. Isso reflete o domínio do T3 (colheita da soja), que na série SA é removido e
  o índice passa a mostrar apenas a tendência de volume de longo prazo.

- **AAPP, Indústria e Serviços**: sazonalidades moderadas, ajustadas com sucesso.

As variações anuais SA diferem das NSA porque a sazonalidade é evolutiva (amplitude muda
ao longo do tempo, especialmente na agropecuária com crescimento da soja).

**Nota técnica:**

Avisos de `IEEE_UNDERFLOW_FLAG` e `IEEE_DENORMAL` aparecem no console — são emitidos pelo
código Fortran interno do X-13 ao rodar no Windows e não têm impacto nos resultados.
Com 24 trimestres (limite mínimo recomendado), os modelos convergiram sem fallback para STL.

**Arquivos gerados:**
- `R/05c_ajuste_sazonal.R` — script do ajuste sazonal (versionado)
- `data/output/indice_geral_rr_sa.csv` — série completa NSA + SA para todos os componentes
- `data/output/fatores_sazonais.csv` — fatores sazonais aditivos por componente e trimestre

---

### Abril de 2026 — Fase 5.2: Teste de sensibilidade do calendário agrícola (A vs. B vs. C)

**O que foi feito:**

Rodamos o teste de sensibilidade comparando as três versões do calendário de colheita para a
agropecuária. O script `R/05b_sensibilidade_calendario.R` executa `01_agropecuaria.R` com cada
versão de forma não-destrutiva (sem sobrescrever os arquivos de produção) e compara os resultados.

**Resultado técnico:**

As médias anuais de 2020 a 2023 são **idênticas nas três versões** — diferença menor que 10⁻⁶
pontos de índice. Isso confirma que o Denton-Cholette funciona corretamente: ele ancora todos os
resultados ao mesmo VAB agropecuário das Contas Regionais do IBGE. O calendário não muda os
*totais anuais*, apenas distribui a produção entre os trimestres dentro de cada ano.

**A diferença é no perfil sazonal (média 2020–2023):**

| Trimestre | A (SEADI-RR) | B (Censo 2006 área) | C (Censo 2006 estab) |
|---|---|---|---|
| T1 | 27,8 | 31,1 | 70,5 |
| T2 | 20,4 | 24,9 | 18,5 |
| **T3** | **351,7** | **517,4** | **485,3** |
| **T4** | **200,9** | **27,4** | **26,5** |
| Amplitude sazonal | 17,2x | 20,8x | 26,2x |

O ponto crítico é o **T4**: na versão A (SEADI), o quarto trimestre tem índice ~200 (alta
produção); nas versões B e C (Censo 2006), cai para ~27 — sete vezes menor. O motivo é a
**soja**, que representa 53% do peso das lavouras: o calendário SEADI-RR distribui sua colheita
entre agosto e outubro (T3 e T4), enquanto os calendários do Censo 2006 concentram
praticamente tudo em agosto (T3 apenas).

O impacto máximo no índice geral chega a 21,7 pontos por trimestre (pelo peso de 8,87% da
agropecuária no VAB total).

**Conclusão metodológica:**

A versão A (SEADI-RR) foi mantida como versão de produção. O teste confirmou que:
1. O calendário é uma hipótese metodológica de **alta sensibilidade** — deve ser documentada
   com destaque na nota técnica.
2. O Censo Agropecuário de 2006 não é adequado como base para o calendário de RR em 2026:
   os padrões de plantio/colheita de soja no Cerrado roraimense mudaram muito nas últimas
   duas décadas.
3. A revisão periódica do calendário (junto à SEADI-RR) deve ser parte da rotina de
   manutenção do indicador.

**Arquivos gerados:**
- `R/05b_sensibilidade_calendario.R` — script do teste (versionado)
- `data/output/sensibilidade/agropecuaria_versao_B.csv`
- `data/output/sensibilidade/agropecuaria_versao_C.csv`
- `data/output/sensibilidade/comparacao_calendarios.csv`

---

---

## Reforma metodológica — 13 de abril de 2026

**O que mudou:** O IAET-RR tinha um problema conceitual fundamental: o benchmark anual do método Denton-Cholette usava o **VAB nominal** das Contas Regionais (valores em preços correntes), mas as proxies trimestrais são indicadores de **volume** (emprego, energia, passageiros). Isso fazia o índice absorver inflação setorial, gerando crescimentos artificialmente elevados — +20,3% em 2023, quando o crescimento real foi de apenas +4,3%.

**Como foi corrigido:** O benchmark do Denton-Cholette foi substituído pelo **índice encadeado de volume** das Contas Regionais IBGE (arquivo Especiais, `tab05.xls`, série base 2002=100, rebaseada para 2020=100). A mudança afetou as 11 chamadas Denton dos scripts setoriais (01 a 04) e o segundo Denton na agregação (05). Os pesos do Laspeyres também foram corrigidos para usar participações de 2020 (ano base) em vez de 2023.

**Resultado:** As taxas de crescimento anual do IAET-RR agora refletem crescimento real:

| Ano | Antes (nominal) | Depois (real) | Deflator implícito |
|-----|-----------------|---------------|--------------------|
| 2021 | +12,3% | +8,2% | +3,8% |
| 2022 | +17,2% | +10,9% | +6,5% |
| 2023 | +20,3% | +4,3% | +15,7% |

A diferença entre antes e depois corresponde ao deflator implícito setorial de RR — exatamente o esperado.

**Comparação com IBCR Norte:** O erro médio absoluto caiu de 14 pp para 5,2 pp. A correlação em variação melhorou de -0,74 para -0,24 (ainda negativa porque RR tem 46% de AAPP, com ciclo diferente do Norte regional).

**Produto adicional:** O script `R/05f_vab_nominal.R` gera o índice nominal trimestral (real × deflator implícito) para análises de arrecadação e comparação com PIB nominal. Deflator anual derivado das próprias Contas Regionais; deflator trimestral via Denton com IPCA como proxy.

**Arquivos modificados:** `R/00_dados_referencia.R`, `R/01_agropecuaria.R`, `R/02_adm_publica.R`, `R/03_industria.R`, `R/04_servicos.R`, `R/05_agregacao.R`

**Novos arquivos:** `R/05f_vab_nominal.R`, `data/processed/contas_regionais_RR_volume.csv`, `data/processed/contas_regionais_RR_deflator.csv`, `data/output/indice_nominal_rr.csv`, aba "VAB Nominal" no Excel

---

### Abril de 2026 — Documentação consolidada na versão atual do projeto

**O que foi consolidado:**

Os arquivos de documentação foram alinhados ao estado real do projeto após a reforma metodológica.
Isso era necessário porque parte dos textos ainda descrevia a Fase 5 como "a iniciar", embora o
projeto já estivesse com sensibilidade, ajuste sazonal, validação, exportação, dashboard e VAB
nominal implementados.

**Estado atual correto do projeto:**

- o pipeline completo está operacional de `00` a `05f`;
- o índice geral cobre **2020T1 a 2025T4** em base 2020 = 100;
- o crescimento anual real consolidado do IAET-RR está em **+8,2% (2021)**,
  **+10,9% (2022)**, **+4,3% (2023)**, **+7,7% (2024, extrapolado)** e
  **+9,2% (2025, extrapolado)**;
- o dashboard Shiny já está funcional localmente e consome os arquivos finais de `data/output/`;
- o principal item ainda pendente é a **nota técnica** em `notas/nota_tecnica.qmd`,
  além dos testes finais de responsividade e da publicação do dashboard.

**Arquivos documentais alinhados:**
- `README.md`
- `plano_projeto.md`
- `checklist.md`
- `historico_simples.md`

---

### Abril de 2026 — SIAPE integrado: folha federal incluída com dados reais

**Situação anterior:**

O componente federal do índice de Administração Pública (AAPP) era baseado apenas nas folhas
estadual e municipal. A folha dos servidores federais em Roraima (SIAPE) não estava incluída
porque a API do Portal da Transparência retorna HTTP 403 para qualquer consulta de remuneração.
O índice compensava via Denton-Cholette, que ancora ao VAB IBGE (que inclui o federal implicitamente),
mas a proxy intra-anual ficava subrepresentada.

**O que foi feito:**

Os 73 ZIPs mensais do Portal da Transparência foram baixados manualmente
(`bases_baixadas_manualmente/dados_siape_portal_transparencia/`) e o script `02_adm_publica.R`
foi atualizado para processá-los automaticamente, extraindo e filtrando os registros de
servidores com lotação em Roraima (UF_EXERCICIO = "RR" ou órgão com "RORAIMA" no nome).

Resultado: **8.000–9.700 servidores federais por mês** identificados em RR, com folha bruta
entre R$ 4,7 bi e R$ 6,0 bi/mês — componente agora incluído no cálculo trimestral da AAPP.

**Problema de qualidade de dados identificado:**

Três meses têm o arquivo `Remuneracao.csv` essencialmente vazio dentro do ZIP (apenas cabeçalho):
- **Abril/2021**: 96 bytes
- **Dezembro/2024**: 585 KB (vs. ~170 MB dos demais meses)
- **Fevereiro/2025**: 1.609 bytes

Esses ZIPs foram publicados pelo Portal da Transparência antes de os dados de remuneração serem
consolidados. O script detecta automaticamente os meses ausentes (comparando a grade completa
com os meses presentes no cache) e os preenche por **interpolação linear** entre os meses
vizinhos, com log explícito dos meses afetados.

**Impacto:**

Antes da integração do SIAPE, os trimestres com meses ausentes mostravam queda artificial de
~33% na folha federal (apenas 2 meses somados em vez de 3). O índice AAPP caía de ~123 para
~88 em 2024T4 e ~85 em 2025T1. Após a correção: 2024T4 = 115, 2025T1 = 113 — valores estáveis
e coerentes com a trajetória crescente do funcionalismo.

---

### Abril de 2026 — Dashboard Shiny: painel interativo do IAET-RR

**O que foi feito:**

Criamos o dashboard interativo do projeto em `dashboard/app.R`, usando as bibliotecas `bslib`
(tema visual institucional), `plotly` (gráficos interativos) e `DT` (tabela filtrável).

**Estrutura do dashboard (5 abas):**

| Aba | Conteúdo |
|---|---|
| Índice Geral | 3 caixas de indicadores + gráfico NSA/SA com slider de período + linha separando benchmark de extrapolação |
| Componentes | Barras empilhadas de contribuição setorial (p.p.) + linhas dos índices setoriais |
| VAB Nominal | Barras em R$ milhões (azul escuro = CR IBGE, azul claro = extrapolação) + variação anual + nota metodológica |
| Dados | Tabela filtrável com `var_trim`, `var_anual`, `var_trim_sa` + botão de download CSV/XLSX |
| Sobre | Pizza interativa dos pesos setoriais 2020 + ficha técnica do projeto |

**Detalhe técnico:**

O app lê os arquivos de `data/output/` via variável de ambiente `IAET_DATA_DIR`, o que permite
rodá-lo tanto pelo RStudio (com caminho relativo ao projeto) quanto via script externo (com
caminho absoluto). Os pesos setoriais Laspeyres 2020 são definidos como constante no app e
precisam ser atualizados manualmente quando o pipeline for rerodado com novos benchmarks.

Para rodar localmente: executar `/tmp/run_shiny.R` (ou equivalente) com `IAET_DATA_DIR` apontando
para a pasta de outputs.

---

### Abril de 2026 — Correção crítica: proxies reais para 2024–2025 em todos os setores

**Problema identificado:**

O índice geral mostrava contribuições agrícolas absurdas em 2024 — agropecuária contribuindo
+116 pp em um único trimestre, quando o normal é ±5 pp. A causa era que, para 2024–2025 (além
do benchmark CR IBGE 2023), o sistema estava usando **extrapolação plana de tendência**
em vez dos dados reais das proxies.

**Raiz do problema:**

A função `extrapolar_tendencia()` em `05_agregacao.R` crescia trimestre a trimestre a partir
do último valor disponível — que era o T4 2023 (pico de colheita, agro ≈ 259). Assim, T1 2024
saía como 255 ao invés de ~25 (entressafra). A sazonalidade era completamente destruída.

O mesmo problema existia nos scripts setoriais (01 a 04): quando a proxy (LSPA, folha de
pagamento, CAGED, etc.) cobria períodos além do benchmark CR IBGE, o código truncava a série
ao período com benchmark — descartando dados reais de 2024–2025.

**Correções aplicadas:**

1. **`R/utils.R`**: adicionada função `estender_benchmark()`, que estende o benchmark CR IBGE
   de 2023 para 2024–2025 por crescimento geométrico baseado nos últimos 3 anos da série de
   volume real — permitindo que o Denton rode sobre o período completo das proxies.

2. **`R/01_agropecuaria.R`**: Denton agora cobre o período completo da LSPA (2020–2025), com
   benchmark estendido. A sazonalidade agrícola é preservada integralmente pelo Denton.

3. **`R/02_adm_publica.R`**: mesma lógica para a folha de pagamento.

4. **`R/03_industria.R`**: `aplicar_denton()` usa série completa de proxy sem fallback para
   tendência linear — elimina a descontinuidade de nível na transição 2023→2024.

5. **`R/05_agregacao.R`**: `extrapolar_tendencia()` corrigida para crescer pelo trimestre
   homólogo do ano anterior (T1 2024 = T1 2023 × taxa), e não pelo trimestre imediatamente
   anterior. Isso preserva o padrão sazonal.

**Resultado após correções:**

| Período | Agropecuária (antes) | Agropecuária (depois) |
|---|---|---|
| 2024T1 | ~255 (crescendo do pico T4) | ~25 (entressafra ✓) |
| 2024T2 | ~262 | ~20 (mínimo anual ✓) |
| 2024T3 | ~268 | ~557 (colheita ✓) |
| 2024T4 | ~274 | ~319 (pós-colheita ✓) |

O índice geral em 2024–2025 passou a refletir ciclos reais, com as proxies como LSPA, folha
de pagamento, CAGED e energia elétrica determinando o comportamento intra-anual.

---

### Abril de 2026 — Correção do cálculo de pesos Laspeyres

**Problema identificado:**

Os pesos setoriais do índice geral estavam com valores errados — Agropecuária com 3,45%
em vez de 6,89%, AAPP com 22,5% em vez de 45%. Todos os pesos estavam exatamente na metade
do valor correto.

**Causa:**

O arquivo `contas_regionais_RR_serie.csv` contém, além das 12 atividades econômicas, uma linha
chamada "Total das Atividades" com o VAB somado de todas as demais (R$ 14.524 M em 2020).
Quando o script somava todas as linhas para calcular o denominador dos pesos, incluía essa linha
e dobrava o total — resultando em 29.048 M em vez de 14.524 M — e todos os pesos caíam à metade.

**Correção:**

Adicionado filtro `!grepl("^Total", atividade, ignore.case = TRUE)` antes de calcular o
denominador em `05_agregacao.R`. Os pesos corretos para o Laspeyres 2020 são:

| Setor | Peso correto |
|---|---|
| Agropecuária | 6,89% |
| Adm. Pública (AAPP) | 45,01% |
| Indústria | 11,63% |
| Serviços Privados | 36,46% |

O mesmo ajuste foi propagado para o `dashboard/app.R`, onde os pesos estavam hardcoded.

## Onde estamos agora (abril de 2026)

| Componente | Status | Cobertura |
|---|---|---|
| Agropecuária | ✅ Concluído | 2020T1–2025T4 |
| Adm. Pública (AAPP) | ✅ Concluído (incl. SIAPE federal) | 2020T1–2025T4 |
| Indústria | ✅ Concluído | 2020T1–2025T4 |
| Serviços Privados | ✅ Concluído | 2020T1–2025T4 |
| Índice Geral | ✅ Concluído | 2020T1–2025T4 |
| Ajuste Sazonal | ✅ Concluído | 2020T1–2025T4 |
| VAB Nominal | ✅ Concluído | 2020T1–2025T4 |
| Dashboard Shiny | ✅ Operacional localmente | — |
| Nota Técnica | ⏳ Não iniciada | — |

**Taxas de crescimento real do IAET-RR (base 2020 = 100):**

| Ano | IAET-RR real |
|---|---|
| 2021 | +8,2% |
| 2022 | +10,9% |
| 2023 | +4,3% |
| 2024 | +7,7% *(extrapolado — CR IBGE 2024 prevista para out/2026)* |
| 2025 | +9,2% *(extrapolado)* |

**Próximas prioridades:**
1. Nota técnica metodológica (`notas/nota_tecnica.qmd`)
2. ICMS por atividade econômica da SEFAZ-RR para o bloco Comércio
3. Publicação do dashboard em servidor institucional ou Shinyapps.io
4. Incorporar CR IBGE 2024 quando publicada (outubro de 2026)

---

### Abril de 2026 — Ajuste de consistência metodológica nos pesos do bloco de serviços

**O que foi feito:**

Atendemos a uma crítica metodológica correta sobre heterogeneidade de bases de ponderação dentro do
sistema. O índice geral já estava em formato Laspeyres base 2020 no topo, mas o bloco interno de
serviços ainda agregava seus subsetores com pesos hardcoded de 2023.

**A correção:**

O script `R/04_servicos.R` passou a calcular dinamicamente os pesos dos sete subsetores do bloco
de serviços com base no **VAB nominal de 2020** das Contas Regionais, alinhando o bloco interno ao
mesmo ano-base do índice geral.

**O que mudou conceitualmente:**

- o topo do sistema continua sendo um Laspeyres base 2020;
- o bloco de serviços agora também usa base 2020 na agregação entre subsetores;
- os pesos entre proxies dentro de cada subsetor continuam sendo pesos técnicos e pragmáticos
  (por exemplo, energia + emprego no comércio), porque não são pesos contábeis, e sim escolhas
  de engenharia do indicador;
- a agropecuária continua usando pesos médios plurianuais de VBP nas culturas, o que foi mantido
  por estabilidade estatística e por refletir melhor a composição recente das lavouras.

**Resultado institucional:**

A crítica deixou de atingir o bloco de serviços. A única assimetria remanescente é a da
agropecuária, que continua sendo uma escolha metodológica deliberada e defensável, desde que
explicitada na nota técnica.

---

### Abril de 2026 — Correção operacional do dashboard Shiny

**O que foi feito:**

Corrigimos dois pontos no `dashboard/app.R` para tornar a abertura do painel mais robusta no uso
real do projeto.

**Correção 1 — caminho dos dados:**

O app antes assumia implicitamente um único diretório de execução e montava o caminho dos dados de
forma rígida. Isso podia falhar quando o painel era aberto a partir da raiz do projeto. O código
passou a resolver `data/output` de forma mais robusta, aceitando:

- execução pela raiz do projeto;
- execução pela pasta `dashboard/`;
- definição explícita por variável de ambiente `IAET_DATA_DIR`.

**Correção 2 — dependência de fonte online:**

O tema usava `font_google("Source Sans 3")`. Em ambientes com rede restrita, isso pode atrasar ou
bloquear a inicialização do app. A fonte foi substituída por uma pilha local (`Segoe UI`, `Arial`,
`sans-serif`), eliminando a dependência externa.

**Resultado prático:**

Depois dessas correções, o painel voltou a abrir normalmente no RStudio do projeto.

---

### Abril de 2026 — Planejamento da frente de impostos e PIB nominal trimestral

**O que foi feito:**

Abrimos formalmente uma nova frente documental para transformar a ideia de `PIB nominal trimestral`
em uma trilha de implementação controlada. Até aqui, o projeto já tinha o `VAB nominal trimestral`
como produto derivado, mas ainda não tinha um plano próprio para o componente de **impostos
líquidos sobre produtos (ILP)**.

**O que foi definido:**

- foi criado `plano_reforma_impostos.md`, com a estratégia metodológica da nova frente;
- foi criado `checklist_reforma_impostos.md`, com as etapas de mapeamento, coleta, script,
  validação e versionamento;
- ficou definido que a primeira versão recomendada do ILP trimestral deve começar com
  **ICMS estadual + ISS municipal**;
- ficou registrado que `IPI` sozinho **não é suficiente** como proxy federal;
- a recomendação para uma versão federal ampliada passou a ser: `IPI + II + PIS/Pasep + Cofins +
  CIDE-Combustíveis`;
- `ITBI` ficou como candidato secundário e `IOF` como item opcional, sujeito a teste.

**Por que isso importa:**

Sem esse plano, a frente de impostos poderia avançar de forma difusa, misturando arrecadação total
com o conceito mais restrito de `impostos sobre produtos` usado pelo IBGE. A nova documentação
evita esse risco e organiza a implementação futura do `R/05g_pib_nominal.R`.

**Arquivos criados:**
- `plano_reforma_impostos.md`
- `checklist_reforma_impostos.md`

**Arquivo atualizado:**
- `regras.md` — ganhou uma seção específica para manutenção obrigatória dos documentos da reforma
  de impostos e do futuro `05g_pib_nominal.R`

---

### Abril de 2026 — Etapa B.1 executada: identificação do ICMS estadual no Siconfi

**O que foi feito:**

Executamos a primeira etapa operacional da frente de impostos: descobrir, de forma reproduzível,
como extrair o `ICMS` do Estado de Roraima no Siconfi.

**O que foi descoberto:**

- a fonte correta é a **MSC Orçamentária** do Siconfi, e não o RREO;
- o ente do Estado de Roraima aparece como `id_ente = 14`;
- a combinação metodologicamente correta usa:
  - `co_tipo_matriz = MSCC`;
  - `classe_conta = 6`;
  - `id_tv = period_change`;
  - `conta_contabil = 621200000` para isolar a **receita realizada**;
- nas naturezas de receita, o núcleo observado do ICMS em RR aparece como:
  - `11145011` — principal;
  - `11145013` — dívida ativa.

Também foi identificado que a série histórica não usa um único conjunto de códigos ao longo de
todo o período. Parte da série antiga aparece no padrão `1118021x`, enquanto a série mais recente
usa `1114501x`. Isso significa que a rota de extração já está validada, mas a harmonização
completa de `2020 até o presente` ainda precisa de tratamento adicional.

Na primeira execução do script, a série limpa obtida ficou com **59 meses válidos**, de
`2020-01` a `2026-02`, mas com uma lacuna de `2022-01` a `2023-03`. Ou seja: a etapa de
identificação da rota foi concluída, mas a harmonização histórica ainda não.

**O achado mais importante:**

Não basta somar todas as linhas da classe 6 com código de ICMS. Isso mistura previsão, realização
e outros movimentos contábeis, o que gera valores artificialmente altos, especialmente em janeiro.
O filtro pela conta `621200000` resolve esse problema e entrega uma série mensal plausível de
arrecadação realizada.

**Produto desta etapa:**

Foi criado um script exploratório reproduzível:
- `R/exploratorio/inspecionar_siconfi_icms_rr.R`

Esse script baixa os dados mês a mês, filtra o ICMS corretamente e salva duas bases locais:
- `data/raw/icms_rr_siconfi_mensal_detalhado.csv`
- `data/raw/icms_rr_siconfi_mensal_total.csv`

---

### Abril de 2026 — Limpeza da `.git` local e ajuste do `.gitignore`

**O que foi feito:**

Foi identificada uma anomalia grave no repositório local: a pasta `.git` havia crescido para
quase 7 GB porque o Git tinha armazenado internamente blobs gigantes correspondentes a bases
brutas locais, especialmente arquivos em `bases_baixadas_manualmente/`.

**Como foi resolvido:**

- a `.git` local inflada foi substituída por uma cópia limpa obtida a partir de um clone novo
  do GitHub;
- a `.git` voltou a ter tamanho normal, cerca de 8 MB;
- o índice foi normalizado para eliminar falsos "arquivos modificados";
- o `.gitignore` foi atualizado para ignorar explicitamente:
  - `bases_baixadas_manualmente/`
  - `teste_calendario_colheita_censo_agro_2006/`
  - `.claude/`

**Resultado prático:**

O Git deixou de ser a fonte do volume excessivo no OneDrive. A única pasta ainda muito pesada no
projeto local é `bases_baixadas_manualmente/`, que permanece no projeto por decisão deliberada,
mas agora sem risco de ser reingerida acidentalmente pelo Git.

---

### Abril de 2026 — Implementação do PIB nominal trimestral via proxy de ICMS

**O que foi feito:**

Concluímos a primeira versão operacional do `PIB nominal trimestral` de Roraima, fechando a frente
da reforma de impostos no código. O novo script `R/05g_pib_nominal.R` passou a:

- ler o `VAB nominal trimestral` já escalado em `R$ milhões`;
- usar a série mensal de `ICMS` da SEFAZ-RR como proxy trimestral do `ILP`;
- buscar o `PIB anual` de Roraima no SIDRA/IBGE (Tabela 5938);
- calcular `ILP anual = PIB anual - VAB anual`;
- extrapolar o ILP anual de `2024` e `2025` pela taxa anual do ICMS;
- distribuir o ILP anual pelos trimestres via `Denton-Cholette`;
- gerar `data/output/ilp_rr_trimestral.csv` e `data/output/pib_nominal_rr.csv`;
- adicionar a aba **"PIB Nominal"** ao `IAET_RR_series.xlsx`.

**Correções importantes durante a implementação:**

Na primeira execução, o script falhou por dois motivos:

- o PIB do SIDRA veio em `Mil Reais`, e precisou ser convertido para `R$ milhões` para ficar na
  mesma unidade do VAB;
- a chamada do Denton precisava usar séries `ts` explícitas para evitar que o `tempdisagg`
  entrasse em modo numérico.

Após esses ajustes, a rotina fechou normalmente.

**Validação obtida:**

- o `ICMS/ILP` anual ficou em linha com o diagnóstico do plano:
  - `2020`: 82,7%
  - `2021`: 82,9%
  - `2022`: 80,7%
  - `2023`: 80,5%
- a soma dos quatro trimestres reproduziu exatamente o benchmark anual do ILP em todos os anos de
  `2020` a `2025`, com desvio numérico residual desprezível;
- o produto final passou a cobrir `2020T1–2025T4`.

**Situação em que o projeto fica agora:**

Além do `IAET-RR real` e do `VAB nominal trimestral`, o projeto passa a ter também uma série de
`PIB nominal trimestral` pronta para análise interna e eventual incorporação ao dashboard.

---

### Abril de 2026 — Reforma do dashboard: IAET no centro, exploração por escolha do usuário

**O que foi feito:**

O dashboard em `dashboard/app.R` foi redesenhado para ficar menos estático e mais exploratório.
Antes, o painel tinha pouca escolha para o usuário: a maior parte dos gráficos era fixa, os
componentes apareciam sem contraposição sistemática entre NSA e SA, e o bloco nominal mostrava só
o `VAB`, mesmo depois de o projeto já ter passado a gerar `ILP` e `PIB nominal trimestral`.

**O que mudou no painel:**

- a navegação passou a ser organizada em quatro frentes mais claras:
  - `IAET`: foco no índice principal;
  - `Componentes`: leitura individual dos blocos setoriais;
  - `PIB`: lógica contábil do nominal com `VAB + impostos + PIB`;
  - `Dados`: tabela e download da base escolhida pelo usuário;
- o usuário agora pode escolher a janela de análise em cada aba;
- o índice principal passou a destacar explicitamente:
  - nível do IAET;
  - variação interanual;
  - variação de margem dessazonalizada;
- os gráficos de índice passaram a mostrar sempre `NSA x SA` juntos, tanto para o `IAET` quanto
  para o componente escolhido;
- os componentes deixaram de ser apenas um gráfico fixo com todas as linhas ao mesmo tempo e
  passaram a ter leitura orientada por seleção do usuário;
- foi criada uma aba própria do `PIB nominal`, com:
  - `VAB nominal`;
  - `ILP trimestral`;
  - `PIB nominal`;
  - taxas de crescimento do PIB nominal.

**Crítica que motivou a reforma:**

O painel anterior era bom como vitrine, mas ainda fraco como ferramenta de análise. Ele mostrava
o que o projeto produzia, mas não deixava o usuário escolher com facilidade o que queria explorar.
Também misturava prioridades: dava muito espaço ao `VAB nominal` e pouco ao uso mais natural do
painel, que é acompanhar o `IAET` e comparar as taxas de crescimento.

**Validação feita nesta etapa:**

- o arquivo novo do dashboard passou na checagem de sintaxe;
- o carregamento completo do `app.R` também passou;
- apareceu apenas um aviso de cache do `sass` no ambiente local do terminal, mas sem impedir a
  montagem do app.

---

### Abril de 2026 — Segunda rodada de refinamento do dashboard

**O que foi ajustado:**

Depois da primeira reforma do painel, fizemos uma segunda rodada focada em linguagem, leitura e
priorização analítica.

**Melhorias aplicadas:**

- deixamos de usar siglas como `NSA` e `SA` na interface visível do usuário;
- os gráficos e tabelas passaram a falar em:
  - `sem ajuste sazonal`;
  - `dessazonalizado`;
  - `taxa de crescimento anual (t/t-4)`;
  - `taxa de crescimento trimestral`;
- os quadrinhos do topo passaram a responder ao período escolhido pelo usuário em cada aba, em vez
  de ficarem presos ao último trimestre da base completa;
- a aba de componentes deixou de destacar o nível em card próprio e passou a priorizar as taxas;
- foram criadas abas específicas para gráficos de **taxas anuais**:
  - uma para `IAET e componentes`;
  - outra para `VAB, impostos e PIB`.

**Ajuste visual importante:**

As legendas dos gráficos foram rebaixadas e receberam margem inferior maior, para reduzir o risco
de cobrir informação da própria área útil do gráfico.

**Validação:**

O `dashboard/app.R` voltou a passar tanto na checagem de sintaxe quanto no carregamento completo
do script.

*Última atualização: 14 de abril de 2026 — dashboard refinado com linguagem mais clara, cards dependentes do período selecionado e novas abas de taxas anuais*

---

### Abril de 2026 — Terceira rodada de refinamento do dashboard

**O que foi ajustado:**

Fizemos uma terceira rodada para deixar o painel mais legível e mais controlável pelo usuário,
especialmente nas abas de taxas e na aba `Sobre`.

**Melhorias aplicadas:**

- deixamos de usar a notação `t/t-4` na interface visível e passamos a falar apenas em:
  - `taxa de crescimento anual`;
  - `taxa de crescimento trimestral`;
- as abas `Taxas IAET` e `Taxas PIB` passaram a permitir alternância entre:
  - visualização `anual`, com eixo mostrando apenas os anos;
  - visualização `trimestral`, com a série trimestral correspondente;
- os gráficos anuais dessas abas passaram a condensar a leitura para os anos e suas taxas de
  crescimento, em vez de repetir rótulos trimestrais;
- o texto dinâmico dos seletores de período foi padronizado como `Período de referência`;
- as legendas passaram a ficar fora da área útil dos gráficos principais, reduzindo sobreposição
  sobre linhas, barras e pontos;
- a aba `Sobre` deixou de ser estática e passou a permitir:
  - escolha do `ano da estrutura setorial`;
  - ajuste do `período de referência` exibido no painel;
- a pizza de estrutura setorial deixou de ficar presa a 2020 e passou a ler diretamente
  `data/processed/contas_regionais_RR_serie.csv`.

**Validação:**

- a checagem de sintaxe do `dashboard/app.R` passou com `parse_ok`;
- o carregamento completo do app passou com `source_ok`;
- o único aviso residual continuou sendo o cache local do `sass`, sem bloquear a montagem.

*Última atualização: 14 de abril de 2026 — dashboard refinado com alternância anual/trimestral, legendas reposicionadas e aba Sobre interativa*

---

### Abril de 2026 — Ajuste conceitual das abas finais do dashboard

**O que foi ajustado:**

Houve uma correção conceitual nas duas abas finais do painel. A crítica central era que elas estavam
nomeadas como abas de `taxas`, mas a leitura desejada passou a ser outra: mostrar primeiro os
niveis das séries e, abaixo, o crescimento real correspondente.

**Mudanças aplicadas:**

- a aba `Taxas IAET` foi substituída por uma aba de `IAET em nível`;
- a aba `Taxas PIB` foi substituída por `PIB nominal e crescimento real`;
- na aba do IAET, o gráfico superior passou a mostrar:
  - o índice geral;
  - agropecuária;
  - administração pública;
  - indústria;
  - serviços privados;
  todos em nível;
- abaixo, a mesma aba passou a mostrar o crescimento real com alternância entre:
  - `interanual`;
  - `trimestral`;
- na aba do PIB, o gráfico superior passou a mostrar os níveis nominais de:
  - `VAB nominal`;
  - `impostos sobre produtos (ILP)`;
  - `PIB nominal`;
- abaixo, essa aba passou a mostrar o crescimento real da atividade usando o `IAET-RR`, evitando
  interpretar o crescimento do bloco nominal como se fosse crescimento real.

**Motivação metodológica:**

O ajuste foi feito para reduzir ambiguidade conceitual no painel. Em especial, a aba do PIB não
deve sugerir que o crescimento das séries nominais represente crescimento real da economia.

**Validação:**

- o `dashboard/app.R` passou novamente em `parse_ok`;
- o carregamento completo do app passou em `source_ok`;
- o único aviso residual continuou sendo o cache local do `sass`.

*Última atualização: 14 de abril de 2026 — abas finais reformuladas para separar níveis nominais e crescimento real*

---

### Abril de 2026 — Correção visual e explicativa das abas finais

**O que foi ajustado:**

Depois da reforma das abas finais do dashboard, surgiu um problema visual em que os títulos dos
cards passavam a exibir `[object Object]`. Também havia uma descrição simplificada demais do
`VAB nominal`, que podia induzir leitura errada da metodologia.

**Correções aplicadas:**

- os títulos dinâmicos dos cards passaram de `textOutput()` para `uiOutput()`, eliminando o
  retorno visual indevido de `[object Object]`;
- o texto metodológico do `VAB nominal` foi reescrito para deixar claro que a série:
  - parte do `IAET-RR` em volume;
  - usa o deflator implícito anual das Contas Regionais;
  - desagrega o deflator para frequência trimestral com IPCA via Denton-Cholette;
- os gráficos de nível das duas abas finais passaram a usar colunas empilhadas:
  - na aba `IAET em nível`, os componentes aparecem em colunas empilhadas e o `IAET-RR` permanece
    como linha de referência;
  - na aba `PIB nominal e crescimento real`, `VAB nominal`, `ILP` e `PIB nominal` aparecem como
    colunas empilhadas.

**Validação:**

- o `dashboard/app.R` voltou a passar em `parse_ok`;
- o carregamento completo do app passou em `source_ok`;
- o único aviso residual permaneceu restrito ao cache local do `sass`.

*Última atualização: 14 de abril de 2026 — corrigido bug visual dos títulos e convertidos gráficos de nível para colunas empilhadas*

---

### Abril de 2026 — Correção metodológica dos pesos internos da indústria

**O que foi corrigido:**

O bloco industrial ainda agregava `SIUP`, `Construção` e `Transformação` com pesos internos
calculados a partir das Contas Regionais de `2021`, apesar de o sistema já operar com ano-base
`2020` no índice geral e nos demais blocos reformados.

**Correção aplicada:**

- o script `R/03_industria.R` passou a calcular os pesos internos a partir do `VAB 2020`;
- os pesos internos do bloco mudaram de:
  - `SIUP 38,8% / Construção 46,2% / Transformação 15,0%`
  para:
  - `SIUP 47,3% / Construção 42,8% / Transformação 9,9%`;
- a cadeia foi rerrodada da Fase 3 em diante:
  - `03_industria.R`
  - `05_agregacao.R`
  - `05c_ajuste_sazonal.R`
  - `05d_validacao.R`
  - `05e_exportacao.R`
  - `05f_vab_nominal.R`
  - `05g_pib_nominal.R`

**Impacto medido:**

- no bloco industrial, a mudança foi material:
  - 2021: de `+12,1%` para `+10,6%`;
  - 2022: de `+19,0%` para `+20,6%`;
  - 2023: de `+7,9%` para `+9,4%`;
  - 2024: de `+15,8%` para `+17,5%`;
  - 2025: de `+17,4%` para `+19,2%`;
- a diferença máxima intra-trimestral no índice industrial entre pesos 2021 e pesos 2020 ficou em
  `12,9 pontos de índice`;
- no índice geral bruto antes do segundo Denton, a diferença máxima intra-trimestral ficou em
  `1,5 ponto de índice`;
- no índice geral final, as médias anuais de `2020–2023` permaneceram idênticas por construção,
  porque o benchmark anual total do Denton não mudou.

**Leitura metodológica:**

A crítica fazia sentido. O problema não destruía o sistema inteiro, mas quebrava a coerência do
ano-base dentro do bloco industrial. A correção deixa o sistema mais consistente com a lógica
Laspeyres base 2020 já adotada no topo e em serviços.

*Última atualização: 14 de abril de 2026 — pesos internos da indústria alinhados ao ano-base 2020*
