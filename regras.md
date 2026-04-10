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

### 4. Atualizar `checklist.md`
- Marcar com `[x]` todos os itens concluídos na sessão
- Adicionar novos itens se tarefas não previstas foram identificadas durante o trabalho
- Atualizar a tabela de **Status geral** no final do arquivo
  - 🟢 Concluída — todos os itens da fase estão marcados
  - 🟡 Em andamento — fase iniciada mas não concluída
  - ⚪ Não iniciada — nenhum item da fase foi iniciado

### 5. Commit em português
- Fazer commit de **todos** os arquivos modificados (inclusive os de controle acima)
- A mensagem do commit deve ser em **português**
- A mensagem deve descrever claramente o que foi feito, ex:
  - `"Adiciona script de cobertura PAM — Fase 1, Etapa 1.0"`
  - `"Corrige cálculo do índice de Laspeyres em 01_agropecuaria.R"`
  - `"Atualiza checklist e histórico após conclusão da Fase 2"`
- Incluir sempre ao final: `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>`

### 6. Push para o GitHub
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
5. checklist.md
        ↓
6. git commit -m "mensagem em português"
        ↓
7. git push
```

---

## Regras gerais do projeto

- Os dados brutos e processados ficam **apenas localmente** (pasta `data/` está no `.gitignore`)
- Os scripts R devem ser autocontidos e reproduzíveis: qualquer pessoa com acesso ao repositório e às fontes deve conseguir rodar
- Nomes de arquivos e variáveis em R: usar `snake_case` em português (ex: `serie_lavouras`, `peso_vbp`)
- Comentários nos scripts R: em português
- Cada script deve começar com um cabeçalho padronizado (autor, data, descrição, dependências)
