.pragma library

// Launcher quick answers, Spotlight style: "2*(3+4)", "sqrt 2", "15% of 80", "10 km to mi", "72f in c".
// Both return "" / null when the query isn't math or a conversion, so app search runs as usual.

var FN = { sqrt: "Math.sqrt", cbrt: "Math.cbrt", sin: "Math.sin", cos: "Math.cos", tan: "Math.tan", asin: "Math.asin",
    acos: "Math.acos", atan: "Math.atan", ln: "Math.log", log: "Math.log10", log2: "Math.log2", abs: "Math.abs", exp: "Math.exp",
    round: "Math.round", floor: "Math.floor", ceil: "Math.ceil", min: "Math.min", max: "Math.max", pi: "Math.PI", e: "Math.E" };

function fmt(v) {
    if (!isFinite(v)) return "";
    if (v !== 0 && (Math.abs(v) >= 1e15 || Math.abs(v) < 1e-6)) return v.toExponential(6).replace(/\.?0+e/, "e");
    var s = String(+v.toPrecision(12));
    var p = s.split(".");
    p[0] = p[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
    return p.join(".");
}

// strict: the query started with "=", so a lone number counts too.
function calc(q, strict) {
    q = q.trim().toLowerCase().replace(/×/g, "*").replace(/÷/g, "/").replace(/,/g, "");
    if (!q || !/\d|pi/.test(q)) return "";
    if (!strict && !/[-+*/^%(]|[a-z]/.test(q.replace(/^-/, ""))) return "";
    q = q.replace(/(\d+(?:\.\d+)?)\s*%\s*of\s+/g, "($1/100)*");   // 15% of 80
    q = q.replace(/(\d+(?:\.\d+)?)%(?!\s*\d)/g, "($1/100)");       // 15% alone
    q = q.replace(/\^/g, "**");
    var bad = false;
    var js = q.replace(/[a-z][a-z0-9]*/g, function (w) {
        if (!(w in FN)) bad = true;
        return FN[w] || w;
    });
    if (bad || /[^0-9+\-*/().%\s,a-zA-Z0-9.]/.test(js)) return "";
    js = js.replace(/(Math\.\w+)\s+(\d+(?:\.\d+)?)/g, "$1($2)");     // "sqrt 2"
    js = js.replace(/(\d|\))\s*(\(|Math)/g, "$1*$2");                // 2(3+4), 2pi
    try {
        var v = Function("return (" + js + ")")();
        return typeof v === "number" ? fmt(v) : "";
    } catch (e) {
        return "";
    }
}

// [category, factor to the base unit, label, aliases...]
var UNITS = [
    ["length", 0.001, "mm", "millimeter", "millimeters", "millimetre", "millimetres"],
    ["length", 0.01, "cm", "centimeter", "centimeters", "centimetre", "centimetres"],
    ["length", 1, "m", "meter", "meters", "metre", "metres"],
    ["length", 1000, "km", "kilometer", "kilometers", "kilometre", "kilometres"],
    ["length", 0.0254, "in", "inch", "inches", "\""],
    ["length", 0.3048, "ft", "foot", "feet", "'"],
    ["length", 0.9144, "yd", "yard", "yards"],
    ["length", 1609.344, "mi", "mile", "miles"],
    ["length", 1852, "nmi", "nautical mile", "nautical miles"],
    ["mass", 1e-6, "mg", "milligram", "milligrams"],
    ["mass", 0.001, "g", "gram", "grams"],
    ["mass", 1, "kg", "kilo", "kilos", "kilogram", "kilograms"],
    ["mass", 1000, "t", "tonne", "tonnes", "ton", "tons"],
    ["mass", 0.028349523125, "oz", "ounce", "ounces"],
    ["mass", 0.45359237, "lb", "lbs", "pound", "pounds"],
    ["mass", 6.35029318, "st", "stone", "stones"],
    ["time", 0.001, "ms", "millisecond", "milliseconds"],
    ["time", 1, "s", "sec", "secs", "second", "seconds"],
    ["time", 60, "min", "mins", "minute", "minutes"],
    ["time", 3600, "h", "hr", "hrs", "hour", "hours"],
    ["time", 86400, "day", "d", "days"],
    ["time", 604800, "wk", "week", "weeks"],
    ["time", 2629800, "mo", "month", "months"],
    ["time", 31557600, "yr", "yrs", "year", "years"],
    ["data", 0.125, "bit", "bits"],
    ["data", 1, "B", "b", "byte", "bytes"],
    ["data", 1e3, "KB", "kb", "kilobyte", "kilobytes"],
    ["data", 1e6, "MB", "mb", "megabyte", "megabytes"],
    ["data", 1e9, "GB", "gb", "gigabyte", "gigabytes"],
    ["data", 1e12, "TB", "tb", "terabyte", "terabytes"],
    ["data", 1024, "KiB", "kib"],
    ["data", 1048576, "MiB", "mib"],
    ["data", 1073741824, "GiB", "gib"],
    ["data", 1099511627776, "TiB", "tib"],
    ["volume", 0.001, "mL", "ml", "milliliter", "milliliters", "millilitre", "millilitres"],
    ["volume", 1, "L", "l", "liter", "liters", "litre", "litres"],
    ["volume", 3.785411784, "gal", "gallon", "gallons"],
    ["volume", 0.946352946, "qt", "quart", "quarts"],
    ["volume", 0.473176473, "pt", "pint", "pints"],
    ["volume", 0.2365882365, "cup", "cups"],
    ["volume", 0.0295735295625, "fl oz", "floz", "fluid ounce", "fluid ounces"],
    ["volume", 0.01478676478125, "tbsp", "tablespoon", "tablespoons"],
    ["volume", 0.00492892159375, "tsp", "teaspoon", "teaspoons"],
    ["speed", 1, "m/s", "mps"],
    ["speed", 1 / 3.6, "km/h", "kmh", "kph"],
    ["speed", 0.44704, "mph"],
    ["speed", 0.514444, "kn", "knot", "knots"],
    ["area", 1, "m²", "m2", "sqm"],
    ["area", 1e6, "km²", "km2"],
    ["area", 1e4, "ha", "hectare", "hectares"],
    ["area", 4046.8564224, "acre", "acres"],
    ["area", 0.09290304, "ft²", "ft2", "sqft"],
    ["temp", 0, "°C", "c", "°c", "celsius"],
    ["temp", 0, "°F", "f", "°f", "fahrenheit"],
    ["temp", 0, "K", "k", "kelvin"]
];
var BY = {};
for (var i = 0; i < UNITS.length; i++)
    for (var j = 2; j < UNITS[i].length; j++)
        if (!(UNITS[i][j] in BY)) BY[UNITS[i][j]] = UNITS[i];

function unit(w) {
    w = w.trim();
    return BY[w] || BY[w.toLowerCase()] || null;
}
function toC(v, u) { return u === "°F" ? (v - 32) * 5 / 9 : u === "K" ? v - 273.15 : v; }
function fromC(v, u) { return u === "°F" ? v * 9 / 5 + 32 : u === "K" ? v + 273.15 : v; }

// "10 km to mi" -> { title: "6.21371 mi", sub: "10 km = 6.21371 mi" }
function convert(q) {
    var m = q.trim().match(/^(-?[\d.,]*\d)\s*([^\d\s].*?)\s+(?:to|in|as|into|=|->)\s+(.+)$/i);
    if (!m) return null;
    var v = parseFloat(m[1].replace(/,/g, ""));
    var a = unit(m[2]), b = unit(m[3]);
    if (isNaN(v) || !a || !b || a[0] !== b[0]) return null;
    var r = a[0] === "temp" ? fromC(toC(v, a[2]), b[2]) : v * a[1] / b[1];
    var out = fmt(+r.toPrecision(6)) + " " + b[2];
    return { title: out, sub: fmt(v) + " " + a[2] + " = " + out, copy: String(+r.toPrecision(6)) };
}
