import from "node:readline" { createInterface }
import from "node:process" { default as process }

type InteractiveOptions = any;

glob:priv lazyImport: any = new(globalThis.Function, "specifier", "return import(specifier)");

def resolveNoInteractive(value: any = None) -> bool {
    if kind(value) == "boolean" {
        return value;
    }
    return at(value, "noInteractive") is True or at(value, "interactive") is False;
}

def isInteractive(value: any = None) -> bool {
    return not (
        resolveNoInteractive(value)
        or process.env["OPEN_SPEC_INTERACTIVE"] == "0"
        or owns(process.env, "CI")
    )
        and truthy(process.stdin["isTTY"]);
}

def isNonInteractivePromptError(error: any, value: any = None) -> bool {
    if not isinstance(error, globalThis.Error) {
        return False;
    }
    message: str = error.message;
    return (error.name == "ExitPromptError" or "force closed the prompt" in message)
        and "SIGINT" not in message
        and (not isInteractive(value) or not truthy(process.stdout["isTTY"]));
}

async def confirmPrompt(prompt: any, io: any = None) -> bool {
    source = at(io, "input") ?? process.stdin;
    sink = at(io, "output") ?? process.stdout;
    if truthy(source["isTTY"]) and truthy(sink["isTTY"]) {
        return await (await lazyImport("@inquirer/prompts")).confirm(prompt);
    }
    return await readYesNo(prompt, source, sink);
}

def:priv readYesNo(prompt: any, source: any, sink: any) -> any {
    def run(resolve: any, reject: any) {
        settled = False;
        rl: any = None;
        def settle -> bool {
            if settled {
                return False;
            }
            settled = True;
            source.removeListener("error", onError);
            return True;
        }
        def blockOnNoAnswer {
            if settle() {
                error = new(globalThis.Error, "User force closed the prompt");
                error.name = "ExitPromptError";
                reject(error);
            }
        }
        def onError(err: any) {
            if settle() {
                rl.close();
                reject(
                    err
                        if isinstance(err, globalThis.Error)
                        else new(globalThis.Error, globalThis.String(err)),
                );
            }
        }
        def onLine(line: any) {
            if settle() {
                rl.close();
                sink.write("\n");
                first = line.trim()[:1].lower();
                resolve(True if first == "y" else False if first == "n" else prompt["default"]);
            }
        }
        if source["readableEnded"] {
            blockOnNoAnswer();
            return;
        }
        sink.write(f"{prompt.message} {'(Y/n)' if prompt['default'] else '(y/N)'} ");
        rl = createInterface(rec(input=source, terminal=False));
        source.once("error", onError);
        rl.once("error", onError);
        rl.once("line", onLine);
        rl.once("close", blockOnNoAnswer);
    }
    return new(globalThis.Promise, run);
}

def canRenderSpinner(stream: any = None) -> bool {
    target = stream ?? process.stderr;
    return not truthy(target["isTTY"]) or (target["columns"] ?? 0) > 0;
}
