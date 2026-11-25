import from "node:os" { default as os }
import from "node:process" { default as process }

def:priv log(text: str) {
    globalThis.console.log(text);
}

def:priv fail(text: str) {
    globalThis.console.error(text);
}

def:priv worksetError(message: str, code: str, target: str, fix: str) -> any {
    return StoreError(message, code, rec(target=f"workset.{target}", fix=fix));
}

def:priv readOpenerTable -> any {
    return mergeOpenerTable(getGlobalConfig()["openers"], getGlobalConfigPath());
}

def:priv openerLabel(table: any, tool: str) -> any {
    return at(findOpener(table, tool), "label") ?? tool;
}

def:priv cliOpenerDisabledError(opener: any, name: str) -> any {
    return worksetError(
        f"Opening a workset in {opener.label} is temporarily disabled while CLI-agent opening is reworked. Worksets open in an IDE for now.",
        "workset_cli_opener_disabled",
        "tool",
        f"Open in VS Code or Cursor: openspec workset open {name} --tool code",
    );
}

def launchOpenerCommand(command: any, options: any = None) -> any {
    spawnFn = at(options, "spawnFn") ?? need("cross-spawn");
    def run(resolve: any, reject: any) {
        def failed(error: any) -> any {
            return worksetError(
                f"Could not launch {command.label}: {asErrorMessage(error)}",
                "workset_launch_failed",
                "tool",
                f"Check that '{command.executable}' runs from this terminal, or pass --tool with another installed tool.",
            );
        }
        child: any = None;
        try {
            child = spawnFn(
                command.executable, command.args, rec(cwd=command.cwd, stdio="inherit", shell=False)
            );
        } except Exception as e {
            reject(failed(js_error(e)));
            return;
        }
        def ignoreSignal {}
        process.on("SIGINT", ignoreSignal);
        process.on("SIGTERM", ignoreSignal);
        def cleanup {
            process.removeListener("SIGINT", ignoreSignal);
            process.removeListener("SIGTERM", ignoreSignal);
        }
        def onError(error: any) {
            cleanup();
            reject(failed(error));
        }
        def onClose(code: any, signal: any) {
            cleanup();
            resolve(rec(code=code, signal=signal));
        }
        child.on("error", onError);
        child.on("close", onClose);
    }
    return new(globalThis.Promise, run);
}

def exitCodeForLaunch(result: any) -> int {
    if result["signal"] is not JsNull {
        return 128 + (os.constants.signals[result["signal"]] ?? 1);
    }
    return 0 if missing(result["code"]) else result.code;
}

obj WorksetCommand(globalThis.Object) {
    async def create(name: any, options: any = None) {
        json = at(options, "json");
        try {
            interactive = not json and isInteractive();
            table: any = None;
            workset: any = None;
            if interactive {
                table = readOpenerTable();
                workset = await composeInteractively(
                    name,
                    rec(memberFlags=at(options, "member") ?? [], tool=at(options, "tool")),
                    table,
                );
            } else {
                workset = await self.composeFromFlags(name, options ?? rec());
            }
            await updateWorksetsState(lambda (state: any) -> any { withWorkset(state, workset) });
            if json {
                printJson(rec(workset=workset, status=[]));
                return;
            }
            count = len(workset.members);
            log("");
            log(
                f"Saved workset '{workset.name}' ({count} member{'' if count == 1 else 's'}) to your machine.",
            );
            if interactive and workset["tool"] is not None {
                openNow: any = False;
                try {
                    openNow = await promptOpenNow(openerLabel(table, workset.tool));
                } except Exception as e {
                    if not isPromptCancellationError(js_error(e)) {
                        raise js_error(e);
                    }
                }
                if openNow {
                    log("");
                    await self.open(workset.name, rec());
                    return;
                }
            }
            log(f"Open it any time with: openspec workset open {workset.name}");
        } except Exception as e {
            emitFailure(json, rec(workset=JsNull, status=[]), js_error(e), "workset_error");
        }
    }

    async def composeFromFlags(name: any, options: any) -> any {
        if not name {
            raise worksetError(
                "Pass a workset name.",
                "workset_name_required",
                "name",
                "openspec workset create <name> --member <path>",
            );
        }
        validateWorksetName(name);
        memberFlags = options["member"] ?? [];
        if len(memberFlags) == 0 {
            raise worksetError(
                "Pass at least one member folder.",
                "workset_members_required",
                "member",
                f"openspec workset create {name} --member <path> --member <name>=<path>",
            );
        }
        members = await resolveMemberFlags(memberFlags);
        tool = options["tool"];
        table: any = [];
        if tool is not None {
            table = readOpenerTable();
            chosen = findOpener(table, tool);
            if chosen is not JsNull and not isOpenerEnabled(chosen) {
                raise cliOpenerDisabledError(chosen, name);
            }
        }
        return finalizeWorkset(name, members, tool, table);
    }

    async def ls(options: any = None) {
        json = at(options, "json");
        try {
            worksets: any = listWorksets(await readWorksetsState());
            if json {
                printJson(rec(worksets=worksets, status=[]));
                return;
            }
            if len(worksets) == 0 {
                log("No worksets saved. Create one with: openspec workset create");
                return;
            }
            table = readOpenerTable()
                if worksets.some(lambda (w: any) -> bool { w["tool"] is not None })
                else [];
            for w in worksets {
                tool = w["tool"];
                log(w.name + ("" if tool is None else f"  (opens in {openerLabel(table, tool)})"));
                for row in formatMemberRows(w.members) {
                    log(f"  {row}");
                }
            }
        } except Exception as e {
            emitFailure(json, rec(worksets=[], status=[]), js_error(e), "workset_error");
        }
    }

    async def open(name: str, options: any = None) {
        json = at(options, "json");
        prepared: any = None;
        try {
            if json {
                raise worksetError(
                    "workset open hands this terminal to the chosen tool and has no JSON mode.",
                    "workset_open_json_unsupported",
                    "tool",
                    "Inspect worksets with: openspec workset list --json",
                );
            }
            async def prepare(state: any) -> any {
                workset = getWorkset(state, name);
                if workset is JsNull {
                    raise worksetNotFoundError(name, state);
                }
                members: any = workset.members;
                exists = await globalThis.Promise.all([
                    promise(pathIsDirectory(m.path))
                    for m in members
                ]);
                surviving = [m for (m, ok) in zip(members, exists) if ok];
                if not surviving {
                    raise worksetError(
                        f"No member folder of workset '{name}' exists on this machine.",
                        "workset_no_members_available",
                        "member",
                        f"Recompose it: openspec workset remove {name} --yes && openspec workset create {name} --member <path>",
                    );
                }
                codeWorkspacePath = getWorksetCodeWorkspacePath(name);
                await writeFileAtomically(
                    codeWorkspacePath, buildWorksetCodeWorkspaceJson(surviving)
                );
                return rec(
                    workset=workset,
                    surviving=surviving,
                    skipped=[m for (m, ok) in zip(members, exists) if not ok],
                    codeWorkspacePath=codeWorkspacePath,
                );
            }
            prepared = await withWorksetsLock(prepare);
            for m in prepared.skipped {
                fail(f"Skipped '{m.name}' ({m.path} is not available).");
            }
            primary = prepared.surviving[0];
            if not same(prepared.workset.members[0], primary) {
                fail(f"Using '{primary.name}' ({primary.path}) as the primary for this open.");
            }
            table = readOpenerTable();
            toolId = at(options, "tool") ?? prepared.workset["tool"];
            opener: any = None;
            if toolId is not None {
                opener = findOpener(table, toolId);
                if opener is JsNull {
                    raise toolUnknownError(toolId, table);
                }
                if not isOpenerEnabled(opener) {
                    raise cliOpenerDisabledError(opener, name);
                }
                if not isOpenerCommandAvailable(opener.command) {
                    raise toolUnavailableError(opener, table, name);
                }
            } else {
                if not isInteractive() {
                    raise worksetError(
                        f"Workset '{name}' has no saved tool.",
                        "workset_tool_required",
                        "tool",
                        f"openspec workset open {name} --tool <id>",
                    );
                }
                available = [c for c in listOpenerChoices(table) if c.available];
                if not available {
                    raise noToolInstalledError(table, name);
                }
                selectedId = await promptToolFromChoices(available);
                opener = [c.opener for c in available if c.opener.id == selectedId][0];
            }
            launch = buildLaunchCommand(
                opener,
                rec(members=prepared.surviving, codeWorkspacePath=prepared.codeWorkspacePath),
            );
            log(
                f"Opening '{name}' in {opener.label} (a window opens; this command returns)."
                    if opener.style == "workspace-file"
                    else f"Handing this terminal to {opener.label} for '{name}' (the session ends when you exit).",
            );
            result: any = None;
            try {
                result = await launchOpenerCommand(launch);
            } except Exception as e {
                err = js_error(e);
                if isinstance(err, StoreError) and err.diagnostic.code == "workset_launch_failed" {
                    alternative = firstInstalledAlternative(table, opener.id);
                    if alternative is not JsNull {
                        raise worksetError(
                            err.message,
                            "workset_launch_failed",
                            "tool",
                            f"Run: openspec workset open {name} --tool {alternative}",
                        );
                    }
                }
                raise err;
            }
            exitCode = exitCodeForLaunch(result);
            if exitCode != 0 {
                process.exitCode = exitCode;
            }
        } except Exception as e {
            error = js_error(e);
            emitFailure(json, rec(status=[]), error, "workset_error");
            if not json and prepared is not None and not isPromptCancellationError(error) {
                fail("Open manually:");
                fail(f"  Workspace file: {prepared.codeWorkspacePath}");
                fail("  Members:");
                for row in formatMemberRows(prepared.surviving) {
                    fail(f"    {row}");
                }
            }
        }
    }

    async def remove(name: str, options: any = None) {
        json = at(options, "json");
        try {
            if not at(options, "yes") {
                state = await readWorksetsState();
                workset = getWorkset(state, name);
                if workset is JsNull {
                    raise worksetNotFoundError(name, state);
                }
                if json or not isInteractive() {
                    raise worksetError(
                        "Pass --yes to remove a workset non-interactively.",
                        "workset_remove_confirmation_required",
                        "name",
                        f"openspec workset remove {name} --yes",
                    );
                }
                if not await confirmRemoveInteractively(workset) {
                    raise worksetError(
                        "Workset remove cancelled.",
                        "workset_remove_cancelled",
                        "name",
                        "Rerun remove when you are ready.",
                    );
                }
            }
            await removeWorkset(name);
            if json {
                printJson(rec(removed=rec(name=name), status=[]));
                return;
            }
            log(f"Removed workset '{name}'. Member folders were not touched.");
        } except Exception as e {
            emitFailure(json, rec(removed=JsNull, status=[]), js_error(e), "workset_error");
        }
    }
}
