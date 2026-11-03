import AppKit
import SolicitacoesCore

/// Ficha da solicitação para imprimir (ou salvar em PDF pelo diálogo de impressão do Mac)
@MainActor
enum Impressao {
    static func imprimir(_ s: Solicitacao, modelo m: Modelo) {
        let p = m.paciente(s.pacienteId)
        let texto = NSMutableAttributedString()
        let normal: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11)]
        let negrito: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 11)]

        func titulo(_ t: String, _ tamanho: CGFloat) {
            texto.append(NSAttributedString(string: t + "\n", attributes: [.font: NSFont.boldSystemFont(ofSize: tamanho)]))
        }
        func linha(_ rotulo: String, _ valor: String) {
            guard !valor.isEmpty else { return }
            texto.append(NSAttributedString(string: rotulo + ": ", attributes: negrito))
            texto.append(NSAttributedString(string: valor + "\n", attributes: normal))
        }
        func espaco() { texto.append(NSAttributedString(string: "\n", attributes: normal)) }

        titulo(m.dados.config.nomeClinica.isEmpty ? "Solicitação" : m.dados.config.nomeClinica, 16)
        titulo("Solicitação #\(s.numero) — \(Regras.status(s.status).nome)", 13)
        espaco()
        linha("Paciente", p?.nome ?? "")
        linha("CPF", p?.cpf ?? "")
        linha("Nascimento", Datas.formatar(p?.nascimento ?? ""))
        linha("Telefone", p?.telefone ?? "")
        linha("Convênio", m.convenio(s.convenioId)?.nome ?? "")
        linha("Carteirinha", p?.carteirinha ?? "")
        espaco()
        linha("Tipo", Regras.tipo(s.tipo).nome)
        linha("Caráter", s.carater == "urgencia" ? "Urgência / emergência" : "Eletiva")
        linha("Pedido", s.descricao)
        linha("Código", s.codigo)
        linha("Quantidade", s.quantidade.map(String.init) ?? "")
        linha("CID", s.cid)
        linha("Médico solicitante", s.medico)
        linha("Local", s.local)
        espaco()
        linha("Data do pedido", Datas.formatar(s.dataPedido))
        linha("Enviada em", Datas.formatar(s.dataEnvio))
        linha("Data limite da resposta", Datas.formatar(m.dataLimite(s) ?? ""))
        linha("Protocolo", s.protocolo)
        linha("Guia", s.guia)
        linha("Senha", s.senha)
        linha("Validade da senha", Datas.formatar(s.validadeSenha))
        linha("Agendado para", Datas.formatar(s.dataAgendada))
        linha("Realizado em", Datas.formatar(s.dataRealizada))
        linha("Valor", Regras.moeda(s.valor))
        linha("Observações", s.obs)
        espaco()
        titulo("Histórico", 12)
        for h in s.historico {
            var t = Datas.formatarCarimbo(h.em) + " — "
            if h.tipo == "status" { t += "\(Regras.status(h.de ?? "").nome) → \(Regras.status(h.para ?? "").nome). " }
            t += h.texto
            texto.append(NSAttributedString(string: "• " + t + "\n", attributes: normal))
        }
        espaco()
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "dd/MM/yyyy HH:mm"
        texto.append(NSAttributedString(string: "Impresso em \(f.string(from: Date()))",
                                        attributes: [.font: NSFont.systemFont(ofSize: 9), .foregroundColor: NSColor.gray]))

        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isVerticallyCentered = false
        info.topMargin = 40; info.bottomMargin = 40; info.leftMargin = 40; info.rightMargin = 40
        let largura = info.paperSize.width - info.leftMargin - info.rightMargin
        let vista = NSTextView(frame: NSRect(x: 0, y: 0, width: largura, height: 100))
        vista.isVerticallyResizable = true
        vista.textContainer?.widthTracksTextView = true
        vista.textStorage?.setAttributedString(texto)
        vista.sizeToFit()
        let op = NSPrintOperation(view: vista, printInfo: info)
        op.jobTitle = "Solicitação \(s.numero) - \(p?.nome ?? "")"
        op.run()
    }
}
