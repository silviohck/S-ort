import Foundation

/// Datas do dia sempre como texto "AAAA-MM-DD", sem fuso horário.
public enum Datas {
    private static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private static func partes(_ iso: String) -> (Int, Int, Int)? {
        let p = iso.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return (p[0], p[1], p[2])
    }

    private static func dataUTC(_ iso: String) -> Date? {
        guard let (a, m, d) = partes(iso) else { return nil }
        return utc.date(from: DateComponents(year: a, month: m, day: d))
    }

    private static func isoUTC(_ d: Date) -> String {
        let c = utc.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    /// Dia de hoje no fuso do computador
    public static func hoje() -> String { isoLocal(Date()) }

    /// Converte um instante para o dia no fuso do computador
    public static func isoLocal(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    /// Meio-dia do dia no fuso do computador (para seletores de data)
    public static func dataLocal(_ iso: String) -> Date {
        guard let (a, m, d) = partes(iso) else { return Date() }
        return Calendar.current.date(from: DateComponents(year: a, month: m, day: d, hour: 12)) ?? Date()
    }

    public static func somarDias(_ iso: String, _ n: Int) -> String {
        guard let d = dataUTC(iso), let r = utc.date(byAdding: .day, value: n, to: d) else { return iso }
        return isoUTC(r)
    }

    /// b - a, em dias
    public static func diferenca(_ a: String, _ b: String) -> Int {
        guard let da = dataUTC(a), let db = dataUTC(b) else { return 0 }
        return utc.dateComponents([.day], from: da, to: db).day ?? 0
    }

    public static func pascoa(_ ano: Int) -> String {
        let a = ano % 19, b = ano / 100, c = ano % 100
        let d = b / 4, e = b % 4, f = (b + 8) / 25
        let g = (b - f + 1) / 3, h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let mes = (h + l - 7 * m + 114) / 31, dia = ((h + l - 7 * m + 114) % 31) + 1
        return String(format: "%04d-%02d-%02d", ano, mes, dia)
    }

    public static func feriadosNacionais(_ ano: Int) -> Set<String> {
        var s = Set(["01-01", "04-21", "05-01", "09-07", "10-12", "11-02", "11-15", "11-20", "12-25"].map { "\(ano)-\($0)" })
        s.insert(somarDias(pascoa(ano), -2)) // Sexta-feira Santa
        return s
    }

    public static func diaUtil(_ iso: String, extras: [String] = []) -> Bool {
        guard let d = dataUTC(iso), let (ano, _, _) = partes(iso) else { return false }
        let semana = utc.component(.weekday, from: d) // 1 = domingo, 7 = sábado
        if semana == 1 || semana == 7 { return false }
        if feriadosNacionais(ano).contains(iso) { return false }
        return !extras.contains(iso)
    }

    /// Conta n dias úteis a partir do dia seguinte a `inicio`
    public static func somarDiasUteis(_ inicio: String, _ n: Int, extras: [String] = []) -> String {
        var d = inicio
        var restantes = n
        while restantes > 0 {
            d = somarDias(d, 1)
            if diaUtil(d, extras: extras) { restantes -= 1 }
        }
        return d
    }

    /// "2026-11-03" → "03/11/2026"
    public static func formatar(_ iso: String) -> String {
        guard let (a, m, d) = partes(iso) else { return "" }
        return String(format: "%02d/%02d/%04d", d, m, a)
    }

    /// "03/11/2026" → "2026-11-03"
    public static func deTexto(_ s: String) -> String? {
        let p = s.trimmingCharacters(in: .whitespaces).split(separator: "/").compactMap { Int($0) }
        guard p.count == 3, (1...31).contains(p[0]), (1...12).contains(p[1]), p[2] > 1900 else { return nil }
        return String(format: "%04d-%02d-%02d", p[2], p[1], p[0])
    }

    /// Instante no formato ISO 8601 (UTC), usado no histórico
    public static func carimbo(_ d: Date = Date()) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: d)
    }

    public static func deCarimbo(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    /// "03/11/2026 14:05" no fuso do computador
    public static func formatarCarimbo(_ s: String) -> String {
        guard let d = deCarimbo(s) else { return s }
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "dd/MM/yyyy HH:mm"
        return f.string(from: d)
    }
}
