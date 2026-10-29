"""Requisições à API do DataJud, novas tentativas e leitura das respostas."""

from __future__ import annotations

import logging
import random
import time
from typing import Any

import httpx
import pandas as pd

from .config import get_api_key
from .tribunals import normalize_tribunal

logger = logging.getLogger("datajud")

BASE_URL = "https://api-publica.datajud.cnj.jus.br"


class DataJudError(Exception):
    """Falha na requisição à API do DataJud."""


class IncompleteResponseError(DataJudError):
    """A API respondeu 200, mas com resultado parcial."""


class SliceTooLargeError(DataJudError):
    """A fatia tem mais documentos que o permitido; ``total`` guarda a contagem."""

    def __init__(self, message: str, total: int) -> None:
        super().__init__(message)
        self.total = total


def datajud_request(
    tribunal: str,
    query: dict[str, Any],
    size: int = 10,
    api_key: str | None = None,
    base_url: str = BASE_URL,
    from_: int = 0,
    source: dict[str, Any] | None = None,
    aggs: dict[str, Any] | None = None,
    track_total_hits: bool | None = None,
    max_tries: int = 5,
    timeout: float = 120,
) -> dict[str, Any]:
    """Faz um POST em ``/<tribunal>/_search`` e devolve a resposta como dicionário.

    Status 429, 5xx e erros de conexão são repetidos com espera exponencial.

    Args:
        tribunal: Alias do tribunal (curto ou completo).
        query: Consulta Elasticsearch.
        size: Número de documentos a devolver.
        api_key: Chave da API. Se None, usa :func:`get_api_key`.
        base_url: URL base da API.
        from_: Posição do primeiro documento.
        source: Filtro de ``_source``, por exemplo
            ``{"excludes": ["movimentos"]}``.
        aggs: Agregações Elasticsearch.
        track_total_hits: Se True, pede o total exato em vez do limite
            inferior de 10.000.
        max_tries: Número máximo de tentativas.
        timeout: Tempo limite de cada tentativa, em segundos.
    """
    tribunal = normalize_tribunal(tribunal)
    if api_key is None:
        api_key = get_api_key()

    url = f"{base_url}/{tribunal}/_search"

    body: dict[str, Any] = {"query": query, "size": size, "from": from_}
    if source is not None:
        body["_source"] = source
    if aggs is not None:
        body["aggs"] = aggs
    if track_total_hits is not None:
        body["track_total_hits"] = track_total_hits

    # A API costuma responder 429 e 504 em horário comercial
    for attempt in range(1, max_tries + 1):
        try:
            response = datajud_post(url, api_key, body, timeout)
        except httpx.TransportError as e:
            problem = f"{type(e).__name__}: {e}"
            retry = True
        else:
            if response.status_code == 200:
                return response.json()
            problem = f"API request failed with status {response.status_code}: {response.text}"
            retry = response.status_code == 429 or response.status_code >= 500

        if not retry or attempt == max_tries:
            raise DataJudError(problem)

        wait = backoff_seconds(attempt)
        logger.warning("Attempt %d failed (%s). Retrying in %.0f s.", attempt, problem[:80], wait)
        time.sleep(wait)

    raise AssertionError("unreachable")


def datajud_post(url: str, api_key: str, body: dict[str, Any], timeout: float) -> httpx.Response:
    """POST cru à API, separado para que as novas tentativas possam ser testadas sem rede."""
    return httpx.post(
        url,
        headers={"Authorization": f"APIKey {api_key}"},
        json=body,
        timeout=timeout,
    )


def backoff_seconds(attempt: int, base: float = 5, cap: float = 120) -> float:
    """Espera exponencial com variação aleatória, em segundos."""
    return min(cap, base * 2 ** (attempt - 1)) + random.uniform(0, base)


def check_complete(response: dict[str, Any], check_hits: bool = True) -> bool:
    """Confere se uma resposta do DataJud está completa.

    A API pode devolver resultados parciais sem erro HTTP quando alguns shards
    estouram o tempo. A resposta é rejeitada se tiver ``timed_out``, shards com
    falha, total aproximado ou menos documentos que o total informado.

    Args:
        response: Resposta crua da API.
        check_hits: Se False, não compara o número de documentos com o total
            (útil em contagens com ``size=0``).

    Returns:
        True se a resposta estiver completa.

    Raises:
        IncompleteResponseError: Se a resposta estiver incompleta.
    """
    problems: list[str] = []

    if response.get("timed_out"):
        problems.append("the search timed out")

    failed = (response.get("_shards") or {}).get("failed") or 0
    if failed > 0:
        problems.append(f"{failed} shard(s) failed")

    total = (response.get("hits") or {}).get("total")
    relation = total.get("relation", "eq") if isinstance(total, dict) else "eq"
    if relation != "eq":
        problems.append("the total is a lower bound (use track_total_hits)")

    if check_hits:
        expected = hits_total(response)
        n = len((response.get("hits") or {}).get("hits") or [])
        if n < expected:
            problems.append(f"{n} of {expected} documents returned")

    if problems:
        raise IncompleteResponseError("Incomplete DataJud response: " + "; ".join(problems))

    return True


def hits_total(response: dict[str, Any]) -> int:
    """Total de documentos informado na resposta."""
    total = (response.get("hits") or {}).get("total")
    if isinstance(total, dict):
        total = total.get("value")
    return total or 0


def search_datajud(
    tribunal: str,
    query: dict[str, Any],
    size: int = 10,
    parse: bool = True,
    api_key: str | None = None,
    from_: int = 0,
) -> pd.DataFrame | dict[str, Any]:
    """Busca com uma consulta Elasticsearch qualquer.

    Args:
        tribunal: Alias do tribunal; veja :func:`list_tribunals`.
        query: Consulta no formato Query DSL do Elasticsearch.
        size: Número de documentos (máximo 10.000).
        parse: Se True, devolve um DataFrame; senão, a resposta crua.
        api_key: Chave da API.
        from_: Posição do primeiro documento.

    Examples:
        >>> query = {"match": {"numeroProcesso": "00001234520204036100"}}
        >>> search_datajud("trf1", query)  # doctest: +SKIP
    """
    response = datajud_request(tribunal, query, size, api_key, from_=from_)
    if not parse:
        return response
    return parse_response(response)


_COLUMNS = [
    "id",
    "score",
    "numeroProcesso",
    "classe",
    "sistema",
    "formato",
    "tribunal",
    "dataHoraUltimaAtualizacao",
    "grau",
    "nivelSigilo",
    "dataAjuizamento",
    "movimentos",
    "assuntos",
    "orgaoJulgador",
]


def parse_response(response: dict[str, Any]) -> pd.DataFrame:
    """Converte a resposta crua num DataFrame, um processo por linha.

    ``classe``, ``sistema``, ``formato``, ``movimentos``, ``assuntos`` e
    ``orgaoJulgador`` ficam como objetos aninhados (dicionários ou listas).
    """
    hits = (response.get("hits") or {}).get("hits") or []
    if not hits:
        logger.info("No results found.")
        return pd.DataFrame(columns=_COLUMNS)

    rows = []
    for hit in hits:
        source = hit.get("_source") or {}
        row = {col: source.get(col) for col in _COLUMNS}
        row["id"] = hit.get("_id")
        row["score"] = hit.get("_score")
        rows.append(row)

    return pd.DataFrame(rows, columns=_COLUMNS)
