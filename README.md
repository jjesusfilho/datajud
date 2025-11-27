# datajud

Um pacote R para acessar e baixar metadados de processos judiciais da [API Pública do DataJud](https://datajud-wiki.cnj.jus.br/api-publica/), mantida pelo Conselho Nacional de Justiça (CNJ).

## Instalação

Você pode instalar a versão de desenvolvimento pelo GitHub:

```r
# install.packages("remotes")
remotes::install_github("jjesusfilho/datajud")
```

Ou instalar localmente:

```r
remotes::install_local(".")
```

## Primeiros Passos

### 1. Configurar autenticação

A API do DataJud requer uma chave de API para autenticação. Você pode usar a chave pública padrão:

```r
library(datajud)

# Definir a chave de API pública padrão
set_api_key(get_default_api_key())

# Ou definir sua própria chave
set_api_key("sua_chave_api_aqui")

# Alternativamente, definir como variável de ambiente
Sys.setenv(DATAJUD_API_KEY = "sua_chave_api_aqui")
```

### 2. Explorar tribunais disponíveis

```r
# Listar todos os tribunais disponíveis
tribunals <- list_tribunals()
head(tribunals)

# Filtrar por tipo
tribunals[tribunals$type == "TRF", ]  # Tribunais Regionais Federais
tribunals[tribunals$type == "TJ", ]   # Tribunais de Justiça Estaduais
tribunals[tribunals$type == "TRT", ]  # Tribunais Regionais do Trabalho
```

### 3. Nomes de tribunais simplificados

O pacote aceita tanto nomes curtos quanto nomes completos de tribunais:

```r
# Formas equivalentes - use a forma curta para maior conveniência
search_processes(tribunal = "trf1", ...)      # ✅ Recomendado
search_processes(tribunal = "api_publica_trf1", ...)  # Também funciona

# Exemplos de nomes curtos
# TRF: trf1, trf2, trf3, trf4, trf5, trf6
# TJ: tjsp, tjrj, tjmg, tjrs, tjba, tjpr, etc.
# TRT: trt1, trt2, trt3, ..., trt24
# Superiores: stj, tst, tse, stm
```

## Exemplos de Uso

### Buscar por número CNJ

```r
# Número CNJ único
results <- search_cnj(
  cnj_number = "00001234520204036100",
  tribunal = "trf1",
  size = 10
)

# Múltiplos números CNJ
cnj_numbers <- c("00001234520204036100", "00005678920204036100")
results <- search_cnj(cnj_numbers, tribunal = "trf1")
```

### Buscar por intervalo de datas

```r
# Buscar por data de ajuizamento
results <- search_by_date(
  tribunal = "tjsp",
  date_field = "dataAjuizamento",
  start_date = "2020-01-01",
  end_date = "2020-12-31",
  size = 50
)
```

### Busca avançada com strings de consulta

```r
results <- search_advanced(
  tribunal = "trf1",
  query_string = "ação civil pública",
  fields = c("classe.nome", "assuntos.nome"),
  size = 100
)
```

### Busca com todos os parâmetros disponíveis

A função `search_processes()` permite buscar usando qualquer combinação de parâmetros:

```r
# Busca por classe e órgão julgador
results <- search_processes(
  tribunal = "trf1",
  classe_codigo = "1199",
  orgaoJulgador_nome = "1ª Turma",
  size = 20
)

# Busca completa com múltiplos critérios
results <- search_processes(
  tribunal = "trf1",
  grau = "G2",
  classe_codigo = "1199",
  sistema_nome = "PJe",
  nivelSigilo = 0,
  dataAjuizamento_start = "2020-01-01",
  dataAjuizamento_end = "2020-12-31",
  orgaoJulgador_nome = "1ª Turma",
  size = 50
)
```

### Consultas Elasticsearch personalizadas

Para controle total, você pode construir consultas Elasticsearch personalizadas:

```r
# Consulta booleana complexa
query <- list(
  bool = list(
    must = list(
      list(match = list(classe.codigo = 1199)),
      list(range = list(
        dataAjuizamento = list(
          gte = "2020-01-01",
          lte = "2020-12-31"
        )
      ))
    )
  )
)

results <- search_datajud(
  tribunal = "trf1",
  query = query,
  size = 100
)
```

### Trabalhando com resultados

```r
# Extrair movimentações dos resultados
movements <- extract_movements(results)
head(movements)

# Extrair assuntos
subjects <- extract_subjects(results)
head(subjects)

# Acessar resposta bruta da API
raw_results <- search_cnj(
  "00001234520204036100",
  tribunal = "trf1",
  parse = FALSE
)
```

### Busca com paginação automática

A função `search_processes_paginated()` permite buscar grandes volumes de dados com paginação automática e opção de salvar cada página:

```r
# Busca simples com paginação
results <- search_processes_paginated(
  tribunal = "trf1",
  grau = "G2",
  dataAjuizamento_start = "2020-01-01",
  dataAjuizamento_end = "2020-01-31",
  page_size = 100,    # Resultados por página
  max_pages = 10      # Máximo de páginas a buscar
)

# Acessar resultados
head(results$data)              # Todos os resultados combinados
results$total_hits              # Total de resultados disponíveis
results$pages_fetched           # Número de páginas buscadas
results$pages[[1]]              # Primeira página separadamente
```

#### Salvando páginas automaticamente

Salve cada página em disco conforme são recuperadas:

```r
# Salvar páginas em formato RDS (padrão)
results <- search_processes_paginated(
  tribunal = "tjsp",
  classe_codigo = "1199",
  grau = "G2",
  page_size = 100,
  max_pages = 20,
  save_pages = TRUE,
  output_dir = "dados_tjsp",
  output_format = "rds"
)

# Salvar páginas em formato CSV
results <- search_processes_paginated(
  tribunal = "trf1",
  sistema_nome = "PJe",
  dataAjuizamento_start = "2023-01-01",
  dataAjuizamento_end = "2023-12-31",
  page_size = 100,
  max_pages = 50,
  save_pages = TRUE,
  output_dir = "processos_pje_2023",
  output_format = "csv"
)

# Salvar páginas em formato JSON
results <- search_processes_paginated(
  tribunal = "trt2",
  assuntos_codigo = "7678",
  page_size = 100,
  save_pages = TRUE,
  output_dir = "dados_trt",
  output_format = "json"
)

# Verificar arquivos salvos
results$files_saved
# [1] "dados_trt/page_001_20250125_143022.json"
# [2] "dados_trt/page_002_20250125_143023.json"
# ...
```

#### Exemplo completo: Coleta em lote

```r
# Coletar dados por classe judicial com salvamento automático
library(datajud)

# Configurar API
set_api_key(get_default_api_key())

# Buscar e salvar processualmente
results <- search_processes_paginated(
  tribunal = "trf1",
  classe_codigo = "1199",           # Ação Civil Pública
  grau = "G2",                      # Segunda instância
  sistema_nome = "PJe",
  dataAjuizamento_start = "2022-01-01",
  dataAjuizamento_end = "2022-12-31",
  page_size = 100,                  # 100 processos por página
  max_pages = NULL,                 # Buscar todas as páginas disponíveis
  save_pages = TRUE,                # Salvar cada página
  output_dir = "coleta_acp_2022",
  output_format = "csv"
)

# Resumo da coleta
cat("Total de processos encontrados:", results$total_hits, "\n")
cat("Páginas coletadas:", results$pages_fetched, "\n")
cat("Processos baixados:", nrow(results$data), "\n")
cat("Arquivos salvos:", length(results$files_saved), "\n")
```

**Formatos de saída disponíveis:**
- `"rds"` - Formato nativo do R (preserva tipos de dados)
- `"csv"` - Formato tabular compatível com Excel
- `"json"` - Formato JSON (útil para outras linguagens)

**Notas sobre paginação:**
- A API do DataJud limita cada requisição a 10.000 resultados
- Use `page_size` entre 100-1000 para melhor performance
- `max_pages = NULL` buscará todas as páginas disponíveis
- Um atraso de 0.5 segundos é aplicado entre requisições
- Arquivos salvos incluem timestamp para evitar sobrescrita

### Baixando múltiplas classes ou assuntos

Quando você precisa baixar dados para múltiplas classes processuais ou assuntos, use `purrr::walk()` para iterar sobre os códigos de interesse:

#### Exemplo: Múltiplas classes sem paginação

```r
library(datajud)
library(purrr)

# Configurar API
set_api_key(get_default_api_key())

# Definir códigos de classes processuais
classes <- c("1199", "1200", "1181", "7")  # Exemplo: ACP, ADPF, ADI, etc.

# Baixar dados para cada classe
walk(classes, ~{
  cat("Baixando classe:", .x, "\n")

  results <- search_processes(
    tribunal = "trf1",
    classe_codigo = .x,
    grau = "G2",
    dataAjuizamento_start = "2023-01-01",
    dataAjuizamento_end = "2023-12-31",
    size = 100
  )

  # Salvar cada classe em arquivo separado
  if (!is.null(results) && nrow(results) > 0) {
    saveRDS(results, file = paste0("classe_", .x, ".rds"))
    cat("  -> Salvos", nrow(results), "processos\n")
  } else {
    cat("  -> Nenhum resultado encontrado\n")
  }

  Sys.sleep(1)  # Respeitar limites da API
})
```

#### Exemplo: Múltiplas classes com paginação

```r
library(datajud)
library(purrr)

# Configurar API
set_api_key(get_default_api_key())

# Definir códigos de classes processuais
classes <- c("1199", "1200", "1181", "7")

# Baixar dados paginados para cada classe
walk(classes, ~{
  cat("Iniciando download da classe:", .x, "\n")

  results <- search_processes_paginated(
    tribunal = "trf1",
    classe_codigo = .x,
    grau = "G2",
    dataAjuizamento_start = "2023-01-01",
    dataAjuizamento_end = "2023-12-31",
    page_size = 100,
    max_pages = NULL,              # Buscar todas as páginas
    save_pages = TRUE,
    output_dir = paste0("classe_", .x),
    output_format = "csv"
  )

  # Resumo
  cat("Classe", .x, "concluída:\n")
  cat("  - Total de processos:", results$total_hits, "\n")
  cat("  - Páginas baixadas:", results$pages_fetched, "\n")
  cat("  - Arquivos salvos:", length(results$files_saved), "\n\n")

  Sys.sleep(2)  # Pausa entre classes para respeitar limites da API
})
```

#### Exemplo: Múltiplos assuntos com paginação

```r
library(datajud)
library(purrr)

# Configurar API
set_api_key(get_default_api_key())

# Definir códigos de assuntos
assuntos <- c("7678", "6326", "11253")  # Exemplo de códigos de assuntos

# Baixar dados para cada assunto
walk(assuntos, ~{
  cat("========================================\n")
  cat("Baixando assunto:", .x, "\n")
  cat("========================================\n")

  results <- search_processes_paginated(
    tribunal = "tjsp",
    assuntos_codigo = .x,
    grau = "G2",
    dataAjuizamento_start = "2022-01-01",
    dataAjuizamento_end = "2023-12-31",
    page_size = 100,
    max_pages = 50,                # Limitar a 50 páginas por assunto
    save_pages = TRUE,
    output_dir = paste0("assunto_", .x),
    output_format = "rds"
  )

  # Log detalhado
  cat("\nResumo do assunto", .x, ":\n")
  cat("  - Total disponível:", results$total_hits, "\n")
  cat("  - Páginas baixadas:", results$pages_fetched, "\n")
  cat("  - Processos no data frame:", nrow(results$data), "\n")
  cat("  - Diretório:", paste0("assunto_", .x), "\n\n")

  Sys.sleep(2)
})

cat("Download concluído para todos os assuntos!\n")
```

#### Exemplo: Combinação de classes e tribunais

```r
library(datajud)
library(purrr)
library(dplyr)

# Configurar API
set_api_key(get_default_api_key())

# Criar grid de combinações
params <- expand.grid(
  tribunal = c("trf1", "trf2", "trf3"),
  classe = c("1199", "1200"),
  stringsAsFactors = FALSE
)

# Baixar para cada combinação
pwalk(params, ~{
  cat("Baixando:", ..1, "- Classe:", ..2, "\n")

  results <- search_processes_paginated(
    tribunal = ..1,
    classe_codigo = ..2,
    grau = "G2",
    dataAjuizamento_start = "2023-01-01",
    dataAjuizamento_end = "2023-12-31",
    page_size = 100,
    max_pages = 20,
    save_pages = TRUE,
    output_dir = paste0(..1, "_classe_", ..2),
    output_format = "csv"
  )

  cat("  -> Baixados", results$pages_fetched, "páginas\n\n")

  Sys.sleep(2)
})
```

#### Dicas para downloads em lote

1. **Gerenciamento de erros**: Envolva as chamadas em `tryCatch()` para continuar mesmo se uma classe falhar:

```r
walk(classes, ~{
  tryCatch({
    results <- search_processes_paginated(
      tribunal = "trf1",
      classe_codigo = .x,
      # ... outros parâmetros ...
    )
  }, error = function(e) {
    cat("ERRO na classe", .x, ":", e$message, "\n")
  })
})
```

2. **Salvamento progressivo**: Use `save_pages = TRUE` para não perder dados se o processo for interrompido.

3. **Controle de taxa**: Ajuste `Sys.sleep()` entre iterações conforme necessário para respeitar limites da API.

4. **Logging**: Mantenha um registro das classes baixadas com sucesso:

```r
log_file <- "download_log.txt"
walk(classes, ~{
  # ... código de download ...
  cat(paste(Sys.time(), "- Classe", .x, "OK\n"),
      file = log_file, append = TRUE)
})
```

## Tribunais Disponíveis

O pacote suporta todos os sistemas judiciários brasileiros:

- **Tribunais Superiores**: TST, TSE, STJ, STM
- **Tribunais Regionais Federais**: TRF1 a TRF6
- **Tribunais de Justiça**: Todos os 27 tribunais estaduais (TJSP, TJRJ, etc.)
- **Tribunais Regionais do Trabalho**: TRT1 a TRT24
- **Tribunais Regionais Eleitorais**: Todos os 27 tribunais regionais
- **Tribunais de Justiça Militar**: Todos os 3 tribunais militares

Use `list_tribunals()` para ver a lista completa com aliases e nomes.

## Parâmetros de Busca Disponíveis

A função `search_processes()` suporta todos os parâmetros documentados na API:

### Parâmetros Principais
- **id**: Identificador do processo
- **numeroProcesso**: Número CNJ do processo
- **grau**: Grau/instância do processo (valores: "G1" para primeira instância, "G2" para segunda instância, etc.)
- **nivelSigilo**: Nível de sigilo

### Parâmetros de Objetos Aninhados

**formato** (tipo de processo):
- formato_codigo, formato_nome

**sistema** (sistema judicial):
- sistema_codigo, sistema_nome

**classe** (classificação do caso):
- classe_codigo, classe_nome

**assuntos** (assuntos do processo):
- assuntos_codigo, assuntos_nome

**orgaoJulgador** (órgão julgador):
- orgaoJulgador_codigo, orgaoJulgador_nome, orgaoJulgador_codigoMunicipioIBGE

**movimentos** (movimentações do processo):
- movimentos_codigo, movimentos_nome
- movimentos_dataHora_start, movimentos_dataHora_end

### Parâmetros de Intervalo de Data
- **dataAjuizamento_start / _end**: Intervalo de data de ajuizamento
- **dataHoraUltimaAtualizacao_start / _end**: Intervalo de última atualização

## Documentação da API

A API do DataJud usa Elasticsearch Query DSL para buscas. Tipos comuns de consulta incluem:

- **match**: Correspondência de texto simples
- **range**: Intervalos de data ou numéricos
- **bool**: Combinações booleanas (must, should, must_not)
- **query_string**: Busca de texto completo com sintaxe avançada

Para mais informações:

- [Wiki da API DataJud](https://datajud-wiki.cnj.jus.br/api-publica/)
- [Endpoints do DataJud](https://datajud-wiki.cnj.jus.br/api-publica/endpoints/)
- [Informações de Acesso DataJud](https://datajud-wiki.cnj.jus.br/api-publica/acesso/)
- [Glossário de Dados](https://datajud-wiki.cnj.jus.br/api-publica/glossario/)
- [Tutorial Oficial (PDF)](https://www.cnj.jus.br/wp-content/uploads/2023/05/tutorial-api-publica-datajud-beta.pdf)

## Estrutura de Dados

Os resultados tipicamente incluem:

- `numeroProcesso`: Número CNJ do processo
- `classe`: Informação de classe do processo
- `tribunal`: Identificador do tribunal
- `dataAjuizamento`: Data de ajuizamento
- `dataHoraUltimaAtualizacao`: Timestamp da última atualização
- `grau`: Instância/grau
- `nivelSigilo`: Nível de sigilo
- `movimentos`: Movimentações do processo (coluna lista)
- `assuntos`: Assuntos do processo (coluna lista)
- `orgaoJulgador`: Informação do órgão julgador

## Observações

- A chave de API padrão é pública e pode ser alterada pelo CNJ a qualquer momento
- A API possui limites de taxa (consulte a documentação oficial)
- Máximo de 10.000 resultados por requisição (use paginação para mais)
- Alguns processos podem ter informações restritas devido à confidencialidade
- A API opera sob a Portaria Nº 160 (09/09/2020)

## Contribuindo

Contribuições são bem-vindas! Sinta-se à vontade para enviar um Pull Request.

## Licença

Licença MIT - consulte o arquivo LICENSE para detalhes

## Citação

Se você usar este pacote em sua pesquisa, por favor cite:

```
Pacote DataJud (2025). Acesso e Download de Dados da API DataJud.
Pacote R versão 0.1.0.
```

## Aviso Legal

Este pacote não é oficialmente afiliado ou endossado pelo CNJ (Conselho Nacional de Justiça). É uma ferramenta independente criada para facilitar o acesso à API pública do DataJud.

## Fontes

- [Wiki da API DataJud](https://datajud-wiki.cnj.jus.br/api-publica/)
- [Documentação dos Endpoints do DataJud](https://datajud-wiki.cnj.jus.br/api-publica/endpoints/)
- [Documentação de Acesso do DataJud](https://datajud-wiki.cnj.jus.br/api-publica/acesso/)
- [Glossário de Dados](https://datajud-wiki.cnj.jus.br/api-publica/glossario/)
- [Tutorial Oficial PDF](https://www.cnj.jus.br/wp-content/uploads/2023/05/tutorial-api-publica-datajud-beta.pdf)
- [DataJud API Caller (Implementação em Go)](https://github.com/DanielFillol/DataJUD_API_CALLER)
