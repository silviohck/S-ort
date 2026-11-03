import Foundation

// Formato do arquivo dados.json. As chaves são as mesmas da versão anterior do app,
// então um arquivo antigo abre sem conversão. Campos ausentes recebem valor padrão.

public struct Dados: Codable, Equatable {
    public var versao: Int = 1
    public var seq: Int = 0
    public var config = Config()
    public var convenios: [Convenio] = [.particular]
    public var pacientes: [Paciente] = []
    public var solicitacoes: [Solicitacao] = []

    public init() {}

    enum CodingKeys: String, CodingKey { case versao, seq, config, convenios, pacientes, solicitacoes }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        versao = c.v(.versao, 1)
        seq = c.v(.seq, 0)
        config = c.v(.config, Config())
        convenios = c.v(.convenios, [])
        pacientes = c.v(.pacientes, [])
        solicitacoes = c.v(.solicitacoes, [])
        if !convenios.contains(where: { $0.tipo == "particular" }) { convenios.insert(.particular, at: 0) }
        let maior = solicitacoes.map(\.numero).max() ?? 0
        if seq < maior { seq = maior }
    }
}

public struct Config: Codable, Equatable {
    public var nomeClinica = ""
    public var prazos: [String: Int] = Regras.prazosPadrao
    public var feriadosExtras: [String] = []

    public init() {}

    enum CodingKeys: String, CodingKey { case nomeClinica, prazos, feriadosExtras }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nomeClinica = c.v(.nomeClinica, "")
        let lidos: [String: Int] = c.v(.prazos, [:])
        prazos = Regras.prazosPadrao.merging(lidos) { _, novo in novo }
        feriadosExtras = c.v(.feriadosExtras, [])
    }
}

public struct Convenio: Codable, Identifiable, Hashable {
    public var id: String
    public var nome = ""
    public var tipo = "plano" // "plano" ou "particular"
    public var ans = ""
    public var telefone = ""
    public var email = ""
    public var site = ""
    public var obs = ""

    public static let particular = Convenio(id: "particular", nome: "Particular", tipo: "particular")

    public init(id: String = UUID().uuidString, nome: String = "", tipo: String = "plano") {
        self.id = id; self.nome = nome; self.tipo = tipo
    }

    public var ehParticular: Bool { tipo == "particular" }

    enum CodingKeys: String, CodingKey { case id, nome, tipo, ans, telefone, email, site, obs }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.v(.id, UUID().uuidString)
        nome = c.v(.nome, ""); tipo = c.v(.tipo, "plano"); ans = c.v(.ans, "")
        telefone = c.v(.telefone, ""); email = c.v(.email, ""); site = c.v(.site, ""); obs = c.v(.obs, "")
    }
}

public struct Paciente: Codable, Identifiable, Hashable {
    public var id: String
    public var nome = ""
    public var cpf = ""
    public var nascimento = ""
    public var telefone = ""
    public var email = ""
    public var convenioId = ""
    public var plano = ""
    public var carteirinha = ""
    public var validadeCarteirinha = ""
    public var obs = ""
    public var criadoEm = ""
    public var atualizadoEm = ""

    public init(id: String = UUID().uuidString, nome: String = "") { self.id = id; self.nome = nome }

    enum CodingKeys: String, CodingKey {
        case id, nome, cpf, nascimento, telefone, email, convenioId, plano, carteirinha, validadeCarteirinha, obs, criadoEm, atualizadoEm
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.v(.id, UUID().uuidString)
        nome = c.v(.nome, ""); cpf = c.v(.cpf, ""); nascimento = c.v(.nascimento, "")
        telefone = c.v(.telefone, ""); email = c.v(.email, ""); convenioId = c.v(.convenioId, "")
        plano = c.v(.plano, ""); carteirinha = c.v(.carteirinha, ""); validadeCarteirinha = c.v(.validadeCarteirinha, "")
        obs = c.v(.obs, ""); criadoEm = c.v(.criadoEm, ""); atualizadoEm = c.v(.atualizadoEm, "")
    }
}

public struct Anexo: Codable, Identifiable, Hashable {
    public var id: String
    public var nome: String
    public var arquivo: String // nome do arquivo dentro de anexos/<id da solicitação>/
    public var adicionadoEm: String

    public init(id: String = UUID().uuidString, nome: String, arquivo: String, adicionadoEm: String) {
        self.id = id; self.nome = nome; self.arquivo = arquivo; self.adicionadoEm = adicionadoEm
    }
}

public struct Evento: Codable, Hashable {
    public var em: String
    public var tipo: String // "criacao", "status" ou "nota"
    public var de: String?
    public var para: String?
    public var texto: String

    public init(em: String, tipo: String, de: String? = nil, para: String? = nil, texto: String = "") {
        self.em = em; self.tipo = tipo; self.de = de; self.para = para; self.texto = texto
    }

    enum CodingKeys: String, CodingKey { case em, tipo, de, para, texto }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        em = c.v(.em, ""); tipo = c.v(.tipo, "nota")
        de = try? c.decodeIfPresent(String.self, forKey: .de)
        para = try? c.decodeIfPresent(String.self, forKey: .para)
        texto = c.v(.texto, "")
    }
}

public struct Solicitacao: Codable, Identifiable, Hashable {
    public var id: String
    public var numero = 0
    public var pacienteId = ""
    public var convenioId = ""
    public var tipo = "exame"
    public var carater = "eletiva" // "eletiva" ou "urgencia"
    public var descricao = ""
    public var codigo = ""
    public var quantidade: Int? = 1
    public var cid = ""
    public var medico = ""
    public var local = ""
    public var status = "rascunho"
    public var dataPedido = ""
    public var dataEnvio = ""
    public var protocolo = ""
    public var guia = ""
    public var senha = ""
    public var validadeSenha = ""
    public var prazoDias: Int?
    public var retorno = ""
    public var dataAgendada = ""
    public var dataResposta = ""
    public var dataRealizada = ""
    public var valor: Double?
    public var formaPagamento = ""
    public var pagamento = "pendente" // "pendente", "sinal" ou "pago"
    public var obs = ""
    public var anexos: [Anexo] = []
    public var historico: [Evento] = []
    public var criadoEm = ""
    public var atualizadoEm = ""

    public init(id: String = UUID().uuidString, numero: Int = 0) { self.id = id; self.numero = numero }

    enum CodingKeys: String, CodingKey {
        case id, numero, pacienteId, convenioId, tipo, carater, descricao, codigo, quantidade, cid, medico, local, status
        case dataPedido, dataEnvio, protocolo, guia, senha, validadeSenha, prazoDias, retorno, dataAgendada, dataResposta
        case dataRealizada, valor, formaPagamento, pagamento, obs, anexos, historico, criadoEm, atualizadoEm
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.v(.id, UUID().uuidString)
        numero = c.inteiro(.numero) ?? 0
        pacienteId = c.v(.pacienteId, ""); convenioId = c.v(.convenioId, "")
        tipo = c.v(.tipo, "exame"); carater = c.v(.carater, "eletiva")
        descricao = c.v(.descricao, ""); codigo = c.v(.codigo, ""); quantidade = c.inteiro(.quantidade)
        cid = c.v(.cid, ""); medico = c.v(.medico, ""); local = c.v(.local, ""); status = c.v(.status, "rascunho")
        dataPedido = c.v(.dataPedido, ""); dataEnvio = c.v(.dataEnvio, ""); protocolo = c.v(.protocolo, "")
        guia = c.v(.guia, ""); senha = c.v(.senha, ""); validadeSenha = c.v(.validadeSenha, "")
        prazoDias = c.inteiro(.prazoDias); retorno = c.v(.retorno, ""); dataAgendada = c.v(.dataAgendada, "")
        dataResposta = c.v(.dataResposta, ""); dataRealizada = c.v(.dataRealizada, "")
        valor = c.numero(.valor); formaPagamento = c.v(.formaPagamento, ""); pagamento = c.v(.pagamento, "pendente")
        obs = c.v(.obs, ""); anexos = c.v(.anexos, []); historico = c.v(.historico, [])
        criadoEm = c.v(.criadoEm, ""); atualizadoEm = c.v(.atualizadoEm, "")
    }
}

extension KeyedDecodingContainer {
    /// Lê o campo; se faltar ou tiver tipo errado, usa o padrão.
    func v<T: Decodable>(_ chave: Key, _ padrao: T) -> T {
        if let x = try? decodeIfPresent(T.self, forKey: chave) { return x }
        return padrao
    }

    /// Número que pode ter sido gravado como número ou texto ("" vira nil).
    func numero(_ chave: Key) -> Double? {
        if let d = try? decodeIfPresent(Double.self, forKey: chave) { return d }
        if let s = try? decodeIfPresent(String.self, forKey: chave) {
            return Double(s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
        }
        return nil
    }

    func inteiro(_ chave: Key) -> Int? { numero(chave).map { Int($0) } }
}
