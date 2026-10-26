#!/usr/bin/env python3
"""O servidor falso de letras e clima da fumaça (ci/smoke.sh).

Responde no lugar da LRCLIB e do Open-Meteo, com respostas fixas, num porto
livre de 127.0.0.1; o lucernad chega aqui pelo LUCERNAD_WEB_BASE
(http://127.0.0.1:<porto>), com as fontes em /lrclib, /forecast e /geocoding.
Nada sai para a internet. Só a biblioteca padrão; roda com `python3 -I`.

  ci/web-fake.py <arquivo-do-porto>

Grava o porto escolhido no arquivo (escrita atômica: quem espera o arquivo
nunca lê um porto pela metade) e escreve uma linha por pedido em stderr.

- GET /lrclib/api/get: a faixa "Canção da Fumaça" de "Lucerna" → 200 com o LRC
  sincronizado de quatro linhas, uma a cada 5 s; o resto → 404 TrackNotFound.
- GET /lrclib/api/search → [].
- GET /forecast/v1/forecast → a previsão de 7 dias, com as datas a partir de
  hoje no fuso da cidade (UTC-4, o de Rondônia).
- GET /geocoding/v1/search: `name` começando por "Cacau" → três cidades
  (Cacaulândia/RO primeiro); o resto → {} (sem `results`, como o Open-Meteo).
- Qualquer outro caminho → 404.
"""

import datetime
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit

TRACK = "Canção da Fumaça"
ARTIST = "Lucerna"
SYNCED = "\n".join(
    [
        "[00:00.00]Acende a lanterna no meio da fumaça",
        "[00:05.00]O painel abre e a letra vem junto",
        "[00:10.00]Nada sai daqui, a rede é de teste",
        "[00:15.00]E o clima de Cacaulândia diz que vai chover",
    ]
)
UTC_OFFSET = -4 * 3600

CITIES = [
    {
        "id": 3954177,
        "name": "Cacaulândia",
        "latitude": -10.3375,
        "longitude": -62.8986,
        "country_code": "BR",
        "country": "Brasil",
        "admin1": "Rondônia",
    },
    {
        "id": 3402592,
        "name": "Cacau Pirêra",
        "latitude": -3.1708,
        "longitude": -60.0786,
        "country_code": "BR",
        "country": "Brasil",
        "admin1": "Amazonas",
    },
    {
        "id": 3468001,
        "name": "Cacaueira",
        "latitude": -14.7861,
        "longitude": -39.2797,
        "country_code": "BR",
        "country": "Brasil",
        "admin1": "Bahia",
    },
]


def lyrics_entry():
    """A entrada da LRCLIB para a faixa da fumaça (o mpv toca 20 s)."""
    plain = "\n".join(line.split("]", 1)[1] for line in SYNCED.splitlines())
    return {
        "id": 1,
        "trackName": TRACK,
        "artistName": ARTIST,
        "albumName": "",
        "duration": 20.0,
        "instrumental": False,
        "plainLyrics": plain,
        "syncedLyrics": SYNCED,
    }


def forecast():
    """A previsão de 7 dias (os números do Formato no primeiro dia), com as
    datas a partir de hoje na hora local da cidade."""
    today = (datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(seconds=UTC_OFFSET)).date()
    dates = [(today + datetime.timedelta(days=i)).isoformat() for i in range(7)]
    return {
        "latitude": -10.3375,
        "longitude": -62.8986,
        "timezone": "America/Porto_Velho",
        "utc_offset_seconds": UTC_OFFSET,
        "current": {
            "time": f"{dates[0]}T14:00",
            "temperature_2m": 31.2,
            "apparent_temperature": 35.0,
            "relative_humidity_2m": 58,
            "wind_speed_10m": 7.6,
            "weather_code": 2,
            "is_day": 1,
        },
        "daily": {
            "time": dates,
            "weather_code": [95, 80, 3, 2, 61, 1, 0],
            "temperature_2m_max": [33.4, 32.1, 31.8, 33.0, 30.2, 32.6, 34.1],
            "temperature_2m_min": [22.1, 22.8, 21.9, 22.4, 21.5, 22.0, 23.2],
            "precipitation_probability_max": [80, 65, 20, 10, 55, 5, 0],
            "sunrise": [f"{d}T05:41" for d in dates],
            "sunset": [f"{d}T18:03" for d in dates],
        },
    }


class Handler(BaseHTTPRequestHandler):
    server_version = "lucerna-web-fake/1"

    def reply(self, status, body):
        data = json.dumps(body, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        url = urlsplit(self.path)
        query = {k: v[0] for k, v in parse_qs(url.query).items()}
        if url.path == "/lrclib/api/get":
            if query.get("track_name") == TRACK and query.get("artist_name") == ARTIST:
                self.reply(200, lyrics_entry())
            else:
                self.reply(
                    404,
                    {"statusCode": 404, "name": "TrackNotFound", "message": "Failed to find specified track"},
                )
        elif url.path == "/lrclib/api/search":
            self.reply(200, [])
        elif url.path == "/forecast/v1/forecast":
            self.reply(200, forecast())
        elif url.path == "/geocoding/v1/search":
            if query.get("name", "").casefold().startswith("cacau"):
                self.reply(200, {"results": CITIES, "generationtime_ms": 0.1})
            else:
                self.reply(200, {})
        else:
            self.reply(404, {"error": True, "reason": "Not Found"})


def main():
    if len(sys.argv) != 2:
        print("uso: ci/web-fake.py <arquivo-do-porto>", file=sys.stderr)
        return 2
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    server.daemon_threads = True
    port_file = sys.argv[1]
    tmp = f"{port_file}.tmp"
    with open(tmp, "w") as f:
        f.write(f"{server.server_address[1]}\n")
    os.replace(tmp, port_file)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
