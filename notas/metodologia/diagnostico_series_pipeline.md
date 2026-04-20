# Diagnóstico das séries utilizadas no pipeline

Gerado em 2026-04-19 20:55:26 pelo script `R/98_diagnostico_series_pipeline.R`.

## Escopo

Este documento consolida, para as séries atualmente usadas no pipeline do PIB trimestral de Roraima:

- quantidade de NAs literais na variável operacional;
- faltantes de cobertura na grade esperada da janela 2020–2025;
- existência de tratamento preparado para faltantes;
- forma de uso na composição da proxy ou do índice final;
- gráficos comparativos das proxies por atividade.

Foram incluídas também as séries de deflação e o bloco de impostos/ILP.

## Leitura rápida

- A maior parte das séries operacionais do núcleo 2020–2025 já está sem NAs literais, mas ainda existem problemas relevantes de cobertura em alguns insumos manuais e administrativos.
- A folha municipal passou a ter regra explícita de exclusão: municípios com mais de 1 bimestre final ausente são excluídos automaticamente, com base no trimestre publicado em `config/release.R`. Na fase 2025T4, Amajari e Caracaraí foram excluídos; Iracema foi mantida com carry-forward do último bimestre observado (2025B5).
- No SIAPE, o tratamento de faltantes existe e está explícito: o código interpola meses ausentes linearmente.
- No CAGED, o padrão do projeto é completar meses ausentes com `saldo = 0` antes de construir o estoque acumulado.
- Extrativas passou a usar CAGED B (estoque de emprego formal) como indicador trimestral na Denton-Cholette. A CFEM (ANM) foi avaliada e descartada — documentação completa em `notas/metodologia/cfem_extrativas_indice_composto.md`.
- Em serviços, quando uma proxy falta, o código redistribui os pesos apenas entre as proxies disponíveis do mesmo subsetor.
- Em impostos, o ILP trimestral usa Denton-Cholette com ICMS total como indicador temporal.

## Principais problemas por cobertura e NA

| bloco | atividade | serie | na_valor | faltantes_grade | tratamento_na |
| --- | --- | --- | --- | --- | --- |
| AAPP | Folha municipal | SICONFI RREO Anexo 06 | 0 | 32 | Conversão acumulado->incremental; municípios com gap final > 1 bimestre são excluídos automaticamente (regra derivada de config/release.R); único bimestre final faltante é preenchido com carry-forward; Amajari e Caracaraí excluídos na fase 2025T4 |
| AAPP | Folha federal | SIAPE | 0 |  3 | Interpolação linear de meses ausentes no código |
| AAPP | Folha estadual | FIPLAN FIP855 | 0 |  0 | Sem correção específica; ausência entra como 0 na soma final |
| Agropecuária | Lavouras | Índice de lavouras | 0 |  0 | PAM e LSPA são combinadas; sem imputação direta por NA |
| Agropecuária | Pecuária | Abate bovino | 0 |  0 | Sem fallback; completude é exigida na janela operacional |
| Agropecuária | Pecuária | Ovos | 0 |  0 | Sem fallback; completude é exigida na janela operacional |
| Agropecuária | Pecuária | Índice de pecuária | 0 |  0 | Sem fallback; só é gerado com cobertura completa |
| Deflação | Deflator trimestral | Deflator implícito trimestral | 0 |  0 | Denton com fallback para IPCA reescalado se necessário |
| Deflação | IPCA | IPCA mensal | 0 |  0 | Sem imputação; usado como nível de preços |
| Impostos | ILP / impostos | ICMS total trimestral | 0 |  0 | No PIB nominal, faltantes do indicador entram como 0 no Denton do ILP |
| Impostos | ILP / impostos | ILP trimestral | 0 |  0 | Denton-Cholette com benchmark anual e ICMS como indicador |
| Indústria | Construção | CAGED F | 0 |  0 | Meses ausentes são completados com saldo=0 no código |

## Quadro geral das séries

A tabela abaixo resume o diagnóstico das principais séries efetivamente usadas no pipeline.

| bloco | atividade | serie | periodicidade | na_valor | faltantes_grade | primeiro_periodo | ultimo_periodo | tratamento_na | uso_no_indice |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| AAPP | Folha estadual | FIPLAN FIP855 | Mensal | 0 | 0 | 2020M01 | 2025M12 | Sem correção específica; ausência entra como 0 na soma final | Somada à folha federal e municipal; depois deflacionada |
| AAPP | Folha federal | SIAPE | Mensal | 0 | 3 | 2020M01 | 2026M02 | Interpolação linear de meses ausentes no código | Somada à folha estadual e municipal; depois deflacionada |
| AAPP | Folha municipal | SICONFI RREO Anexo 06 | Bimestral acumulada | 0 | 32 | 2020B1 | 2026B1 | Conversão acumulado->incremental; municípios com gap final > 1 bimestre são excluídos automaticamente (regra derivada de config/release.R); único bimestre final faltante é preenchido com carry-forward; Amajari e Caracaraí excluídos na fase 2025T4 | Convertida para trimestral e somada à folha estadual e federal |
| Agropecuária | Lavouras | Índice de lavouras | Trimestral | 0 | 0 | 2020T1 | 2026T4 | PAM e LSPA são combinadas; sem imputação direta por NA | Média ponderada de 10 culturas com pesos de VBP e calendário |
| Agropecuária | Pecuária | Abate bovino | Trimestral | 0 | 0 | 2006T3 | 2025T4 | Sem fallback; completude é exigida na janela operacional | Média ponderada com ovos na proxy de pecuária |
| Agropecuária | Pecuária | Ovos | Trimestral | 0 | 0 | 2006T1 | 2025T4 | Sem fallback; completude é exigida na janela operacional | Média ponderada com abate bovino na proxy de pecuária |
| Agropecuária | Pecuária | Índice de pecuária | Trimestral | 0 | 0 | 2020T1 | 2025T4 | Sem fallback; só é gerado com cobertura completa | Componente da média ponderada do índice agro |
| Deflação | Deflator trimestral | Deflator implícito trimestral | Trimestral | 0 | 0 | 2020T1 | 2025T4 | Denton com fallback para IPCA reescalado se necessário | Deflator do VAB nominal e insumo do PIB real |
| Deflação | IPCA | IPCA mensal | Mensal | 0 | 0 | 1979M12 | 2026M03 | Sem imputação; usado como nível de preços | Deflator da AAPP e proxy temporal dos deflatores trimestrais |
| Impostos | ILP / impostos | ICMS total trimestral | Trimestral | 0 | 0 | 2020T1 | 2026T1 | No PIB nominal, faltantes do indicador entram como 0 no Denton do ILP | Indicador temporal do ILP trimestral |
| Impostos | ILP / impostos | ILP trimestral | Trimestral | 0 | 0 | 2020T1 | 2025T4 | Denton-Cholette com benchmark anual e ICMS como indicador | Somado ao VAB nominal para formar o PIB nominal |
| Indústria | Construção | CAGED F | Mensal | 0 | 0 | 2020M01 | 2025M12 | Meses ausentes são completados com saldo=0 no código | Proxy única da construção na configuração atual |
| Indústria | Extrativas | CAGED B (estoque) | Mensal | 0 | 0 | 2020M01 | 2025M12 | Meses ausentes são completados com saldo=0 no código; estoque = 1000 + cumsum(saldo), rebaseado 2020=100 | Indicador trimestral da Denton-Cholette de extrativas (proxy de emprego formal) |
| Indústria | Extrativas | Índice extrativas | Trimestral | 0 | 0 | 2020T1 | 2025T4 | CAGED B como indicador trimestral; Denton-Cholette ancora ao benchmark anual das Contas Regionais | Componente do índice industrial com peso de VAB 2020 |
| Indústria | Transformação | ANEEL industrial | Mensal | 0 | 0 | 2020M01 | 2026M02 | Sem imputação; se faltar, transformação usa proxy remanescente | Componente da média ponderada da transformação |
| Indústria | Transformação | CAGED C | Mensal | 0 | 0 | 2020M01 | 2025M12 | Meses ausentes são completados com saldo=0 no código | Componente da média ponderada da transformação |
| Serviços | Comércio | ANEEL comercial | Mensal | 0 | 0 | 2020M01 | 2026M02 | Sem imputação; se faltar, peso é redistribuído | Componente da média ponderada do comércio |
| Serviços | Comércio | CAGED G | Mensal | 0 | 0 | 2020M01 | 2025M12 | Meses ausentes são completados com saldo=0 no código | Componente da média ponderada do comércio |
| Serviços | Comércio | ICMS comércio | Trimestral | 0 | 0 | 2020T1 | 2026T1 | Se faltar, peso é redistribuído; no ILP faltantes viram 0 | Componente da média ponderada do comércio; também alimenta o ILP |
| Serviços | Comércio | PMC | Mensal | 0 | 0 | 2020M01 | 2026M02 | Sem imputação; se faltar, peso é redistribuído | Componente da média ponderada do comércio |
| Serviços | Financeiro | BCB Concessões | Mensal | 0 | 0 | 2020M01 | 2026M02 | Deflação pelo IPCA; se faltar, pesos são redistribuídos | Componente da média ponderada do financeiro |
| Serviços | Financeiro | BCB Estban | Mensal | 0 | 0 | 2020M01 | 2025M12 | Deflação pelo IPCA; se faltar, pesos são redistribuídos | Componente da média ponderada do financeiro |
| Serviços | Imobiliário | ANEEL consumidores residenciais | Mensal | 0 | 0 | 2020M01 | 2026M02 | Sem imputação; usado como indicador temporal no Denton do subsetor | Indicador temporal do índice de atividades imobiliárias |
| Serviços | InfoCom | CAGED J | Mensal | 0 | 0 | 2020M01 | 2025M12 | Meses ausentes são completados com saldo=0 no código | Componente da média ponderada de informação e comunicação |
| Serviços | Outros serviços | CAGED I | Mensal | 0 | 0 | 2020M01 | 2025M12 | Meses ausentes são completados com saldo=0 no código | Componente da média ponderada de outros serviços |
| Serviços | Outros serviços | CAGED M+N | Mensal | 0 | 0 | 2020M01 | 2025M12 | Meses ausentes são completados com saldo=0 no código | Componente da média ponderada de outros serviços |
| Serviços | Outros serviços | CAGED P+Q | Mensal | 0 | 0 | 2020M01 | 2025M12 | Meses ausentes são completados com saldo=0 no código | Componente da média ponderada de outros serviços |
| Serviços | Outros serviços / InfoCom | PMS | Mensal | 0 | 0 | 2020M01 | 2026M02 | Sem imputação; se faltar, pesos são redistribuídos | Componente da média ponderada de outros serviços e infocom |
| Serviços | Transportes | ANAC passageiros | Mensal | 0 | 0 | 2020M01 | 2026M02 | Sem imputação; se faltar, pesos são redistribuídos | Componente da média ponderada dos transportes |
| Serviços | Transportes | ANP diesel | Mensal | 0 | 0 | 2020M01 | 2026M02 | Sem imputação; se faltar, pesos são redistribuídos | Componente da média ponderada dos transportes |

## Como as proxies entram nos índices

A tabela abaixo resume a regra de combinação usada hoje no código.

| bloco | atividade | combinacao |
| --- | --- | --- |
| Agropecuária | Lavouras | Média ponderada das 10 culturas com pesos de VBP da PAM; distribuição trimestral via calendário de colheita e LSPA/PAM |
| Agropecuária | Pecuária | Média ponderada entre abate bovino e ovos |
| Agropecuária | Índice agropecuário | Média ponderada entre lavouras e pecuária; depois Denton-Cholette contra benchmark anual de volume |
| AAPP | Índice de administração pública | Soma nominal de folha estadual + municipal + federal; deflação pelo IPCA; depois Denton-Cholette contra benchmark anual |
| Indústria | SIUP | Proxy única baseada na energia elétrica total distribuída pela ANEEL; depois Denton-Cholette contra benchmark anual |
| Indústria | Transformação | Média ponderada entre energia industrial ANEEL e CAGED C |
| Indústria | Construção | Proxy única baseada em CAGED F na configuração atual |
| Indústria | Extrativas | CAGED B (estoque de emprego formal) como indicador trimestral; Denton-Cholette ancora ao benchmark anual das Contas Regionais; CFEM (ANM) avaliada e descartada — ver notas/metodologia/cfem_extrativas_indice_composto.md |
| Indústria | Índice industrial | Média ponderada entre SIUP, Construção, Transformação e Extrativas com pesos de VAB 2020 |
| Serviços | Comércio | Média ponderada entre energia comercial, PMC, ICMS comércio e CAGED G |
| Serviços | Transportes | Média ponderada entre passageiros ANAC e diesel ANP; carga ANAC permanece só no diagnóstico |
| Serviços | Financeiro | Média ponderada entre concessões BCB e depósitos Estban, ambos deflacionados |
| Serviços | Imobiliário | Denton-Cholette entre benchmarks anuais das Contas Regionais, usando consumidores residenciais da ANEEL como indicador temporal |
| Serviços | Outros serviços | Média ponderada entre CAGED I, CAGED M+N, CAGED P+Q e PMS |
| Serviços | Informação e comunicação | Média ponderada entre CAGED J e PMS |
| Serviços | Índice de serviços | Média ponderada entre 6 subsetores com pesos de VAB 2020; ancoragem anual por Denton |
| Deflação | Deflator trimestral do VAB | Denton-Cholette do deflator anual implícito, usando IPCA trimestral como indicador temporal |
| Impostos | ILP trimestral | Denton-Cholette do ILP anual, usando ICMS total trimestral como indicador; PIB nominal = VAB nominal + ILP |

## Gráficos comparativos das proxies por atividade

### Agropecuária

![Agropecuária - subsetores e índice final](../../data/output/diagnostico_series_pipeline/agro_componentes.png)

![Agropecuária - lavouras: culturas individuais e índice](../../data/output/diagnostico_series_pipeline/agro_lavouras_proxies.png)

![Agropecuária - pecuária: proxies e índice](../../data/output/diagnostico_series_pipeline/agro_pecuaria_proxies.png)

### Administração pública

![AAPP - componentes da folha e índice final](../../data/output/diagnostico_series_pipeline/aapp_componentes.png)

### Indústria

![Indústria - subsetores e índice final](../../data/output/diagnostico_series_pipeline/industria_subsetores.png)

![Indústria - SIUP: proxy e índice](../../data/output/diagnostico_series_pipeline/industria_siup_proxy.png)

![Indústria - construção: proxy e índice](../../data/output/diagnostico_series_pipeline/industria_construcao_proxy.png)

![Indústria - transformação: proxies e índice](../../data/output/diagnostico_series_pipeline/industria_transformacao_proxies.png)

![Indústria - extrativas: índice final](../../data/output/diagnostico_series_pipeline/industria_extrativas.png)

### Serviços

![Serviços - subsetores e índice final](../../data/output/diagnostico_series_pipeline/servicos_subsetores.png)

![Serviços - comércio: proxies e índice](../../data/output/diagnostico_series_pipeline/servicos_comercio.png)

![Serviços - transportes: proxies e índice](../../data/output/diagnostico_series_pipeline/servicos_transportes.png)

![Serviços - financeiro: proxies e índice](../../data/output/diagnostico_series_pipeline/servicos_financeiro.png)

![Serviços - atividades imobiliárias: proxy e índice](../../data/output/diagnostico_series_pipeline/servicos_imobiliario.png)

![Serviços - outros serviços: proxies e índice](../../data/output/diagnostico_series_pipeline/servicos_outros.png)

![Serviços - informação e comunicação: proxies e índice](../../data/output/diagnostico_series_pipeline/servicos_infocom.png)

### Deflação e impostos

![Deflação](../../data/output/diagnostico_series_pipeline/deflacao_ipca_deflator.png)

![Impostos e ILP](../../data/output/diagnostico_series_pipeline/impostos_ilp_icms.png)

## Arquivos auxiliares gerados

- `data/output/diagnostico_series_pipeline/resumo_series.csv`
- `data/output/diagnostico_series_pipeline/combinacao_series.csv`
- PNGs comparativos na mesma pasta.

## Observações metodológicas finais

- Este diagnóstico separa `NA literal` de `faltante de cobertura`. Em várias séries administrativas o problema real não é `NA` em célula, mas período ausente na grade esperada.
- O diagnóstico foi montado sobre a configuração vigente do projeto em 2026-04-19. Se os pesos operacionais ou as fontes mudarem, este relatório deve ser regenerado.
- O relatório não substitui a leitura dos scripts, mas ajuda a localizar rapidamente onde há risco de cobertura, redistribuição de pesos ou interpolação.
