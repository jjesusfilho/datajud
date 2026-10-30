# datajud (Python)

Versão em Python do pacote R `datajud`, para acessar a [API Pública do DataJud](https://datajud-wiki.cnj.jus.br/api-publica/), mantida pelo Conselho Nacional de Justiça (CNJ).

## Instalação

```bash
uv add "datajud @ git+https://github.com/jjesusfilho/datajud#subdirectory=python"
```

## Primeiros passos

```python
import datajud as dj

dj.set_api_key(dj.get_default_api_key())  # ou defina DATAJUD_API_KEY

dj.list_tribunals()                      # DataFrame com alias, nome e tipo
dj.search_cnj("0000123-45.2020.4.03.6100", tribunal="trf3")
dj.search_processes("tjsp", classe_codigo="1199", grau="G2", size=100)
dj.search_by_date("trf1", start_date="2020-01-01", end_date="2020-01-31")
```

Os nomes curtos (`"tjsp"`, `"trf1"`) e completos (`"api_publica_tjsp"`) são equivalentes.

## Coleta robusta em fatias

A API é lenta e instável em horário comercial (429 e 504 frequentes), pode devolver resultados parciais com status 200, e paginar com `from`/`size` sem ordenação repete e pula documentos. Para baixar muitos processos, divida a consulta em fatias pequenas e baixe cada uma numa requisição só:

```python
import datetime as dt

MAX_SIZE = 1000

def baixar(filtros, inicio, fim):
    consulta = {"bool": {"filter": [
        *filtros, dj.date_range_query("dataAjuizamento", inicio, fim),
    ]}}
    try:
        return [dj.search_slice("tjsp", consulta, max_size=MAX_SIZE,
                                source={"excludes": ["movimentos"]})]
    except dj.SliceTooLargeError as erro:
        partes = dj.split_date_range(inicio, fim, parts=erro.total // MAX_SIZE + 1)
        return [df for a, b in partes for df in baixar(filtros, a, b)]

fatias = baixar([{"term": {"classe.codigo": 49}}], dt.date(2024, 1, 1), dt.date(2024, 12, 31))
```

`search_slice` conta os documentos antes de baixar, levanta `SliceTooLargeError` (com o atributo `total`) se a fatia passar de `max_size` e só aceita respostas completas (sem `timed_out`, sem shards com falha e com todos os documentos), repetindo com espera crescente.

As datas vêm em dois formatos (ISO e compacto), e o índice lê as compactas como milissegundos desde 1970: um filtro `range` escrito num formato só encontra os documentos gravados naquele formato. Filtre sempre com `dj.date_range_query()`, que cobre os dois, e leia as datas com `dj.parse_datajud_date()`, que devolve uma série em UTC.

Prefixos curtos do número CNJ (`add_cnj_prefix`, `split_by_cnj_prefix`) costumam estourar o tempo do gateway; divida primeiro por datas.

O [tutorial](docs/tutorial.md) mostra uma coleta completa e retomável.

Mensagens de novas tentativas e progresso usam o `logging` (logger `"datajud"`); para vê-las:

```python
import logging
logging.basicConfig(level=logging.INFO)
```

## Diferenças em relação ao pacote R

- Resultados são `pandas.DataFrame`; colunas aninhadas guardam dicionários e listas.
- Erros são exceções: `DataJudError`, `IncompleteResponseError` e `SliceTooLargeError`.
- O argumento `from` chama-se `from_`.
- Em `search_slice(parse=True)`, o total fica em `df.attrs["total"]`.
- `search_processes_paginated` salva em `pickle`, `csv` ou `json` (em vez de `rds`).
- `search_with_pagination` não foi portada: no R ela só devolve a primeira página.
- `build_query()` expõe a consulta montada por `search_processes`.
- Os filtros de data (`search_processes`, `search_by_date`) cobrem os dois formatos de data do índice; no R, só o compacto.
- `date_range_query()` e `split_date_range()` não existem no R.

## Testes

```bash
uv run pytest --doctest-modules src tests
```
