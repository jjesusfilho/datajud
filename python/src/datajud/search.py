"""Funções de busca de alto nível."""

from __future__ import annotations

import datetime as dt
import logging
import re
import time
import warnings
from pathlib import Path
from typing import Any

import pandas as pd

from .api_request import datajud_request, hits_total, parse_response, search_datajud

logger = logging.getLogger("datajud")

DateLike = str | dt.date | None

# Parâmetro de search_processes -> campo no índice
_MATCH_FIELDS: dict[str, str] = {
    "id": "id",
    "numeroProcesso": "numeroProcesso",
    "grau": "grau",
    "nivelSigilo": "nivelSigilo",
    "formato_codigo": "formato.codigo",
    "formato_nome": "formato.nome",
    "sistema_codigo": "sistema.codigo",
    "sistema_nome": "sistema.nome",
    "classe_codigo": "classe.codigo",
    "classe_nome": "classe.nome",
    "assuntos_codigo": "assuntos.codigo",
    "assuntos_nome": "assuntos.nome",
    "orgaoJulgador_codigo": "orgaoJulgador.codigo",
    "orgaoJulgador_nome": "orgaoJulgador.nome",
    "orgaoJulgador_codigoMunicipioIBGE": "orgaoJulgador.codigoMunicipioIBGE",
    "movimentos_codigo": "movimentos.codigo",
    "movimentos_nome": "movimentos.nome",
}

_RANGE_FIELDS: dict[str, str] = {
    "dataAjuizamento": "dataAjuizamento",
    "dataHoraUltimaAtualizacao": "dataHoraUltimaAtualizacao",
    "movimentos_dataHora": "movimentos.dataHora",
}


def format_datajud_date(date_input: DateLike, time_suffix: str = "000000") -> str | None:
    """Converte uma data para o formato ``yyyymmddhhmmss`` usado nas consultas.

    Aceita ``"yyyy-mm-dd"``, ``"yyyy/mm/dd"``, ``"yyyymmdd"``,
    ``"yyyymmddhhmmss"`` e objetos ``date``/``datetime``. O que não reconhece
    devolve como texto, para a API decidir.

    Examples:
        >>> format_datajud_date("2020-01-31", "235959")
        '20200131235959'
    """
    if date_input is None:
        return None
    if isinstance(date_input, dt.date):
        return date_input.strftime("%Y%m%d") + time_suffix

    date_str = str(date_input)
    if re.fullmatch(r"\d{14}", date_str):
        return date_str
    if re.fullmatch(r"\d{8}", date_str):
        return date_str + time_suffix
    if re.match(r"\d{4}[-/]\d{2}[-/]\d{2}", date_str):
        return re.sub(r"[-/]", "", date_str[:10]) + time_suffix
    return date_str


def _compact_and_iso(date_input: DateLike, time_suffix: str, millis: str) -> tuple[str, str]:
    compact = format_datajud_date(date_input, time_suffix)
    if compact is None or not re.fullmatch(r"\d{14}", compact):
        raise ValueError(f"Unrecognized date: {date_input!r}")
    c = compact
    iso = f"{c[:4]}-{c[4:6]}-{c[6:8]}T{c[8:10]}:{c[10:12]}:{c[12:14]}.{millis}Z"
    return compact, iso


def date_range_query(field: str, start: DateLike = None, end: DateLike = None) -> dict[str, Any]:
    """Filtro de intervalo de datas que funciona com os dois formatos do índice.

    O DataJud grava as datas ora em ISO (``2024-01-16T12:41:15.000Z``), ora no
    formato compacto (``20240311124906``). O índice lê as compactas como
    milissegundos desde 1970, de modo que um ``range`` em ISO só encontra os
    documentos gravados em ISO e um ``range`` compacto só os compactos. Este
    filtro combina os dois com ``should``.

    Args:
        field: Campo de data, por exemplo ``"dataAjuizamento"``.
        start: Início do intervalo, inclusive.
        end: Fim do intervalo, inclusive (o dia inteiro, se for só a data).

    Examples:
        >>> date_range_query("dataAjuizamento", "2024-01-01", "2024-01-31")
        {'bool': {'should': [{'range': {'dataAjuizamento': {'gte': '2024-01-01T00:00:00.000Z', 'lte': '2024-01-31T23:59:59.999Z'}}}, {'range': {'dataAjuizamento': {'gte': '20240101000000', 'lte': '20240131235959'}}}], 'minimum_should_match': 1}}
    """
    if start is None and end is None:
        raise ValueError("At least one of start or end must be provided.")
    iso: dict[str, str] = {}
    compact: dict[str, str] = {}
    if start is not None:
        compact["gte"], iso["gte"] = _compact_and_iso(start, "000000", "000")
    if end is not None:
        compact["lte"], iso["lte"] = _compact_and_iso(end, "235959", "999")
    return {"bool": {
        "should": [{"range": {field: iso}}, {"range": {field: compact}}],
        "minimum_should_match": 1,
    }}


def _clean_cnj(number: str) -> str:
    return re.sub(r"[^0-9]", "", number)


def build_query(**params: Any) -> dict[str, Any]:
    """Monta a consulta ``bool.must`` usada por :func:`search_processes`.

    Aceita os mesmos parâmetros de busca de :func:`search_processes`.
    """
    unknown = set(params) - set(_MATCH_FIELDS) - {
        f"{name}_{side}" for name in _RANGE_FIELDS for side in ("start", "end")
    }
    if unknown:
        raise TypeError(f"Unknown search parameter(s): {', '.join(sorted(unknown))}")

    must: list[dict[str, Any]] = []

    for param, field in _MATCH_FIELDS.items():
        value = params.get(param)
        if value is None:
            continue
        if param == "numeroProcesso":
            value = _clean_cnj(value)
        must.append({"match": {field: value}})

    for name, field in _RANGE_FIELDS.items():
        start = params.get(f"{name}_start")
        end = params.get(f"{name}_end")
        if start is not None or end is not None:
            must.append(date_range_query(field, start, end))

    if not must:
        raise ValueError("At least one search parameter must be provided.")

    return {"bool": {"must": must}}


def search_cnj(
    cnj_number: str | list[str],
    tribunal: str,
    size: int = 10,
    parse: bool = True,
    api_key: str | None = None,
) -> Any:
    """Busca processos pelo número CNJ (com ou sem formatação).

    Com uma lista de números, devolve um dicionário com um resultado por
    número, indexado pelo número como foi informado.

    Examples:
        >>> search_cnj("0000123-45.2020.4.03.6100", tribunal="trf3")  # doctest: +SKIP
    """
    def one(number: str) -> Any:
        query = {"match": {"numeroProcesso": _clean_cnj(number)}}
        return search_datajud(tribunal, query, size, parse, api_key)

    if isinstance(cnj_number, str):
        return one(cnj_number)
    return {number: one(number) for number in cnj_number}


def search_by_date(
    tribunal: str,
    date_field: str = "dataAjuizamento",
    start_date: DateLike = None,
    end_date: DateLike = None,
    size: int = 10,
    parse: bool = True,
    api_key: str | None = None,
) -> Any:
    """Busca processos num intervalo de datas.

    Args:
        date_field: ``"dataAjuizamento"`` ou ``"dataHoraUltimaAtualizacao"``.
        start_date: Início do intervalo (``"YYYY-MM-DD"`` ou ``date``).
        end_date: Fim do intervalo, inclusive.
    """
    if start_date is None and end_date is None:
        raise ValueError("At least one of start_date or end_date must be provided.")
    query = date_range_query(date_field, start_date, end_date)
    return search_datajud(tribunal, query, size, parse, api_key)


def search_advanced(
    tribunal: str,
    query_string: str,
    fields: list[str] | None = None,
    size: int = 10,
    parse: bool = True,
    api_key: str | None = None,
) -> Any:
    """Busca com ``query_string`` do Elasticsearch nos campos indicados.

    Examples:
        >>> search_advanced("trf1", "ação civil pública",
        ...                 fields=["classe.nome", "assuntos.nome"])  # doctest: +SKIP
    """
    query = {"query_string": {"query": query_string, "fields": fields or ["*"]}}
    return search_datajud(tribunal, query, size, parse, api_key)


def search_processes(
    tribunal: str,
    size: int = 10,
    parse: bool = True,
    api_key: str | None = None,
    **params: Any,
) -> Any:
    """Busca combinando os critérios documentados da API.

    Critérios aceitos (todos opcionais, combinados com E): ``id``,
    ``numeroProcesso``, ``grau``, ``nivelSigilo``, ``formato_codigo``,
    ``formato_nome``, ``sistema_codigo``, ``sistema_nome``, ``classe_codigo``,
    ``classe_nome``, ``assuntos_codigo``, ``assuntos_nome``,
    ``orgaoJulgador_codigo``, ``orgaoJulgador_nome``,
    ``orgaoJulgador_codigoMunicipioIBGE``, ``movimentos_codigo``,
    ``movimentos_nome`` e os intervalos ``dataAjuizamento_start/_end``,
    ``dataHoraUltimaAtualizacao_start/_end`` e ``movimentos_dataHora_start/_end``.

    Examples:
        >>> search_processes("tjsp", classe_codigo="1199", grau="G2")  # doctest: +SKIP
    """
    query = build_query(**params)
    return search_datajud(tribunal, query, size, parse, api_key)


def search_processes_paginated(
    tribunal: str,
    page_size: int = 100,
    max_pages: int | None = None,
    save_pages: bool = False,
    output_dir: str | Path = "datajud_pages",
    output_format: str = "pickle",
    api_key: str | None = None,
    **params: Any,
) -> dict[str, Any]:
    """Busca em páginas com ``from``/``size``, opcionalmente salvando cada página.

    Paginar sem ordenação repete e pula documentos na API do DataJud; prefira
    :func:`search_slice` com fatias pequenas.

    Args:
        page_size: Documentos por página (máximo 10.000).
        max_pages: Número máximo de páginas; None para todas.
        save_pages: Se True, grava cada página em ``output_dir``.
        output_format: ``"pickle"``, ``"csv"`` ou ``"json"``.
        **params: Critérios de busca, como em :func:`search_processes`.

    Returns:
        Dicionário com ``data`` (todas as páginas juntas), ``pages``,
        ``total_hits``, ``pages_fetched`` e, se ``save_pages``, ``files_saved``.
    """
    warnings.warn(
        "Paging with from/size without a sort repeats and skips documents in the "
        "DataJud API. Prefer search_slice() with small slices.",
        stacklevel=2,
    )
    if output_format not in ("pickle", "csv", "json"):
        raise ValueError("output_format must be 'pickle', 'csv' or 'json'.")

    output_dir = Path(output_dir)
    if save_pages:
        output_dir.mkdir(parents=True, exist_ok=True)

    query = build_query(**params)

    pages: list[pd.DataFrame] = []
    files_saved: list[Path] = []
    total_hits: int | None = None
    page = 0

    while True:
        page += 1
        from_ = (page - 1) * page_size
        logger.info("Fetching page %d...", page)
        response = datajud_request(tribunal, query, size=page_size, api_key=api_key, from_=from_)

        if total_hits is None:
            total_hits = hits_total(response)
            logger.info("Total results available: %d", total_hits)

        if not (response.get("hits") or {}).get("hits"):
            logger.info("No more results. Stopping at page %d", page - 1)
            break

        page_data = parse_response(response)
        pages.append(page_data)

        if save_pages:
            stamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
            base = output_dir / f"page_{page:03d}_{stamp}"
            if output_format == "pickle":
                path = base.with_suffix(".pkl")
                page_data.to_pickle(path)
            elif output_format == "csv":
                path = base.with_suffix(".csv")
                page_data.to_csv(path, index=False)
            else:
                path = base.with_suffix(".json")
                page_data.to_json(path, orient="records", force_ascii=False, indent=2)
            files_saved.append(path)
            logger.info("Saved page %d to: %s", page, path)

        if max_pages is not None and page >= max_pages:
            logger.info("Reached max_pages limit (%d). Stopping.", max_pages)
            break
        if from_ + page_size >= total_hits:
            logger.info("Fetched all available results. Stopping at page %d", page)
            break

        time.sleep(0.5)

    result: dict[str, Any] = {
        "data": pd.concat(pages, ignore_index=True) if pages else None,
        "pages": pages,
        "total_hits": total_hits,
        "pages_fetched": len(pages),
    }
    if save_pages:
        result["files_saved"] = files_saved
    return result


def extract_movements(results: pd.DataFrame) -> pd.DataFrame:
    """Desaninha os movimentos: uma linha por movimento de cada processo."""
    rows = []
    for numero, movimentos in zip(results["numeroProcesso"], results["movimentos"]):
        for m in movimentos or []:
            complementos = m.get("complementos")
            rows.append({
                "numeroProcesso": numero,
                "movimento_codigo": m.get("codigo"),
                "movimento_nome": m.get("nome"),
                "movimento_data": m.get("dataHora"),
                "movimento_complemento": (
                    "; ".join(str(c.get("nome")) for c in complementos) if complementos else None
                ),
            })
    return pd.DataFrame(rows, columns=[
        "numeroProcesso", "movimento_codigo", "movimento_nome", "movimento_data",
        "movimento_complemento",
    ])


def extract_subjects(results: pd.DataFrame) -> pd.DataFrame:
    """Desaninha os assuntos: uma linha por assunto de cada processo."""
    rows = [
        {"numeroProcesso": numero, "assunto_codigo": a.get("codigo"), "assunto_nome": a.get("nome")}
        for numero, assuntos in zip(results["numeroProcesso"], results["assuntos"])
        for a in assuntos or []
    ]
    return pd.DataFrame(rows, columns=["numeroProcesso", "assunto_codigo", "assunto_nome"])
