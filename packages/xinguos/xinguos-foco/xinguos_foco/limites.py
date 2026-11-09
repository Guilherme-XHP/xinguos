"""Limites diários: quem passou do limite hoje e ainda não foi avisado."""


def limites_estourados(totais: list[tuple[str, int]], limites_min: dict[str, int], ja_avisados: set[str]) -> list[str]:
    return [app for app, segundos in totais
            if app in limites_min and app not in ja_avisados and segundos >= limites_min[app] * 60]
