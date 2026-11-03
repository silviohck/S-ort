// swift-tools-version:5.9
import PackageDescription

// SolicitacoesCore: regras e gravação dos dados (só Foundation, testável em qualquer sistema).
// Solicitacoes: o app em SwiftUI (só compila no macOS).
var targets: [Target] = [
    .target(name: "SolicitacoesCore"),
    .testTarget(name: "SolicitacoesCoreTests", dependencies: ["SolicitacoesCore"]),
]
#if os(macOS)
targets.append(.executableTarget(name: "Solicitacoes", dependencies: ["SolicitacoesCore"]))
#endif

let package = Package(
    name: "Solicitacoes",
    platforms: [.macOS(.v13)],
    targets: targets
)
