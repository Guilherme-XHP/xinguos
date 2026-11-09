from xinguos_foco.config import Config, carregar, peso, salvar


def escrever(p, texto):
    p.write_text(texto, encoding="utf-8")
    return p


def test_usuario_substitui_chave_do_sistema(tmp_path):
    sis = escrever(tmp_path / "sis.toml", '[prioridades]\nsempre = ["steam"]\nsegundo_plano = ["qbit"]\n[limites]\n"firefox" = 60\n')
    usu = escrever(tmp_path / "usu.toml", '[prioridades]\nsempre = ["blender"]\n')
    cfg, avisos = carregar(sis, usu)
    assert avisos == []
    # a chave de topo [prioridades] do usuário substitui a do sistema inteira
    assert cfg.sempre == {"blender"}
    assert cfg.segundo_plano == set()
    # o que o usuário não definiu vem do sistema
    assert cfg.limites_min == {"firefox": 60}


def test_arquivos_ausentes_viram_vazio(tmp_path):
    cfg, avisos = carregar(tmp_path / "nao", tmp_path / "existe")
    assert cfg == Config(set(), set(), {}, set())
    assert avisos == []


def test_toml_invalido_vira_padrao_com_aviso(tmp_path):
    sis = escrever(tmp_path / "sis.toml", '[prioridades]\nsegundo_plano = ["qbit"]\n')
    usu = escrever(tmp_path / "usu.toml", "isso = não é toml [[[\n")
    cfg, avisos = carregar(sis, usu)
    assert cfg.segundo_plano == {"qbit"}
    assert len(avisos) == 1 and avisos[0].startswith("foco.toml inválido:")


def test_limite_com_tipo_errado_descartado_com_aviso(tmp_path):
    usu = escrever(tmp_path / "usu.toml", '[limites]\n"firefox" = "muito"\n"steam" = 90\n"zero" = -5\n[prioridades]\nsempre = "steam"\n')
    cfg, avisos = carregar(tmp_path / "nao", usu)
    assert cfg.limites_min == {"steam": 90}
    assert cfg.sempre == set()
    assert len(avisos) == 3


def test_pesos_do_spec():
    cfg = Config(sempre={"steam"}, segundo_plano={"qbit"}, limites_min={}, sem_autotile=set())
    assert peso("steam", cfg, em_foco=False) == 1000
    assert peso("qbit", cfg, em_foco=True) == 25
    assert peso("firefox", cfg, em_foco=True) == 500
    assert peso("firefox", cfg, em_foco=False) == 100


def test_salvar_e_carregar_ida_e_volta(tmp_path):
    cfg = Config(
        sempre={"steam", "org.kde.kdenlive"},
        segundo_plano={"org.qbittorrent.qBittorrent"},
        limites_min={"firefox": 60, 'app "esquisito"': 5},
        sem_autotile={"blender"},
    )
    usu = tmp_path / "sub" / "foco.toml"
    salvar(cfg, usu)
    lido, avisos = carregar(tmp_path / "nao", usu)
    assert avisos == []
    assert lido == cfg
    assert not list(usu.parent.glob("*.tmp"))


def test_padrao_do_sistema_e_valido(tmp_path):
    from pathlib import Path
    padrao = Path(__file__).resolve().parents[1] / "foco.toml.padrao"
    cfg, avisos = carregar(padrao, tmp_path / "nao")
    assert avisos == []
    assert cfg.segundo_plano == {"org.qbittorrent.qBittorrent"}
    assert cfg.sempre == set() and cfg.limites_min == {} and cfg.sem_autotile == set()
