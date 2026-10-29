"""Acesso à API pública do DataJud, mantida pelo CNJ."""

from .api_request import (
    DataJudError,
    IncompleteResponseError,
    SliceTooLargeError,
    check_complete,
    datajud_request,
    hits_total,
    parse_response,
    search_datajud,
)
from .config import get_api_key, get_default_api_key, set_api_key
from .search import (
    build_query,
    extract_movements,
    extract_subjects,
    format_datajud_date,
    search_advanced,
    search_by_date,
    search_cnj,
    search_processes,
    search_processes_paginated,
)
from .slices import add_cnj_prefix, parse_datajud_date, search_slice, split_by_cnj_prefix
from .tribunals import list_tribunals, normalize_tribunal, validate_tribunal

__all__ = [
    "DataJudError",
    "IncompleteResponseError",
    "SliceTooLargeError",
    "add_cnj_prefix",
    "build_query",
    "check_complete",
    "datajud_request",
    "extract_movements",
    "extract_subjects",
    "format_datajud_date",
    "get_api_key",
    "get_default_api_key",
    "hits_total",
    "list_tribunals",
    "normalize_tribunal",
    "parse_datajud_date",
    "parse_response",
    "search_advanced",
    "search_by_date",
    "search_cnj",
    "search_datajud",
    "search_processes",
    "search_processes_paginated",
    "search_slice",
    "set_api_key",
    "split_by_cnj_prefix",
    "validate_tribunal",
]
