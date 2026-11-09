from xinguos_foco.limites import limites_estourados


def test_limites_estourou():
    assert limites_estourados([("firefox", 3600), ("steam", 60)], {"firefox": 60}, set()) == ["firefox"]


def test_limites_nao_estourou():
    assert limites_estourados([("firefox", 3599)], {"firefox": 60, "steam": 10}, set()) == []


def test_limites_ja_avisado():
    assert limites_estourados([("firefox", 7200)], {"firefox": 60}, {"firefox"}) == []
