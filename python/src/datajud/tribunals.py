"""Tribunais disponíveis na API pública do DataJud."""

from __future__ import annotations

import pandas as pd

_TRIBUNALS: list[tuple[str, str, str]] = [
    ("api_publica_tst", "Tribunal Superior do Trabalho", "Superior"),
    ("api_publica_tse", "Tribunal Superior Eleitoral", "Superior"),
    ("api_publica_stj", "Superior Tribunal de Justiça", "Superior"),
    ("api_publica_stm", "Superior Tribunal Militar", "Superior"),
    ("api_publica_tre-ac", "Tribunal Regional Eleitoral do Acre", "TRE"),
    ("api_publica_tre-al", "Tribunal Regional Eleitoral de Alagoas", "TRE"),
    ("api_publica_tre-ap", "Tribunal Regional Eleitoral do Amapá", "TRE"),
    ("api_publica_tre-am", "Tribunal Regional Eleitoral do Amazonas", "TRE"),
    ("api_publica_tre-ba", "Tribunal Regional Eleitoral da Bahia", "TRE"),
    ("api_publica_tre-ce", "Tribunal Regional Eleitoral do Ceará", "TRE"),
    ("api_publica_tre-dft", "Tribunal Regional Eleitoral do Distrito Federal", "TRE"),
    ("api_publica_tre-es", "Tribunal Regional Eleitoral do Espírito Santo", "TRE"),
    ("api_publica_tre-go", "Tribunal Regional Eleitoral de Goiás", "TRE"),
    ("api_publica_tre-ma", "Tribunal Regional Eleitoral do Maranhão", "TRE"),
    ("api_publica_tre-mt", "Tribunal Regional Eleitoral de Mato Grosso", "TRE"),
    ("api_publica_tre-ms", "Tribunal Regional Eleitoral de Mato Grosso do Sul", "TRE"),
    ("api_publica_tre-mg", "Tribunal Regional Eleitoral de Minas Gerais", "TRE"),
    ("api_publica_tre-pa", "Tribunal Regional Eleitoral do Pará", "TRE"),
    ("api_publica_tre-pb", "Tribunal Regional Eleitoral da Paraíba", "TRE"),
    ("api_publica_tre-pr", "Tribunal Regional Eleitoral do Paraná", "TRE"),
    ("api_publica_tre-pe", "Tribunal Regional Eleitoral de Pernambuco", "TRE"),
    ("api_publica_tre-pi", "Tribunal Regional Eleitoral do Piauí", "TRE"),
    ("api_publica_tre-rj", "Tribunal Regional Eleitoral do Rio de Janeiro", "TRE"),
    ("api_publica_tre-rn", "Tribunal Regional Eleitoral do Rio Grande do Norte", "TRE"),
    ("api_publica_tre-rs", "Tribunal Regional Eleitoral do Rio Grande do Sul", "TRE"),
    ("api_publica_tre-ro", "Tribunal Regional Eleitoral de Rondônia", "TRE"),
    ("api_publica_tre-rr", "Tribunal Regional Eleitoral de Roraima", "TRE"),
    ("api_publica_tre-sc", "Tribunal Regional Eleitoral de Santa Catarina", "TRE"),
    ("api_publica_tre-sp", "Tribunal Regional Eleitoral de São Paulo", "TRE"),
    ("api_publica_tre-se", "Tribunal Regional Eleitoral de Sergipe", "TRE"),
    ("api_publica_tre-to", "Tribunal Regional Eleitoral do Tocantins", "TRE"),
    ("api_publica_trf1", "Tribunal Regional Federal da 1ª Região", "TRF"),
    ("api_publica_trf2", "Tribunal Regional Federal da 2ª Região", "TRF"),
    ("api_publica_trf3", "Tribunal Regional Federal da 3ª Região", "TRF"),
    ("api_publica_trf4", "Tribunal Regional Federal da 4ª Região", "TRF"),
    ("api_publica_trf5", "Tribunal Regional Federal da 5ª Região", "TRF"),
    ("api_publica_trf6", "Tribunal Regional Federal da 6ª Região", "TRF"),
    ("api_publica_tjac", "Tribunal de Justiça do Acre", "TJ"),
    ("api_publica_tjal", "Tribunal de Justiça de Alagoas", "TJ"),
    ("api_publica_tjap", "Tribunal de Justiça do Amapá", "TJ"),
    ("api_publica_tjam", "Tribunal de Justiça do Amazonas", "TJ"),
    ("api_publica_tjba", "Tribunal de Justiça da Bahia", "TJ"),
    ("api_publica_tjce", "Tribunal de Justiça do Ceará", "TJ"),
    ("api_publica_tjdft", "Tribunal de Justiça do Distrito Federal e Territórios", "TJ"),
    ("api_publica_tjes", "Tribunal de Justiça do Espírito Santo", "TJ"),
    ("api_publica_tjgo", "Tribunal de Justiça de Goiás", "TJ"),
    ("api_publica_tjma", "Tribunal de Justiça do Maranhão", "TJ"),
    ("api_publica_tjmt", "Tribunal de Justiça de Mato Grosso", "TJ"),
    ("api_publica_tjms", "Tribunal de Justiça de Mato Grosso do Sul", "TJ"),
    ("api_publica_tjmg", "Tribunal de Justiça de Minas Gerais", "TJ"),
    ("api_publica_tjpa", "Tribunal de Justiça do Pará", "TJ"),
    ("api_publica_tjpb", "Tribunal de Justiça da Paraíba", "TJ"),
    ("api_publica_tjpr", "Tribunal de Justiça do Paraná", "TJ"),
    ("api_publica_tjpe", "Tribunal de Justiça de Pernambuco", "TJ"),
    ("api_publica_tjpi", "Tribunal de Justiça do Piauí", "TJ"),
    ("api_publica_tjrj", "Tribunal de Justiça do Rio de Janeiro", "TJ"),
    ("api_publica_tjrn", "Tribunal de Justiça do Rio Grande do Norte", "TJ"),
    ("api_publica_tjrs", "Tribunal de Justiça do Rio Grande do Sul", "TJ"),
    ("api_publica_tjro", "Tribunal de Justiça de Rondônia", "TJ"),
    ("api_publica_tjrr", "Tribunal de Justiça de Roraima", "TJ"),
    ("api_publica_tjsc", "Tribunal de Justiça de Santa Catarina", "TJ"),
    ("api_publica_tjsp", "Tribunal de Justiça de São Paulo", "TJ"),
    ("api_publica_tjse", "Tribunal de Justiça de Sergipe", "TJ"),
    ("api_publica_tjto", "Tribunal de Justiça do Tocantins", "TJ"),
    ("api_publica_trt1", "Tribunal Regional do Trabalho da 1ª Região", "TRT"),
    ("api_publica_trt2", "Tribunal Regional do Trabalho da 2ª Região", "TRT"),
    ("api_publica_trt3", "Tribunal Regional do Trabalho da 3ª Região", "TRT"),
    ("api_publica_trt4", "Tribunal Regional do Trabalho da 4ª Região", "TRT"),
    ("api_publica_trt5", "Tribunal Regional do Trabalho da 5ª Região", "TRT"),
    ("api_publica_trt6", "Tribunal Regional do Trabalho da 6ª Região", "TRT"),
    ("api_publica_trt7", "Tribunal Regional do Trabalho da 7ª Região", "TRT"),
    ("api_publica_trt8", "Tribunal Regional do Trabalho da 8ª Região", "TRT"),
    ("api_publica_trt9", "Tribunal Regional do Trabalho da 9ª Região", "TRT"),
    ("api_publica_trt10", "Tribunal Regional do Trabalho da 10ª Região", "TRT"),
    ("api_publica_trt11", "Tribunal Regional do Trabalho da 11ª Região", "TRT"),
    ("api_publica_trt12", "Tribunal Regional do Trabalho da 12ª Região", "TRT"),
    ("api_publica_trt13", "Tribunal Regional do Trabalho da 13ª Região", "TRT"),
    ("api_publica_trt14", "Tribunal Regional do Trabalho da 14ª Região", "TRT"),
    ("api_publica_trt15", "Tribunal Regional do Trabalho da 15ª Região", "TRT"),
    ("api_publica_trt16", "Tribunal Regional do Trabalho da 16ª Região", "TRT"),
    ("api_publica_trt17", "Tribunal Regional do Trabalho da 17ª Região", "TRT"),
    ("api_publica_trt18", "Tribunal Regional do Trabalho da 18ª Região", "TRT"),
    ("api_publica_trt19", "Tribunal Regional do Trabalho da 19ª Região", "TRT"),
    ("api_publica_trt20", "Tribunal Regional do Trabalho da 20ª Região", "TRT"),
    ("api_publica_trt21", "Tribunal Regional do Trabalho da 21ª Região", "TRT"),
    ("api_publica_trt22", "Tribunal Regional do Trabalho da 22ª Região", "TRT"),
    ("api_publica_trt23", "Tribunal Regional do Trabalho da 23ª Região", "TRT"),
    ("api_publica_trt24", "Tribunal Regional do Trabalho da 24ª Região", "TRT"),
]

_ALIASES: frozenset[str] = frozenset(alias for alias, _, _ in _TRIBUNALS)


def list_tribunals() -> pd.DataFrame:
    """Lista os tribunais disponíveis.

    Returns:
        DataFrame com as colunas ``alias`` (código do tribunal na API),
        ``name`` (nome) e ``type`` (Superior, TRE, TRF, TJ ou TRT).

    Examples:
        >>> tribunals = list_tribunals()
        >>> tribunals[tribunals["type"] == "TRF"]  # doctest: +SKIP
    """
    return pd.DataFrame(_TRIBUNALS, columns=["alias", "name", "type"])


def validate_tribunal(tribunal: str) -> bool:
    """Indica se ``tribunal`` é um alias válido (formato ``api_publica_xxx``)."""
    return tribunal in _ALIASES


def normalize_tribunal(tribunal: str) -> str:
    """Converte o nome curto do tribunal para o alias da API.

    Aceita tanto a forma curta (``"trf1"``, ``"tjsp"``) quanto a completa
    (``"api_publica_trf1"``).

    Examples:
        >>> normalize_tribunal("tjsp")
        'api_publica_tjsp'
        >>> normalize_tribunal("api_publica_trf1")
        'api_publica_trf1'
    """
    full_name = tribunal if tribunal.startswith("api_publica_") else f"api_publica_{tribunal.lower()}"
    if not validate_tribunal(full_name):
        raise ValueError(
            f"Invalid tribunal: {tribunal}. Use list_tribunals() to see available options."
        )
    return full_name
