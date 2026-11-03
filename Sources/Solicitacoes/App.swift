import AppKit
import SwiftUI
import SolicitacoesCore

@main
struct SolicitacoesApp: App {
    @NSApplicationDelegateAdaptor(Delegado.self) var delegado
    @StateObject var modelo = Modelo()

    var body: some Scene {
        Window("Solicitações", id: "principal") {
            Principal()
                .environmentObject(modelo)
                .environment(\.locale, Locale(identifier: "pt_BR"))
                .frame(minWidth: 1000, minHeight: 640)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    modelo.gravarAgora()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
                    modelo.gravarAgora()
                }
        }
        .defaultSize(width: 1280, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Nova solicitação") { modelo.novaSolicitacao() }.keyboardShortcut("n")
                Button("Novo paciente") { modelo.tela = .pacientes; NotificationCenter.default.post(name: .novoPaciente, object: nil) }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
            }
            CommandGroup(after: .importExport) {
                Button("Exportar planilha…") { modelo.exportarPlanilha() }.keyboardShortcut("e", modifiers: [.command, .shift])
                Divider()
                Button("Exportar backup…") { modelo.exportarBackup() }
                Button("Importar backup…") { modelo.importarBackup() }
            }
            CommandMenu("Ir") {
                Button("Painel") { modelo.abertaId = nil; modelo.tela = .painel }.keyboardShortcut("1")
                Button("Solicitações") { modelo.abertaId = nil; modelo.tela = .solicitacoes }.keyboardShortcut("2")
                Button("Pacientes") { modelo.tela = .pacientes }.keyboardShortcut("3")
                Button("Convênios") { modelo.tela = .convenios }.keyboardShortcut("4")
            }
        }

        Settings {
            Ajustes()
                .environmentObject(modelo)
                .environment(\.locale, Locale(identifier: "pt_BR"))
        }
    }
}

final class Delegado: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

extension Notification.Name {
    static let novoPaciente = Notification.Name("novoPaciente")
}

struct Principal: View {
    @EnvironmentObject var m: Modelo

    var body: some View {
        NavigationSplitView {
            List(selection: Binding(get: { m.tela }, set: { m.tela = $0; m.abertaId = nil })) {
                Label("Painel", systemImage: "square.grid.2x2").tag(Tela.painel)
                Label("Solicitações", systemImage: "doc.text.magnifyingglass")
                    .badge(m.quantidadeAlertasAltos)
                    .tag(Tela.solicitacoes)
                Label("Pacientes", systemImage: "person.2").tag(Tela.pacientes)
                Label("Convênios", systemImage: "building.2").tag(Tela.convenios)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 200, max: 260)
            .safeAreaInset(edge: .bottom) {
                if !m.dados.config.nomeClinica.isEmpty {
                    Text(m.dados.config.nomeClinica)
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
            }
        } detail: {
            Group {
                switch m.tela ?? .painel {
                case .painel: Painel()
                case .solicitacoes:
                    if let id = m.abertaId, m.solicitacao(id) != nil { EditorSolicitacao(id: id).id(id) } else { ListaSolicitacoes() }
                case .pacientes: Pacientes()
                case .convenios: Convenios()
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { m.novaSolicitacao() } label: { Label("Nova solicitação", systemImage: "plus") }
                        .help("Nova solicitação (⌘N)")
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let aviso = m.aviso {
                Text(aviso)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(radius: 4)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}
