import SwiftUI
import SolicitacoesCore

/// Janela de Ajustes (⌘,)
struct Ajustes: View {
    @EnvironmentObject var m: Modelo

    var body: some View {
        TabView {
            Geral().tabItem { Label("Geral", systemImage: "gearshape") }
            Prazos().tabItem { Label("Prazos", systemImage: "calendar.badge.clock") }
            DadosEBackup().tabItem { Label("Dados", systemImage: "externaldrive") }
        }
        .frame(width: 560, height: 520)
    }
}

private struct Geral: View {
    @EnvironmentObject var m: Modelo
    var body: some View {
        Form {
            TextField("Nome da clínica / consultório", text: $m.dados.config.nomeClinica)
            Text("Aparece na barra lateral e na ficha impressa.").font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}

private struct Prazos: View {
    @EnvironmentObject var m: Modelo
    @State var feriados = ""

    var body: some View {
        Form {
            Section {
                ForEach(Regras.tipos) { t in
                    TextField(t.nome, value: Binding(
                        get: { m.dados.config.prazos[t.id] ?? Regras.prazosPadrao[t.id] ?? 10 },
                        set: { m.dados.config.prazos[t.id] = max(0, $0) }), format: .number)
                }
                Button("Voltar aos valores padrão") { m.dados.config.prazos = Regras.prazosPadrao }
            } header: {
                Text("Prazo de resposta em dias úteis")
            } footer: {
                Text("Usados para calcular a data limite a partir do envio à operadora. Os valores iniciais seguem os prazos de garantia de atendimento da ANS (RN 566/2022): confira a norma vigente e o contrato de cada operadora. Urgência/emergência: imediato. Também pode ser alterado em cada solicitação.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                TextEditor(text: $feriados).font(.body.monospacedDigit()).frame(minHeight: 70)
                HStack {
                    Spacer()
                    Button("Salvar feriados") {
                        let lidos = feriados.split(whereSeparator: \.isNewline).compactMap { Datas.deTexto(String($0)) }
                        m.dados.config.feriadosExtras = Array(Set(lidos)).sorted()
                        feriados = m.dados.config.feriadosExtras.map(Datas.formatar).joined(separator: "\n")
                        m.mostrarAviso("\(lidos.count) feriado(s) local(is) salvo(s).")
                    }
                }
            } header: {
                Text("Feriados locais")
            } footer: {
                Text("Municipais e estaduais, um por linha (DD/MM/AAAA). Os feriados nacionais já são considerados.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { feriados = m.dados.config.feriadosExtras.map(Datas.formatar).joined(separator: "\n") }
    }
}

private struct DadosEBackup: View {
    @EnvironmentObject var m: Modelo
    var body: some View {
        Form {
            Section {
                LabeledContent("Pasta") {
                    Text(m.pasta.path).textSelection(.enabled).lineLimit(3).truncationMode(.middle)
                }
                HStack {
                    Button("Mostrar no Finder") { m.abrirPasta() }
                    Button("Trocar pasta…") { m.trocarPasta() }
                }
            } header: {
                Text("Onde ficam os dados")
            } footer: {
                Text("Tudo fica neste Mac: dados.json, a pasta anexos e uma cópia automática por dia em backups (as 30 mais recentes). Para usar em mais de um Mac, escolha uma pasta no iCloud Drive ou Dropbox e evite editar nos dois ao mesmo tempo: se outro Mac gravar, o app avisa e recarrega em vez de sobrescrever.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Backup") {
                HStack {
                    Button("Exportar backup…") { m.exportarBackup() }
                    Button("Importar backup…") { m.importarBackup() }
                }
            }
            Section {
                LabeledContent("Versão", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
            }
        }
        .formStyle(.grouped)
    }
}
