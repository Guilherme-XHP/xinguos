from xinguos_boasvindas.estado import aviso_hw, ja_visto, marcar_visto


def test_visto(tmp_path):
    d = tmp_path / "state" / "xinguos"
    assert not ja_visto(d)
    marcar_visto(d)
    assert ja_visto(d)
    marcar_visto(d)
    assert ja_visto(d)


def test_aviso_hw():
    assert aviso_hw("perfil=nvidia-580xx\npacotes=a b\ngaming=compativel\naviso=\n") == ""
    assert aviso_hw("perfil=desconhecida\naviso=nenhuma GPU reconhecida\n") == "nenhuma GPU reconhecida"
    assert aviso_hw("") == ""
