"""Coleta em fatias pequenas, com conferência de respostas completas."""

from __future__ import annotations

import logging
import re
import time
from collections.abc import Iterable
from typing import Any

import pandas as pd

from .api_request import (
    IncompleteResponseError,
    SliceTooLargeError,
    backoff_seconds,
    check_complete,
    datajud_request,
    hits_total,
    parse_response,
)

logger = logging.getLogger("datajud")


def search_slice(
    tribunal: str,
    query: dict[str, Any],
    max_size: int = 2000,
    source: dict[str, Any] | None = None,
    parse: bool = True,
    api_key: str | None = None,
    max_tries: int = 5,
    **kwargs: Any,
) -> pd.DataFrame | dict[str, Any]:
    """Baixa numa única requisição todos os documentos de uma fatia pequena.

    Paginar com ``from``/``size`` sem ordenação repete e pula documentos na API
    do DataJud, e a ordenação tende a estourar o tempo do gateway. Por isso
    conjuntos grandes devem ser divididos em fatias que caibam numa requisição
    (por exemplo, por órgão julgador, ano de ajuizamento e prefixo do número
    CNJ; veja :func:`split_by_cnj_prefix`).

    A função primeiro conta os documentos. Se houver mais que ``max_size``,
    levanta :class:`SliceTooLargeError`, cujo atributo ``total`` traz a
    contagem, para quem chamou dividir a fatia. Senão, baixa a fatia e só
    aceita a resposta se :func:`check_complete` passar, com até ``max_tries``
    tentativas.

    Args:
        tribunal: Alias do tribunal.
        query: Consulta Elasticsearch.
        max_size: Maior fatia aceita. Fatias menores são mais rápidas e falham
            menos; com movimentos, as respostas são grandes e valores entre 500
            e 1000 funcionam melhor.
        source: Filtro de ``_source``, por exemplo
            ``{"excludes": ["movimentos"]}``, que reduz muito a resposta.
        parse: Se True, devolve um DataFrame (com o total em
            ``df.attrs["total"]``); senão, a resposta crua.
        api_key: Chave da API.
        max_tries: Número máximo de tentativas para obter resposta completa.
        **kwargs: Repassados a :func:`datajud_request` (por exemplo,
            ``timeout``).

    Examples:
        >>> query = {"bool": {"filter": [
        ...     {"term": {"classe.codigo": 49}},
        ...     {"term": {"orgaoJulgador.codigo": 12345}},
        ... ]}}
        >>> search_slice("tjsp", query, max_size=1000)  # doctest: +SKIP
    """
    count = request_complete(
        tribunal, query,
        size=0, track_total_hits=True, api_key=api_key,
        check_hits=False, max_tries=max_tries, **kwargs,
    )
    total = hits_total(count)

    if total > max_size:
        raise SliceTooLargeError(
            f"Slice has {total} documents, more than max_size = {max_size}.", total=total
        )

    response = count
    if total > 0:
        response = request_complete(
            tribunal, query,
            size=max_size, source=source, track_total_hits=True,
            api_key=api_key, max_tries=max_tries, **kwargs,
        )

    if not parse:
        return response
    result = parse_response(response)
    result.attrs["total"] = total
    return result


def request_complete(
    *args: Any, check_hits: bool = True, max_tries: int = 5, **kwargs: Any
) -> dict[str, Any]:
    """Chama :func:`datajud_request` até :func:`check_complete` passar.

    A API responde 200 mesmo quando a maioria dos shards recusa a busca, de
    modo que repetir só os erros HTTP não basta.
    """
    for attempt in range(1, max_tries + 1):
        response = datajud_request(*args, max_tries=max_tries, **kwargs)
        try:
            check_complete(response, check_hits=check_hits)
        except IncompleteResponseError as e:
            if attempt == max_tries:
                raise
            wait = backoff_seconds(attempt)
            logger.warning("Attempt %d: %s Retrying in %.0f s.", attempt, e, wait)
            time.sleep(wait)
        else:
            return response
    raise AssertionError("unreachable")


def add_cnj_prefix(query: dict[str, Any], prefix: str) -> dict[str, Any]:
    """Restringe a consulta aos números CNJ que começam com ``prefix``.

    Os sete primeiros dígitos do número CNJ são sequenciais, de modo que os
    prefixos dividem uma fatia em partes de tamanho parecido.

    Examples:
        >>> add_cnj_prefix({"term": {"classe.codigo": 49}}, "10")
        {'bool': {'filter': [{'term': {'classe.codigo': 49}}, {'prefix': {'numeroProcesso': '10'}}]}}
    """
    if not re.fullmatch(r"[0-9]*", prefix):
        raise ValueError("prefix must contain only digits.")
    if prefix == "":
        return query
    return {"bool": {"filter": [query, {"prefix": {"numeroProcesso": prefix}}]}}


def split_by_cnj_prefix(query: dict[str, Any], prefix: str = "") -> dict[str, dict[str, Any]]:
    """Divide a consulta em dez, uma para cada dígito seguinte a ``prefix``.

    Use para dividir uma fatia que :func:`search_slice` recusou por ser grande,
    descendo um dígito por vez.

    Returns:
        Dicionário de dez consultas, indexado pelos novos prefixos.

    Examples:
        >>> list(split_by_cnj_prefix({"term": {"classe.codigo": 49}}, "1"))[:3]
        ['10', '11', '12']
    """
    return {f"{prefix}{d}": add_cnj_prefix(query, f"{prefix}{d}") for d in range(10)}


_COMPACT = r"[0-9]{8}(?:[0-9]{6})?"
_ISO = r"[0-9]{4}-[0-9]{2}-[0-9]{2}(?:T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]+)?Z?)?"


def parse_datajud_date(x: Iterable[str | None] | str | None) -> pd.Series:
    """Lê as datas do DataJud, que vêm em dois formatos.

    ISO 8601 (``2021-07-22T15:41:21.000Z``) e compacto (``20231110002114``).
    O índice interpreta mal o formato compacto em consultas por intervalo, então
    leia as datas do lado do cliente com esta função.

    Os dois formatos são lidos como UTC. O compacto não traz fuso, de modo que
    horários perto da meia-noite podem estar um dia fora.

    Returns:
        Série ``datetime64[ns, UTC]``; valores não reconhecidos viram ``NaT``.

    Examples:
        >>> parse_datajud_date(["2021-07-22T15:41:21.000Z", "20231110002114"]).tolist()
        [Timestamp('2021-07-22 15:41:21+0000', tz='UTC'), Timestamp('2023-11-10 00:21:14+0000', tz='UTC')]
    """
    if x is None or isinstance(x, str):
        x = [x]
    s = pd.Series(list(x), dtype="object")
    out = pd.Series(pd.NaT, index=s.index, dtype="datetime64[ns, UTC]")

    text = s.where(s.notna(), "").astype(str)

    compact = text.str.fullmatch(_COMPACT)
    y = text[compact].where(text[compact].str.len() == 14, text[compact] + "000000")
    out[compact] = pd.to_datetime(y, format="%Y%m%d%H%M%S", utc=True, errors="coerce")

    iso = text.str.fullmatch(_ISO)
    y = text[iso].str.replace(r"Z$", "", regex=True).str.replace(r"\.[0-9]+$", "", regex=True)
    y = y.str.replace("T", " ").where(y.str.len() != 10, y + " 00:00:00")
    out[iso] = pd.to_datetime(y, format="%Y-%m-%d %H:%M:%S", utc=True, errors="coerce")

    return out
