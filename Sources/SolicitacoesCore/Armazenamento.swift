import Foundation

/// Grava os dados em <pasta>/dados.json, os anexos em <pasta>/anexos/<id>/ e uma cópia
/// por dia em <pasta>/backups/ (mantém as 30 mais recentes).
public final class Armazenamento {
    public enum Resultado: Equatable { case ok, conflito }

    public let pasta: URL
    private var versaoLida: Date?
    private let fm = FileManager.default

    public init(pasta: URL) throws {
        self.pasta = pasta
        try fm.createDirectory(at: pasta, withIntermediateDirectories: true)
    }

    public var arquivo: URL { pasta.appendingPathComponent("dados.json") }

    /// ~/Library/Application Support/Solicitações/dados (a mesma da versão anterior do app)
    public static func pastaPadrao() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Solicitações").appendingPathComponent("dados")
    }

    /// Pasta escolhida na versão anterior do app (preferencias.json), se houver
    public static func pastaDaVersaoAnterior() -> URL? {
        let pref = pastaPadrao().deletingLastPathComponent().appendingPathComponent("preferencias.json")
        guard let d = try? Data(contentsOf: pref),
              let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let p = obj["pastaDados"] as? String, !p.isEmpty else { return nil }
        return URL(fileURLWithPath: p)
    }

    private func dataModificacao() -> Date? {
        (try? fm.attributesOfItem(atPath: arquivo.path))?[.modificationDate] as? Date
    }

    public static func decodificar(_ data: Data) throws -> Dados { try JSONDecoder().decode(Dados.self, from: data) }

    public static func codificar(_ dados: Dados) throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try e.encode(dados)
    }

    /// nil quando ainda não existe arquivo de dados
    public func carregar() throws -> Dados? {
        defer { versaoLida = dataModificacao() }
        guard fm.fileExists(atPath: arquivo.path) else { return nil }
        return try Self.decodificar(Data(contentsOf: arquivo))
    }

    /// Não sobrescreve se outro computador (pasta sincronizada) gravou depois da nossa leitura
    public func salvar(_ dados: Dados) throws -> Resultado {
        if let atual = dataModificacao(), let lida = versaoLida, abs(atual.timeIntervalSince(lida)) > 0.001 {
            return .conflito
        }
        try backupDiario()
        try Self.codificar(dados).write(to: arquivo, options: .atomic)
        versaoLida = dataModificacao()
        return .ok
    }

    /// Ignora a versão em disco e grava (usado ao importar backup)
    public func substituir(_ dados: Dados) throws {
        versaoLida = nil
        _ = try salvar(dados)
    }

    public var pastaBackups: URL { pasta.appendingPathComponent("backups") }

    private func backupDiario() throws {
        guard fm.fileExists(atPath: arquivo.path) else { return }
        try fm.createDirectory(at: pastaBackups, withIntermediateDirectories: true)
        let destino = pastaBackups.appendingPathComponent("dados-\(Datas.hoje()).json")
        if !fm.fileExists(atPath: destino.path) { try fm.copyItem(at: arquivo, to: destino) }
        let nomes = try fm.contentsOfDirectory(atPath: pastaBackups.path)
            .filter { $0.hasPrefix("dados-") && $0.hasSuffix(".json") }.sorted()
        for n in nomes.dropLast(30) { try? fm.removeItem(at: pastaBackups.appendingPathComponent(n)) }
    }

    // MARK: Anexos

    static func nomeSeguro(_ n: String) -> String {
        String(n.map { "/\\:*?\"<>|".contains($0) ? "_" : $0 })
    }

    public func pastaAnexos(_ solId: String) -> URL {
        pasta.appendingPathComponent("anexos").appendingPathComponent(Self.nomeSeguro(solId))
    }

    public func urlAnexo(_ solId: String, _ arquivo: String) -> URL {
        pastaAnexos(solId).appendingPathComponent(Self.nomeSeguro(arquivo))
    }

    /// Copia os arquivos para a pasta de anexos da solicitação
    public func adicionarAnexos(_ solId: String, _ urls: [URL]) throws -> [Anexo] {
        let dir = pastaAnexos(solId)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return try urls.map { origem in
            let nome = origem.lastPathComponent
            let prefixo = String(UUID().uuidString.prefix(6)).lowercased()
            let arquivo = "\(prefixo)-\(Self.nomeSeguro(nome))"
            try fm.copyItem(at: origem, to: dir.appendingPathComponent(arquivo))
            return Anexo(nome: nome, arquivo: arquivo, adicionadoEm: Datas.carimbo())
        }
    }

    public func removerAnexo(_ solId: String, _ arquivo: String) {
        try? fm.removeItem(at: urlAnexo(solId, arquivo))
    }

    public func removerAnexos(_ solId: String) {
        try? fm.removeItem(at: pastaAnexos(solId))
    }

    /// Leva dados.json e anexos para outra pasta, se ela ainda não tiver dados.
    /// Retorna true se a pasta de destino já tinha dados (e eles passam a ser usados).
    public static func prepararNovaPasta(de antiga: URL, para nova: URL) throws -> Bool {
        let fm = FileManager.default
        try fm.createDirectory(at: nova, withIntermediateDirectories: true)
        if fm.fileExists(atPath: nova.appendingPathComponent("dados.json").path) { return true }
        for item in ["dados.json", "anexos"] {
            let de = antiga.appendingPathComponent(item)
            if fm.fileExists(atPath: de.path) { try fm.copyItem(at: de, to: nova.appendingPathComponent(item)) }
        }
        return false
    }
}
