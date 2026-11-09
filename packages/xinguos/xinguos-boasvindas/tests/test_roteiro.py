import subprocess

import pytest

from xinguos_boasvindas.catalogo import ITENS
from xinguos_boasvindas.roteiro import PASSOS_DE_USUARIO, roteiro

IDS = [i.id for i in ITENS]


def test_catalogo_na_ordem_do_spec():
    assert IDS == ["xinguos-apps", "vesktop", "zapzap", "spotify", "natron", "curseforge", "claude-code",
                   "claude-desktop", "android-sdk", "proton-ge", "protonup-qt", "impressao"]


def test_marcados_por_padrao():
    marcados = {i.id for i in ITENS if i.marcado}
    assert marcados == set(IDS) - {"claude-desktop", "impressao"}


def test_claude_desktop_desmarcado_com_aviso():
    cd = next(i for i in ITENS if i.id == "claude-desktop")
    assert not cd.marcado and "não oficial" in cd.aviso


def test_todo_item_tem_passo_e_o_roteiro_e_bash_valido(tmp_path):
    texto = roteiro(IDS)
    for i in ITENS:
        assert f'"{i.nome}"' in texto
    arq = tmp_path / "r.sh"
    arq.write_text(texto, encoding="utf-8")
    r = subprocess.run(["bash", "-n", str(arq)], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr


def test_passos_na_ordem_pedida():
    texto = roteiro(["spotify", "xinguos-apps"])
    assert texto.index('"Spotify"') < texto.index('"Apps do XInguOS')
    assert "Vesktop" not in texto


def test_id_desconhecido():
    with pytest.raises(ValueError):
        roteiro(["xinguos-apps", "nao-existe"])


def test_passos_de_usuario_sem_sudo():
    from xinguos_boasvindas.roteiro import PASSOS
    for i in PASSOS_DE_USUARIO:
        assert "sudo" not in PASSOS[i], i
    assert "--user" in PASSOS["vesktop"]
    assert "sudo pacman -S --needed --noconfirm xinguos-apps" in PASSOS["xinguos-apps"]


def test_roteiro_continua_depois_de_falha_e_lista_o_que_falhou(tmp_path):
    from xinguos_boasvindas import roteiro as r
    texto = r.montar([("Um", "false"), ("Dois", "echo segundo")])
    arq = tmp_path / "r.sh"
    arq.write_text(texto, encoding="utf-8")
    out = subprocess.run(["bash", str(arq)], capture_output=True, text=True)
    assert out.returncode == 1
    assert "segundo" in out.stdout
    assert "Não deu certo: Um" in out.stdout
