type StoreDiagnosticSeverity = any;

type StoreDiagnostic = any;

obj StoreError(globalThis.Error) {
    def init(message: str, code: str, options: any = None) {
        super.init(message);
        self.name = "StoreError";
        self.diagnostic = makeStoreDiagnostic("error", code, message, options);
    }
}

def makeStoreDiagnostic(severity: str, code: str, message: str, options: any = None) -> any {
    return merge(rec(severity=severity, code=code, message=message), options);
}
