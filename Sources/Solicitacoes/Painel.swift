import SwiftUI
import SolicitacoesCore

struct Painel: View {
    @EnvironmentObject var m: Modelo

    private struct Cartao: Identifiable {
        let id: String
        let titulo: String
        let valor: Int
        let destaque: Bool
        let filtro: (inout Filtro) -> Void
    }

    var body: some View {
        let abertas = m.dados.solicitacoes.filter { !Regras.status($0.status).final }
        let comAlertas = abertas.map { ItemAlerta(s: $0, alertas: m.alertas($0)) }
        let hoje = Datas.hoje()
        let atencao = comAlertas.filter { !$0.alertas.isEmpty }.sorted { a, b in
            let aa = a.alertas.contains { $0.alto }, ba = b.alertas.contains { $0.alto }
            return aa != ba ? aa : a.s.numero < b.s.numero
        }
        let agenda = abertas.filter { $0.status == "agendada" && !$0.dataAgendada.isEmpty && Datas.diferenca(hoje, $0.dataAgendada) >= 0 }
            .sorted { $0.dataAgendada < $1.dataAgendada }
        let conta = { (f: (Solicitacao) -> Bool) in abertas.filter(f).count }
        let cartoes = [
            Cartao(id: "abertas", titulo: "Em aberto", valor: abertas.count, destaque: false) { _ in },
            Cartao(id: "enviar", titulo: "A enviar", valor: conta { $0.status == "rascunho" }, destaque: false) { $0.status = "rascunho" },
            Cartao(id: "aguardando", titulo: "Aguardando operadora", valor: conta { Regras.aguardandoResposta.contains($0.status) },
                   destaque: false) { $0.status = "analise" },
            Cartao(id: "pendencia", titulo: "Pendências", valor: conta { $0.status == "pendencia" }, destaque: false) { $0.status = "pendencia" },
            Cartao(id: "agendar", titulo: "Autorizadas a agendar", valor: conta { ["autorizada", "parcial"].contains($0.status) },
                   destaque: false) { $0.status = "autorizada" },
            Cartao(id: "vencido", titulo: "Prazo vencido", valor: comAlertas.filter { $0.alertas.contains { $0.tipo == "atrasada" } }.count,
                   destaque: true) { $0.soAlertas = true },
        ]

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(cartoes) { c in
                        Button { m.irParaLista(c.filtro) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(c.titulo).font(.callout).foregroundStyle(.secondary).lineLimit(2, reservesSpace: true)
                                Text("\(c.valor)").font(.system(size: 30, weight: .semibold, design: .rounded))
                                    .foregroundStyle(c.destaque && c.valor > 0 ? Color.red : Color.primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(.background, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(alignment: .top, spacing: 16) {
                    GroupBox {
                        if atencao.isEmpty {
                            Text("Nada pendente. Tudo em dia.").foregroundStyle(.secondary).frame(maxWidth: .infinity).padding()
                        } else {
                            VStack(spacing: 0) {
                                ForEach(atencao.prefix(30)) { item in
                                    LinhaResumo(s: item.s) { ChipStatus(id: item.s.status); ChipsAlerta(alertas: item.alertas) }
                                    Divider()
                                }
                            }
                        }
                    } label: { Text("Precisa de atenção (\(atencao.count))").font(.headline) }
                    .frame(maxWidth: .infinity)
                    .layoutPriority(1)

                    GroupBox {
                        if agenda.isEmpty {
                            Text("Nenhum procedimento agendado.").foregroundStyle(.secondary).frame(maxWidth: .infinity).padding()
                        } else {
                            VStack(spacing: 0) {
                                ForEach(agenda.prefix(10)) { s in
                                    LinhaResumo(s: s) { Text(Datas.formatar(s.dataAgendada)).bold().monospacedDigit() }
                                    Divider()
                                }
                            }
                        }
                    } label: { Text("Próximos agendamentos").font(.headline) }
                    .frame(maxWidth: .infinity)
                }

                if m.dados.solicitacoes.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("1. Cadastre os convênios com que você trabalha (o Particular já existe).")
                            Text("2. Clique em + (Nova solicitação), escolha ou cadastre o paciente e preencha o pedido.")
                            Text("3. Ao enviar à operadora, mude o status para Enviada: o app calcula o prazo e avisa quando vencer.")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                    } label: { Text("Começando").font(.headline) }
                }
            }
            .padding(20)
        }
        .navigationTitle("Painel")
        .navigationSubtitle(Datas.formatar(hoje))
    }
}

private struct ItemAlerta: Identifiable {
    let s: Solicitacao
    let alertas: [Alerta]
    var id: String { s.id }
}

struct LinhaResumo<Direita: View>: View {
    @EnvironmentObject var m: Modelo
    let s: Solicitacao
    @ViewBuilder let direita: () -> Direita

    var body: some View {
        Button { m.abrir(s.id) } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(m.paciente(s.pacienteId)?.nome ?? "Sem paciente").fontWeight(.medium)
                    Text("#\(s.numero) · \(s.descricao.isEmpty ? Regras.tipo(s.tipo).nome : s.descricao) · \(m.convenio(s.convenioId)?.nome ?? "")")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 8)
                direita()
            }
            .padding(.vertical, 8).padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
