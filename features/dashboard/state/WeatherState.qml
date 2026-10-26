pragma Singleton

import QtQuick
import Quickshell
import qs.core.config
import qs.core.format
import qs.core.widgets
import qs.services

// View model da aba Clima.
Singleton {
    id: root

    readonly property var locale: Qt.locale("pt_BR")
    readonly property bool offline: Config.offline
    readonly property bool fahrenheit: Config.temperatureUnit === "f"

    // A Open-Meteo responde em °C e km/h; a conversão é feita aqui.
    function temperature(celsius: real): string {
        return `${Math.round(fahrenheit ? celsius * 9 / 5 + 32 : celsius)}°`;
    }

    function speed(kmh: real): string {
        return Config.windUnit === "ms" ? `${Format.number(kmh / 3.6, 1)} m/s` : `${Math.round(kmh)} km/h`;
    }
    readonly property bool hasLocation: Weather.location !== null
    readonly property string place: Weather.location?.name ?? ""
    readonly property bool loading: Weather.loading
    readonly property string error: Weather.error
    readonly property var c: Weather.current
    readonly property bool hasData: c !== null

    readonly property string icon: hasData ? Icons.forWeather(c.code, c.isDay) : Icons.weather
    readonly property string temp: hasData ? temperature(c.temp) : "—"
    readonly property string condition: hasData ? describe(c.code) : ""
    readonly property string feels: hasData ? `Sensação de ${temperature(c.feels)}` : ""
    readonly property string humidity: hasData ? `${c.humidity}%` : "—"
    readonly property string wind: hasData ? speed(c.wind) : "—"
    readonly property string rainChance: "—"
    readonly property string updated: Weather.updatedAt ? `Atualizado às ${Qt.formatTime(Weather.updatedAt, "HH:mm")}` : ""

    // Sem previsão por hora até a aba Clima nova.
    readonly property var hourly: []

    // Faixa de temperatura da semana, para desenhar as barras min–max na mesma escala.
    readonly property real weekMin: Math.min(...Weather.daily.map(d => d.min))
    readonly property real weekMax: Math.max(...Weather.daily.map(d => d.max))
    readonly property var daily: Weather.daily.map((d, i) => ({
        day: i === 0 ? "Hoje" : Format.capitalize(new Date(`${d.date}T12:00:00`).toLocaleDateString(locale, "ddd").replace(".", "")),
        icon: Icons.forWeather(d.code, true),
        min: temperature(d.min),
        max: temperature(d.max),
        rain: d.rainChance >= 20 ? `${d.rainChance}%` : "",
        from: (d.min - weekMin) / Math.max(1, weekMax - weekMin),
        to: (d.max - weekMin) / Math.max(1, weekMax - weekMin)
    }))

    function search(name: string): void {
        Weather.search(name);
    }

    function refresh(): void {
        Weather.refresh();
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
}
