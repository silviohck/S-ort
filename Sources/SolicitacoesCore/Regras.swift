import Foundation

public enum Cor: String { case cinza, azul, verde, laranja, vermelho, roxo }

public struct StatusInfo: Identifiable, Hashable {
    public let id: String
    public let nome: String
    public let cor: Cor
    public let final: Bool
}

public struct TipoInfo: Identifiable, Hashable {
    public let id: String
    public let nome: String
}

public struct Alerta: Hashable {
    public let tipo: String
    public let texto: String
    public let alto: Bool
}

public struct Filtro: Equatable {
    public var busca = ""
    public var status = "abertas" // "abertas", "todas" ou o id de um status
    public var tipo = ""
    public var convenioId = ""
    public var pacienteId = ""
    public var soAlertas = false
    public init() {}
}

public enum Regras {
    public static let status: [StatusInfo] = [
        .init(id: "rascunho", nome: "A enviar", cor: .cinza, final: false),
        .init(id: "enviada", nome: "Enviada", cor: .azul, final: false),
        .init(id: "analise", nome: "Em análise", cor: .azul, final: false),
        .init(id: "pendencia", nome: "Pendência", cor: .laranja, final: false),
        .init(id: "autorizada", nome: "Autorizada", cor: .verde, final: false),
        .init(id: "parcial", nome: "Autorizada parcial", cor: .verde, final: false),
        .init(id: "negada", nome: "Negada", cor: .vermelho, final: false),
        .init(id: "agendada", nome: "Agendada", cor: .roxo, final: false),
        .init(id: "realizada", nome: "Realizada", cor: .cinza, final: true),
        .init(id: "cancelada", nome: "Cancelada", cor: .cinza, final: true),
    ]

    /// Status em que se espera resposta da operadora (conta prazo)
    public static let aguardandoResposta: Set<String> = ["enviada", "analise", "pendencia"]

    public static let tipos: [TipoInfo] = [
        .init(id: "consulta", nome: "Consulta"),
        .init(id: "exame_lab", nome: "Exame laboratorial"),
        .init(id: "exame", nome: "Exame de imagem / diagnóstico"),
        .init(id: "terapia", nome: "Terapia / sessões"),
        .init(id: "procedimento", nome: "Procedimento ambulatorial"),
        .init(id: "alta_complexidade", nome: "Procedimento de alta complexidade"),
        .init(id: "hospital_dia", nome: "Hospital-dia"),
        .init(id: "cirurgia", nome: "Cirurgia / internação eletiva"),
        .init(id: "opme", nome: "OPME (órteses, próteses, materiais)"),
        .init(id: "outro", nome: "Outro"),
    ]

    /// Prazos de referência em dias úteis (garantia de atendimento, ANS RN 566/2022).
    /// Editáveis nos Ajustes do app: confira a norma vigente e o contrato.
    public static let prazosPadrao: [String: Int] = [
        "consulta": 14, "exame_lab": 3, "exame": 10, "terapia": 10, "procedimento": 10,
        "alta_complexidade": 21, "hospital_dia": 10, "cirurgia": 21, "opme": 21, "outro": 10,
    ]

    public static let formasPagamento = ["Pix", "Dinheiro", "Cartão de débito", "Cartão de crédito", "Boleto", "Transferência"]

    public static func status(_ id: String) -> StatusInfo { status.first { $0.id == id } ?? status[0] }
    public static func tipo(_ id: String) -> TipoInfo { tipos.first { $0.id == id } ?? tipos[tipos.count - 1] }

    // MARK: Prazo e alertas

    public static func dataLimite(_ s: Solicitacao, config: Config = Config()) -> String? {
        guard !s.dataEnvio.isEmpty else { return nil }
        if s.carater == "urgencia" { return s.dataEnvio }
        let dias = s.prazoDias ?? config.prazos[s.tipo] ?? prazosPadrao[s.tipo] ?? 10
        return Datas.somarDiasUteis(s.dataEnvio, dias, extras: config.feriadosExtras)
    }

    public static func alertas(_ s: Solicitacao, particular: Bool, config: Config = Config(), hoje: String = Datas.hoje()) -> [Alerta] {
        var out: [Alerta] = []
        if aguardandoResposta.contains(s.status), let lim = dataLimite(s, config: config) {
            let d = Datas.diferenca(hoje, lim)
            if d < 0 { out.append(.init(tipo: "atrasada", texto: "Prazo vencido há \(-d) dia(s)", alto: true)) }
            else if d <= 2 { out.append(.init(tipo: "vence", texto: d == 0 ? "Prazo vence hoje" : "Prazo vence em \(d) dia(s)", alto: false)) }
        }
        if ["autorizada", "parcial"].contains(s.status), !s.validadeSenha.isEmpty {
            let d = Datas.diferenca(hoje, s.validadeSenha)
            if d < 0 { out.append(.init(tipo: "senha_vencida", texto: "Senha de autorização vencida", alto: true)) }
            else if d <= 7 { out.append(.init(tipo: "senha_vence", texto: "Senha vence em \(d) dia(s)", alto: false)) }
        }
        if s.status == "pendencia" { out.append(.init(tipo: "pendencia", texto: "Operadora pediu documentos", alto: false)) }
        if !s.retorno.isEmpty, !status(s.status).final {
            let d = Datas.diferenca(hoje, s.retorno)
            if d <= 0 { out.append(.init(tipo: "retorno", texto: d == 0 ? "Retornar hoje" : "Retorno atrasado", alto: false)) }
        }
        if s.status == "agendada", !s.dataAgendada.isEmpty, Datas.diferenca(hoje, s.dataAgendada) < 0 {
            out.append(.init(tipo: "confirmar", texto: "Data passou: confirmar se foi realizada", alto: false))
        }
        if particular, (s.valor ?? 0) > 0, s.pagamento != "pago", ["agendada", "realizada"].contains(s.status) {
            out.append(.init(tipo: "pagamento", texto: "Pagamento particular em aberto", alto: false))
        }
        return out
    }

    /// Muda o status registrando no histórico. Retorna false se já estava nesse status.
    @discardableResult
    public static func mudarStatus(_ s: inout Solicitacao, para novo: String, texto: String = "", quando: Date = Date()) -> Bool {
        guard s.status != novo else { return false }
        let em = Datas.carimbo(quando)
        s.historico.append(Evento(em: em, tipo: "status", de: s.status, para: novo, texto: texto))
        s.status = novo
        s.atualizadoEm = em
        let dia = Datas.isoLocal(quando)
        if novo == "enviada", s.dataEnvio.isEmpty { s.dataEnvio = dia }
        if ["autorizada", "parcial", "negada"].contains(novo), s.dataResposta.isEmpty { s.dataResposta = dia }
        if novo == "realizada", s.dataRealizada.isEmpty { s.dataRealizada = dia }
        return true
    }

    // MARK: Busca

    public static func normalizar(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR")).lowercased()
    }

    public static func filtrar(_ lista: [Solicitacao], _ f: Filtro, dados: Dados, hoje: String = Datas.hoje()) -> [Solicitacao] {
        let termos = normalizar(f.busca).split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let pacientes = Dictionary(dados.pacientes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let convenios = Dictionary(dados.convenios.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return lista.filter { s in
            switch f.status {
            case "abertas": if status(s.status).final { return false }
            case "todas", "": break
            default: if s.status != f.status { return false }
            }
            if !f.tipo.isEmpty, s.tipo != f.tipo { return false }
            if !f.convenioId.isEmpty, s.convenioId != f.convenioId { return false }
            if !f.pacienteId.isEmpty, s.pacienteId != f.pacienteId { return false }
            if f.soAlertas {
                let part = convenios[s.convenioId]?.ehParticular ?? false
                if alertas(s, particular: part, config: dados.config, hoje: hoje).isEmpty { return false }
            }
            if !termos.isEmpty {
                let p = pacientes[s.pacienteId]
                let texto = normalizar([String(s.numero), s.descricao, s.codigo, s.cid, s.medico, s.local, s.protocolo, s.senha,
                                        p?.nome ?? "", p?.cpf ?? "", p?.carteirinha ?? "", convenios[s.convenioId]?.nome ?? ""]
                    .joined(separator: " "))
                if !termos.allSatisfy({ texto.contains($0) }) { return false }
            }
            return true
        }
    }

    // MARK: Planilha

    /// CSV com ';' e BOM, para abrir direto no Excel/Numbers em português
    public static func csv(_ linhas: [[String]]) -> String {
        func esc(_ v: String) -> String {
            v.contains(where: { $0 == ";" || $0 == "\"" || $0 == "\n" }) ? "\"" + v.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : v
        }
        return "\u{FEFF}" + linhas.map { $0.map(esc).joined(separator: ";") }.joined(separator: "\r\n")
    }

    public static func formatarCPF(_ v: String) -> String {
        let n = v.filter(\.isNumber)
        guard n.count == 11 else { return v.trimmingCharacters(in: .whitespaces) }
        let c = Array(n)
        return "\(String(c[0..<3])).\(String(c[3..<6])).\(String(c[6..<9]))-\(String(c[9..<11]))"
    }

    public static func moeda(_ v: Double?) -> String {
        guard let v else { return "" }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: NSNumber(value: v)) ?? String(v)
    }
}
