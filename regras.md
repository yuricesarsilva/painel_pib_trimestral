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

### 4. Atualizar `plano_projeto.md` (se necessário)
- Atualizar se houver mudanças metodológicas, novas decisões de design, correções de proxies ou fontes
- Manter as decisões metodológicas sempre refletindo o estado atual do projeto
- Não é necessário atualizar a cada pequena mudança — apenas quando algo alterar a estratégia ou metodologia

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
3. historico_simples.md
        ↓
4. README.md  (se necessário)
        ↓
5. plano_projeto.md  (se necessário)
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
