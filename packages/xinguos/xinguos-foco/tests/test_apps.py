from xinguos_foco.apps import nome_e_icone


def test_nome_do_desktop_em_pt_br(tmp_path):
    (tmp_path / "org.kde.dolphin.desktop").write_text(
        "[Desktop Entry]\nName=Dolphin\nName[pt_BR]=Dolphin (arquivos)\nIcon=system-file-manager\n"
        "[Desktop Action x]\nName[pt_BR]=Outra coisa\n", encoding="utf-8")
    assert nome_e_icone("org.kde.dolphin", [tmp_path]) == ("Dolphin (arquivos)", "system-file-manager")


def test_nome_sem_traducao_e_fallback(tmp_path):
    (tmp_path / "steam.desktop").write_text("[Desktop Entry]\nName=Steam\nIcon=steam\n", encoding="utf-8")
    assert nome_e_icone("steam", [tmp_path / "nao", tmp_path]) == ("Steam", "steam")
    assert nome_e_icone("sumiu", [tmp_path]) == ("sumiu", "application-x-executable")
