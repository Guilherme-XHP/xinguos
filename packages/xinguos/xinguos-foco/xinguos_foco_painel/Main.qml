// Painel "Foco" do XInguOS: tempo de uso de hoje e da semana, prioridades, limites e autotile por app.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: janela
    visible: true
    width: 680
    height: 560
    minimumWidth: 480
    minimumHeight: 360
    title: "Foco"

    property var hoje: []
    property var semana: []
    property var apps: []
    property var mudancas: ({})
    property string diaEscolhido: ""
    property var appsDoDia: []
    readonly property var chaves: ["sempre", "normal", "segundo_plano"]

    function total(lista) {
        var s = 0
        for (var i = 0; i < lista.length; i++) s += lista[i].segundos
        return s
    }
    function maior(lista) {
        var m = 1
        for (var i = 0; i < lista.length; i++) m = Math.max(m, lista[i].segundos)
        return m
    }
    function atualizarUso() {
        hoje = foco.hoje()
        semana = foco.semana()
        if (diaEscolhido !== "") appsDoDia = foco.dia(diaEscolhido)
    }
    function abrirDia(data) {
        diaEscolhido = (diaEscolhido === data) ? "" : data
        appsDoDia = diaEscolhido === "" ? [] : foco.dia(diaEscolhido)
    }
    function atualizar() {
        atualizarUso()
        apps = foco.apps()
        mudancas = ({})
    }
    function marcar(a, campo, valor) {
        var m = mudancas[a.app] || { app: a.app, prioridade: a.prioridade, limite_min: a.limite_min || 0, autotile: a.autotile }
        m[campo] = valor
        mudancas[a.app] = m
        aviso.text = "Mudanças não salvas."
    }
    function salvar() {
        var lista = []
        for (var k in mudancas) lista.push(mudancas[k])
        aviso.text = lista.length ? foco.salvar(lista) : "Nada para salvar."
        atualizar()
    }

    Component.onCompleted: atualizar()

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: janela.atualizarUso()
    }

    SystemPalette { id: cores }

    component Barra: RowLayout {
        property string icone: ""
        property string rotulo: ""
        property string texto: ""
        property real fracao: 0
        spacing: 8
        SystemPalette { id: coresBarra }
        ToolButton {
            visible: icone !== ""
            icon.name: icone
            icon.width: 22
            icon.height: 22
            focusPolicy: Qt.NoFocus
            hoverEnabled: false
            Layout.preferredWidth: 32
        }
        Label {
            text: rotulo
            elide: Text.ElideRight
            Layout.preferredWidth: 190
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 10
            radius: 5
            color: coresBarra.midlight
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, fracao))
                height: parent.height
                radius: 5
                color: coresBarra.highlight
            }
        }
        Label {
            text: texto
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 90
        }
    }

    header: TabBar {
        id: abas
        TabButton { text: "Hoje" }
        TabButton { text: "Semana" }
        TabButton { text: "Prioridades e limites" }
    }

    StackLayout {
        anchors.fill: parent
        anchors.margins: 12
        currentIndex: abas.currentIndex

        ColumnLayout {
            spacing: 10
            Label {
                text: janela.hoje.length ? "Hoje: " + foco.texto(janela.total(janela.hoje)) + " de uso" : "Nada registrado hoje ainda."
                font.bold: true
            }
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: janela.hoje
                delegate: Barra {
                    width: ListView.view.width
                    icone: modelData.icone
                    rotulo: modelData.nome
                    texto: modelData.texto
                    fracao: modelData.segundos / janela.maior(janela.hoje)
                }
            }
        }

        ColumnLayout {
            spacing: 10
            Label {
                text: "Últimos 7 dias: " + foco.texto(janela.total(janela.semana))
                font.bold: true
            }
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: janela.semana
                delegate: ItemDelegate {
                    width: ListView.view.width
                    highlighted: modelData.data === janela.diaEscolhido
                    onClicked: janela.abrirDia(modelData.data)
                    contentItem: Barra {
                        rotulo: modelData.dia
                        texto: modelData.texto
                        fracao: modelData.segundos / janela.maior(janela.semana)
                    }
                }
            }
            Label {
                text: janela.diaEscolhido === "" ? "Clique num dia para ver os apps dele." : "Apps do dia:"
                opacity: janela.diaEscolhido === "" ? 0.7 : 1
                font.bold: janela.diaEscolhido !== ""
            }
            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: janela.diaEscolhido === "" ? 0 : Math.min(contentHeight, 200)
                visible: janela.diaEscolhido !== ""
                clip: true
                spacing: 6
                model: janela.appsDoDia
                delegate: Barra {
                    width: ListView.view.width
                    icone: modelData.icone
                    rotulo: modelData.nome
                    texto: modelData.texto
                    fracao: modelData.segundos / janela.maior(janela.appsDoDia)
                }
            }
        }

        ColumnLayout {
            spacing: 8
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "Prioridade de CPU e disco, limite diário (aviso) e autotile de cada app."
                      + (janela.apps.length ? "" : " Os apps aparecem aqui depois de usados.")
            }
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: janela.apps
                delegate: RowLayout {
                    required property var modelData
                    width: ListView.view.width
                    spacing: 8
                    Label {
                        text: modelData.nome
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    ComboBox {
                        model: ["Sempre prioridade", "Normal", "Segundo plano"]
                        currentIndex: Math.max(0, janela.chaves.indexOf(modelData.prioridade))
                        Layout.preferredWidth: 170
                        onActivated: janela.marcar(modelData, "prioridade", janela.chaves[currentIndex])
                    }
                    SpinBox {
                        from: 0
                        to: 1440
                        stepSize: 15
                        editable: true
                        value: modelData.limite_min || 0
                        Layout.preferredWidth: 140
                        textFromValue: function(v) { return v === 0 ? "sem limite" : v + " min" }
                        valueFromText: function(t) { var n = parseInt(t); return isNaN(n) ? 0 : n }
                        onValueModified: janela.marcar(modelData, "limite_min", value)
                    }
                    Switch {
                        text: "Autotile"
                        checked: modelData.autotile
                        onToggled: janela.marcar(modelData, "autotile", checked)
                    }
                }
            }
            Label {
                text: "Autotile vale a partir do próximo login."
                opacity: 0.7
            }
            RowLayout {
                Layout.fillWidth: true
                Label {
                    id: aviso
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Button {
                    text: "Salvar"
                    icon.name: "document-save"
                    onClicked: janela.salvar()
                }
            }
        }
    }
}
