from xinguos_foco.prioridade import Aplicador, scope_do_pid


def proc_com(tmp_path, pid, conteudo):
    d = tmp_path / str(pid)
    d.mkdir(parents=True)
    (d / "cgroup").write_text(conteudo)
    return tmp_path


def test_scope_de_app_slice(tmp_path):
    proc = proc_com(tmp_path, 42, "0::/user.slice/user-1000.slice/user@1000.service/app.slice/app-org.kde.dolphin@a1b2.scope\n")
    assert scope_do_pid(42, proc) == "app-org.kde.dolphin@a1b2.scope"


def test_scope_none_para_session_slice_e_pid_inexistente(tmp_path):
    proc = proc_com(tmp_path, 7, "0::/user.slice/user-1000.slice/session-2.scope\n")
    assert scope_do_pid(7, proc) is None
    proc_com(tmp_path, 8, "0::/user.slice/user-1000.slice/user@1000.service/app.slice/xinguos-foco.service\n")
    assert scope_do_pid(8, tmp_path) is None
    assert scope_do_pid(999999, tmp_path) is None
    assert scope_do_pid(-1, tmp_path) is None


def test_aplicador_nao_repete_mesmo_peso():
    chamadas = []
    a = Aplicador(lambda cmd: chamadas.append(cmd) or 0)
    a.aplicar("app-x.scope", 500)
    a.aplicar("app-x.scope", 500)
    a.aplicar("app-x.scope", 100)
    assert chamadas == [
        ["systemctl", "--user", "set-property", "--runtime", "app-x.scope", "CPUWeight=500", "IOWeight=500"],
        ["systemctl", "--user", "set-property", "--runtime", "app-x.scope", "CPUWeight=100", "IOWeight=100"],
    ]


def test_aplicador_segue_quando_systemctl_falha():
    chamadas = []

    def falha(cmd):
        chamadas.append(cmd)
        if len(chamadas) == 2:
            raise OSError("sem systemctl")
        return 1

    a = Aplicador(falha)
    a.aplicar("app-x.scope", 500)   # retorno ≠ 0
    a.aplicar("app-x.scope", 500)   # tenta de novo (não ficou gravado) e explode
    a.aplicar("app-y.scope", 25)
    assert len(chamadas) == 3
