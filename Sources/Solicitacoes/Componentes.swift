import SwiftUI
import SolicitacoesCore

extension Cor {
    var cor: Color {
        switch self {
        case .cinza: return .gray
        case .azul: return .blue
        case .verde: return .green
        case .laranja: return .orange
        case .vermelho: return .red
        case .roxo: return .purple
        }
    }
}

struct ChipStatus: View {
    let id: String
    var body: some View {
        let st = Regras.status(id)
        Text(st.nome)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(st.cor.cor.opacity(0.18), in: Capsule())
            .foregroundStyle(st.cor.cor)
    }
}

struct ChipsAlerta: View {
    let alertas: [Alerta]
    var body: some View {
        HStack(spacing: 4) {
            ForEach(alertas, id: \.self) { a in
                Text(a.texto)
                    .font(.caption.weight(a.alto ? .semibold : .regular))
                    .lineLimit(1)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background((a.alto ? Color.red : Color.orange).opacity(0.16), in: Capsule())
                    .foregroundStyle(a.alto ? Color.red : Color.orange)
            }
        }
    }
}

/// Campo de data que pode ficar vazio (o DatePicker do sistema não permite)
struct CampoData: View {
    let titulo: String
    @Binding var iso: String

    init(_ titulo: String, _ iso: Binding<String>) {
        self.titulo = titulo
        _iso = iso
    }

    var body: some View {
        LabeledContent(titulo) {
            if iso.isEmpty {
                Button("Definir") { iso = Datas.hoje() }
                    .buttonStyle(.link)
            } else {
                HStack(spacing: 4) {
                    DatePicker(titulo, selection: Binding(get: { Datas.dataLocal(iso) }, set: { iso = Datas.isoLocal($0) }),
                               displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.stepperField)
                    Button { iso = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .help("Limpar data")
                }
            }
        }
    }
}

/// Texto ⇄ número opcional (aceita vírgula)
func textoInteiro(_ b: Binding<Int?>) -> Binding<String> {
    Binding(get: { b.wrappedValue.map(String.init) ?? "" },
            set: { b.wrappedValue = Int($0.filter(\.isNumber)) })
}

func textoDecimal(_ b: Binding<Double?>) -> Binding<String> {
    Binding(get: {
        guard let v = b.wrappedValue else { return "" }
        return v == v.rounded() ? String(Int(v)) : String(format: "%.2f", v).replacingOccurrences(of: ".", with: ",")
    }, set: {
        let t = $0.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        b.wrappedValue = t.isEmpty ? nil : Double(t)
    })
}

struct Vazio: View {
    let titulo: String
    let detalhe: String
    var icone = "tray"
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icone).font(.system(size: 32)).foregroundStyle(.tertiary)
            Text(titulo).font(.headline)
            Text(detalhe).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
