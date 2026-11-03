# Solicitações

App para **Mac** (Intel e Apple Silicon, macOS 13 Ventura ou mais recente) para acompanhar solicitações de
**exames, procedimentos, terapias, cirurgias/internações e OPME**, por **plano de saúde** ou **particular**.

Feito em Swift e SwiftUI, com as telas e controles do próprio macOS. Não embute navegador: o instalador tem poucos MB.

## Instalar

1. Baixe **`Solicitacoes-x.y.z-mac.dmg`** em https://github.com/silviohck/S-ort/releases/latest
2. Abra o `.dmg` e arraste **Solicitações** para **Aplicativos**.
3. Na primeira vez o Mac avisa que não pode verificar o desenvolvedor (o app ainda não tem a assinatura paga da Apple):
   abra **Ajustes do Sistema → Privacidade e Segurança** e clique em **Abrir mesmo assim**.
4. Se aparecer "está danificado e não pode ser aberto", rode no Terminal `xattr -cr /Applications/Solicitações.app`.

## O que faz

- **Painel**: em aberto, a enviar, aguardando a operadora, pendências, autorizadas a agendar e prazo vencido; lista do que
  precisa de atenção e dos próximos agendamentos.
- **Solicitações**: tabela com busca (sem precisar de acento) e filtros por status, tipo e convênio, ou **quadro** em que
  se arrasta o cartão para mudar o status. Exporta planilha (CSV para Excel/Numbers).
- **Ficha**: paciente, convênio, tipo, caráter, procedimento, código TUSS, CID, médico, local, protocolo, guia, senha e
  validade, datas de envio, resposta, agendamento e realização. Nas particulares: valor, forma e situação do pagamento.
- **Status** com **histórico** (data, hora e observação de cada mudança) e registro de contatos.
- **Prazo em dias úteis** a partir do envio (fins de semana, feriados nacionais e locais). Prazos por tipo da ANS
  (RN 566/2022), editáveis nos Ajustes (⌘,) ou em cada solicitação.
- **Alertas**: prazo vencendo/vencido, senha vencendo, pendência, retorno, agendamento que passou, pagamento em aberto.
- **Anexos**: arraste pedidos, laudos e guias para a ficha.
- **Imprimir ficha** (⌘P), também dá para salvar em PDF pelo diálogo de impressão.

Atalhos: ⌘N nova solicitação, ⇧⌘N novo paciente, ⌘1–⌘4 telas, ⌘[ voltar, ⇧⌘E exportar planilha.

## Onde ficam os dados

Em `~/Library/Application Support/Solicitações/dados/`: `dados.json`, a pasta `anexos/` e uma cópia diária em
`backups/` (as 30 mais recentes). Nos Ajustes dá para trocar a pasta (ex.: iCloud Drive), exportar e importar backup.
Se outro Mac gravar na mesma pasta, o app avisa e recarrega em vez de sobrescrever.

## Desenvolvimento

```
Sources/SolicitacoesCore/   regras (prazos, alertas, busca), modelos e gravação — só Foundation
Sources/Solicitacoes/       telas em SwiftUI
Tests/                      testes das regras e da gravação (+ dados de exemplo)
scripts/empacotar.sh        gera o .app e o .dmg
VERSAO                      número da versão (aumente para publicar uma nova)
```

```bash
swift test                 # testes (funciona também em Linux)
swift run Solicitacoes     # abre o app (num Mac)
./scripts/empacotar.sh     # gera dist/Solicitacoes-<versão>-mac.dmg (num Mac com Xcode)
```

O GitHub Actions roda os testes, gera o `.dmg` e publica na página de versões a cada envio para `main`.
