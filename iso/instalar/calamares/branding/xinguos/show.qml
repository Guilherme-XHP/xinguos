// Slides mostrados enquanto o XInguOS é instalado
import QtQuick
import calamares.slideshow 1.0

Presentation {
    id: apresentacao

    function proximo() {
        apresentacao.goToNextSlide()
    }

    Timer {
        interval: 9000
        running: apresentacao.activatedInCalamares
        repeat: true
        onTriggered: apresentacao.proximo()
    }

    Slide {
        Image {
            id: logo
            source: "logo.svg"
            width: 160
            height: 160
            sourceSize.width: 320
            sourceSize.height: 320
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 40
        }
        Text {
            anchors.top: logo.bottom
            anchors.topMargin: 24
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.8
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.pixelSize: 20
            text: "Instalando o XInguOS: Arch Linux + KDE Plasma, pronto pra jogar e trabalhar."
        }
    }
    Slide {
        Text {
            anchors.centerIn: parent
            width: parent.width * 0.8
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.pixelSize: 20
            text: "Atalhos do Windows: Win abre o menu, Win+R executa, Win+setas encaixam janelas, Win+T liga o autotile."
        }
    }
    Slide {
        Text {
            anchors.centerIn: parent
            width: parent.width * 0.8
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.pixelSize: 20
            text: "O app Foco mostra seu tempo de uso e dá prioridade ao app que você está usando."
        }
    }
    Slide {
        Text {
            anchors.centerIn: parent
            width: parent.width * 0.8
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.pixelSize: 20
            text: "No primeiro login, o Bem-vindo ao XInguOS instala seus apps, o Proton-GE e o Android SDK."
        }
    }

    function onActivate() { }
    function onLeave() { }
}
