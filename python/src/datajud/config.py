"""Chave de acesso à API do DataJud."""

from __future__ import annotations

import os

DEFAULT_API_KEY = "cDZHYzlZa0JadVREZDJCendQbXY6SkJlTzNjLV9TRENyQk1RdnFKZGRQdw=="

_api_key: str | None = None


def set_api_key(api_key: str | None = None) -> str:
    """Define a chave da API para a sessão.

    Args:
        api_key: Chave da API. Se None, lê a variável de ambiente
            ``DATAJUD_API_KEY``.

    Returns:
        A chave definida.

    Examples:
        >>> set_api_key(get_default_api_key())  # doctest: +SKIP
    """
    global _api_key
    if api_key is None:
        api_key = os.environ.get("DATAJUD_API_KEY", "")
        if not api_key:
            raise ValueError(
                "API key not found. Please provide an api_key or set DATAJUD_API_KEY environment variable."
            )
    _api_key = api_key
    return api_key


def get_api_key() -> str:
    """Devolve a chave definida com :func:`set_api_key` ou a de ``DATAJUD_API_KEY``."""
    if _api_key is not None:
        return _api_key
    api_key = os.environ.get("DATAJUD_API_KEY", "")
    if not api_key:
        raise ValueError(
            "API key not set. Use set_api_key() or set the DATAJUD_API_KEY environment variable.\n"
            f"The default public key is: {DEFAULT_API_KEY}"
        )
    return api_key


def get_default_api_key() -> str:
    """Devolve a chave pública divulgada pelo CNJ, que pode mudar a qualquer momento."""
    return DEFAULT_API_KEY
