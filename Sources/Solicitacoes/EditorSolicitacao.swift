import SwiftUI
import SolicitacoesCore

struct EditorSolicitacao: View {
    @EnvironmentObject var m: Modelo
    let id: String
    @State var mudanca: MudancaStatus?
    @State var novoPaciente: Paciente?
    @State var editarPaciente: Paciente?

    var body: some View {
        let s = m.binding(id)
        let atual = s.wrappedValue
        HStack(alignment: .top, spacing: 0) {
            formulario(s, atual)
            Divider()
            Lateral(id: id, mudanca: $mudanca)
                .frame(width: 330)
        }
        .navigationTitle("Solicitação #\(atual.numero)")
        .navigationSubtitle(Regras.status(atual.status).nome)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { m.abertaId = nil } label: { Label("Voltar", systemImage: "chevron.backward") }
                    .help("Voltar para a lista")
                    .keyboardShortcut("[", modifiers: .command)
            }
            ToolbarItemGroup {
                Button { Impressao.imprimir(atual, modelo: m) } label: { Label("Imprimir ficha", systemImage: "printer") }
                    .help("Imprimir ficha (⌘P)").keyboardShortcut("p")
                Button { m.duplicar(id) } label: { Label("Duplicar", systemImage: "plus.square.on.square") }
                    .help("Duplicar")
                Button(role: .destructive) { m.excluir(id) } label: { Label("Excluir", systemImage: "trash") }
                    .help("Excluir")
            }
        }
        .sheet(item: $mudanca) { mud in
            MudarStatus(solicitacao: atual, particular: m.particular(atual), novo: mud.novo).environmentObject(m)
        }
        .sheet(item: $novoPaciente) { p in
            EditorPaciente(paciente: p) { salvo in
                m.salvarPaciente(salvo)
                s.wrappedValue.pacienteId = salvo.id
                if !salvo.convenioId.isEmpty { s.wrappedValue.convenioId = salvo.convenioId }
            }
            .environmentObject(m)
        }
        .sheet(item: $editarPaciente) { p in EditorPaciente(paciente: p) { m.salvarPaciente($0) }.environmentObject(m) }
    }

    private func formulario(_ s: Binding<Solicitacao>, _ atual: Solicitacao) -> some View {
        let part = m.particular(atual)
        let p = m.paciente(atual.pacienteId)
        let alertas = m.alertas(atual)
        return Form {
            if !alertas.isEmpty {
                Section { ChipsAlerta(alertas: alertas) }
            }
            Section("Paciente e convênio") {
                HStack {
                    Picker("Paciente", selection: s.pacienteId) {
                        Text("— escolha —").tag("")
                        ForEach(m.pacientesOrdenados) { Text($0.nome).tag($0.id) }
                    }
                    Button("Novo…") { novoPaciente = Paciente() }
                    if let p { Button("Editar…") { editarPaciente = p } }
                }
                Picker("Convênio", selection: s.convenioId) {
                    Text("— escolha —").tag("")
                    ForEach(m.conveniosOrdenados) { Text($0.nome).tag($0.id) }
                }
                if let p {
                    LabeledContent("Dados do paciente") {
                        Text([p.cpf.isEmpty ? nil : "CPF \(p.cpf)",
                              p.nascimento.isEmpty ? nil : "Nasc. \(Datas.formatar(p.nascimento))",
                              p.carteirinha.isEmpty ? nil : "Carteirinha \(p.carteirinha)",
                              p.telefone.isEmpty ? nil : p.telefone].compactMap { $0 }.joined(separator: " · "))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .onChange(of: atual.pacienteId) { novo in
                if s.wrappedValue.convenioId.isEmpty, let c = m.paciente(novo)?.convenioId, !c.isEmpty { s.wrappedValue.convenioId = c }
            }

            Section("Pedido") {
                Picker("Tipo", selection: s.tipo) { ForEach(Regras.tipos) { Text($0.nome).tag($0.id) } }
                Picker("Caráter", selection: s.carater) {
                    Text("Eletiva").tag("eletiva")
                    Text("Urgência / emergência").tag("urgencia")
                }
                TextField("Procedimento / exame", text: s.descricao, prompt: Text("Ex.: Ressonância magnética de joelho direito"))
                TextField("Código (TUSS)", text: s.codigo)
                TextField("Quantidade", text: textoInteiro(s.quantidade))
                TextField("CID", text: s.cid, prompt: Text("Ex.: M23.2"))
                TextField("Médico solicitante", text: s.medico)
                TextField("Local / prestador que vai realizar", text: s.local)
            }

            Section(part ? "Andamento" : "Autorização") {
                CampoData("Data do pedido médico", s.dataPedido)
                if !part {
                    CampoData("Enviada à operadora em", s.dataEnvio)
                    TextField("Protocolo", text: s.protocolo)
                    TextField("Nº da guia", text: s.guia)
                    TextField("Prazo (dias úteis)", text: textoInteiro(s.prazoDias),
                              prompt: Text(atual.carater == "urgencia" ? "imediato" : "\(m.dados.config.prazos[atual.tipo] ?? 10) (padrão)"))
                    LabeledContent("Data limite da resposta") {
                        if let lim = m.dataLimite(atual) { Text(Datas.formatar(lim)).bold().monospacedDigit() }
                        else { Text("defina a data de envio").foregroundStyle(.secondary) }
                    }
                    CampoData("Resposta recebida em", s.dataResposta)
                    TextField("Senha de autorização", text: s.senha)
                    CampoData("Validade da senha", s.validadeSenha)
                }
                CampoData("Agendado para", s.dataAgendada)
                CampoData("Realizado em", s.dataRealizada)
                CampoData("Retornar / cobrar em", s.retorno)
            }

            if part {
                Section("Particular") {
                    TextField("Valor (R$)", text: textoDecimal(s.valor), prompt: Text("0,00"))
                    Picker("Forma de pagamento", selection: s.formaPagamento) {
                        Text("—").tag("")
                        ForEach(Regras.formasPagamento, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Pagamento", selection: s.pagamento) {
                        Text("Pendente").tag("pendente")
                        Text("Sinal pago").tag("sinal")
                        Text("Pago").tag("pago")
                    }
                }
            }

            Section("Observações") {
                TextEditor(text: s.obs)
                    .font(.body)
                    .frame(minHeight: 80)
            }
        }
        .formStyle(.grouped)
    }
}

struct MudancaStatus: Identifiable {
    let id = UUID()
    let novo: String
}

private struct Lateral: View {
    @EnvironmentObject var m: Modelo
    let id: String
    @Binding var mudanca: MudancaStatus?
    @State var nota = ""
    @State var alvo = false

    var body: some View {
        let s = m.solicitacao(id) ?? Solicitacao(id: id)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mudar status").font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 6)], alignment: .leading, spacing: 6) {
                        ForEach(Regras.status) { st in
                            Button {
                                if st.id != s.status { mudanca = MudancaStatus(novo: st.id) }
                            } label: {
                                HStack(spacing: 5) {
                                    Circle().fill(st.cor.cor).frame(width: 7, height: 7)
                                    Text(st.nome).lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(st.id == s.status ? st.cor.cor : nil)
                            .fontWeight(st.id == s.status ? .bold : .regular)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Anexos (\(s.anexos.count))").font(.headline)
                    VStack(spacing: 6) {
                        Image(systemName: "tray.and.arrow.down").font(.title2).foregroundStyle(.secondary)
                        Text("Arraste arquivos aqui").foregroundStyle(.secondary)
                        Button("Escolher arquivos…") { m.escolherAnexos(id) }.buttonStyle(.link)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(alvo ? 0.15 : 0)))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(alvo ? Color.accentColor : Color.secondary.opacity(0.4),
                                                                            style: StrokeStyle(lineWidth: 1.5, dash: [5])))
                    .dropDestination(for: URL.self) { urls, _ in
                        m.adicionarAnexos(id, urls.filter(\.isFileURL))
                        return true
                    } isTargeted: { alvo = $0 }
                    ForEach(s.anexos) { a in
                        HStack {
                            Image(systemName: "doc")
                            Button(a.nome) { m.abrirAnexo(id, a) }.buttonStyle(.link).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Text(Datas.formatar(String(a.adicionadoEm.prefix(10)))).font(.caption).foregroundStyle(.secondary)
                            Menu {
                                Button("Abrir") { m.abrirAnexo(id, a) }
                                Button("Mostrar no Finder") { m.mostrarAnexoNoFinder(id, a) }
                                Divider()
                                Button("Remover…", role: .destructive) { m.removerAnexo(id, a) }
                            } label: { Image(systemName: "ellipsis.circle") }
                            .menuStyle(.borderlessButton)
                            .menuIndicator(.hidden)
                            .fixedSize()
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Histórico").font(.headline)
                    TextField("Registrar contato, ligação, pendência…", text: $nota, axis: .vertical)
                        .lineLimit(2...5)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Spacer()
                        Button("Registrar") {
                            let t = nota.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !t.isEmpty else { return }
                            m.registrarNota(id, t)
                            nota = ""
                        }
                        .disabled(nota.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    ForEach(Array(s.historico.enumerated().reversed()), id: \.offset) { item in
                        let h = item.element
                        HStack(alignment: .top, spacing: 8) {
                            Circle().fill(Color.secondary.opacity(0.5)).frame(width: 7, height: 7).padding(.top, 5)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(Datas.formatarCarimbo(h.em)).font(.caption).foregroundStyle(.secondary)
                                if h.tipo == "status" {
                                    HStack(spacing: 4) {
                                        ChipStatus(id: h.de ?? "")
                                        Image(systemName: "arrow.right").font(.caption2)
                                        ChipStatus(id: h.para ?? "")
                                    }
                                }
                                if !h.texto.isEmpty { Text(h.texto).textSelection(.enabled).fixedSize(horizontal: false, vertical: true) }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

/// Janela ao mudar o status: pede os dados que fazem sentido para cada etapa
struct MudarStatus: View {
    @EnvironmentObject var m: Modelo
    @Environment(\.dismiss) var fechar
    let solicitacao: Solicitacao
    let particular: Bool
    let novo: String

    @State var protocolo = ""
    @State var dataEnvio = ""
    @State var senha = ""
    @State var validadeSenha = ""
    @State var dataAgendada = ""
    @State var retorno = ""
    @State var texto = ""

    init(solicitacao s: Solicitacao, particular: Bool, novo: String) {
        solicitacao = s
        self.particular = particular
        self.novo = novo
        _protocolo = State(initialValue: s.protocolo)
        _dataEnvio = State(initialValue: s.dataEnvio.isEmpty ? Datas.hoje() : s.dataEnvio)
        _senha = State(initialValue: s.senha)
        _validadeSenha = State(initialValue: s.validadeSenha)
        _dataAgendada = State(initialValue: s.dataAgendada)
        _retorno = State(initialValue: s.retorno)
    }

    private var autorizacao: Bool { ["autorizada", "parcial"].contains(novo) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Mudar para \"\(Regras.status(novo).nome)\"").font(.title3.bold()).padding([.horizontal, .top], 20)
            Form {
                if novo == "enviada" && !particular {
                    TextField("Protocolo (opcional)", text: $protocolo)
                    CampoData("Enviada em", $dataEnvio)
                }
                if autorizacao && !particular {
                    TextField("Senha", text: $senha)
                    CampoData("Validade da senha", $validadeSenha)
                }
                if novo == "agendada" { CampoData("Data agendada", $dataAgendada) }
                if novo == "pendencia" { CampoData("Retornar / cobrar em", $retorno) }
                TextField(novo == "negada" ? "Motivo da negativa" : novo == "pendencia" ? "O que a operadora pediu" : "Observação (opcional)",
                          text: $texto, axis: .vertical)
                    .lineLimit(3...6)
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancelar") { fechar() }.keyboardShortcut(.cancelAction)
                Button("Confirmar") { confirmar() }.keyboardShortcut(.defaultAction)
            }
            .padding([.horizontal, .bottom], 20)
        }
        .frame(width: 460)
    }

    private func confirmar() {
        var campos: [WritableKeyPath<Solicitacao, String>: String] = [:]
        if novo == "enviada" && !particular { campos[\.protocolo] = protocolo; campos[\.dataEnvio] = dataEnvio }
        if autorizacao && !particular { campos[\.senha] = senha; campos[\.validadeSenha] = validadeSenha }
        if novo == "agendada" { campos[\.dataAgendada] = dataAgendada }
        if novo == "pendencia" { campos[\.retorno] = retorno }
        m.mudarStatus(solicitacao.id, para: novo, texto: texto.trimmingCharacters(in: .whitespacesAndNewlines), campos: campos)
        fechar()
    }
}
