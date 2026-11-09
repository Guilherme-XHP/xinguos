// "Bem-vindo ao XInguOS" (spec 5.3). A logo, clicada 7 vezes, mostra o verdadeiro dono da distro.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: janela
    visible: true
    width: 640
    height: 620
    minimumWidth: 460
    minimumHeight: 420
    title: "Bem-vindo ao XInguOS"

    property var itens: []
    property var marcados: ({})
    property int cliques: 0
    property string avisoHw: ""
    property var sessao: ({ disponivel: false, padrao: "ultima", modo: "compativel" })
    readonly property var padroes: ["ultima", "desktop", "gaming"]
    readonly property var modos: ["compativel", "completo"]

    Component.onCompleted: {
        itens = boasvindas.itens()
        var m = {}
        for (var i = 0; i < itens.length; i++) m[itens[i].id] = itens[i].marcado
        marcados = m
        avisoHw = boasvindas.avisoHw()
        sessao = boasvindas.sessao()
    }

    function instalar() {
        var ids = []
        for (var i = 0; i < itens.length; i++)
            if (marcados[itens[i].id]) ids.push(itens[i].id)
        status.text = boasvindas.instalar(ids)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        RowLayout {
            spacing: 14
            Item {
                implicitWidth: 72
                implicitHeight: 72
                Image {
                    id: logo
                    anchors.fill: parent
                    source: boasvindas.logo()
                    sourceSize.width: 144
                    sourceSize.height: 144
                    fillMode: Image.PreserveAspectFit
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        janela.cliques += 1
                        if (janela.cliques >= 7) {
                            janela.cliques = 0
                            cachorro.open()
                        }
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Label {
                    text: "Bem-vindo ao XInguOS"
                    font.pointSize: 18
                    font.bold: true
                }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: "Marque o que quer instalar agora. Dá para voltar aqui quando quiser pelo menu de apps."
                }
            }
        }

        Label {
            visible: janela.avisoHw !== ""
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: "#d97706"
            text: "Placa de vídeo: " + janela.avisoHw
        }

        GridLayout {
            visible: janela.sessao.disponivel
            Layout.fillWidth: true
            columns: 2
            Label { text: "Ao ligar o PC, abrir:" }
            ComboBox {
                Layout.fillWidth: true
                model: ["A última sessão usada", "A Área de Trabalho (entra sem senha)", "O Gaming Mode (entra sem senha)"]
                currentIndex: Math.max(0, janela.padroes.indexOf(janela.sessao.padrao))
                onActivated: status.text = boasvindas.definirPadrao(janela.padroes[currentIndex])
            }
            Label { text: "Gaming Mode:" }
            ComboBox {
                Layout.fillWidth: true
                model: ["Compatível (KWin + Steam; seguro para GTX 10xx)", "Completo (gamescope, como no Steam Deck)"]
                currentIndex: Math.max(0, janela.modos.indexOf(janela.sessao.modo))
                onActivated: status.text = boasvindas.definirModo(janela.modos[currentIndex])
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: janela.itens
            delegate: CheckDelegate {
                required property var modelData
                width: ListView.view.width
                checked: modelData.marcado
                text: modelData.nome + " — " + modelData.descricao
                      + (modelData.aviso !== "" ? "  (" + modelData.aviso + ")" : "")
                onToggled: janela.marcados[modelData.id] = checked
            }
        }

        RowLayout {
            Layout.fillWidth: true
            CheckBox {
                text: "Mostrar ao iniciar"
                checked: boasvindas.mostrarAoIniciar()
                onToggled: boasvindas.definirMostrarAoIniciar(checked)
            }
            Label {
                id: status
                Layout.fillWidth: true
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
            }
            Button {
                text: "Instalar selecionados"
                icon.name: "run-install"
                onClicked: janela.instalar()
            }
        }
    }

    Dialog {
        id: cachorro
        title: "O verdadeiro dono do XInguOS"
        modal: true
        anchors.centerIn: parent
        width: Math.min(janela.width - 40, 520)
        standardButtons: Dialog.Close
        contentItem: ColumnLayout {
            Image {
                Layout.fillWidth: true
                Layout.preferredHeight: 360
                fillMode: Image.PreserveAspectFit
                autoTransform: true
                source: cachorro.visible ? boasvindas.cachorro() : ""
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: "Au au! 🐶"
            }
        }
    }
}
