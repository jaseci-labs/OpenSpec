glob JsNull: any = globalThis.JSON.parse("null");

def rec(**fields: any) -> any {
    return globalThis.Object.fromEntries(list(fields.items()));
}

def merge(*parts: any) -> any {
    return globalThis.Object.assign(rec(), *parts);
}

def js_error(e: any) -> any {
    return getattr(e, "js", e);
}

def rx(pattern: str, flags: str = "") -> any {
    return new(globalThis.RegExp, pattern, flags);
}

def sub(text: str, pattern: str, to: any, flags: str = "g") -> str {
    return globalThis.String.prototype.replace.call(text, rx(pattern, flags), to);
}

def found(text: str, pattern: str, flags: str = "") -> bool {
    return rx(pattern, flags).test(text);
}

def missing(value: any) -> bool {
    return value is None or value is JsNull;
}

def at(value: any, *keys: str) -> any {
    for key in keys {
        if missing(value) {
            return None;
        }
        value = value[key];
    }
    return value;
}
