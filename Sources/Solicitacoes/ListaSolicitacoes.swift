import SwiftUI
import SolicitacoesCore

struct ListaSolicitacoes: View {
    @EnvironmentObject var m: Modelo
    @State var selecao = Set<String>()

    var body: some View {
        let lista = m.filtradas
        VStack(spacing: 0) {
            BarraFiltros()
            Divider()
            if lista.isEmpty {
                Vazio(titulo: m.dados.solicitacoes.isEmpty ? "Nenhuma solicitação ainda" : "Nada encontrado",
                      detalhe: m.dados.solicitacoes.isEmpty ? "Clique em + para criar a primeira." : "Nenhuma solicitação com esses filtros.",
                      icone: "doc.text.magnifyingglass")
            } else if m.modoQuadro {
                Quadro(lista: lista)
            } else {
                tabela(lista)
            }
        }
        .searchable(text: $m.filtro.busca, placement: .toolbar, prompt: "Paciente, procedimento, protocolo, senha…")
        .navigationTitle("Solicitações")
        .navigationSubtitle("\(lista.count) solicitação(ões)")
        .toolbar {
            ToolbarItem {
                Picker("Exibir", selection: $m.modoQuadro) {
                    Label("Lista", systemImage: "list.bullet").tag(false)
                    Label("Quadro", systemImage: "rectangle.split.3x1").tag(true)
                }
                .pickerStyle(.segmented)
                .help("Lista ou quadro")
            }
            ToolbarItem {
                Button { m.exportarPlanilha() } label: { Label("Exportar planilha", systemImage: "square.and.arrow.up") }
                    .help("Exportar planilha (CSV para Excel/Numbers)")
            }
        }
    }

    private func tabela(_ lista: [Solicitacao]) -> some View {
        Table(lista, selection: $selecao) {
            TableColumn("Nº") { s in Text("\(s.numero)").foregroundStyle(.secondary).monospacedDigit() }
                .width(min: 30, ideal: 40, max: 60)
            TableColumn("Paciente") { s in Text(m.paciente(s.pacienteId)?.nome ?? "—").fontWeight(.medium) }
                .width(min: 120, ideal: 180)
            TableColumn("Pedido") { s in
                VStack(alignment: .leading, spacing: 1) {
                    Text(s.descricao.isEmpty ? "—" : s.descricao).lineLimit(1)
                    HStack(spacing: 4) {
                        Text(Regras.tipo(s.tipo).nome)
                        if s.carater == "urgencia" { Text("URGÊNCIA").bold().foregroundStyle(.red) }
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
            }
            .width(min: 150, ideal: 220)
            TableColumn("Convênio") { s in Text(m.convenio(s.convenioId)?.nome ?? "—") }
                .width(min: 80, ideal: 110)
            TableColumn("Status") { s in ChipStatus(id: s.status) }
                .width(min: 90, ideal: 110)
            TableColumn("Enviada") { s in Text(Datas.formatar(s.dataEnvio)).monospacedDigit() }
                .width(min: 84, ideal: 88)
            TableColumn("Prazo") { s in
                Text(Regras.aguardandoResposta.contains(s.status) ? Datas.formatar(m.dataLimite(s) ?? "") : "").monospacedDigit()
            }
            .width(min: 84, ideal: 88)
            TableColumn("Alertas") { s in ChipsAlerta(alertas: m.alertas(s)) }
                .width(min: 120, ideal: 200)
        }
        .contextMenu(forSelectionType: String.self) { ids in
            if let id = ids.first {
                Button("Abrir") { m.abrir(id) }
                Button("Duplicar") { m.duplicar(id) }
                Menu("Mudar status") {
                    ForEach(Regras.status) { st in Button(st.nome) { m.mudarStatus(id, para: st.id) } }
                }
                Divider()
                Button("Excluir…", role: .destructive) { m.excluir(id) }
            }
        } primaryAction: { ids in
            if let id = ids.first { m.abrir(id) }
        }
    }
}

struct BarraFiltros: View {
    @EnvironmentObject var m: Modelo

    var body: some View {
        HStack(spacing: 10) {
            Picker("Status", selection: $m.filtro.status) {
                Text("Em aberto").tag("abertas")
                Text("Todas").tag("todas")
                Divider()
                ForEach(Regras.status) { Text($0.nome).tag($0.id) }
            }
            .frame(width: 190)
            Picker("Tipo", selection: $m.filtro.tipo) {
                Text("Todos").tag("")
                Divider()
                ForEach(Regras.tipos) { Text($0.nome).tag($0.id) }
            }
            .frame(width: 230)
            Picker("Convênio", selection: $m.filtro.convenioId) {
                Text("Todos").tag("")
                Divider()
                ForEach(m.conveniosOrdenados) { Text($0.nome).tag($0.id) }
            }
            .frame(width: 210)
            Toggle("Só com alertas", isOn: $m.filtro.soAlertas)
            if let p = m.paciente(m.filtro.pacienteId) {
                HStack(spacing: 4) {
                    Text("Paciente: \(p.nome)")
                    Button { m.filtro.pacienteId = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.borderless)
                }
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.15), in: Capsule())
            }
            Spacer()
        }
        .controlSize(.small)
        .padding(.horizontal, 12).padding(.vertical, 8)
    }
}

struct Quadro: View {
    @EnvironmentObject var m: Modelo
    let lista: [Solicitacao]

    var body: some View {
        let colunas = Regras.status.filter { m.filtro.status == "todas" || !$0.final || $0.id == m.filtro.status }
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 12, alignment: .top)], alignment: .leading, spacing: 12) {
                ForEach(colunas) { st in ColunaQuadro(st: st, itens: lista.filter { $0.status == st.id }) }
            }
            .padding(16)
        }
    }
}

struct ColunaQuadro: View {
    @EnvironmentObject var m: Modelo
    let st: StatusInfo
    let itens: [Solicitacao]
    @State var alvo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().strokeBorder(st.cor.cor, lineWidth: 2.5).frame(width: 10, height: 10)
                Text(st.nome).font(.headline)
                Text("\(itens.count)").foregroundStyle(.secondary)
            }
            ForEach(itens) { s in
                VStack(alignment: .leading, spacing: 3) {
                    Text(m.paciente(s.pacienteId)?.nome ?? "—").fontWeight(.semibold)
                    Text(s.descricao.isEmpty ? Regras.tipo(s.tipo).nome : s.descricao).lineLimit(2)
                    Text("#\(s.numero) · \(m.convenio(s.convenioId)?.nome ?? "")").font(.caption).foregroundStyle(.secondary)
                    let alertas = m.alertas(s)
                    if !alertas.isEmpty { ChipsAlerta(alertas: alertas) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(9)
                .background(.background, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
                .contentShape(Rectangle())
                .onTapGesture { m.abrir(s.id) }
                .draggable(s.id)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(alvo ? 0.22 : 0.09)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.accentColor, lineWidth: alvo ? 2 : 0))
        .dropDestination(for: String.self) { ids, _ in
            for id in ids { m.mudarStatus(id, para: st.id) }
            return !ids.isEmpty
        } isTargeted: { alvo = $0 }
    }
}
