glob JsNull: any = globalThis.JSON.parse("null");

def rx(pattern: str, flags: str = "") -> any {
    return new(globalThis.RegExp, pattern, flags);
}

def sub(text: str, pattern: str, to: any, flags: str = "g") -> str {
    return globalThis.String.prototype.replace.call(text, rx(pattern, flags), to);
}

def found(text: str, pattern: str, flags: str = "") -> bool {
    return rx(pattern, flags).test(text);
}
