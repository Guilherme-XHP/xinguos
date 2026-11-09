# XInguOS — Plano 5: `xinguos-foco` (prioridade + Bem-Estar)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Objetivo:**
- O app em foco e os apps marcados "sempre prioridade" ganham CPU e disco na frente; os de "segundo plano" ficam atrás.
- O tempo de uso de cada app é registrado localmente.
- Um painel "Foco" mostra hoje e a semana e deixa editar prioridades, limites diários e autotile por app.

**Arquitetura** (spec 7.2 + 7.2.1):

1. **Script do KWin** `xinguos-foco` (JS). A cada janela ativada, chama o daemon por D-Bus com `Foco(desktop, classe, pid)`.
2. **Daemon** `xinguos-foco`: Python, serviço de **usuário** do systemd, nome D-Bus `org.xinguos.Foco` no barramento de sessão. É dividido em módulos puros (testáveis sem D-Bus) e uma cola fina de D-Bus:
   - `config`: lista de prioridades, limites e autotile;
   - `banco`: SQLite;
   - `rastreador`: intervalos de foco e ociosidade;
   - `prioridade`: `/proc/<pid>/cgroup` → scope → `systemctl --user set-property`;
   - `limites`: quem estourou o limite hoje.
3. **Painel** `xinguos-foco-painel`: PySide6 + QML com três abas.
   - O módulo `dados` (consultas e gravação do TOML) é Python puro e testável.
   - O botão "Autotile: não" grava o `ignoreClass` do Krohnkite com `kwriteconfig6`.

**Stack:** Python 3 (`asyncio`, `sqlite3`, `tomllib`), `python-dbus-fast`, PySide6/QML, JS (script do KWin), pytest, node (teste do script do KWin), bats, systemd user units.

**Spec:** `docs/superpowers/specs/2026-11-08-xinguos-design.md` (7.2, 7.2.1, 6.4, 2.4). Depende dos Planos 2 e 4 já no main.

**Branch:** `plano5`, a partir do `main` depois do merge do `plano4`.

**Execução:** o Xingu delegou a revisão deste plano. O executor segue sem esperar; o Xingu revisa depois.

## Restrições globais

- Tudo dos planos anteriores:
  - shellcheck limpo;
  - LF;
  - commits em PT com `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`;
  - o CI é o ambiente de teste;
  - **mudou o conteúdo de um pacote publicado → sobe o `pkgrel`**.
- O código Python fica em `foco/` no repositório e é instalado em `/usr/lib/xinguos/foco/`. Os executáveis `/usr/bin/xinguos-foco` e `/usr/bin/xinguos-foco-painel` são wrappers `sh`: `exec env PYTHONPATH=/usr/lib/xinguos/foco python3 -m <módulo> "$@"`.
- **Dados:**
  - banco em `${XDG_DATA_HOME:-~/.local/share}/xinguos/foco.db`;
  - configuração do usuário em `${XDG_CONFIG_HOME:-~/.config}/xinguos/foco.toml`;
  - padrão do sistema em `/etc/xdg/xinguos/foco.toml`.
  - Os caminhos podem ser trocados por `XINGUOS_FOCO_DB` e `XINGUOS_FOCO_CONFIG` nos testes.
- **Pesos** (spec 7.2): app em foco = 500; "sempre prioridade" = 1000; normal = 100; "segundo plano" = 25. O mesmo valor vai para `CPUWeight` e `IOWeight`.
- **Ociosidade:** consulta a cada 30 s. Acima de 120 s parado, o intervalo é fechado em `agora - ocioso`. Os dados ficam guardados por 90 dias.
- **Nada sai do PC:** sem rede e sem telemetria.

## Foco da revisão

1. **App sem scope próprio** (pid no `session.slice`, processo morto, `/proc` sumiu): o daemon ignora e segue, sem cair (teste na Task 3).
2. **Banco corrompido:** é renomeado para `foco.db.corrompido-<data>` e um novo é criado; o daemon não cai (teste na Task 2).
3. **TOML do usuário inválido ou parcialmente preenchido:** usa o padrão no que faltar e avisa no log, sem cair (teste na Task 1).
4. **Foco trocando muito rápido ou para a mesma janela:** não duplica intervalos e não chama o `systemctl` à toa (teste na Task 3).
5. **Ociosidade que atravessa a meia-noite:** o intervalo é contado no dia em que aconteceu, e os totais do dia não ficam negativos (teste na Task 2).

---

### Task 1: `config` — ler e gravar `foco.toml`

**Arquivos:** `foco/xinguos_foco/__init__.py` (vazio), `foco/xinguos_foco/config.py`, `foco/tests/test_config.py`, `foco/foco.toml.padrao`.

**Interface:**
```python
@dataclass
class Config:
    sempre: set[str]            # [prioridades] sempre = [...]
    segundo_plano: set[str]     # [prioridades] segundo_plano = [...]
    limites_min: dict[str, int] # [limites] "<app>" = minutos
    sem_autotile: set[str]      # [autotile] nao = [...]

def carregar(sistema: Path, usuario: Path) -> tuple[Config, list[str]]  # (config, avisos)
def salvar(cfg: Config, usuario: Path) -> None   # escrita atômica (tmp + os.replace)
def peso(app: str, cfg: Config, em_foco: bool) -> int
```
- `carregar`: lê o arquivo do sistema e depois o do usuário. Cada **chave de topo** do usuário substitui a do sistema. Arquivo ausente vira vazio; TOML inválido também vira vazio, com um aviso `"foco.toml inválido: <erro>"`. Tipos errados (ex.: limite não inteiro) são descartados com aviso.
- `peso`: `sempre` → 1000; `segundo_plano` → 25 (mesmo em foco); em foco → 500; senão → 100.
- `salvar`: gera TOML à mão (listas de strings e inteiros), em ordem estável.
- O `foco.toml.padrao` traz `segundo_plano = ["org.qbittorrent.qBittorrent"]` e o resto vazio.

**Testes (pytest):**
- `test_usuario_substitui_chave_do_sistema`;
- `test_toml_invalido_vira_padrao_com_aviso`;
- `test_limite_com_tipo_errado_descartado_com_aviso`;
- `test_pesos_do_spec` (1000, 25 em foco, 500, 100);
- `test_salvar_e_carregar_ida_e_volta`.

No CI: `pip` não; use os pacotes do Arch (`python-pytest`, `python-dbus-fast`, `pyside6`) no `ci-setup.sh`. Novo passo no job `testes`: `python -m pytest -q foco/tests`.

- [ ] RED → implementar → GREEN → commit `feat(foco): config (foco.toml) e pesos de prioridade`.

### Task 2: `banco` — SQLite de intervalos

**Arquivos:** `foco/xinguos_foco/banco.py`, `foco/tests/test_banco.py`.

**Interface:**
```python
class Banco:
    def __init__(self, caminho: Path, agora: Callable[[], float] = time.time): ...
    # abre ou cria; se estiver corrompido, renomeia para foco.db.corrompido-AAAAMMDD-HHMMSS e cria um novo
    def registrar(self, app: str, inicio: float, fim: float) -> None   # ignora fim <= inicio
    def totais_do_dia(self, dia: date) -> list[tuple[str, int]]         # (app, segundos), maior→menor, só a parte dentro do dia (fuso local)
    def totais_por_dia(self, ate: date, dias: int = 7) -> dict[date, int]
    def purgar(self, manter_dias: int = 90) -> int                      # apaga intervalos que terminaram antes do corte
```
- Tabela: `intervalos(app TEXT NOT NULL, inicio REAL NOT NULL, fim REAL NOT NULL)`, índice em `fim`.
- O recorte por dia usa `max(inicio, começo_do_dia)` e `min(fim, fim_do_dia)`.

**Testes:**
- `test_banco_corrompido_e_renomeado` (escreve lixo no arquivo e abre);
- `test_intervalo_que_atravessa_meia_noite_divide_entre_os_dias`;
- `test_totais_ordenados_do_maior_para_o_menor`;
- `test_purgar_90_dias`;
- `test_intervalo_vazio_ou_invertido_ignorado`.

- [ ] RED → implementar → GREEN → commit `feat(foco): banco de intervalos de uso`.

### Task 3: `rastreador` + `prioridade`

**Arquivos:** `foco/xinguos_foco/rastreador.py`, `foco/xinguos_foco/prioridade.py`, testes `foco/tests/test_rastreador.py` e `foco/tests/test_prioridade.py`.

**Interface:**
```python
class Rastreador:  # máquina de estados pura
    def __init__(self, banco: Banco): ...
    def foco(self, app: str, agora: float) -> None        # fecha o intervalo atual (se for outro app) e abre um novo
    def ocioso(self, segundos: float, agora: float) -> None  # >120: fecha em agora-segundos e pausa; <=120 com pausa: reabre o último app
    def encerrar(self, agora: float) -> None

def scope_do_pid(pid: int, proc: Path = Path("/proc")) -> str | None
    # lê <proc>/<pid>/cgroup ("0::/.../app.slice/app-x-123.scope") → "app-x-123.scope";
    # None se não terminar em .scope, se não estiver sob app.slice, ou se o arquivo não existir

class Aplicador:
    def __init__(self, executar: Callable[[list[str]], int]): ...
    def aplicar(self, unit: str, peso: int) -> None
    # só chama se o peso daquela unit mudou: ["systemctl","--user","set-property","--runtime",unit,f"CPUWeight={peso}",f"IOWeight={peso}"]
    # erro do executar → registra e segue
```

**Testes:**
- `test_foco_no_mesmo_app_nao_duplica_intervalo`;
- `test_trocar_de_app_fecha_o_anterior`;
- `test_ocioso_fecha_em_agora_menos_ocioso_e_reabre_ao_voltar`;
- `test_scope_de_app_slice`;
- `test_scope_none_para_session_slice_e_pid_inexistente`;
- `test_aplicador_nao_repete_mesmo_peso`;
- `test_aplicador_segue_quando_systemctl_falha`.

- [ ] RED → implementar → GREEN → commit `feat(foco): rastreador de foco/ociosidade e aplicação de pesos`.

### Task 4: `limites` + serviço D-Bus

**Arquivos:**
- `foco/xinguos_foco/limites.py`, `foco/xinguos_foco/servico.py`, `foco/xinguos_foco/__main__.py`;
- testes `foco/tests/test_limites.py` e `foco/tests/test_servico_dbus.py`.

**Interface:**
- `limites_estourados(totais: list[tuple[str,int]], limites_min: dict[str,int], ja_avisados: set[str]) -> list[str]`.
- **Serviço `org.xinguos.Foco`**, objeto `/org/xinguos/Foco`, interface `org.xinguos.Foco` (dbus-fast `ServiceInterface`). Métodos:
  - `Foco(desktop: s, classe: s, pid: s)`:
    - `app = desktop or classe`;
    - atualiza o rastreador;
    - aplica os pesos: a unit em foco ganha `peso(app, em_foco=True)`, e a unit anterior volta para `peso(app_anterior, em_foco=False)`;
  - `Recarregar()`: relê o config;
  - `Totais() -> s`: JSON dos totais de hoje, usado no teste e no painel.
- **Tarefa periódica (30 s):**
  - `GetSessionIdleTime` (`org.freedesktop.ScreenSaver`). Se não existir, trata como 0;
  - rastreador `ocioso`;
  - limites → `org.freedesktop.Notifications.Notify("XInguOS Foco", 0, "dialog-information", "Limite de <app>", "Você usou <app> por <N> min hoje (limite: <L> min).", [], {}, 10000)`, uma vez por app por dia;
  - `purgar` uma vez por dia;
  - recarrega o config se o mtime mudar.
- `__main__`: logging no stderr (vai para o journal) e `asyncio.run`.

**Testes:**
- `test_limites_*`: estourou, não estourou, já avisado;
- `test_servico_dbus` (marcado `dbus`; o CI roda com `dbus-run-session -- python -m pytest -q foco/tests -m dbus`):
  1. sobe o serviço num barramento de sessão próprio, com banco temporário;
  2. chama `Foco("org.kde.dolphin","dolphin","999999")` e, 1 s depois, `Foco("firefox","firefox","999999")`;
  3. espera que `Totais()` contenha `org.kde.dolphin`;
  4. pid inexistente → nada quebra.

- [ ] RED → implementar → GREEN → commit `feat(foco): serviço D-Bus org.xinguos.Foco com limites e ociosidade`.

### Task 5: script do KWin

**Arquivos:**
- `foco/kwin/xinguos-foco/metadata.json`: `KPackageStructure: "KWin/Script"`, `KPlugin.Id: "xinguos-foco"`, `X-Plasma-API: "javascript"`, `X-Plasma-MainScript: "code/main.js"`;
- `foco/kwin/xinguos-foco/contents/code/main.js`;
- `foco/tests/kwin.test.js` (node, sem dependências).

**Interface do `main.js`:**
- Conecta `workspace.windowActivated`.
- Ignora janela nula ou que não seja `normalWindow`.
- Chama `callDBus("org.xinguos.Foco", "/org/xinguos/Foco", "org.xinguos.Foco", "Foco", desktopFileName || "", resourceClass || "", String(pid))`.

**Teste** (`node foco/tests/kwin.test.js`): carrega o `main.js` num `vm` com `workspace`/`callDBus` falsos, dispara `windowActivated` com:
- uma janela normal → 1 chamada com os 3 argumentos;
- `null` e uma janela `normalWindow:false` → nenhuma chamada.

Sai com 1 se falhar. Passo novo no job `testes`.

- [ ] RED → implementar → GREEN → commit `feat(foco): script do KWin que avisa o foco ao daemon`.

### Task 6: painel "Foco"

**Arquivos:**
- `foco/xinguos_foco_painel/__init__.py`, `dados.py`, `__main__.py`, `Main.qml`;
- `foco/tests/test_painel_dados.py`.

**Interface do `dados.py`:**
```python
def resumo_hoje(banco: Banco, hoje: date) -> list[dict]       # [{"app","nome","icone","segundos","texto"}]; texto "1 h 05 min"/"12 min"/"<1 min"
def resumo_semana(banco: Banco, hoje: date) -> list[dict]     # 7 itens {"dia":"seg 03/11","segundos","texto"}, do mais antigo ao hoje
def apps_conhecidos(banco: Banco, cfg: Config) -> list[dict]  # {"app","nome","prioridade":"sempre|normal|segundo_plano","limite_min":int|None,"autotile":bool}
def aplicar_mudancas(cfg: Config, mudancas: list[dict], usuario: Path, escrever_kwin: Callable[[list[str]],int]) -> None
    # atualiza o cfg, salva; recalcula o ignoreClass do Krohnkite = padrão do Plano 4 + cfg.sem_autotile e grava com
    # ["kwriteconfig6","--file","kwinrc","--group","Script-krohnkite","--key","ignoreClass",<lista>]
def nome_e_icone(app: str, dirs: list[Path]) -> tuple[str, str]  # do .desktop (Name[pt_BR] > Name; Icon); fallback (app, "application-x-executable")
```
- **`Main.qml`:**
  - `TabBar` com "Hoje", "Semana" e "Prioridades e limites";
  - listas com barras proporcionais;
  - na 3ª aba, um `ComboBox` (Sempre prioridade / Normal / Segundo plano), um `SpinBox` de limite (0 = sem limite), um `Switch` "Autotile" e o botão "Salvar". Salvar chama `aplicar_mudancas` e depois `Recarregar()` no D-Bus;
  - aviso "Autotile vale a partir do próximo login".
- `__main__.py` liga o QML ao `dados` por um `QObject` com `Slot`s, e o `app.desktop` aparece como "Foco: tempo de uso e prioridades".

**Testes:**
- `test_texto_de_tempo`;
- `test_semana_tem_7_dias_terminando_hoje`;
- `test_nome_do_desktop_em_pt_br`;
- `test_aplicar_mudancas_salva_toml_e_ignoreclass` (`escrever_kwin` falso registra a lista; o `ignoreClass` contém o padrão + o app marcado);
- `test_qml_carrega`: `QT_QPA_PLATFORM=offscreen`, `QQmlApplicationEngine` carrega o `Main.qml` sem erros.

- [ ] RED → implementar → GREEN → commit `feat(foco): painel Foco (hoje, semana, prioridades e limites)`.

### Task 7: pacotes e integração

**Arquivos:**
- `packages/xinguos/xinguos-foco/PKGBUILD`, `xinguos-foco.install`, `xinguos-foco.service`, `org.xinguos.foco.desktop`, `kwinrc`;
- modificar `packages/xinguos/xinguos-base/` (drop-in `90-xinguos-delegate.conf`, `pkgrel=2`);
- modificar `packages/xinguos/xinguos-desktop/PKGBUILD` (`depends += xinguos-foco`, `pkgrel=4`);
- modificar `packages/ordem.txt`, `tests/base.bats`, `tests/desktop.bats`, `tests/foco.bats`.

**Interface:**
- **`xinguos-foco`:**
  - `depends=(python python-dbus-fast pyside6 systemd kwin)`;
  - instala `foco/xinguos_foco*` em `/usr/lib/xinguos/foco/`, os dois wrappers em `/usr/bin/`, o script do KWin em `/usr/share/kwin/scripts/xinguos-foco/` e `foco.toml.padrao` em `/etc/xdg/xinguos/foco.toml` (com `backup=`);
  - `/etc/xdg/kwinrc` com `[Plugins] xinguos-focoEnabled=true`. É padrão do sistema; o `kwinrc` do usuário só tem as chaves do Krohnkite, então a cascata do KConfig mantém essa chave;
  - `/usr/lib/systemd/user/xinguos-foco.service`: `PartOf/After=graphical-session.target`, `ExecStart=/usr/bin/xinguos-foco`, `Restart=on-failure`, `WantedBy=graphical-session.target`;
  - `.install`: `systemctl --global enable xinguos-foco.service || true`.
- **`xinguos-base` 0.1.0-2:** `/usr/lib/systemd/system/user@.service.d/90-xinguos-delegate.conf` → `[Service]` / `Delegate=cpu cpuset io memory pids`.
- **`xinguos-desktop` 0.1.0-4:** `depends` ganha `xinguos-foco`.
- **`ordem.txt`:** `xinguos/xinguos-foco` antes de `xinguos/xinguos-desktop`.

**Testes:**
- `foco.bats`:
  - `@test "unidade do usuário é válida"`: `systemd-analyze verify --user` no `.service`, ou `systemd-analyze verify` com `SYSTEMD_UNIT_PATH`;
  - `@test "kwinrc do sistema liga o script"`;
  - `@test "wrappers usam PYTHONPATH /usr/lib/xinguos/foco"`.
- `base.bats`: `@test "user@ delega io"`.
- `desktop.bats`: `xinguos-desktop` depende de `xinguos-foco`.

Depois, dispatch: `build` verde com os pacotes na release, e o smoke ganha:
- `pacman -S --noconfirm xinguos-foco`;
- `XINGUOS_FOCO_DB=/tmp/f.db dbus-run-session -- sh -c 'xinguos-foco & sleep 3; busctl --user call org.xinguos.Foco /org/xinguos/Foco org.xinguos.Foco Totais'`, que precisa responder.

- [ ] RED → implementar → GREEN → commit `feat(foco): pacote xinguos-foco; base delega io; desktop depende do foco`.

### Task 8: ISO de teste com o foco

- [ ] Não precisa mexer no `pacotes.txt`: o `xinguos-desktop` já puxa o `xinguos-foco`.
- [ ] Teste no `build-iso.bats`: nenhum novo.
- [ ] Dispatch com `iso=true`, depois baixe para `D:\isos\Linux` e rode `sha256sum -c`.

### Task 9: [MANUAL — Xingu] conferir no live

| Faça | Esperado |
|---|---|
| `systemctl --user status xinguos-foco` | `active (running)` |
| Use o Dolphin e o Firefox por uns minutos e abra "Foco" no launcher | aba Hoje com os dois e o tempo de cada um |
| Com o Firefox em foco, rode `cat /sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/app.slice/app-*firefox*.scope/cpu.weight` | `500` |
| Na aba Prioridades, Firefox em "Segundo plano" + Salvar; foque o Firefox | `cpu.weight` = `25` |
| Limite de 1 min no Firefox, espere uns 2 min usando | aparece a notificação "Limite de Firefox" |
