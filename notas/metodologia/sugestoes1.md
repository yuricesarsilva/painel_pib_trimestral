# Sugestões sobre as proxies do projeto

## Visão geral

No geral, a arquitetura das proxies está bem pensada para a realidade de Roraima: você partiu do que é metodologicamente defensável e, ao mesmo tempo, viável em dados. O desenho é especialmente forte em três pontos: ancoragem nas Contas Regionais, prioridade para administração pública pelo peso real no VAB e uso de índice de volume em vez de tentar forçar um "PIB trimestral em reais". Dito isso, eu faria alguns ajustes para reduzir risco de viés, principalmente nos setores em que a proxy hoje mistura nível de atividade com preço, estoque ou massa salarial.

## Onde eu manteria quase como está

- `Administração pública`: folha federal + estadual é a melhor escolha do projeto. Aqui a proxy é conceitualmente muito próxima do próprio critério das contas regionais.
- `SIUP`: consumo de energia é uma proxy forte para Roraima.
- `Agropecuária`: LSPA + calendário de colheita + benchmarking anual faz sentido. É imperfeito, mas metodologicamente honesto.
- `Atividades imobiliárias`: tendência suavizada entre benchmarks anuais é uma solução defensável, porque esse setor realmente é difícil de observar em alta frequência.

## Onde eu criticaria mais fortemente

- `Comércio via ICMS`: ICMS é útil, mas sozinho é arriscado. Ele capta preço, regime tributário, benefícios fiscais, composição setorial e eventuais mudanças administrativas. Eu não deixaria como proxy principal isolada.
- `Construção via emprego + ICMS`: emprego formal reage com atraso e ICMS de materiais não mede bem obra pública, autoconstrução e informalidade, que podem ser relevantes em RR.
- `Indústria de transformação via emprego + ICMS`: funciona como aproximação fraca, mas pode ficar muito barulhenta para um setor pequeno.
- `Transportes via passageiros aéreos + diesel`: faz sentido em tese, mas diesel é proxy muito contaminada por agro, construção, geração térmica e uso geral da economia.
- `Outros serviços via CAGED`: emprego formal mede só uma parte do setor e tende a subcaptar serviços informais e ocupações com ajuste lento.
- `Financeiro via crédito e depósitos`: isso mede intermediação e condições financeiras, mas não necessariamente volume de produção do setor financeiro.

## Mudanças e inclusões por setor

### 1. Administração pública

- Manter folha federal e estadual.
- Separar `ativos` de `inativos/pensionistas`, se os dados permitirem.
- Tentar incluir uma proxy complementar de consumo intermediário do governo, mesmo simples, para não deixar o setor excessivamente dependente só da remuneração.
- Se a folha municipal for fraca, preferir interpolação conservadora a introduzir ruído excessivo.

### 2. Agropecuária

- Manter a estrutura central.
- Incluir distinção explícita entre `lavouras temporárias`, `lavouras permanentes` e `pecuária`, com pesos separados.
- Buscar proxy complementar para pecuária além das pesquisas trimestrais, caso a cobertura de RR seja ruim.
- Fazer um teste de sensibilidade com dois calendários de colheita: um fixo e um alternativo, para medir o quanto a série depende dessa hipótese.

### 3. Comércio

- Transformar o ICMS em uma proxy composta, não única.
- Inclusões desejáveis:
- emprego formal no comércio como componente de controle;
- consumo de energia comercial, se disponível;
- dados de arrecadação segmentada ou emissão fiscal, se a SEFAZ tiver algo melhor que ICMS agregado.
- Se houver mudança de alíquota ou regime, criar uma série ajustada ou ao menos dummies de quebra.

### 4. Construção

- Manter emprego e ICMS, mas acrescentar uma proxy física.
- Inclusões desejáveis:
- consumo de cimento ou outro insumo-chave;
- área licenciada ou número de alvarás/habite-se em Boa Vista e principais municípios;
- obras públicas empenhadas/liquidadas, separadamente.
- Sem isso, a construção tende a ficar submedida ou capturada com atraso.

### 5. SIUP

- Abrir o consumo de energia por classe de consumo.
- Melhor do que usar só o total:
- residencial;
- comercial;
- industrial;
- poder público.
- Isso ajuda a filtrar choques que não correspondem exatamente à atividade econômica agregada.

### 6. Indústria de transformação

- Como o peso é pequeno, eu não gastaria energia excessiva aqui, mas refinaria um pouco.
- Inclusões possíveis:
- consumo de energia industrial;
- emprego industrial;
- ICMS industrial deflacionado.
- Eu daria peso maior à energia industrial do que ao emprego, se a série estiver limpa.

### 7. Transportes

- Reduzir a dependência do diesel.
- Mudanças que eu faria:
- separar passageiros e carga aérea;
- usar diesel com peso menor;
- se possível, incluir fluxo rodoviário, frete ou movimentação logística.
- Em RR, o transporte terrestre é central, mas diesel puro é muito "sujo" como indicador.

### 8. Informação e comunicação

- Emprego formal é aceitável, mas fraco.
- Incluir, se houver acesso:
- consumo de energia de telecom/TI;
- dados administrativos de acessos, tráfego ou base instalada, se disponíveis.
- Se não houver, manter CAGED, mas com peso pequeno e nota metodológica clara.

### 9. Financeiro

- Usar `crédito + depósitos`, mas com bastante cautela.
- Melhorias:
- separar saldo de fluxo, porque saldo pode crescer sem atividade corrente equivalente;
- considerar receita de serviços financeiros, se houver alguma base pública regionalizada;
- usar essa proxy com suavização maior.
- Esse setor provavelmente precisa de tratamento mais estrutural e menos conjuntural.

### 10. Atividades imobiliárias

- Manter benchmarking anual com interpolação.
- Talvez incluir uma proxy secundária de mercado formal, como financiamentos imobiliários ou ligações residenciais, apenas para guiar pequenas oscilações, sem deixar o setor "andar sozinho".

### 11. Outros serviços

- Não deixar esse bloco só no CAGED agregado.
- Quebrar em subgrupos:
- alojamento e alimentação;
- saúde e educação privadas;
- atividades profissionais e administrativas;
- artes, cultura e outros.
- Combinar emprego com pelo menos uma proxy de consumo ou receita onde houver disponibilidade, porque serviço formal pode manter emprego mesmo com atividade caindo.

## Ajustes transversais

- Classificar cada proxy em três níveis: `conceitualmente forte`, `aceitável`, `fraca mas necessária`.
- Fazer índices compostos com pesos explícitos dentro de cada setor, em vez de escolher uma única proxy "principal".
- Aplicar testes de sensibilidade: gerar uma versão A e uma versão B do índice para ver quais proxies mais mudam o resultado.
- Criar uma regra para tratar quebras estruturais tributárias e administrativas.
- Documentar melhor quando uma proxy mede `volume`, `valor nominal`, `estoque` ou `insumo`, porque isso muda muito sua interpretação.

## Se eu tivesse que priorizar só algumas mudanças

1. Melhorar `comércio`, para não depender demais de ICMS.
2. Fortalecer `construção` com uma proxy física.
3. Reduzir o peso analítico do `diesel` em transportes.
4. Abrir `outros serviços` em subblocos.
5. Refinar `administração pública` separando ativos de inativos, se possível.
6. Desagregar energia por classe de consumo em `SIUP` e talvez também como apoio a outros setores.

## Síntese

Seu desenho de proxies é bom e plausível para uma primeira versão institucional. Eu não mudaria a espinha dorsal. O que eu faria é trocar várias proxies unitárias por proxies compostas e reduzir dependência de ICMS, emprego formal e diesel onde eles hoje estão carregando mais significado do que conseguem sustentar.
