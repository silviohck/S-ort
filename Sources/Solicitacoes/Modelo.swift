import AppKit
import SwiftUI
import UniformTypeIdentifiers
import SolicitacoesCore

enum Tela: Hashable { case painel, solicitacoes, pacientes, convenios }

/// Estado do app: os dados, a tela atual e as ações. Toda alteração em `dados` é gravada sozinha.
@MainActor
final class Modelo: ObservableObject {
    @Published var dados = Dados() { didSet { if !carregando { agendarGravacao() } } }
    @Published var tela: Tela? = .painel
    @Published var abertaId: String?
    @Published var filtro = Filtro()
    @Published var modoQuadro = false
    @Published var aviso: String?
    @Published private(set) var pasta: URL = Armazenamento.pastaPadrao()

    private var armazenamento: Armazenamento?
    private var carregando = false
    private var gravacao: DispatchWorkItem?
    private var avisoItem: DispatchWorkItem?

    init() {
        carregar()
        // Usado pelas capturas de tela automáticas: abre direto numa tela
        switch ProcessInfo.processInfo.environment["SOLICITACOES_TELA"] ?? "" {
        case "solicitacoes": tela = .solicitacoes
        case "quadro": tela = .solicitacoes; modoQuadro = true
        case "editor": abertaId = dados.solicitacoes.first?.id; tela = .solicitacoes
        case "pacientes": tela = .pacientes
        case "convenios": tela = .convenios
        default: break
        }
    }

    // MARK: Gravação

    static func pastaEscolhida() -> URL {
        if let p = ProcessInfo.processInfo.environment["SOLICITACOES_DADOS"], !p.isEmpty { return URL(fileURLWithPath: p) }
        if let p = UserDefaults.standard.string(forKey: "pastaDados"), !p.isEmpty { return URL(fileURLWithPath: p) }
        return Armazenamento.pastaDaVersaoAnterior() ?? Armazenamento.pastaPadrao()
    }

    func carregar() {
        do {
            let a = try Armazenamento(pasta: Self.pastaEscolhida())
            armazenamento = a
            pasta = a.pasta
            let lidos = try a.carregar()
            carregando = true
            dados = lidos ?? Dados()
            carregando = false
            if lidos == nil { gravarAgora() }
        } catch {
            carregando = false
            erro("Não foi possível abrir os dados", error.localizedDescription)
        }
    }

    private func agendarGravacao() {
        gravacao?.cancel()
        let item = DispatchWorkItem { [weak self] in Task { @MainActor in self?.gravarAgora() } }
        gravacao = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: item)
    }

    func gravarAgora() {
        gravacao?.cancel()
        gravacao = nil
        guard let a = armazenamento else { return }
        do {
            if try a.salvar(dados) == .conflito {
                erro("Os dados foram alterados em outro computador",
                     "O app vai abrir a versão mais recente. A última alteração feita aqui não foi gravada e precisa ser refeita.")
                carregar()
            }
        } catch {
            erro("Não foi possível gravar os dados", error.localizedDescription)
        }
    }

    // MARK: Consultas

    func paciente(_ id: String) -> Paciente? { dados.pacientes.first { $0.id == id } }
    func convenio(_ id: String) -> Convenio? { dados.convenios.first { $0.id == id } }
    func solicitacao(_ id: String) -> Solicitacao? { dados.solicitacoes.first { $0.id == id } }
    func particular(_ s: Solicitacao) -> Bool { convenio(s.convenioId)?.ehParticular ?? false }
    func alertas(_ s: Solicitacao) -> [Alerta] { Regras.alertas(s, particular: particular(s), config: dados.config) }
    func dataLimite(_ s: Solicitacao) -> String? { Regras.dataLimite(s, config: dados.config) }

    var pacientesOrdenados: [Paciente] {
        dados.pacientes.sorted { $0.nome.localizedCaseInsensitiveCompare($1.nome) == .orderedAscending }
    }

    var conveniosOrdenados: [Convenio] {
        dados.convenios.sorted {
            if $0.ehParticular != $1.ehParticular { return $0.ehParticular }
            return $0.nome.localizedCaseInsensitiveCompare($1.nome) == .orderedAscending
        }
    }

    var filtradas: [Solicitacao] {
        Regras.filtrar(dados.solicitacoes, filtro, dados: dados).sorted { $0.numero > $1.numero }
    }

    var quantidadeAlertasAltos: Int {
        dados.solicitacoes.filter { alertas($0).contains { $0.alto } }.count
    }

    func binding(_ id: String) -> Binding<Solicitacao> {
        Binding(
            get: { self.solicitacao(id) ?? Solicitacao(id: id) },
            set: { novo in
                guard let i = self.dados.solicitacoes.firstIndex(where: { $0.id == id }), self.dados.solicitacoes[i] != novo else { return }
                var n = novo
                n.atualizadoEm = Datas.carimbo()
                self.dados.solicitacoes[i] = n
            })
    }

    // MARK: Navegação

    func abrir(_ id: String) {
        abertaId = id
        tela = .solicitacoes
    }

    func irParaLista(_ ajuste: (inout Filtro) -> Void = { _ in }) {
        var f = Filtro()
        ajuste(&f)
        filtro = f
        abertaId = nil
        tela = .solicitacoes
    }

    func mostrarAviso(_ texto: String) {
        avisoItem?.cancel()
        withAnimation { aviso = texto }
        let item = DispatchWorkItem { [weak self] in Task { @MainActor in withAnimation { self?.aviso = nil } } }
        avisoItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6, execute: item)
    }

    // MARK: Solicitações

    func novaSolicitacao(pacienteId: String = "") {
        dados.seq += 1
        var s = Solicitacao(numero: dados.seq)
        s.pacienteId = pacienteId
        s.convenioId = paciente(pacienteId)?.convenioId ?? ""
        s.dataPedido = Datas.hoje()
        s.criadoEm = Datas.carimbo()
        s.atualizadoEm = s.criadoEm
        s.historico = [Evento(em: s.criadoEm, tipo: "criacao", texto: "Solicitação criada")]
        dados.solicitacoes.append(s)
        abrir(s.id)
    }

    func duplicar(_ id: String) {
        guard let o = solicitacao(id) else { return }
        dados.seq += 1
        var c = o
        c.id = UUID().uuidString
        c.numero = dados.seq
        c.status = "rascunho"
        c.anexos = []
        let limpar: [WritableKeyPath<Solicitacao, String>] = [\.protocolo, \.guia, \.senha, \.validadeSenha, \.dataEnvio, \.dataResposta,
                                                             \.dataAgendada, \.dataRealizada, \.retorno]
        for k in limpar {
            c[keyPath: k] = ""
        }
        c.pagamento = "pendente"
        c.criadoEm = Datas.carimbo()
        c.atualizadoEm = c.criadoEm
        c.historico = [Evento(em: c.criadoEm, tipo: "criacao", texto: "Cópia da solicitação #\(o.numero)")]
        dados.solicitacoes.append(c)
        abrir(c.id)
        mostrarAviso("Criada a solicitação #\(c.numero)")
    }

    func excluir(_ id: String) {
        guard let s = solicitacao(id),
              confirmar("Excluir a solicitação #\(s.numero)?", "Os anexos também serão removidos.", botao: "Excluir", destrutivo: true)
        else { return }
        armazenamento?.removerAnexos(id)
        dados.solicitacoes.removeAll { $0.id == id }
        if abertaId == id { abertaId = nil }
    }

    func mudarStatus(_ id: String, para novo: String, texto: String = "", campos: [WritableKeyPath<Solicitacao, String>: String] = [:]) {
        guard let i = dados.solicitacoes.firstIndex(where: { $0.id == id }) else { return }
        var s = dados.solicitacoes[i]
        for (k, v) in campos { s[keyPath: k] = v }
        let mudou = Regras.mudarStatus(&s, para: novo, texto: texto)
        dados.solicitacoes[i] = s
        if mudou { mostrarAviso("#\(s.numero): \(Regras.status(novo).nome)") }
    }

    func registrarNota(_ id: String, _ texto: String) {
        guard let i = dados.solicitacoes.firstIndex(where: { $0.id == id }) else { return }
        dados.solicitacoes[i].historico.append(Evento(em: Datas.carimbo(), tipo: "nota", texto: texto))
        dados.solicitacoes[i].atualizadoEm = Datas.carimbo()
    }

    // MARK: Anexos

    func escolherAnexos(_ id: String) {
        let p = NSOpenPanel()
        p.title = "Anexar arquivos à solicitação"
        p.allowsMultipleSelection = true
        p.canChooseDirectories = false
        if p.runModal() == .OK { adicionarAnexos(id, p.urls) }
    }

    func adicionarAnexos(_ id: String, _ urls: [URL]) {
        guard let a = armazenamento, let i = dados.solicitacoes.firstIndex(where: { $0.id == id }), !urls.isEmpty else { return }
        do {
            let novos = try a.adicionarAnexos(id, urls)
            dados.solicitacoes[i].anexos += novos
            dados.solicitacoes[i].historico.append(Evento(em: Datas.carimbo(), tipo: "nota",
                                                          texto: "Anexo(s): " + novos.map(\.nome).joined(separator: ", ")))
        } catch {
            erro("Não foi possível anexar", error.localizedDescription)
        }
    }

    func abrirAnexo(_ id: String, _ anexo: Anexo) {
        guard let a = armazenamento else { return }
        NSWorkspace.shared.open(a.urlAnexo(id, anexo.arquivo))
    }

    func mostrarAnexoNoFinder(_ id: String, _ anexo: Anexo) {
        guard let a = armazenamento else { return }
        NSWorkspace.shared.activateFileViewerSelecting([a.urlAnexo(id, anexo.arquivo)])
    }

    func removerAnexo(_ id: String, _ anexo: Anexo) {
        guard confirmar("Remover o anexo \"\(anexo.nome)\"?", botao: "Remover", destrutivo: true),
              let i = dados.solicitacoes.firstIndex(where: { $0.id == id }) else { return }
        armazenamento?.removerAnexo(id, anexo.arquivo)
        dados.solicitacoes[i].anexos.removeAll { $0.id == anexo.id }
        dados.solicitacoes[i].historico.append(Evento(em: Datas.carimbo(), tipo: "nota", texto: "Anexo removido: \(anexo.nome)"))
    }

    // MARK: Pacientes e convênios

    func salvarPaciente(_ p: Paciente) {
        var p = p
        p.nome = p.nome.trimmingCharacters(in: .whitespaces)
        p.cpf = Regras.formatarCPF(p.cpf)
        p.atualizadoEm = Datas.carimbo()
        if let i = dados.pacientes.firstIndex(where: { $0.id == p.id }) {
            dados.pacientes[i] = p
        } else {
            p.criadoEm = p.atualizadoEm
            dados.pacientes.append(p)
        }
    }

    func excluirPaciente(_ id: String) {
        let n = dados.solicitacoes.filter { $0.pacienteId == id }.count
        if n > 0 { return erro("Este paciente tem \(n) solicitação(ões)", "Exclua as solicitações antes de excluir o paciente.") }
        guard confirmar("Excluir este paciente?", botao: "Excluir", destrutivo: true) else { return }
        dados.pacientes.removeAll { $0.id == id }
    }

    func salvarConvenio(_ c: Convenio) {
        if let i = dados.convenios.firstIndex(where: { $0.id == c.id }) { dados.convenios[i] = c } else { dados.convenios.append(c) }
    }

    func excluirConvenio(_ id: String) {
        guard id != Convenio.particular.id else { return }
        if dados.solicitacoes.contains(where: { $0.convenioId == id }) || dados.pacientes.contains(where: { $0.convenioId == id }) {
            return erro("Convênio em uso", "Há pacientes ou solicitações com este convênio, então ele não pode ser excluído.")
        }
        guard confirmar("Excluir este convênio?", botao: "Excluir", destrutivo: true) else { return }
        dados.convenios.removeAll { $0.id == id }
    }

    // MARK: Arquivos

    func exportarPlanilha() {
        var linhas = [["Nº", "Paciente", "CPF", "Carteirinha", "Convênio", "Tipo", "Caráter", "Pedido", "Código", "Qtd", "CID", "Médico",
                       "Local", "Status", "Data do pedido", "Enviada em", "Prazo", "Resposta em", "Protocolo", "Guia", "Senha",
                       "Validade senha", "Agendada para", "Realizada em", "Valor", "Pagamento", "Observações"]]
        for s in filtradas {
            let p = paciente(s.pacienteId)
            linhas.append([String(s.numero), p?.nome ?? "", p?.cpf ?? "", p?.carteirinha ?? "", convenio(s.convenioId)?.nome ?? "",
                           Regras.tipo(s.tipo).nome, s.carater == "urgencia" ? "Urgência" : "Eletiva", s.descricao, s.codigo,
                           s.quantidade.map(String.init) ?? "", s.cid, s.medico, s.local, Regras.status(s.status).nome,
                           Datas.formatar(s.dataPedido), Datas.formatar(s.dataEnvio), Datas.formatar(dataLimite(s) ?? ""),
                           Datas.formatar(s.dataResposta), s.protocolo, s.guia, s.senha, Datas.formatar(s.validadeSenha),
                           Datas.formatar(s.dataAgendada), Datas.formatar(s.dataRealizada),
                           s.valor.map { String(format: "%.2f", $0).replacingOccurrences(of: ".", with: ",") } ?? "",
                           s.pagamento, s.obs])
        }
        salvarArquivo(nome: "solicitacoes-\(Datas.hoje()).csv", conteudo: Data(Regras.csv(linhas).utf8), aviso: "Planilha salva.")
    }

    func exportarBackup() {
        gravarAgora()
        guard let d = try? Armazenamento.codificar(dados) else { return }
        salvarArquivo(nome: "backup-solicitacoes-\(Datas.hoje()).json", conteudo: d,
                      aviso: "Backup exportado. Os anexos ficam na pasta de dados.")
    }

    func importarBackup() {
        let p = NSOpenPanel()
        p.title = "Importar backup"
        p.allowedContentTypes = [.json]
        guard p.runModal() == .OK, let url = p.url else { return }
        do {
            let novo = try Armazenamento.decodificar(Data(contentsOf: url))
            guard confirmar("Substituir os dados atuais por este backup?",
                            "\(novo.solicitacoes.count) solicitação(ões) e \(novo.pacientes.count) paciente(s). Os dados atuais serão substituídos.",
                            botao: "Substituir", destrutivo: true) else { return }
            try armazenamento?.substituir(novo)
            carregar()
            abertaId = nil
            mostrarAviso("Backup importado.")
        } catch {
            erro("Arquivo de backup inválido", error.localizedDescription)
        }
    }

    func abrirPasta() { NSWorkspace.shared.open(pasta) }

    func trocarPasta() {
        gravarAgora()
        let p = NSOpenPanel()
        p.title = "Escolha a pasta onde os dados serão guardados"
        p.canChooseDirectories = true
        p.canChooseFiles = false
        p.canCreateDirectories = true
        guard p.runModal() == .OK, let nova = p.url, nova.standardizedFileURL != pasta.standardizedFileURL else { return }
        do {
            let jaTinha = try Armazenamento.prepararNovaPasta(de: pasta, para: nova)
            UserDefaults.standard.set(nova.path, forKey: "pastaDados")
            abertaId = nil
            carregar()
            mostrarAviso(jaTinha ? "Usando os dados que já estavam na pasta escolhida." : "Dados copiados para a nova pasta.")
        } catch {
            erro("Não foi possível usar essa pasta", error.localizedDescription)
        }
    }

    private func salvarArquivo(nome: String, conteudo: Data, aviso texto: String) {
        let p = NSSavePanel()
        p.nameFieldStringValue = nome
        p.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard p.runModal() == .OK, let url = p.url else { return }
        do {
            try conteudo.write(to: url, options: .atomic)
            mostrarAviso(texto)
        } catch {
            erro("Não foi possível salvar o arquivo", error.localizedDescription)
        }
    }

    // MARK: Diálogos

    func confirmar(_ mensagem: String, _ detalhe: String = "", botao: String = "OK", destrutivo: Bool = false) -> Bool {
        let a = NSAlert()
        a.messageText = mensagem
        a.informativeText = detalhe
        a.alertStyle = destrutivo ? .warning : .informational
        let b = a.addButton(withTitle: botao)
        b.hasDestructiveAction = destrutivo
        a.addButton(withTitle: "Cancelar")
        return a.runModal() == .alertFirstButtonReturn
    }

    func erro(_ mensagem: String, _ detalhe: String = "") {
        let a = NSAlert()
        a.messageText = mensagem
        a.informativeText = detalhe
        a.alertStyle = .warning
        a.runModal()
    }
}
