glob JsNull: any = globalThis.JSON.parse("null");

def rec(**fields: any) -> any {
    return globalThis.Object(fields);
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

glob:priv madePatterns: dict[str, dict[str, any]] = {};

def:priv madeRx(pattern: any, flags: str) -> any {
    if not isinstance(pattern, str) {
        return new(globalThis.RegExp, pattern, flags);
    }
    byFlags = madePatterns.get(flags);
    if byFlags is None {
        byFlags = {};
        madePatterns[flags] = byFlags;
    }
    made = byFlags.get(pattern);
    if made is None {
        made = rx(pattern, flags);
        byFlags[pattern] = made;
    } elif "g" in flags or "y" in flags {
        made.lastIndex = 0;
    }
    return made;
}

def sub(text: str, pattern: str, to: any, flags: str = "g") -> str {
    return globalThis.String.prototype.replace.call(text, madeRx(pattern, flags), to);
}

def splitBy(text: any, pattern: str) -> any {
    return globalThis.String.prototype.split.call(text, madeRx(pattern, ""));
}

def found(text: str, pattern: str, flags: str = "") -> bool {
    return globalThis.RegExp.prototype.test.call(madeRx(pattern, flags), text);
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

glob:priv typeOf: any = new(globalThis.Function, "x", "return typeof x"),
          truthyOf: any = new(globalThis.Function, "x", "return !!x"),
          sameOf: any = new(globalThis.Function, "a", "b", "return a === b");

def kind(value: any) -> str {
    return typeOf(value);
}

def truthy(value: any) -> bool {
    return truthyOf(value);
}

def same(a: any, b: any) -> bool {
    return sameOf(a, b);
}

def owns(target: any, key: str) -> bool {
    return not missing(target) and globalThis.Object.hasOwn(target, key);
}

def promise(work: any) -> any {
    return globalThis.Promise.resolve().then(lambda -> any { work });
}

def matchOf(text: str, pattern: str, flags: str = "") -> any {
    return globalThis.RegExp.prototype.exec.call(madeRx(pattern, flags), text);
}

def unique(items: any) -> list[any] {
    return globalThis.Array.from(new(globalThis.Set, items));
}

def trim(s: any) -> str {
    if isinstance(s, str) {
        return globalThis.String.prototype.trim.call(s);
    }
    return s.trim();
}

def rtrim(s: any) -> str {
    if isinstance(s, str) {
        return globalThis.String.prototype.trimEnd.call(s);
    }
    return s.trimEnd();
}

def fail(message: str) -> any {
    return new(globalThis.Error, message);
}

def messageOf(error: any) -> str {
    err = js_error(error);
    return err.message if globalThis.Error.prototype.isPrototypeOf(err) else globalThis.String(err);
}

def linkOf(view: any, p: str) -> any {
    return None if missing(view["linkTarget"]) else view.linkTarget(p);
}

def jsAsync(C: any, names: list[str]) {
    new(
        globalThis.Function,
        "C",
        "names",
        "for (const k of names) { const f = C.prototype[k]; C.prototype[k] = function (...a) { return f.apply(this, a).then(); }; }",
    )(C, names);
}
