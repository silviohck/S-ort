import XCTest
@testable import SolicitacoesCore

final class DatasTests: XCTestCase {
    func testPascoaESextaSanta() {
        XCTAssertEqual(Datas.pascoa(2025), "2025-04-20")
        XCTAssertEqual(Datas.pascoa(2026), "2026-04-05")
        XCTAssertTrue(Datas.feriadosNacionais(2026).contains("2026-04-03"))
    }

    func testDiasUteis() {
        // sexta 13/11/2026 + 1: segunda 16/11 (15/11 é domingo)
        XCTAssertEqual(Datas.somarDiasUteis("2026-11-13", 1), "2026-11-16")
        // quinta 19/11 + 1: 20/11 é feriado, cai na segunda 23/11
        XCTAssertEqual(Datas.somarDiasUteis("2026-11-19", 1), "2026-11-23")
        XCTAssertEqual(Datas.somarDiasUteis("2026-11-16", 1, extras: ["2026-11-17"]), "2026-11-18")
        XCTAssertEqual(Datas.somarDiasUteis("2026-11-16", 0), "2026-11-16")
    }

    func testFormatos() {
        XCTAssertEqual(Datas.formatar("2026-11-03"), "03/11/2026")
        XCTAssertEqual(Datas.formatar(""), "")
        XCTAssertEqual(Datas.deTexto("3/11/2026"), "2026-11-03")
        XCTAssertNil(Datas.deTexto("31/13/2026"))
        XCTAssertEqual(Datas.diferenca("2026-11-01", "2026-11-05"), 4)
        XCTAssertEqual(Datas.diferenca("2026-12-31", "2027-01-01"), 1)
        let c = Datas.carimbo(Date(timeIntervalSince1970: 0))
        XCTAssertEqual(c, "1970-01-01T00:00:00.000Z")
        XCTAssertEqual(Datas.deCarimbo(c), Date(timeIntervalSince1970: 0))
    }
}

final class RegrasTests: XCTestCase {
    func sol(_ status: String, envio: String = "", tipo: String = "exame_lab") -> Solicitacao {
        var s = Solicitacao(numero: 1)
        s.status = status; s.dataEnvio = envio; s.tipo = tipo
        return s
    }

    func testDataLimite() {
        let s = sol("analise", envio: "2026-11-02") // segunda
        XCTAssertEqual(Regras.dataLimite(s), "2026-11-05")
        var p = s; p.prazoDias = 1
        XCTAssertEqual(Regras.dataLimite(p), "2026-11-03")
        var u = s; u.carater = "urgencia"
        XCTAssertEqual(Regras.dataLimite(u), "2026-11-02")
        var cfg = Config(); cfg.prazos["exame"] = 2
        XCTAssertEqual(Regras.dataLimite(sol("analise", envio: "2026-11-02", tipo: "exame"), config: cfg), "2026-11-04")
        XCTAssertNil(Regras.dataLimite(sol("rascunho")))
        // 21 dias úteis com os feriados de 15/11 (domingo) e 20/11
        XCTAssertEqual(Regras.dataLimite(sol("enviada", envio: "2026-11-02", tipo: "alta_complexidade")), "2026-12-02")
    }

    func testAlertas() {
        let s = sol("analise", envio: "2026-11-02")
        let tipos = { (s: Solicitacao, hoje: String, part: Bool) in Regras.alertas(s, particular: part, hoje: hoje).map(\.tipo) }
        XCTAssertEqual(tipos(s, "2026-11-01", false), [])
        XCTAssertEqual(tipos(s, "2026-11-05", false), ["vence"])
        XCTAssertEqual(tipos(s, "2026-11-09", false), ["atrasada"])
        var a = s; a.status = "autorizada"; a.validadeSenha = "2026-11-12"
        XCTAssertEqual(tipos(a, "2026-11-09", false), ["senha_vence"])
        XCTAssertEqual(tipos(a, "2026-11-13", false), ["senha_vencida"])
        var r = sol("rascunho"); r.retorno = "2026-11-03"
        XCTAssertEqual(tipos(r, "2026-11-03", false), ["retorno"])
        r.status = "realizada"
        XCTAssertEqual(tipos(r, "2026-11-04", false), [])
        var p = sol("agendada"); p.valor = 500; p.dataAgendada = "2026-11-10"
        XCTAssertEqual(tipos(p, "2026-11-04", true), ["pagamento"])
        XCTAssertEqual(tipos(p, "2026-11-04", false), [])
        p.pagamento = "pago"
        XCTAssertEqual(tipos(p, "2026-11-11", true), ["confirmar"])
    }

    func testMudarStatus() {
        var s = sol("rascunho")
        let quando = Date(timeIntervalSince1970: 1_793_000_000) // 2026-10-26 (meio do dia UTC)
        XCTAssertTrue(Regras.mudarStatus(&s, para: "enviada", texto: "pelo portal", quando: quando))
        XCTAssertEqual(s.dataEnvio, Datas.isoLocal(quando))
        XCTAssertEqual(s.historico.count, 1)
        XCTAssertEqual(s.historico[0].de, "rascunho")
        XCTAssertEqual(s.historico[0].para, "enviada")
        XCTAssertEqual(s.historico[0].texto, "pelo portal")
        let envio = s.dataEnvio
        Regras.mudarStatus(&s, para: "autorizada", quando: quando.addingTimeInterval(86400 * 2))
        XCTAssertEqual(s.dataResposta, Datas.isoLocal(quando.addingTimeInterval(86400 * 2)))
        XCTAssertEqual(s.dataEnvio, envio)
        XCTAssertFalse(Regras.mudarStatus(&s, para: "autorizada"))
        XCTAssertEqual(s.historico.count, 2)
    }

    func testFiltrar() {
        var d = Dados()
        var p1 = Paciente(id: "p1", nome: "João da Conceição"); p1.cpf = "123"
        d.pacientes = [p1, Paciente(id: "p2", nome: "Maria Souza")]
        d.convenios.append(Convenio(id: "c1", nome: "Unimed"))
        var a = sol("analise", envio: "2026-11-02"); a.id = "1"; a.pacienteId = "p1"; a.convenioId = "c1"; a.descricao = "Hemograma"
        var b = sol("realizada", tipo: "cirurgia"); b.id = "2"; b.pacienteId = "p2"; b.convenioId = "c1"; b.descricao = "Colecistectomia"
        let ids = { (f: Filtro) in Regras.filtrar([a, b], f, dados: d, hoje: "2026-11-20").map(\.id) }
        var f = Filtro(); f.status = "todas"
        f.busca = "joao conceicao"; XCTAssertEqual(ids(f), ["1"])
        f.busca = "UNIMED"; XCTAssertEqual(ids(f), ["1", "2"])
        f.busca = ""; f.tipo = "cirurgia"; XCTAssertEqual(ids(f), ["2"])
        f = Filtro(); XCTAssertEqual(ids(f), ["1"]) // abertas
        f.soAlertas = true; XCTAssertEqual(ids(f), ["1"])
        f = Filtro(); f.status = "todas"; f.pacienteId = "p2"; XCTAssertEqual(ids(f), ["2"])
    }

    func testCSVeCPF() {
        XCTAssertEqual(Regras.csv([["a", "b;c"], ["x\"y", "1"]]), "\u{FEFF}a;\"b;c\"\r\n\"x\"\"y\";1")
        XCTAssertEqual(Regras.formatarCPF("12345678901"), "123.456.789-01")
        XCTAssertEqual(Regras.formatarCPF(" 123 "), "123")
    }
}

final class ArmazenamentoTests: XCTestCase {
    var pasta: URL!

    override func setUpWithError() throws {
        pasta = FileManager.default.temporaryDirectory.appendingPathComponent("sol-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: pasta) }

    func testLeArquivoDaVersaoAnterior() throws {
        // Como a versão anterior gravava: números às vezes como "", campos faltando
        let json = """
        {"versao":1,"seq":2,"config":{"nomeClinica":"Clínica X","prazos":{"exame":7},"feriadosExtras":["2026-11-17"]},
         "convenios":[{"id":"c1","nome":"Unimed","tipo":"plano"}],
         "pacientes":[{"id":"p1","nome":"Ana"}],
         "solicitacoes":[{"id":"s1","numero":2,"pacienteId":"p1","convenioId":"c1","status":"enviada","quantidade":"",
           "prazoDias":"","valor":"850","dataEnvio":"2026-11-02",
           "historico":[{"em":"2026-11-03T10:00:00.000Z","tipo":"status","de":"rascunho","para":"enviada","texto":""}]}]}
        """
        let d = try Armazenamento.decodificar(Data(json.utf8))
        XCTAssertEqual(d.config.nomeClinica, "Clínica X")
        XCTAssertEqual(d.config.prazos["exame"], 7)
        XCTAssertEqual(d.config.prazos["cirurgia"], 21, "completa prazos que faltam")
        XCTAssertEqual(d.convenios.first?.id, "particular", "garante o convênio Particular")
        let s = d.solicitacoes[0]
        XCTAssertNil(s.quantidade); XCTAssertNil(s.prazoDias); XCTAssertEqual(s.valor, 850)
        XCTAssertEqual(s.tipo, "exame"); XCTAssertEqual(s.historico.first?.para, "enviada")
        // regrava e lê de novo sem perder nada
        XCTAssertEqual(try Armazenamento.decodificar(Armazenamento.codificar(d)), d)
    }

    func testSalvarCarregarBackupEConflito() throws {
        let a = try Armazenamento(pasta: pasta)
        XCTAssertNil(try a.carregar())
        var d = Dados(); d.config.nomeClinica = "Teste"
        XCTAssertEqual(try a.salvar(d), .ok)
        d.seq = 5
        XCTAssertEqual(try a.salvar(d), .ok)
        XCTAssertEqual(try Armazenamento(pasta: pasta).carregar()?.seq, 5)
        let backups = try FileManager.default.contentsOfDirectory(atPath: a.pastaBackups.path)
        XCTAssertEqual(backups, ["dados-\(Datas.hoje()).json"])

        // outro computador grava no arquivo
        Thread.sleep(forTimeInterval: 0.05)
        var outro = d; outro.config.nomeClinica = "Outro PC"
        try Armazenamento.codificar(outro).write(to: a.arquivo)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(5)], ofItemAtPath: a.arquivo.path)
        d.seq = 6
        XCTAssertEqual(try a.salvar(d), .conflito)
        XCTAssertEqual(try a.carregar()?.config.nomeClinica, "Outro PC")
        XCTAssertEqual(try a.salvar(d), .ok, "depois de recarregar, grava")
    }

    func testAnexos() throws {
        let a = try Armazenamento(pasta: pasta)
        let origem = pasta.appendingPathComponent("pedido médico.pdf")
        try Data("conteudo".utf8).write(to: origem)
        let anexos = try a.adicionarAnexos("s1", [origem])
        XCTAssertEqual(anexos.first?.nome, "pedido médico.pdf")
        let url = a.urlAnexo("s1", anexos[0].arquivo)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "conteudo")
        a.removerAnexo("s1", anexos[0].arquivo)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testDadosDeExemplo() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Exemplo/dados.json")
        let d = try Armazenamento.decodificar(Data(contentsOf: url))
        XCTAssertEqual(d.solicitacoes.count, 7)
        XCTAssertEqual(d.solicitacoes[2].valor, 850)
        XCTAssertEqual(d.config.prazos["cirurgia"], 21)
    }

    func testNovaPasta() throws {
        let a = try Armazenamento(pasta: pasta.appendingPathComponent("antiga"))
        _ = try a.salvar(Dados())
        let nova = pasta.appendingPathComponent("nova")
        XCTAssertFalse(try Armazenamento.prepararNovaPasta(de: a.pasta, para: nova))
        XCTAssertTrue(FileManager.default.fileExists(atPath: nova.appendingPathComponent("dados.json").path))
        XCTAssertTrue(try Armazenamento.prepararNovaPasta(de: a.pasta, para: nova))
    }
}
