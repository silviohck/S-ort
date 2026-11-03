import SwiftUI
import SolicitacoesCore

// MARK: Pacientes

struct Pacientes: View {
    @EnvironmentObject var m: Modelo
    @State var busca = ""
    @State var selecao = Set<String>()
    @State var editando: Paciente?

    var body: some View {
        let q = Regras.normalizar(busca)
        let lista = m.pacientesOrdenados.filter {
            q.isEmpty || Regras.normalizar([$0.nome, $0.cpf, $0.carteirinha, $0.telefone].joined(separator: " ")).contains(q)
        }
        var abertas: [String: Int] = [:]
        for s in m.dados.solicitacoes where !Regras.status(s.status).final { abertas[s.pacienteId, default: 0] += 1 }

        return Group {
            if lista.isEmpty {
                Vazio(titulo: m.dados.pacientes.isEmpty ? "Nenhum paciente cadastrado" : "Nenhum paciente encontrado",
                      detalhe: m.dados.pacientes.isEmpty ? "Clique em \"Novo paciente\" para cadastrar." : "Tente outro nome, CPF ou carteirinha.",
                      icone: "person.2")
            } else {
                Table(lista, selection: $selecao) {
                    TableColumn("Nome") { p in Text(p.nome).fontWeight(.medium) }.width(min: 160, ideal: 220)
                    TableColumn("CPF") { p in Text(p.cpf).monospacedDigit() }.width(min: 118, ideal: 124)
                    TableColumn("Nascimento") { p in Text(Datas.formatar(p.nascimento)).monospacedDigit() }.width(min: 84, ideal: 90)
                    TableColumn("Telefone") { p in Text(p.telefone) }.width(min: 110, ideal: 120)
                    TableColumn("Convênio") { p in Text(m.convenio(p.convenioId)?.nome ?? "") }.width(min: 80, ideal: 120)
                    TableColumn("Carteirinha") { p in Text(p.carteirinha).monospacedDigit() }.width(min: 90, ideal: 130)
                    TableColumn("Em aberto") { p in Text(abertas[p.id].map(String.init) ?? "") }.width(min: 60, ideal: 70)
                }
                .contextMenu(forSelectionType: String.self) { ids in
                    if let id = ids.first, let p = m.paciente(id) {
                        Button("Editar…") { editando = p }
                        Button("Nova solicitação") { m.novaSolicitacao(pacienteId: id) }
                        Button("Ver solicitações") { m.irParaLista { $0.status = "todas"; $0.pacienteId = id } }
                        Divider()
                        Button("Excluir…", role: .destructive) { m.excluirPaciente(id) }
                    }
                } primaryAction: { ids in
                    if let id = ids.first { editando = m.paciente(id) }
                }
            }
        }
        .searchable(text: $busca, placement: .toolbar, prompt: "Nome, CPF, carteirinha ou telefone")
        .navigationTitle("Pacientes")
        .navigationSubtitle("\(m.dados.pacientes.count) cadastrado(s)")
        .toolbar {
            ToolbarItem {
                Button { editando = Paciente() } label: { Label("Novo paciente", systemImage: "person.badge.plus") }
                    .help("Novo paciente (⇧⌘N)")
            }
        }
        .sheet(item: $editando) { p in EditorPaciente(paciente: p) { m.salvarPaciente($0) }.environmentObject(m) }
        .onReceive(NotificationCenter.default.publisher(for: .novoPaciente)) { _ in editando = Paciente() }
    }
}

struct EditorPaciente: View {
    @EnvironmentObject var m: Modelo
    @Environment(\.dismiss) var fechar
    @State var paciente: Paciente
    let aoSalvar: (Paciente) -> Void

    private var novo: Bool { m.paciente(paciente.id) == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(novo ? "Novo paciente" : "Editar paciente").font(.title3.bold()).padding([.horizontal, .top], 20)
            Form {
                TextField("Nome completo", text: $paciente.nome)
                TextField("CPF", text: $paciente.cpf, prompt: Text("000.000.000-00"))
                CampoData("Nascimento", $paciente.nascimento)
                TextField("Telefone / WhatsApp", text: $paciente.telefone)
                TextField("E-mail", text: $paciente.email)
                Picker("Convênio", selection: $paciente.convenioId) {
                    Text("—").tag("")
                    ForEach(m.conveniosOrdenados) { Text($0.nome).tag($0.id) }
                }
                TextField("Plano / produto", text: $paciente.plano)
                TextField("Nº da carteirinha", text: $paciente.carteirinha)
                CampoData("Validade da carteirinha", $paciente.validadeCarteirinha)
                TextField("Observações", text: $paciente.obs, axis: .vertical).lineLimit(2...5)
            }
            .formStyle(.grouped)
            HStack {
                if !novo {
                    Button("Excluir…", role: .destructive) { fechar(); m.excluirPaciente(paciente.id) }
                }
                Spacer()
                Button("Cancelar") { fechar() }.keyboardShortcut(.cancelAction)
                Button("Salvar") { aoSalvar(paciente); fechar() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(paciente.nome.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding([.horizontal, .bottom], 20)
        }
        .frame(width: 500)
    }
}

// MARK: Convênios

struct Convenios: View {
    @EnvironmentObject var m: Modelo
    @State var selecao = Set<String>()
    @State var editando: Convenio?

    var body: some View {
        var uso: [String: Int] = [:]
        for s in m.dados.solicitacoes where !Regras.status(s.status).final { uso[s.convenioId, default: 0] += 1 }

        return Table(m.conveniosOrdenados, selection: $selecao) {
            TableColumn("Nome") { c in Text(c.nome).fontWeight(.medium) }.width(min: 140, ideal: 200)
            TableColumn("Tipo") { c in Text(c.ehParticular ? "Particular" : "Plano de saúde") }.width(min: 90, ideal: 110)
            TableColumn("Registro ANS") { c in Text(c.ans).monospacedDigit() }.width(min: 80, ideal: 100)
            TableColumn("Telefone") { c in Text(c.telefone) }.width(min: 90, ideal: 130)
            TableColumn("Portal") { c in
                if let url = urlSite(c.site) { Link("Abrir", destination: url) }
            }
            .width(min: 50, ideal: 60)
            TableColumn("Em aberto") { c in Text(uso[c.id].map(String.init) ?? "") }.width(min: 60, ideal: 70)
        }
        .contextMenu(forSelectionType: String.self) { ids in
            if let id = ids.first, let c = m.convenio(id) {
                Button("Editar…") { editando = c }
                Button("Ver solicitações") { m.irParaLista { $0.status = "todas"; $0.convenioId = id } }
                if !c.ehParticular || c.id != Convenio.particular.id {
                    Divider()
                    Button("Excluir…", role: .destructive) { m.excluirConvenio(id) }
                }
            }
        } primaryAction: { ids in
            if let id = ids.first { editando = m.convenio(id) }
        }
        .navigationTitle("Convênios")
        .toolbar {
            ToolbarItem {
                Button { editando = Convenio() } label: { Label("Novo convênio", systemImage: "plus.rectangle.on.rectangle") }
                    .help("Novo convênio")
            }
        }
        .sheet(item: $editando) { c in EditorConvenio(convenio: c).environmentObject(m) }
    }
}

func urlSite(_ s: String) -> URL? {
    let t = s.trimmingCharacters(in: .whitespaces)
    guard !t.isEmpty else { return nil }
    return URL(string: t.lowercased().hasPrefix("http") ? t : "https://\(t)")
}

struct EditorConvenio: View {
    @EnvironmentObject var m: Modelo
    @Environment(\.dismiss) var fechar
    @State var convenio: Convenio

    private var novo: Bool { m.convenio(convenio.id) == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(novo ? "Novo convênio" : "Editar convênio").font(.title3.bold()).padding([.horizontal, .top], 20)
            Form {
                TextField("Nome", text: $convenio.nome, prompt: Text("Ex.: Unimed, Bradesco Saúde"))
                Picker("Tipo", selection: $convenio.tipo) {
                    Text("Plano de saúde").tag("plano")
                    Text("Particular").tag("particular")
                }
                TextField("Registro ANS", text: $convenio.ans)
                TextField("Telefone / central", text: $convenio.telefone)
                TextField("E-mail", text: $convenio.email)
                TextField("Portal / site para autorizações", text: $convenio.site, prompt: Text("https://"))
                TextField("Observações (documentos exigidos, contatos…)", text: $convenio.obs, axis: .vertical).lineLimit(3...6)
            }
            .formStyle(.grouped)
            HStack {
                if !novo && convenio.id != Convenio.particular.id {
                    Button("Excluir…", role: .destructive) { fechar(); m.excluirConvenio(convenio.id) }
                }
                Spacer()
                Button("Cancelar") { fechar() }.keyboardShortcut(.cancelAction)
                Button("Salvar") {
                    convenio.nome = convenio.nome.trimmingCharacters(in: .whitespaces)
                    m.salvarConvenio(convenio)
                    fechar()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(convenio.nome.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding([.horizontal, .bottom], 20)
        }
        .frame(width: 500)
    }
}
