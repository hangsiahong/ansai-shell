pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Open-Meteo weather for the city in Settings.weatherCity (off when empty). No key; only the city name and
// its coordinates leave the machine. Refreshes every 30 minutes while a city is set.
Singleton {
    id: root
    readonly property bool enabled: (Settings.weatherCity ?? "").trim() !== ""
    property string place: ""
    property var current: null   // { temp, code, day }
    property var days: []        // [{ date, max, min, code }]
    property string error: ""

    function refresh(): void {
        if (!enabled) { current = null; days = []; place = ""; return; }
        if (!fetch.running) fetch.running = true;
    }

    // WMO weather codes -> [Material icon, label]
    function look(code: int, day: bool): var {
        if (code === 0) return [day ? "sunny" : "clear_night", "Clear"];
        if (code <= 2) return [day ? "partly_cloudy_day" : "nights_stay", "Partly cloudy"];
        if (code === 3) return ["cloud", "Cloudy"];
        if (code <= 48) return ["foggy", "Fog"];
        if (code <= 57) return ["rainy", "Drizzle"];
        if (code <= 67) return ["rainy", "Rain"];
        if (code <= 77) return ["weather_snowy", "Snow"];
        if (code <= 82) return ["rainy", "Showers"];
        if (code <= 86) return ["weather_snowy", "Snow showers"];
        return ["thunderstorm", "Thunderstorm"];
    }

    Connections {
        target: Settings
        function onWeatherCityChanged() { root.refresh(); }
    }
    Component.onCompleted: refresh()
    Timer { interval: 30 * 60 * 1000; repeat: true; running: root.enabled; onTriggered: root.refresh() }

    Process {
        id: fetch
        command: ["sh", "-c", `g=$(curl -sfG --max-time 10 https://geocoding-api.open-meteo.com/v1/search --data-urlencode "name=$1" -d count=1) || exit 1
            set -- $(printf %s "$g" | python3 -c 'import json,sys; r=json.load(sys.stdin)["results"][0]; print(r["latitude"], r["longitude"], (r["name"]+", "+r.get("country_code","")).replace(" ","_"))') || exit 2
            echo "$3"
            curl -sf --max-time 10 "https://api.open-meteo.com/v1/forecast?latitude=$1&longitude=$2&current=temperature_2m,weather_code,is_day&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=5"`,
            "sh", Settings.weatherCity ?? ""]
        stdout: StdioCollector {
            onStreamFinished: {
                const nl = text.indexOf("\n");
                try {
                    const d = JSON.parse(text.slice(nl + 1));
                    root.place = text.slice(0, nl).replace(/_/g, " ");
                    root.current = { temp: Math.round(d.current.temperature_2m), code: d.current.weather_code, day: d.current.is_day === 1 };
                    root.days = d.daily.time.map((t, i) => ({ date: t, max: Math.round(d.daily.temperature_2m_max[i]), min: Math.round(d.daily.temperature_2m_min[i]), code: d.daily.weather_code[i] }));
                    root.error = "";
                } catch (e) { root.error = "Couldn't find that city"; }
            }
        }
        onExited: code => { if (code !== 0) root.error = code === 2 ? "Couldn't find that city" : "No connection"; }
    }
}
