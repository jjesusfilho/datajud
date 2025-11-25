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

## Exemplos de Uso

### Buscar por número CNJ

```r
# Número CNJ único
results <- search_cnj(
  cnj_number = "00001234520204036100",
  tribunal = "api_publica_trf1",
  size = 10
)

# Múltiplos números CNJ
cnj_numbers <- c("00001234520204036100", "00005678920204036100")
results <- search_cnj(cnj_numbers, tribunal = "api_publica_trf1")
```

### Buscar por classe e órgão julgador

```r
results <- search_by_class(
  tribunal = "api_publica_trf1",
  classe_codigo = 1199,
  orgao_julgador = "1ª Turma",
  size = 20
)
```

### Buscar por intervalo de datas

```r
# Buscar por data de ajuizamento
results <- search_by_date(
  tribunal = "api_publica_tjsp",
  date_field = "dataAjuizamento",
  start_date = "2020-01-01",
  end_date = "2020-12-31",
  size = 50
)
```

### Busca avançada com strings de consulta

```r
results <- search_advanced(
  tribunal = "api_publica_trf1",
  query_string = "ação civil pública",
  fields = c("classe.nome", "assuntos.nome"),
  size = 100
)
```

### Busca com todos os parâmetros disponíveis

```r
# Busca completa usando a nova função search_processes
results <- search_processes(
  tribunal = "api_publica_trf1",
  grau = "2",
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
  tribunal = "api_publica_trf1",
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
  tribunal = "api_publica_trf1",
  parse = FALSE
)
```

### Paginação para grandes conjuntos de resultados

```r
# Recuperar até 5000 resultados com paginação automática
query <- list(
  range = list(
    dataAjuizamento = list(
      gte = "2020-01-01",
      lte = "2020-01-31"
    )
  )
)

results <- search_with_pagination(
  tribunal = "api_publica_trf1",
  query = query,
  max_results = 5000,
  size_per_request = 1000
)
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
- **grau**: Grau/instância do processo
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
