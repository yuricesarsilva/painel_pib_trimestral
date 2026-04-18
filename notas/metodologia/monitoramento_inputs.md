# Monitoramento de Variáveis de Input por Script R

Este arquivo resume, por script `R/`, quais são os inputs atuais do pipeline, a fonte de cada variável, a especificação exata usada no código, o tratamento aplicado e os arquivos de saída gerados.

## Escopo

- Inclui os scripts principais do pipeline e os scripts auxiliares que consomem outputs internos.
- Quando a fonte é um arquivo gerado por etapa anterior, isso aparece como `fonte interna do pipeline`.
- As especificações abaixo refletem o estado atual do código em `2026-04-18`.

## `R/00_dados_referencia.R`

### 1. VAB nominal anual por atividade

Fonte: IBGE Contas Regionais 2023.

Especificação exata no código: download do ZIP `Conta_da_Producao_2002_2023_xls.zip` em `https://ftp.ibge.gov.br/Contas_Regionais/2023/xls/Conta_da_Producao_2002_2023_xls.zip`, leitura do arquivo `Tabela5.xls` e extração das abas `Tabela5.1` a `Tabela5.16` para Roraima.

O que é feito com ela: o script extrai a série anual de VAB nominal por atividade, padroniza os nomes das atividades e monta `contas_regionais_RR_serie.csv`. No estado atual do pipeline, esse arquivo ainda é usado em etapas de pesos de composição, validação nominal, VAB nominal, PIB nominal e abertura setorial nominal. Ele não é mais o benchmark anual do Denton nos scripts reais.

Output gerado: `data/processed/vab_roraima_2023.csv` e `data/processed/contas_regionais_RR_serie.csv`.

### 2. Índice de volume anual por atividade

Fonte: IBGE Contas Regionais 2023.

Especificação exata no código: download do ZIP `Especiais_2002_2023_xls.zip` em `https://ftp.ibge.gov.br/Contas_Regionais/2023/xls/Especiais_2002_2023_xls.zip`, com leitura do arquivo `tab05.xls`.

O que é feito com ela: o script extrai o índice encadeado de volume anual por atividade e o rebaseia para `2020 = 100`, gerando o benchmark real hoje usado pelo Denton-Cholette nos scripts setoriais e no agregado.

Output gerado: `data/processed/contas_regionais_RR_volume.csv`.

## `R/00b_icms_sefaz_atividade.R`

### 1. Composição setorial do ICMS em PDFs trimestrais

Fonte: SEFAZ-RR.

Especificação exata no código: leitura dos arquivos em `bases_baixadas_manualmente/dados_icms_por_atividade/trimestral_2020.1-2024.2`, com extração por `pdftools` da última página dos PDFs.

O que é feito com ela: o script identifica a participação setorial do ICMS por trimestre nos blocos `Setor Secundário (Indústria)`, `Terciário Comércio Atacado + Varejo`, `Terciário Serviços` e `Contribuintes Não Cadastrados`.

Output gerado: insumo para `data/processed/icms_sefaz_rr_trimestral.csv`.

### 2. Composição setorial do ICMS em PDFs mensais

Fonte: SEFAZ-RR.

Especificação exata no código: leitura dos arquivos em `bases_baixadas_manualmente/dados_icms_por_atividade/mensal_2024.05_2026.02`, com agregação posterior para trimestre.

O que é feito com ela: o script lê a composição mensal mais recente e a agrega internamente para trimestre, respeitando a precedência da base trimestral nos períodos de sobreposição.

Output gerado: insumo para `data/processed/icms_sefaz_rr_trimestral.csv`.

### 3. ICMS total mensal

Fonte: fonte interna do pipeline com origem em SEFAZ-RR.

Especificação exata no código: arquivo `data/processed/icms_sefaz_rr_mensal.csv`, tratado como série total confiável.

O que é feito com ela: o script aplica as participações setoriais extraídas dos PDFs sobre o total mensal, gerando as séries `icms_industria_mi`, `icms_comercio_mi`, `icms_servicos_mi` e `icms_total_mi` em frequência trimestral.

Output gerado: `data/processed/icms_sefaz_rr_trimestral.csv`.

## `R/01_agropecuaria.R`

### 1. PAM lavouras

Fonte: SIDRA/IBGE.

Especificação exata no código: API `"/t/5457/n3/14/v/214,215/p/all/c782/all"`, com `214 = quantidade`, `215 = VBP`, UF `14 = RR`, e cache em `data/raw/sidra/pam_temp_rr.csv`. No estado atual do script, esse cache é usado por padrão; nova consulta ao SIDRA só ocorre se `atualizar_sidra <- TRUE` for definido explicitamente.

O que é feito com ela: mede a cobertura das culturas e calcula os pesos Laspeyres das lavouras com base na média do VBP dos 4 últimos anos disponíveis da PAM. Hoje, com a PAM disponível até 2024, essa janela corresponde a `2021–2024`. A mesma base também fornece a parte anual definitiva das lavouras.

Output gerado: `data/processed/cobertura_lspa_pam.csv` e insumo para `data/processed/serie_lavouras_trimestral.csv`.

### 2. LSPA dezembro

Fonte: SIDRA/IBGE.

Especificação exata no código: API `"/t/6588/n3/14/v/35/p/all/c48/all"`, usando apenas observações cujo mês começa por `dezembro`, com cache em `data/raw/sidra/lspa_rr.csv`. No estado atual do script, esse cache é usado por padrão; nova consulta ao SIDRA só ocorre se `atualizar_sidra <- TRUE` for definido explicitamente.

O que é feito com ela: substitui a PAM nos anos ainda não fechados, agregando as safras por cultura para gerar quantidade anual provisória.

Output gerado: insumo para `data/processed/serie_lavouras_trimestral.csv`.

### 3. Calendário de colheita

Fonte: SEADI-RR ou referências internas.

Especificação exata no código: arquivo ativo padrão `data/referencias/calendario_colheita_seadi_rr.csv`; alternativas `calendario_colheita_censo2006_area_rr.csv` e `calendario_colheita_censo2006_estabelecimentos_rr.csv`.

O que é feito com ela: converte a produção anual de cada cultura em distribuição mensal, gerando coeficientes sazonais de colheita.

Output gerado: `data/processed/coef_sazonais_colheita.csv` e `data/processed/serie_lavouras_trimestral.csv`.

### 4. Parâmetro estrutural anual da agropecuária

Fonte: arquivo manual de referência interna.

Especificação exata no código: leitura do arquivo manual `bases_baixadas_manualmente/dados_participacao_vab_agopecuaria_rr_2020_2023/vab_agropecuaria_pib_ibge.xlsx`, com média do período `2020–2023` para os subsetores anuais da agropecuária.

O que é feito com ela: o script usa essa tabulação anual como parâmetro estrutural para calibrar a proporção entre `lavouras` e `pecuária` no índice agropecuário trimestral. O terceiro subsetor anual da agropecuária funciona como referência estrutural da calibração, mas não entra como proxy trimestral direta no script.

Output gerado: insumo para `data/output/indice_agropecuaria.csv`.

### 5. Abate de animais

Fonte: SIDRA/IBGE.

Especificação exata no código: API `"/t/1092/n3/14/v/284/p/all/c12716/all"`, com filtro operacional em `Referência temporal = Total do trimestre`. A tabela 1092 é a pesquisa trimestral de abate de bovinos; no arquivo retornado a classificação específica é `Tipo de rebanho bovino`, usada no código com `Total`. Para Roraima, o projeto não usa abate trimestral de suínos ou frango porque o IBGE não divulga, no mesmo desenho operacional adotado aqui, séries trimestrais equivalentes para essas espécies. Cache em `data/raw/sidra/abate_rr.csv`.

O que é feito com ela: compõe, junto com ovos, a proxy trimestral da pecuária com dados efetivamente disponíveis para Roraima. No estado atual do código, `abate bovino` recebe peso predominante na composição interna da proxy pecuária e a série só é aceita quando a cobertura trimestral observada está completa na janela operacional validada.

Output gerado: `data/processed/serie_pecuaria_trimestral.csv`.

### 6. Produção de ovos

Fonte: SIDRA/IBGE.

Especificação exata no código: API `"/t/7524/n3/14/v/29/p/all"`, com filtro operacional em `Finalidade da produção = Total` e `Referência temporal = Total do trimestre`, com cache em `data/raw/sidra/ovos_rr.csv`.

O que é feito com ela: complementa a proxy trimestral da pecuária. Desde a revisão metodológica desta etapa, o script não usa mais fallback por interpolação anual para substituir lacunas observadas em `abate` ou `ovos`.

Output gerado: `data/processed/serie_pecuaria_trimestral.csv`.

### 7. Série real anual oficial da agropecuária

Fonte: fonte interna do pipeline com origem em IBGE.

Especificação exata no código: `data/processed/contas_regionais_RR_volume.csv`, atividade `Agropecuária`.

O que é feito com ela: aplica Denton-Cholette à proxy trimestral, ancorando a série ao benchmark anual real oficial.

Output gerado: `data/output/indice_agropecuaria.csv`.

## `R/02_adm_publica.R`

### 1. Folha federal mensal

Fonte: Portal da Transparência / SIAPE.

Especificação exata no código: arquivos ZIP manuais em `bases_baixadas_manualmente/dados_siape_portal_transparencia/`, consolidados no cache `data/raw/siape_rr_mensal.csv`, com variável monetária `folha_bruta`.

O que é feito com ela: consolida a remuneração mensal dos servidores federais lotados em Roraima, preenche lacunas mensais por interpolação quando necessário e agrega para trimestre.

Output gerado: `data/raw/siape_rr_mensal.csv` e `data/output/indice_adm_publica.csv`.

### 2. Folha estadual mensal

Fonte: FIPLAN / SEPLAN-RR.

Especificação exata no código: arquivos `.xls` manuais em `bases_baixadas_manualmente/dados_folha_rr_fip855/`, leitura do relatório `FIP 855 - Resumo Mensal da Despesa Liquidada`, com a proxy estadual definida como a soma das rubricas `3190.1100`, `3190.1200` e `3190.1300`; cache em `data/raw/folha_estadual_rr_mensal.csv`.

O que é feito com ela: extrai a despesa mensal de pessoal do estado a partir do FIPLAN e agrega diretamente para série trimestral.

Output gerado: `data/raw/folha_estadual_rr_mensal.csv` e `data/output/indice_adm_publica.csv`.

### 3. Folha municipal bimestral acumulada

Fonte: STN / SICONFI.

Especificação exata no código: endpoint `https://apidatalake.tesouro.gov.br/ords/siconfi/tt/rreo`, com `no_anexo = "RREO-Anexo 06"` e `id_ente` de cada município de RR, usando o filtro `RREO6PessoalEEncargosSociais` com `DESPESAS LIQUIDADAS`; cache em `data/raw/folha_municipal_rr.csv`.

O que é feito com ela: consolida as folhas dos 15 municípios, soma os valores e converte o bimestral acumulado para série trimestral.

Output gerado: `data/raw/folha_municipal_rr.csv` e `data/output/indice_adm_publica.csv`.

### 4. IPCA mensal

Fonte: SIDRA/IBGE.

Especificação exata no código: API `"/t/1737/n1/all/v/2266/p/all/d/v2266%2013"`, com cache em `data/raw/ipca_mensal.csv`.

O que é feito com ela: deflaciona a folha total nominal para construir `folha_real` e o índice bruto de Administração Pública.

Output gerado: `data/raw/ipca_mensal.csv` e `data/output/indice_adm_publica.csv`.

### 5. Série real anual oficial de AAPP

Fonte: fonte interna do pipeline com origem em IBGE.

Especificação exata no código: `data/processed/contas_regionais_RR_volume.csv`, benchmark anual da atividade de administração pública.

O que é feito com ela: aplica Denton-Cholette ao índice trimestral bruto de folha real.

Output gerado: `data/output/indice_adm_publica.csv`.

## `R/03_industria.R`

### 1. Energia elétrica por classe

Fonte: ANEEL / SAMP.

Especificação exata no código: API CKAN de `dadosabertos.aneel.gov.br`, `dataset_id = 3e153db4-a503-4093-88be-75d31b002dcf`, com filtros `distribuidora = "BOA VISTA"`, `tipo_mercado = "Sistema Isolado - Regular"` e `detalhe = "Energia TE (kWh)"`; cache em `data/raw/aneel/aneel_energia_rr.csv`.

O que é feito com ela: gera a proxy de `SIUP` com soma de todas as classes e a proxy da transformação com a classe `Industrial`.

Output gerado: `data/raw/aneel/aneel_energia_rr.csv`, `data/output/indice_industria.csv` e `data/output/sensibilidade/proxies_transformacao.csv`.

### 2. Microdados do CAGED

Fonte: MTE / Novo CAGED.

Especificação exata no código: download via FTP `ftp://ftp.mtps.gov.br/pdet/microdados/NOVO%20CAGED/...`, com cache consolidado em `data/raw/caged/caged_rr_mensal.csv`; seções CNAE usadas no bloco são `F` para Construção e `C` para Transformação.

O que é feito com ela: consolida o saldo mensal de vínculos formais em RR, transforma o saldo em estoque acumulado e agrega para trimestre.

Output gerado: `data/raw/caged/caged_rr_mensal.csv`, `data/output/indice_industria.csv` e `data/output/sensibilidade/proxies_transformacao.csv`.

### 3. Cimento

Fonte: arquivo manual opcional.

Especificação exata no código: arquivo `data/raw/snic_cimento_rr.csv`.

O que é feito com ela: quando presente, complementa a proxy da construção; quando ausente, a construção segue apenas com CAGED `F`.

Output gerado: `data/output/indice_industria.csv`.

### 4. Série real anual oficial da indústria

Fonte: fonte interna do pipeline com origem em IBGE.

Especificação exata no código: `data/processed/contas_regionais_RR_volume.csv`, nas atividades `Eletricidade, gás, água, esgoto e resíduos (SIUP)`, `Construção` e `Indústrias de transformação`.

O que é feito com ela: aplica Denton-Cholette aos três subsetores antes da composição do bloco industrial.

Output gerado: `data/output/indice_industria.csv`.

### 5. Série nominal anual oficial da indústria

Fonte: fonte interna do pipeline com origem em IBGE.

Especificação exata no código: `data/processed/contas_regionais_RR_serie.csv`, com uso do ano-base 2020 para pesos internos.

O que é feito com ela: calcula os pesos relativos de `SIUP`, `Construção` e `Transformação` dentro do bloco indústria.

Output gerado: `data/output/indice_industria.csv`.

## `R/04_servicos.R`

### 1. Energia comercial

Fonte: fonte interna do pipeline com origem em ANEEL.

Especificação exata no código: arquivo `data/raw/aneel/aneel_energia_rr.csv`, filtrando `classe == "Comercial"`.

O que é feito com ela: compõe a proxy de `Comércio`, com agregação trimestral e normalização em base 2020.

Output gerado: `data/output/indice_servicos.csv` e `data/output/sensibilidade/proxies_servicos.csv`.

### 2. CAGED serviços

Fonte: fonte interna do pipeline com origem em MTE.

Especificação exata no código: arquivo `data/raw/caged/caged_rr_mensal.csv`, usando as seções `G`, `H`, `I`, `J`, `K`, `M`, `N`, `P` e `Q`, além dos agrupamentos internos por subsetor.

O que é feito com ela: gera estoques trimestrais de emprego para comércio (`G`), outros serviços e componentes auxiliares.

Output gerado: `data/output/indice_servicos.csv` e `data/output/sensibilidade/proxies_servicos.csv`.

### 3. Passageiros e carga aérea

Fonte: ANAC.

Especificação exata no código: arquivos ZIP manuais em pasta de bases baixadas manualmente, consolidados no cache `data/raw/anac/anac_bvb_mensal.csv`, com identificação do aeroporto `SBBV/BVB`.

O que é feito com ela: monta a série mensal de `pax_total` e `carga_kg`, depois agrega a trimestre para o bloco `Transportes`.

Output gerado: `data/raw/anac/anac_bvb_mensal.csv`, `data/output/indice_servicos.csv` e `data/output/sensibilidade/proxies_servicos.csv`.

### 4. Vendas de diesel

Fonte: ANP.

Especificação exata no código: download de dados abertos, consolidado em `data/raw/anp/anp_diesel_rr_mensal.csv`, com a variável `diesel_m3` para `UF = RR`.

O que é feito com ela: agrega a trimestre e usa como componente do bloco `Transportes`.

Output gerado: `data/raw/anp/anp_diesel_rr_mensal.csv`, `data/output/indice_servicos.csv` e `data/output/sensibilidade/proxies_servicos.csv`.

### 5. Depósitos bancários

Fonte: BCB / Estban.

Especificação exata no código: ZIPs manuais em `bases_baixadas_manualmente/dados_estban_bcb`, consolidados em `data/raw/bcb/bcb_estban_rr_mensal.csv`, com soma dos verbetes `420` e `432`.

O que é feito com ela: gera a proxy mensal de `depositos`, depois deflaciona e agrega a trimestre para o bloco `Financeiro`.

Output gerado: `data/raw/bcb/bcb_estban_rr_mensal.csv`, `data/output/indice_servicos.csv` e `data/output/sensibilidade/proxies_servicos.csv`.

### 6. Crédito / carteira ativa

Fonte: BCB / SCR.

Especificação exata no código: ZIPs manuais em `bases_baixadas_manualmente/dados_bcb_src_2020_2025`, consolidados em `data/raw/bcb/bcb_concessoes_rr_mensal.csv`, com variável padronizada no script como `concessoes`.

O que é feito com ela: gera a proxy mensal de crédito para RR, aplica deflação e suavização por média móvel de 3 meses, e depois agrega a trimestre para o bloco `Financeiro`.

Output gerado: `data/raw/bcb/bcb_concessoes_rr_mensal.csv`, `data/output/indice_servicos.csv` e `data/output/sensibilidade/proxies_servicos.csv`.

### 7. IPCA mensal

Fonte: SIDRA/IBGE.

Especificação exata no código: API `"/t/1737/n1/all/v/2266/p/all/d/v2266%2013"`, com cache em `data/raw/ipca_mensal.csv`.

O que é feito com ela: deflaciona `ICMS comércio`, `concessoes` e `depositos`.

Output gerado: `data/raw/ipca_mensal.csv` e `data/output/indice_servicos.csv`.

### 8. ICMS comércio trimestral

Fonte: fonte interna do pipeline com origem em SEFAZ-RR.

Especificação exata no código: arquivo `data/processed/icms_sefaz_rr_trimestral.csv`, usando a coluna `icms_comercio_mi`.

O que é feito com ela: compõe o bloco `Comércio`, após deflação pelo IPCA trimestral médio.

Output gerado: `data/output/indice_servicos.csv` e `data/output/sensibilidade/proxies_servicos.csv`.

### 9. Série real anual oficial de serviços

Fonte: fonte interna do pipeline com origem em IBGE.

Especificação exata no código: `data/processed/contas_regionais_RR_volume.csv`, com benchmarks anuais para comércio, transportes, atividades financeiras, informação e comunicação, outros serviços e imobiliário.

O que é feito com ela: aplica Denton-Cholette aos subsetores trimestrais antes da agregação do bloco serviços.

Output gerado: `data/output/indice_servicos.csv`.

### 10. Série nominal anual oficial de serviços

Fonte: fonte interna do pipeline com origem em IBGE.

Especificação exata no código: `data/processed/contas_regionais_RR_serie.csv`.

O que é feito com ela: calcula pesos internos dos subsetores e ancora o bloco de serviços ao desenho setorial das Contas Regionais.

Output gerado: `data/output/indice_servicos.csv`.

## `R/05_agregacao.R`

### 1. Índice trimestral da agropecuária

Fonte: fonte interna do pipeline.

Especificação exata no código: arquivo `data/output/indice_agropecuaria.csv`, coluna `indice_agropecuaria`.

O que é feito com ela: entra como um dos quatro blocos do índice geral.

Output gerado: `data/output/indice_geral_rr.csv`.

### 2. Índice trimestral de AAPP

Fonte: fonte interna do pipeline.

Especificação exata no código: arquivo `data/output/indice_adm_publica.csv`, coluna `indice_adm_publica`.

O que é feito com ela: entra como um dos quatro blocos do índice geral.

Output gerado: `data/output/indice_geral_rr.csv`.

### 3. Índice trimestral da indústria

Fonte: fonte interna do pipeline.

Especificação exata no código: arquivo `data/output/indice_industria.csv`, coluna `indice_industria`.

O que é feito com ela: entra como um dos quatro blocos do índice geral.

Output gerado: `data/output/indice_geral_rr.csv`.

### 4. Índice trimestral dos serviços

Fonte: fonte interna do pipeline.

Especificação exata no código: arquivo `data/output/indice_servicos.csv`, coluna `indice_servicos`.

O que é feito com ela: entra como um dos quatro blocos do índice geral.

Output gerado: `data/output/indice_geral_rr.csv`.

### 5. VAB nominal anual por atividade

Fonte: fonte interna do pipeline com origem em IBGE.

Especificação exata no código: arquivo `data/processed/contas_regionais_RR_serie.csv`, com uso do ano-base `2020` para os pesos Laspeyres dos quatro blocos.

O que é feito com ela: calcula os pesos setoriais do índice geral.

Output gerado: `data/output/indice_geral_rr.csv`.

### 6. Índice de volume anual por atividade

Fonte: fonte interna do pipeline com origem em IBGE.

Especificação exata no código: arquivo `data/processed/contas_regionais_RR_volume.csv`.

O que é feito com ela: funciona como benchmark real anual do Denton do índice geral.

Output gerado: `data/output/indice_geral_rr.csv`.

## `R/05f_vab_nominal.R`

### 1. VAB nominal anual oficial

Fonte: fonte interna do pipeline com origem em IBGE.

Especificação exata no código: arquivo `data/processed/contas_regionais_RR_serie.csv`.

O que é feito com ela: calcula índices nominais e deflatores anuais implícitos do VAB.

Output gerado: `data/processed/contas_regionais_RR_deflator.csv`, `data/output/vab_nominal_rr_reais.csv` e `data/output/indice_nominal_rr.csv`.

### 2. Índice de volume anual oficial

Fonte: fonte interna do pipeline com origem em IBGE.

Especificação exata no código: arquivo `data/processed/contas_regionais_RR_volume.csv`, coluna `vab_volume_rebased`.

O que é feito com ela: é combinado ao nominal para produzir o deflator anual implícito.

Output gerado: `data/processed/contas_regionais_RR_deflator.csv`.

### 3. IPCA mensal

Fonte: fonte interna do pipeline com origem em SIDRA.

Especificação exata no código: arquivo `data/raw/ipca_mensal.csv`.

O que é feito com ela: constrói um deflator trimestral auxiliar para a interpolação temporal do VAB nominal.

Output gerado: `data/output/vab_nominal_rr_reais.csv` e `data/output/indice_nominal_rr.csv`.

### 4. Índice geral trimestral real

Fonte: fonte interna do pipeline.

Especificação exata no código: arquivo `data/output/indice_geral_rr.csv`, coluna `indice_geral`.

O que é feito com ela: serve como indicador trimestral para distribuir o VAB nominal anual em frequência trimestral.

Output gerado: `data/output/vab_nominal_rr_reais.csv` e `data/output/indice_nominal_rr.csv`.

## `R/05g_pib_nominal.R`

### 1. VAB nominal trimestral

Fonte: fonte interna do pipeline.

Especificação exata no código: arquivo `data/output/vab_nominal_rr_reais.csv`.

O que é feito com ela: é a base principal para converter VAB em PIB nominal trimestral.

Output gerado: `data/output/pib_nominal_rr.csv` e `data/output/ilp_rr_trimestral.csv`.

### 2. ICMS total trimestral

Fonte: fonte interna do pipeline com origem em SEFAZ-RR.

Especificação exata no código: arquivo `data/processed/icms_sefaz_rr_trimestral.csv`, com a coluna `icms_total_mi` renomeada para `icms_mi`.

O que é feito com ela: serve como proxy trimestral do ILP e como indicador temporal do bloco de impostos sobre produtos.

Output gerado: `data/output/ilp_rr_trimestral.csv` e `data/output/pib_nominal_rr.csv`.

### 3. VAB nominal anual oficial

Fonte: fonte interna do pipeline com origem em IBGE.

Especificação exata no código: arquivo `data/processed/contas_regionais_RR_serie.csv`.

O que é feito com ela: permite derivar o ILP anual benchmark por diferença entre PIB anual e VAB anual.

Output gerado: `data/output/ilp_rr_trimestral.csv` e `data/output/pib_nominal_rr.csv`.

### 4. PIB anual oficial

Fonte: SIDRA/IBGE.

Especificação exata no código: leitura prioritária do cache `data/raw/sidra/pib_rr_anual_sidra_5938.csv`; quando `atualizar_sidra <- TRUE`, o script reconsulta `get_sidra(x = 5938, variable = 37, period = "2010-2023", geo = "State", geo.filter = list("State" = 14))` e regrava o cache.

O que é feito com ela: obtém o PIB anual oficial de Roraima para benchmark do ILP e fechamento do PIB nominal trimestral, com comportamento offline por padrão para estabilizar o `run_all`.

Output gerado: `data/output/pib_nominal_rr.csv`.

## `R/05h_vab_nominal_setorial.R`

### 1. VAB nominal anual por atividade

Fonte: fonte interna do pipeline com origem em IBGE.

Especificação exata no código: arquivo `data/processed/contas_regionais_RR_serie.csv`.

O que é feito com ela: agrupa as atividades das Contas Regionais em quatro grandes setores do projeto e define benchmarks nominais anuais por setor.

Output gerado: `data/output/vab_nominal_setorial_rr.csv` e `data/output/vab_nominal_setorial_anual_rr.csv`.

### 2. Índice de volume anual por atividade

Fonte: fonte interna do pipeline com origem em IBGE.

Especificação exata no código: arquivo `data/processed/contas_regionais_RR_volume.csv`.

O que é feito com ela: auxilia na coerência entre o lado real e o lado nominal da abertura setorial.

Output gerado: `data/output/vab_nominal_setorial_rr.csv`.

### 3. IPCA mensal

Fonte: fonte interna do pipeline com origem em SIDRA.

Especificação exata no código: arquivo `data/raw/ipca_mensal.csv`.

O que é feito com ela: dá suporte à interpolação nominal trimestral quando necessário.

Output gerado: `data/output/vab_nominal_setorial_rr.csv`.

### 4. Índices setoriais trimestrais reais

Fonte: fonte interna do pipeline.

Especificação exata no código: arquivos `data/output/indice_agropecuaria.csv`, `data/output/indice_adm_publica.csv`, `data/output/indice_industria.csv` e `data/output/indice_servicos.csv`.

O que é feito com ela: distribui os benchmarks nominais anuais por setor em frequência trimestral.

Output gerado: `data/output/vab_nominal_setorial_rr.csv` e `data/output/vab_nominal_setorial_anual_rr.csv`.

## `R/05i_pib_real.R`

### 1. PIB nominal trimestral

Fonte: fonte interna do pipeline.

Especificação exata no código: arquivo `data/output/pib_nominal_rr.csv`, com a coluna `pib_nominal_mi`.

O que é feito com ela: é deflacionado para gerar a série preliminar do PIB real trimestral.

Output gerado: `data/output/pib_real_rr.csv` e `data/output/pib_real_anual_rr.csv`.

### 2. Deflator trimestral / índice nominal

Fonte: fonte interna do pipeline.

Especificação exata no código: arquivo `data/output/indice_nominal_rr.csv`, com as colunas `deflator_trimestral`, `indice_nominal` e `indice_geral`.

O que é feito com ela: serve para transformar o PIB nominal em valores reais e para reportar a série implícita de preços.

Output gerado: `data/output/pib_real_rr.csv` e `data/output/pib_real_anual_rr.csv`.

### 3. Benchmark anual oficial do PIB real

Fonte: valor fixado no script a partir das Contas Regionais.

Especificação exata no código: tabela interna `bench_pib_real_cr`, com `2021 = 8.4`, `2022 = 11.3` e `2023 = 4.2`.

O que é feito com ela: é usada como conferência e fechamento da taxa anual da série real.

Output gerado: `data/output/pib_real_rr.csv` e `data/output/pib_real_anual_rr.csv`.

## Scripts auxiliares e de monitoramento do pipeline

## `R/05b_sensibilidade_calendario.R`

Fonte dos inputs: `data/output/indice_agropecuaria.csv` e reexecução parametrizada de `R/01_agropecuaria.R`.

Especificação exata no código: roda a agropecuária com `versao_calendario = "censo2006_area"` e `versao_calendario = "censo2006_estabelecimentos"`.

O que é feito com ela: compara a série agropecuária sob três calendários de colheita.

Output gerado: `data/output/sensibilidade/agropecuaria_versao_B.csv`, `data/output/sensibilidade/agropecuaria_versao_C.csv` e `data/output/sensibilidade/comparacao_calendarios.csv`.

## `R/05b_sensibilidade_pesos.R`

Fonte dos inputs: `data/output/sensibilidade/proxies_transformacao.csv`, `data/output/sensibilidade/proxies_servicos.csv` e `data/processed/contas_regionais_RR_volume.csv`.

Especificação exata no código: busca em grade com passo de `5%` para combinações de pesos que somem `1`.

O que é feito com ela: identifica pesos ótimos para as proxies compostas minimizando a variância implícita do Denton.

Output gerado: `data/output/sensibilidade/pesos_otimos.csv` e `data/output/sensibilidade/grid_completo.csv`.

## `R/05c_ajuste_sazonal.R`

Fonte dos inputs: `data/output/indice_geral_rr.csv`.

Especificação exata no código: usa as colunas `indice_geral`, `indice_agropecuaria`, `indice_aapp`, `indice_industria` e `indice_servicos`.

O que é feito com ela: aplica `X-13ARIMA-SEATS` ou fallback `STL` ao índice geral e aos quatro componentes.

Output gerado: `data/output/indice_geral_rr_sa.csv` e `data/output/fatores_sazonais.csv`.

## `R/05d_validacao.R`

Fonte dos inputs: `data/output/indice_geral_rr.csv`, `data/processed/contas_regionais_RR_serie.csv` e, quando disponível, IBCR Norte via API SGS do BCB.

Especificação exata no código: compara trajetória trimestral do índice geral com benchmark anual das CR e com série externa de ciclo econômico.

O que é feito com ela: produz checagens quantitativas de benchmark, ciclo, comportamento da COVID e consistência interna.

Output gerado: `data/output/validacao_relatorio.csv`.

## `R/05e_exportacao.R`

Fonte dos inputs: `data/output/indice_geral_rr.csv`, `data/output/indice_geral_rr_sa.csv`, `data/output/fatores_sazonais.csv` e `logs/fontes_utilizadas.csv`.

Especificação exata no código: prepara abas de série geral, componentes, dessazonalizado, fatores sazonais e metadados.

O que é feito com ela: monta a planilha final de publicação e os CSVs resumidos.

Output gerado: `data/output/IAET_RR_series.xlsx`, `data/output/IAET_RR_geral.csv`, `data/output/IAET_RR_componentes.csv` e `data/output/IAET_RR_dessazonalizado.csv`.

## `R/run_all.R`

Fonte dos inputs: não possui input de dados próprio; apenas chama os demais scripts em ordem.

Especificação exata no código: sequência obrigatória de execução das etapas do pipeline.

O que é feito com ela: orquestra a execução completa do projeto. No estado atual do pipeline, a execução completa depende de `pdftools` para a leitura dos PDFs de ICMS por atividade em `R/00b_icms_sefaz_atividade.R`.

Output gerado: não gera output próprio.

## `R/utils.R`

Fonte dos inputs: não possui input de dados próprio.

Especificação exata no código: guarda funções auxiliares compartilhadas, como rotinas de Denton, validação de série e extensão de benchmark.

O que é feito com ela: fornece infraestrutura comum para os demais scripts.

Output gerado: não gera output próprio.

## Observações rápidas

- O monitoramento acima está alinhado ao que o código usa hoje, não ao desenho metodológico futuro.
- Em `AAPP`, a proxy estadual atual vem do FIPLAN mensal (`FIP 855`, soma de `3190.1100`, `3190.1200` e `3190.1300`), enquanto a proxy municipal permanece no SICONFI com `RREO6PessoalEEncargosSociais` e `DESPESAS LIQUIDADAS`.
- Em `Serviços`, o arquivo `icms_sefaz_rr_trimestral.csv` já aparece como input operacional do bloco `Comércio`.
- Alguns scripts usam caches locais para evitar redownload; nesses casos, a fonte original e o arquivo cacheado aparecem juntos.
