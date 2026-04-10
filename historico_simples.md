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

## Onde estamos agora

**Etapa atual: início da implementação**

O planejamento está concluído e aprovado. A próxima etapa é começar a escrever os códigos em R,
seguindo esta ordem:

1. **`utils.R`** — funções básicas que serão usadas por todos os outros scripts
   (como a função de "ancoragem" Denton-Cholette e a de deflação pelo IPCA)

2. **`01_agropecuaria.R`** — primeiro setor a ser implementado:
   - Calcular quanto do valor da produção agrícola de Roraima é coberto pelos dados do IBGE
   - Montar a série trimestral de lavouras usando LSPA + calendário de colheita do Censo 2006
   - Verificar disponibilidade de dados de abate, leite e ovos para Roraima
   - Ancoragem Denton ao VAB agropecuário anual do IBGE

3. **`02_adm_publica.R`** — setor público (32% da economia de RR)

4. **`03_industria.R`** — construção civil, energia e indústria

5. **`04_servicos.R`** — comércio, transportes e outros serviços

6. **`05_agregacao.R`** — juntar tudo, ajustar sazonalmente e gerar os outputs finais

---

*Última atualização: 10 de abril de 2026 — governança completa do pipeline (renv, QA, credenciais, vintagem, release)*
