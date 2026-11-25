import from "node:fs" { default as fs }

def detectCompleted(artifacts: any, changeDir: str) -> any {
    return new(
        globalThis.Set,
        [a.id for a in artifacts.getAllArtifacts() if artifactOutputExists(changeDir, a.generates)]
            if fs.existsSync(changeDir)
            else [],
    );
}
