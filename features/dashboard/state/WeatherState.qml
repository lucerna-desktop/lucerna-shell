pragma Singleton

import QtQuick
import Quickshell
import qs.core.config
import qs.core.format
import qs.core.panels
import qs.core.widgets
import qs.services

// View model da aba Clima: o que o Weather recebe do lucernad, em texto para a
// tela (a cidade, a data de hoje, os cards, os sete dias e o aviso do rodapé).
// As datas AAAA-MM-DD viram datas locais pelo localDate; os dias se chamam
// pela data, nunca pela posição: a previsão de ontem guardada não vira "Hoje".
Singleton {
    id: root

    readonly property var locale: Qt.locale("pt_BR")
    readonly property bool fahrenheit: Config.temperatureUnit === "f"

    readonly property bool available: Web.available
    readonly property bool hasLocation: Config.weatherLocation !== null
    readonly property string city: String(Config.weatherLocation?.name ?? "").split(",")[0].trim()

    // A data local de hoje (AAAA-MM-DD); o relógio a mantém certa depois da
    // meia-noite. Não é readonly: os testes a põem à mão.
    property string todayKey: dateKey(new Date())
    // Agora, em ms, a cada minuto: refaz o updatedNote (a previsão envelhece).
    property real now: Date.now()

    readonly property string today: Format.capitalize(localDate(todayKey).toLocaleDateString(locale, "dddd, d 'de' MMMM"))
    readonly property string sunrise: Weather.sunrise || "--:--"
    readonly property string sunset: Weather.sunset || "--:--"

    readonly property var c: Weather.current
    readonly property bool hasData: c !== null
    readonly property string icon: hasData ? Icons.forWeather(c.code, c.isDay) : Icons.weather
    readonly property string temp: hasData ? temperature(c.temp) : "—"
    readonly property string condition: hasData ? describe(c.code) : ""
    readonly property string humidity: hasData ? `${c.humidity}%` : "—"
    readonly property string feels: hasData ? temperature(c.feels) : "—"
    readonly property string wind: hasData ? speed(c.wind) : "—"

    readonly property var days: Array.from(Weather.daily).map(d => ({
        label: dayLabel(d.date, todayKey),
        date: shortDate(d.date),
        icon: Icons.forWeather(d.code, true),
        range: `${temperature(d.min)} / ${temperature(d.max)}`
    }))

    // O aviso do rodapé: por que o que se vê pode estar velho (ou faltar).
    readonly property string notice: {
        if (!Web.available)
            return Web.unavailableNote;
        if (Config.offline)
            return "Modo offline: sem atualização";
        if (!Web.online)
            return "Sem internet: mostrando a última previsão";
        if (Weather.state === "error")
            return Weather.error;
        if (Weather.state === "loading" && !hasData)
            return "Buscando a previsão…";
        return "";
    }

    // O aviso com a hora da previsão: no modo offline os dois aparecem juntos.
    readonly property string footnote: {
        if (Config.offline && notice !== "" && updatedNote !== "")
            return `${notice} · ${updatedNote}`;
        return notice || updatedNote;
    }

    // A hora da previsão, só quando ela está velha ou a última busca falhou.
    readonly property string updatedNote: {
        const at = Weather.updatedAt;
        // Lê o `now`: refaz a cada minuto, quando a previsão envelhece.
        if (!at || now <= 0)
            return "";
        if (!Weather.isStale() && Weather.state !== "error")
            return "";
        return `Atualizado às ${Qt.formatTime(at, "HH:mm")}`;
    }

    // A Open-Meteo responde em °C e km/h; a conversão é feita aqui.
    function temperature(celsius: real): string {
        return `${Math.round(fahrenheit ? celsius * 9 / 5 + 32 : celsius)}°`;
    }

    function speed(kmh: real): string {
        return Config.windUnit === "ms" ? `${Format.number(kmh / 3.6, 1)} m/s` : `${Math.round(kmh)} km/h`;
    }

    // Date → "AAAA-MM-DD" pela hora local.
    function dateKey(date: var): string {
        const pad = n => String(n).padStart(2, "0");
        return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
    }

    // "AAAA-MM-DD" → a meia-noite local desse dia. Nunca new Date("AAAA-MM-DD"):
    // é meia-noite UTC, que a oeste de Greenwich cai no dia anterior.
    function localDate(date: string): var {
        const [y, m, d] = String(date).split("-").map(Number);
        return new Date(y, m - 1, d);
    }

    // "Hoje" pela data; senão o dia da semana abreviado: "Dom".
    function dayLabel(date: string, today: string): string {
        if (date === today)
            return "Hoje";
        return Format.capitalize(localDate(date).toLocaleDateString(locale, "ddd").replace(".", ""));
    }

    // "2026-10-25" → "25 out".
    function shortDate(date: string): string {
        return localDate(date).toLocaleDateString(locale, "d MMM").replace(".", "");
    }

    function openSettings(): void {
        Config.settingsTopic = "dashboard";
        Panels.open("settings");
    }

    // Código de tempo WMO → descrição.
    function describe(code: int): string {
        const table = {
            0: "Céu limpo", 1: "Quase limpo", 2: "Parcialmente nublado", 3: "Nublado",
            45: "Neblina", 48: "Neblina com geada",
            51: "Garoa fraca", 53: "Garoa", 55: "Garoa forte", 56: "Garoa congelante", 57: "Garoa congelante forte",
            61: "Chuva fraca", 63: "Chuva", 65: "Chuva forte", 66: "Chuva congelante", 67: "Chuva congelante forte",
            71: "Neve fraca", 73: "Neve", 75: "Neve forte", 77: "Grãos de neve",
            80: "Pancadas fracas", 81: "Pancadas de chuva", 82: "Pancadas fortes",
            85: "Pancadas de neve", 86: "Pancadas de neve fortes",
            95: "Trovoadas", 96: "Trovoadas com granizo", 99: "Trovoadas com granizo forte"
        };
        return table[code] ?? "—";
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            root.todayKey = root.dateKey(new Date());
            root.now = Date.now();
        }
    }
}
