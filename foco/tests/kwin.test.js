// node foco/tests/kwin.test.js — roda o main.js do script do KWin com workspace/callDBus falsos
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const codigo = fs.readFileSync(path.join(__dirname, "..", "kwin", "xinguos-foco", "contents", "code", "main.js"), "utf8");
const chamadas = [];
const ouvintes = [];
const contexto = {
  workspace: { windowActivated: { connect: (f) => ouvintes.push(f) } },
  callDBus: (...args) => chamadas.push(args),
  print: () => {},
};
vm.createContext(contexto);
vm.runInContext(codigo, contexto);

let falhas = 0;
function confere(nome, cond) {
  console.log((cond ? "ok - " : "not ok - ") + nome);
  if (!cond) falhas++;
}

confere("conecta workspace.windowActivated", ouvintes.length === 1);
const ativar = (w) => ouvintes.forEach((f) => f(w));

ativar({ normalWindow: true, desktopFileName: "org.kde.dolphin", resourceClass: "dolphin", pid: 1234 });
confere("janela normal gera 1 chamada", chamadas.length === 1);
confere("chamada com destino e os 3 argumentos",
  JSON.stringify(chamadas[0]) === JSON.stringify(["org.xinguos.Foco", "/org/xinguos/Foco", "org.xinguos.Foco", "Foco", "org.kde.dolphin", "dolphin", "1234"]));

ativar(null);
ativar({ normalWindow: false, desktopFileName: "plasmashell", resourceClass: "plasmashell", pid: 1 });
confere("null e janela não normal são ignoradas", chamadas.length === 1);

ativar({ normalWindow: true, desktopFileName: "", resourceClass: undefined, pid: undefined });
confere("campos ausentes viram texto vazio", JSON.stringify(chamadas[1].slice(4)) === JSON.stringify(["", "", ""]));

process.exit(falhas ? 1 : 0);
