# Tutorial: coletando processos do DataJud com Python

Este tutorial mostra uma coleta completa com o pacote `datajud`: da configuração da chave até uma tabela de processos e outra de movimentos, prontas para análise. O exemplo usa as ações de procedimento comum cível (classe 7) ajuizadas no Tribunal de Justiça do Acre no primeiro trimestre de 2024, mas o roteiro vale para qualquer tribunal, classe ou período.

## 1. Instalação e chave de acesso

Crie um projeto e instale o pacote:

```bash
uv init coleta_datajud
cd coleta_datajud
uv add "datajud @ git+https://github.com/jjesusfilho/datajud#subdirectory=python"
```

A API exige uma chave. O CNJ divulga uma chave pública, que o pacote traz pronta:

```python
import datajud as dj

dj.set_api_key(dj.get_default_api_key())
```

A chave pública pode mudar. Se isso acontecer, consulte a [documentação da API](https://datajud-wiki.cnj.jus.br/api-publica/acesso) e passe a nova chave para `set_api_key()`, ou defina a variável de ambiente `DATAJUD_API_KEY`.

Para acompanhar as requisições e as novas tentativas, ative as mensagens do pacote:

```python
import logging

logging.basicConfig(level=logging.INFO)
```

## 2. Primeiro contato: buscas simples

Cada tribunal tem um índice próprio. A lista completa está em `list_tribunals()`:

```python
tribunais = dj.list_tribunals()
tribunais[tribunais["type"] == "TJ"].head()
```

Os nomes curtos (`"tjac"`) e completos (`"api_publica_tjac"`) são equivalentes.

Para um processo específico, use o número CNJ, com ou sem pontuação:

```python
processo = dj.search_cnj("0700016-66.2024.8.01.0001", tribunal="tjac")
processo[["numeroProcesso", "dataAjuizamento", "grau"]]
```

Para combinar critérios, use `search_processes()`:

```python
amostra = dj.search_processes(
    "tjac",
    classe_codigo=7,
    dataAjuizamento_start="2024-01-01",
    dataAjuizamento_end="2024-01-31",
    size=20,
)
```

Essas funções servem para explorar: devolvem no máximo `size` documentos e não conferem se a resposta veio completa. Para coletar um universo inteiro de processos, siga as próximas seções.

## 3. Por que coletar em fatias

A API pública tem três comportamentos que tornam ingênua a paginação comum:

1. **É lenta e instável.** Em horário comercial, uma consulta pode levar de 20 a 60 segundos, e as respostas 429 (excesso de requisições) e 504 (tempo esgotado no gateway) são frequentes.
2. **Devolve resultados parciais sem erro.** Quando parte dos shards do Elasticsearch estoura o tempo, a resposta chega com status 200, informa um total e traz menos documentos.
3. **Paginar não é confiável.** Com `from`/`size` sem ordenação, documentos se repetem e somem entre páginas; com ordenação, a consulta tende a estourar o tempo do gateway.

A estratégia que funciona é dividir a consulta em **fatias pequenas** (até cerca de 2.000 documentos) e baixar cada uma numa requisição só. É isso que `search_slice()` faz:

- conta os documentos da fatia;
- se houver mais que `max_size`, levanta `SliceTooLargeError`, com a contagem no atributo `total`;
- senão, baixa a fatia e só aceita a resposta se ela estiver completa (sem `timed_out`, sem shards com falha e com todos os documentos), tentando de novo com espera crescente.

## 4. Montando a consulta

Separe os filtros que definem o universo da pesquisa do intervalo de datas, porque é pelas datas que a coleta vai ser dividida:

```python
import datetime as dt

filtros = [{"term": {"classe.codigo": 7}}]
inicio, fim = dt.date(2024, 1, 1), dt.date(2024, 3, 31)


def montar(filtros: list[dict], inicio: dt.date, fim: dt.date) -> dict:
    return {"bool": {"filter": [
        *filtros,
        dj.date_range_query("dataAjuizamento", inicio, fim),
    ]}}
```

**Use sempre `date_range_query()` para filtrar datas.** O DataJud grava as datas em dois formatos, ISO (`2024-01-16T12:41:15.000Z`) e compacto (`20240311124906`), e o índice lê as compactas como milissegundos desde 1970. Na prática, um `range` escrito em ISO só encontra os documentos gravados em ISO, e um `range` compacto só os compactos. No exemplo deste tutorial, o filtro em ISO acha 761 processos, o compacto acha 843, nenhum deles é comum aos dois e o trimestre tem 1.604. `date_range_query()` combina os dois filtros. Se escrever o filtro à mão, nunca use a forma compacta de 8 dígitos (`"20240101"`): ela é lida como um instante de 1970 e o filtro deixa de filtrar.

Antes de coletar, conte quantos processos há:

```python
try:
    fatia = dj.search_slice("tjac", montar(filtros, inicio, fim), max_size=1000)
except dj.SliceTooLargeError as erro:
    print(f"{erro.total} processos: é preciso dividir")
```

## 5. Dividindo por datas

Quando a fatia é grande demais, divida o intervalo de datas. `split_date_range()` corta o intervalo em partes contíguas, sem buracos nem sobreposição; a contagem que vem no erro diz em quantas partes cortar:

```python
dj.split_date_range(inicio, fim, parts=3)
# [(2024-01-01, 2024-01-30), (2024-01-31, 2024-02-29), (2024-03-01, 2024-03-31)]
```

Uma função recursiva divide até cada parte caber numa requisição:

```python
import pandas as pd

MAX_SIZE = 1000


def baixar(tribunal: str, filtros: list[dict], inicio: dt.date, fim: dt.date) -> list[pd.DataFrame]:
    try:
        fatia = dj.search_slice(
            tribunal,
            montar(filtros, inicio, fim),
            max_size=MAX_SIZE,
            source={"excludes": ["movimentos"]},
        )
        return [fatia]
    except dj.SliceTooLargeError as erro:
        partes = dj.split_date_range(inicio, fim, parts=erro.total // MAX_SIZE + 1)
        return [df for a, b in partes for df in baixar(tribunal, filtros, a, b)]


processos = pd.concat(baixar("tjac", filtros, inicio, fim), ignore_index=True)
```

O filtro `source={"excludes": ["movimentos"]}` deixa a resposta cerca de vinte vezes menor. Baixe os movimentos à parte, só se precisar deles (seção 8).

Se um único dia tiver mais processos que `MAX_SIZE` (o que acontece nos tribunais grandes), `split_date_range()` levanta `ValueError`. Nesse caso, divida aquele dia por outro critério, como o órgão julgador (`{"term": {"orgaoJulgador.codigo": ...}}`) ou o prefixo do número CNJ com `add_cnj_prefix()`.

**Cuidado com prefixos curtos do número CNJ.** O filtro de prefixo percorre todos os números do índice que começam com aqueles dígitos, não só os da sua consulta. Um prefixo de um dígito casa com quase o índice inteiro e estoura o tempo do gateway (no TJAC, `"0"` falhou em todas as tentativas, enquanto `"07000"` respondeu em 26 segundos). Use prefixos só quando eles já forem longos, e as datas para o resto.

## 6. Coleta retomável

Numa coleta longa, alguma fatia vai falhar mesmo depois das novas tentativas. Para não recomeçar do zero, grave cada fatia num arquivo assim que ela chegar e pule as que já existem:

```python
from pathlib import Path

PASTA = Path("dados/fatias")
PASTA.mkdir(parents=True, exist_ok=True)


def coletar(tribunal: str, filtros: list[dict], inicio: dt.date, fim: dt.date) -> None:
    arquivo = PASTA / f"{tribunal}_{inicio}_{fim}.pkl"
    if arquivo.exists():
        return
    try:
        fatia = dj.search_slice(
            tribunal,
            montar(filtros, inicio, fim),
            max_size=MAX_SIZE,
            source={"excludes": ["movimentos"]},
        )
    except dj.SliceTooLargeError as erro:
        for a, b in dj.split_date_range(inicio, fim, parts=erro.total // MAX_SIZE + 1):
            coletar(tribunal, filtros, a, b)
        return
    fatia.to_pickle(arquivo)


coletar("tjac", filtros, inicio, fim)
```

Se a execução parar no meio (por `DataJudError` ou `IncompleteResponseError` depois de esgotar as tentativas), basta rodar `coletar()` de novo. As fatias já gravadas são puladas, e as que foram divididas voltam a ser contadas e divididas do mesmo jeito. O arquivo só é gravado quando a fatia chega completa, então um arquivo existente é sempre confiável.

Para coletas grandes, rode o script fora do horário comercial e fora da sessão interativa, por exemplo com `nohup uv run python coleta.py &`.

## 7. Juntando e conferindo

Leia as fatias e junte tudo:

```python
fatias = [pd.read_pickle(arquivo) for arquivo in sorted(PASTA.glob("tjac_*.pkl"))]
processos = pd.concat(fatias, ignore_index=True)
```

Confira se não há duplicatas e se o total bate com a soma das fatias:

```python
print(len(processos), processos["id"].nunique())
print(sum(f.attrs.get("total", len(f)) for f in fatias))
```

As contagens da API oscilam um pouco entre consultas (réplicas e reindexação), então pequenas diferenças são esperadas. Anote a data da coleta junto com os dados.

O mesmo processo pode aparecer mais de uma vez com `id` diferente, por exemplo uma vez para cada grau. O `id` identifica o documento; o `numeroProcesso`, o processo.

## 8. Datas, classes, assuntos e movimentos

As datas vêm em dois formatos: ISO (`2021-07-22T15:41:21.000Z`) e compacto (`20231110002114`), às vezes no mesmo tribunal e na mesma classe (seção 4). `parse_datajud_date()` lê os dois e devolve datas em UTC:

```python
processos["ajuizamento"] = dj.parse_datajud_date(processos["dataAjuizamento"])
processos["atualizacao"] = dj.parse_datajud_date(processos["dataHoraUltimaAtualizacao"])
```

As colunas `classe`, `orgaoJulgador`, `sistema` e `formato` guardam dicionários. Para tirar o código e o nome:

```python
processos["classe_nome"] = processos["classe"].str["nome"]
processos["orgao_codigo"] = processos["orgaoJulgador"].str["codigo"]
processos["orgao_nome"] = processos["orgaoJulgador"].str["nome"]
```

Os assuntos são uma lista por processo; `extract_subjects()` gera uma linha por assunto:

```python
assuntos = dj.extract_subjects(processos)
assuntos["assunto_nome"].value_counts().head(10)
```

Para os movimentos, colete sem o filtro `source`, com `max_size` menor (as respostas ficam grandes) e intervalos mais curtos, e use `extract_movements()`:

```python
semana = montar(filtros, dt.date(2024, 1, 15), dt.date(2024, 1, 19))
com_movimentos = dj.search_slice("tjac", semana, max_size=500)
movimentos = dj.extract_movements(com_movimentos)
movimentos["data"] = dj.parse_datajud_date(movimentos["movimento_data"])
```

## 9. Cuidados na análise

- **A classe é a atual.** O DataJud informa a classe e o órgão julgador de hoje, não os da distribuição. Um processo redistribuído sai do órgão de origem, e um processo cuja classe mudou (por exemplo, para cumprimento de sentença) sai do filtro pela classe original. Quando isso importar, colete sem filtrar pela classe e classifique depois.
- **Não há processos sigilosos.** O DataJud os omite.
- **O sistema informado pode surpreender.** Confira o campo `sistema` antes de usá-lo para separar processos por plataforma.
- **Horários perto da meia-noite.** O formato compacto não traz fuso, então datas lidas dele podem estar um dia fora.

## Resumo

| Etapa | Função |
|---|---|
| Configurar a chave | `set_api_key()` |
| Explorar | `search_cnj()`, `search_processes()` |
| Baixar uma fatia completa | `search_slice()` |
| Dividir uma fatia grande | `split_date_range()`; em último caso, `add_cnj_prefix()` |
| Filtrar datas | `date_range_query()` |
| Ler datas | `parse_datajud_date()` |
| Desaninhar | `extract_subjects()`, `extract_movements()` |
