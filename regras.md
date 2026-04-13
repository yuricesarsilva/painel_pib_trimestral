# Regras do Projeto — Leitura Obrigatória a Cada Interação

Este arquivo define o protocolo obrigatório ao final de **qualquer modificação** feita no projeto.
Nenhuma sessão de trabalho deve ser encerrada sem que todos os itens abaixo tenham sido executados.

---

## Protocolo obrigatório ao final de cada modificação

### 1. Atualizar `.gitignore` (se necessário)
- Verificar se novos tipos de arquivo foram criados que não devem ser versionados
- Exemplos: arquivos de credenciais, dados brutos, outputs temporários, arquivos de ambiente (`.env`)
- Atualizar o `.gitignore` antes do commit se houver algo novo a ignorar

### 2. Atualizar `historico_simples.md`
- Registrar o que foi feito na sessão em linguagem simples e acessível
- Qualquer pessoa leiga deve conseguir entender o que mudou
- Incluir: o que foi feito, por que foi feito, e em que etapa do projeto estamos agora
- Atualizar a linha *"Última atualização"* com a data atual

### 3. Atualizar `README.md`
- Atualizar se houver mudanças na estrutura do projeto, novas fontes, novos scripts ou novos outputs
- Manter a seção de estrutura do repositório sempre refletindo o estado atual dos arquivos
- Não é necessário atualizar a cada pequena mudança — apenas quando algo relevante para quem visita o repositório mudar

### 4. Atualizar `plano_projeto.md` — obrigatório sempre que ocorrer qualquer um dos gatilhos abaixo

O `plano_projeto.md` é o **documento técnico de referência do projeto**. Ele deve refletir
fielmente o que está implementado — não o que foi planejado inicialmente. Toda decisão tomada
durante a coleta ou implementação que diverge do plano original ou que acrescenta detalhes
técnicos relevantes deve ser registrada aqui **imediatamente**, no mesmo commit em que a
mudança ocorreu.

#### Gatilhos obrigatórios de atualização

| Situação | O que registrar no plano |
|---|---|
| Uma fonte de dados não está disponível para RR | Documentar a indisponibilidade, a fonte alternativa usada e a justificativa metodológica |
| Uma tabela ou endpoint SIDRA/API tem estrutura diferente do esperado | Corrigir a referência (tabela, classificação, variável, formato do período) |
| Uma proxy é substituída por outra mais adequada | Substituir a descrição da proxy, atualizar a tabela de fontes e o tipo de medida |
| Uma série é excluída do índice (ex: indisponível para RR) | Documentar a exclusão e como o peso foi redistribuído ou absorvido |
| Uma conversão ou tratamento não trivial é aplicado (ex: bimestral acumulado → trimestral) | Descrever o procedimento na seção do setor correspondente |
| Um resultado de validação muda a interpretação do índice | Registrar o resultado real (ex: variações anuais vs. IBGE) |
| Um peso ou coeficiente é calculado e passa a ser valor definitivo (ex: lavouras 93%, pecuária 7%) | Substituir "a verificar" pelo valor real |
| Uma decisão metodológica nova é tomada (ex: usar fluxo em vez de estoque para financeiro) | Adicionar à seção "Decisões metodológicas a documentar na nota técnica" |

#### O que NÃO precisa atualizar o plano

- Correções de bugs em scripts (não mudam a metodologia)
- Ajustes de formatação ou log output
- Atualizações do checklist, histórico ou README que não envolvam decisão metodológica

#### Padrão de escrita

Escrever no **tempo presente e no estado atual** — não como histórico ("foi descoberto que..."),
mas como especificação viva ("a Tab. 6588 usa classificação c48; o período vem no formato
'dezembro AAAA'"). O plano deve ser legível por alguém que entra no projeto agora, não por
quem acompanhou o processo.

### 5. Atualizar `checklist.md`
- Marcar com `[x]` todos os itens concluídos na sessão
- Adicionar novos itens se tarefas não previstas foram identificadas durante o trabalho
- Atualizar a tabela de **Status geral** no final do arquivo
  - 🟢 Concluída — todos os itens da fase estão marcados
  - 🟡 Em andamento — fase iniciada mas não concluída
  - ⚪ Não iniciada — nenhum item da fase foi iniciado

### 6. Commit em português
- Fazer commit de **todos** os arquivos modificados (inclusive os de controle acima)
- A mensagem do commit deve ser em **português**
- A mensagem deve descrever claramente o que foi feito, ex:
  - `"Adiciona script de cobertura PAM — Fase 1, Etapa 1.0"`
  - `"Corrige cálculo do índice de Laspeyres em 01_agropecuaria.R"`
  - `"Atualiza checklist e histórico após conclusão da Fase 2"`

### 7. Push para o GitHub
- Fazer push após o commit
- Verificar se o push foi bem-sucedido antes de encerrar a sessão

---

## Ordem de execução

```
1. Trabalho técnico (scripts, dados, análises)
        ↓
2. .gitignore  (se necessário)
        ↓
3. plano_projeto.md  ← atualizar imediatamente se houver gatilho metodológico
        ↓              (ver lista de gatilhos na seção 4)
4. historico_simples.md
        ↓
5. README.md  (se necessário)
        ↓
6. checklist.md
        ↓
7. git commit -m "mensagem em português"
        ↓
8. git push
```

---

## Regras gerais do projeto

- Os dados brutos e processados ficam **apenas localmente** (pasta `data/` está no `.gitignore`)
- Os scripts R devem ser autocontidos e reproduzíveis: qualquer pessoa com acesso ao repositório e às fontes deve conseguir rodar
- Nomes de arquivos e variáveis em R: usar `snake_case` em português (ex: `serie_lavouras`, `peso_vbp`)
- Comentários nos scripts R: em português
- Cada script deve começar com um cabeçalho padronizado (autor, data, descrição, dependências)

---

## Regras sobre localização e versionamento de scripts

### A pasta `data/` é para dados — nunca para código

- **Todos os scripts R ficam em `R/`** — sem exceção
- Scripts exploratórios e de depuração ficam em **`R/exploratorio/`** (também versionados)
- Nenhum arquivo `.R` deve estar em `data/raw/`, `data/processed/` ou `data/output/`

### Todos os downloads devem ser automatizados e versionados

- **Nenhum arquivo de dado pode ser baixado manualmente** sem que exista um script em `R/`
  correspondente que faça o mesmo download de forma automática
- Se um dado foi obtido manualmente em algum momento, o script de download automático deve ser
  criado e commitado antes de continuar o projeto
- O script de download deve ser **idempotente**: ao ser rodado mais de uma vez, não deve gerar
  erros nem duplicar dados (verificar se o arquivo já existe antes de baixar)

### Caminhos nos scripts

- Usar sempre **caminhos relativos à raiz do projeto** — nunca caminhos absolutos hardcoded
  (ex: usar `file.path("data", "raw", "arquivo.csv")`, nunca
  `"C:/Users/fulano/OneDrive/..."`)
- O script deve ser executado com o diretório de trabalho definido como a raiz do projeto
  (`setwd()` ou via RStudio com o `.Rproj` aberto)

### Cabeçalho padronizado obrigatório

Todo script em `R/` deve começar com o seguinte cabeçalho:

```r
# ============================================================
# Projeto : Indicador de Atividade Econômica Trimestral — RR
# Script  : nome_do_script.R
# Autor   : Yuri Cesar de Lima e Silva (DIEAS/SEPLAN-RR)
# Data    : AAAA-MM-DD
# Descrição: O que este script faz, em uma ou duas linhas.
# Entrada : arquivos ou APIs consumidos
# Saída   : arquivos gerados em data/processed/ ou data/output/
# Depende : pacotes R necessários
# ============================================================
```

---

## Gestão do ambiente R — `renv`

O projeto usa `renv` para garantir que qualquer pessoa que clone o repositório use exatamente
as mesmas versões de pacotes — agora e no futuro.

### Regras obrigatórias

- O arquivo `renv.lock` deve estar **sempre commitado e atualizado**
- Sempre que um novo pacote for instalado ou a versão de um pacote mudar:
  1. Rodar `renv::snapshot()` para atualizar o `renv.lock`
  2. Commitar o `renv.lock` junto com o script que introduziu o pacote
- Para restaurar o ambiente em uma nova máquina: `renv::restore()`
- A pasta `renv/library/` está no `.gitignore` (não commitar — é gerada localmente)
- O arquivo `renv/activate.R` deve estar commitado

### Inicialização (primeira vez por máquina)

```r
# Na raiz do projeto, com o .Rproj aberto:
renv::restore()   # instala os pacotes nas versões exatas do renv.lock
```

### Ao instalar novo pacote

```r
install.packages("nome_pacote")  # instala
renv::snapshot()                 # registra no renv.lock
# commitar o renv.lock atualizado
```

---

## Gestão de credenciais e APIs

Algumas fontes de dados requerem autenticação. Credenciais **nunca entram em scripts** — isso
evita exposição acidental no repositório público.

### Regras obrigatórias

- Tokens e senhas ficam **exclusivamente** no arquivo `.env` na raiz do projeto
- O arquivo `.env` está no `.gitignore` e **nunca deve ser commitado**
- O arquivo `.env.exemplo` (com as variáveis esperadas, **sem valores reais**) está versionado
  e deve ser atualizado sempre que uma nova variável for necessária
- Nos scripts, credenciais são lidas com `Sys.getenv("NOME_DA_VARIAVEL")`
- Se uma variável obrigatória não estiver definida, o script deve parar imediatamente:

```r
token <- Sys.getenv("TOKEN_TRANSPARENCIA")
if (nchar(token) == 0) stop("TOKEN_TRANSPARENCIA não definido. Configure o arquivo .env.")
```

### Como configurar em uma nova máquina

1. Copiar `.env.exemplo` para `.env`
2. Preencher os valores reais no `.env`
3. Nunca commitar o `.env`

---

## Qualidade e validação (QA)

Todo script setorial deve validar sua série de saída antes de salvar o arquivo. A função
`validar_serie()` está em `R/utils.R` e é o mecanismo padrão de QA do projeto.

### Regras obrigatórias

- **Todo script que gera uma série temporal deve chamar `validar_serie()`** ao final,
  antes do `write.csv()` ou equivalente
- Se a validação falhar, o script para com `stop()` e mensagem descritiva — **nunca** continuar
  com dado inválido para a etapa seguinte
- Variações trimestrais extremas (acima de 50% em valor absoluto) geram **aviso** (`warning`),
  não erro — podem ser legítimas (ex: 2020 COVID), mas devem ser inspecionadas manualmente
- Além da validação automática, cada fase tem uma validação manual definida no `plano_projeto.md`
  (gráfico vs. benchmark IBGE) — obrigatória antes de marcar a fase como concluída

### O que `validar_serie()` verifica

1. Comprimento mínimo da série (≥ 4 observações)
2. Ausência de `NA` em posições não autorizadas
3. Ausência de valores zero ou negativos (índices de volume devem ser positivos)
4. Variações período a período acima do limiar configurável (padrão: 50%)

---

## Vintagem e rastreabilidade dos dados

Para cada release trimestral publicado, deve ser possível saber: quais dados foram usados,
de qual período, baixados em que data, e se houve revisão da fonte.

### Regras obrigatórias

- O arquivo `logs/fontes_utilizadas.csv` deve ser atualizado **a cada run do pipeline**,
  antes do commit do release
- A pasta `logs/` é **versionada** — commitar sempre que atualizada
- O arquivo registra uma linha por fonte por release, com as colunas:

| Coluna | Descrição |
|---|---|
| `fonte` | Nome da fonte de dados (ex: CAGED, PAM, SIAPE) |
| `descricao` | Dado específico coletado |
| `periodo_coberto` | Período da série utilizada (ex: 2020Q1–2025Q4) |
| `data_download` | Data em que o dado foi baixado (AAAA-MM-DD) |
| `versao_release` | Tag do release em que foi usado (ex: v2026-Q1) |
| `url_ou_fonte` | URL, API ou fonte interna |
| `observacao` | Revisões, discrepâncias ou notas |

- Se um dado foi revisado pela fonte entre dois releases, registrar em `observacao`

---

## Execução do pipeline

O pipeline completo é executado via `R/run_all.R`. Nunca rodar scripts setoriais de forma
avulsa fora da sequência definida — isso pode gerar inconsistências entre as séries.

### Regras obrigatórias

- Sempre usar `run_all.R` para rodar o pipeline completo
- O `run_all.R` para na primeira falha — corrigir o erro antes de continuar
- Nunca alterar outputs manualmente — todo resultado deve ser reproduzível via script
- Sempre executar com o diretório de trabalho definido como a raiz do projeto

### Sequência obrigatória dos scripts

```
R/00_dados_referencia.R   → Contas Regionais (pesos)
R/01_agropecuaria.R       → Fase 1
R/02_adm_publica.R        → Fase 2
R/03_industria.R          → Fase 3
R/04_servicos.R           → Fase 4
R/05_agregacao.R          → Fase 5 (índice final)
```

---

## Manutenção de documentos da reforma metodológica

Os arquivos abaixo documentam a reforma metodológica de ancoragem ao VAB real (iniciada em
2026-04-12). Eles devem ser mantidos atualizados sempre que houver mudanças relacionadas.

### `plano_reforma_indicador_real.md`

Atualizar sempre que:
- A estratégia de ancoragem ao volume real for revisada (ex: mudança de Tabela 6 para outra fonte)
- A abordagem do VAB nominal trimestral (Ponto 2) for alterada ou descartada
- O mapeamento de atividades IBGE × setores do projeto for corrigido
- As taxas de crescimento esperadas após a reforma forem verificadas e diferirem do previsto

### `checklist_reforma.md`

Atualizar imediatamente sempre que:
- Uma etapa ou subetapa for concluída → marcar com `[x]`
- Uma etapa precisar ser refeita (ex: erro detectado após conclusão) → desmarcar e adicionar nota
- Uma nova subetapa não prevista for identificada durante a implementação → adicionar ao checklist
- O status geral da tabela ao final do arquivo mudar

**Regra**: nunca encerrar uma sessão que modifique scripts da reforma (00, 01, 02, 03, 04, 05)
sem antes atualizar o `checklist_reforma.md`.

---

## Protocolo de release trimestral

Um **release** é a publicação oficial de um novo trimestre do indicador. O protocolo abaixo
garante rastreabilidade, integridade e reversibilidade.

### Passos obrigatórios (nesta ordem)

```
1. Rodar pipeline completo via run_all.R
        ↓
2. Confirmar que todas as validações automáticas passaram
        ↓
3. Executar validações manuais do checklist (Fase 5.4)
        ↓
4. Atualizar logs/fontes_utilizadas.csv com as fontes do release
        ↓
5. Atualizar nota técnica conjuntural (notas/nota_tecnica.qmd)
        ↓
6. Commitar todos os arquivos modificados
        ↓
7. Criar tag git anotada:
   git tag -a "v2026-Q1" -m "Release Q1 2026 — <descrição breve>"
        ↓
8. Push incluindo a tag:
   git push && git push --tags
        ↓
9. Atualizar dashboard e publicar nota técnica
```

### Sobre outputs e histórico

- Os arquivos em `data/output/` são **sempre sobrescritos** a cada release (versão mais recente)
- O histórico completo de todos os releases é preservado via **tags git**
- Para auditar um número publicado anteriormente: `git checkout v2026-Q1`
- Para comparar dois releases: `git diff v2026-Q1 v2026-Q2 -- data/output/`
  (não funciona diretamente pois `data/` está no gitignore — usar os scripts commitados)

### Nomenclatura das tags

- Formato: `vAAAA-QN` (ex: `v2026-Q1`, `v2026-Q2`)
- Releases metodológicos (mudança de proxy, revisão de pesos): `v2026-Q1-rev1`
