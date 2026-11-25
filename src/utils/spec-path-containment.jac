import from "fs" { default as nodeFs }
import from "path" { default as path }

def:priv findProjectRoot(specsRoot: str) -> any {
    current = path.resolve(specsRoot);
    below: any = None;
    while True {
        parent = path.dirname(current);
        if parent == current {
            return None;
        }
        if path.basename(current) == OPENSPEC_DIR_NAME and below in ["specs", "changes"] {
            return parent;
        }
        below = path.basename(current);
        current = parent;
    }
}

def:priv isLexicallyWithin(allowedDirectory: str, targetPath: str) -> bool {
    relative: str = path.relative(path.resolve(allowedDirectory), path.resolve(targetPath));
    return relative == ""
        or (
            relative != ".."
            and not relative.startswith(f"..{path.sep}")
            and not path.isAbsolute(relative)
        );
}

def:priv isLink(file: str) -> bool {
    try {
        return nodeFs.lstatSync(file).isSymbolicLink();
    } except Exception {
        return False;
    }
}

def:priv assertLinkedSpecFileInProject(base: str, specFile: str, outsideError: any) {
    projectRoot = findProjectRoot(base);
    resolvedFile = path.resolve(specFile);
    if projectRoot is None or not isLink(resolvedFile) {
        raise outsideError;
    }
    FileSystemUtils.assertPathWithin(base, path.dirname(resolvedFile));
    FileSystemUtils.assertPathWithin(projectRoot, resolvedFile);
}

def assertSpecFileWithin(base: str, specFile: str) {
    try {
        FileSystemUtils.assertPathWithin(base, specFile);
    } except Exception as e {
        assertLinkedSpecFileInProject(base, specFile, js_error(e));
    }
}

def assertDiscoveredSpecFile(specsRoot: str, specFile: str) {
    capabilityDir = path.dirname(path.resolve(specFile));
    try {
        FileSystemUtils.assertPathWithin(specsRoot, specFile);
        return;
    } except Exception as e {
        if isLexicallyWithin(specsRoot, capabilityDir) {
            try {
                FileSystemUtils.assertPathWithin(capabilityDir, specFile);
                return;
            } except Exception {}
        }
        assertLinkedSpecFileInProject(specsRoot, specFile, js_error(e));
    }
}
