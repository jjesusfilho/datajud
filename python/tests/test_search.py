import datetime as dt

import pytest

import datajud


def test_normalize_tribunal() -> None:
    assert datajud.normalize_tribunal("TJSP") == "api_publica_tjsp"
    assert datajud.normalize_tribunal("api_publica_trf1") == "api_publica_trf1"
    with pytest.raises(ValueError):
        datajud.normalize_tribunal("tjxx")
    assert len(datajud.list_tribunals()) == 88


def test_format_datajud_date() -> None:
    assert datajud.format_datajud_date("2020-01-31", "235959") == "20200131235959"
    assert datajud.format_datajud_date("20200131") == "20200131000000"
    assert datajud.format_datajud_date("20200131101010") == "20200131101010"
    assert datajud.format_datajud_date(dt.date(2020, 1, 31)) == "20200131000000"
    assert datajud.format_datajud_date(None) is None


def test_build_query() -> None:
    query = datajud.build_query(
        numeroProcesso="0000123-45.2020.4.03.6100",
        classe_codigo="1199",
        dataAjuizamento_start="2020-01-01",
        dataAjuizamento_end="2020-12-31",
    )
    assert query == {"bool": {"must": [
        {"match": {"numeroProcesso": "00001234520204036100"}},
        {"match": {"classe.codigo": "1199"}},
        {"range": {"dataAjuizamento": {"gte": "20200101000000", "lte": "20201231235959"}}},
    ]}}
    with pytest.raises(ValueError):
        datajud.build_query()
    with pytest.raises(TypeError):
        datajud.build_query(classe="1199")


def test_parse_and_extract() -> None:
    response = {"hits": {"hits": [{
        "_id": "a", "_score": 1.0,
        "_source": {
            "numeroProcesso": "1",
            "assuntos": [{"codigo": 10, "nome": "X"}, {"codigo": 11, "nome": "Y"}],
            "movimentos": [{"codigo": 26, "nome": "Distribuição", "dataHora": "2020-01-01",
                            "complementos": [{"nome": "sorteio"}]}],
        },
    }]}}
    df = datajud.parse_response(response)
    assert df.loc[0, "id"] == "a"
    assert len(datajud.extract_subjects(df)) == 2
    movs = datajud.extract_movements(df)
    assert movs.loc[0, "movimento_complemento"] == "sorteio"
    assert datajud.parse_response({"hits": {"hits": []}}).empty
