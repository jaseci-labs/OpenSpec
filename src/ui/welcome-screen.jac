import from "node:child_process" { execFileSync }
import from "node:process" { default as process }

glob:priv chalk: any = pick("chalk"),
          MIN_WIDTH: int = 60,
          ART_COLUMN_WIDTH: int = 24,
          REDUCED_MOTION_EXEC_OPTIONS: any = rec(
              encoding="utf8", timeout=500, killSignal="SIGKILL", stdio=["ignore", "pipe", "ignore"]
          ),
          MOTION_QUERIES: dict[str, tuple[str, list[str], str]] = {
              "darwin": ("defaults", ["read", "com.apple.universalaccess", "reduceMotion"], "1"),
              "linux": (
                  "gsettings",
                  ["get", "org.gnome.desktop.interface", "enable-animations"],
                  "false",
              ),
          };

def:priv getWelcomeText(workflows: list[str]) -> list[str] {
    quickStart: list[str] = [];
    commands = getOnboardingCommands(workflows);
    if commands {
        quickStart.append(chalk.white("Quick start after setup:"));
        for c in commands {
            quickStart.extend([f"  {chalk.yellow(c.skill)}", f"    {chalk.dim(c.description)}"]);
        }
        quickStart.extend([chalk.dim("  (spelling varies by tool)"), ""]);
    }
    return [
        globalThis.Reflect.get(chalk, "white").bold("Welcome to OpenSpec"),
        chalk.dim("A lightweight spec-driven framework"),
        "",
        chalk.white("This setup will configure:"),
        chalk.dim("  • Agent Skills for AI tools"),
        "",
        *quickStart,
        chalk.cyan("Press Enter to select tools..."),
    ];
}

def:priv renderFrame(artLines: list[any], textLines: list[str]) -> str {
    return "\n".join([
        f"\x1b[2K{chalk.cyan((artLines[i] if i < len(artLines) else '').padEnd(ART_COLUMN_WIDTH))}{textLines[i] if i < len(textLines) else ''}"
        for i in range(max(len(artLines), len(textLines)))
    ]);
}

def prefersReducedMotion(platform: any = None) -> bool {
    query = MOTION_QUERIES.get(platform ?? process.platform);
    if query is None {
        return False;
    }
    (file, args, reduced) = query;
    try {
        out: any = execFileSync(file, args, REDUCED_MOTION_EXEC_OPTIONS);
        return out.trim() == reduced;
    } except Exception {
        return False;
    }
}

def:priv canAnimate -> bool {
    return truthy(at(process.stdout, "isTTY"))
        and not process.env["NO_COLOR"]
        and process.env["OPENSPEC_NO_ANIMATION"] is None
        and (at(process.stdout, "columns") or 80) >= MIN_WIDTH
        and not prefersReducedMotion();
}

async def:priv waitForEnter {
    if not truthy(at(process.stdin, "isTTY")) {
        return;
    }
    core = merge(await load("@inquirer/core"));
    def view(config: any, done: any) -> str {
        def onKey(key: any) {
            if key["ctrl"] and key["name"] == "c" {
                process.stdout.write("\n");
                process.exit(0);
            }
            if core.isEnterKey(key) {
                done(None);
            }
        }
        core.useKeypress(onKey);
        return "";
    }
    await core.createPrompt(view)(rec());
}

async def showWelcomeScreen(workflows: list[str], options: any = None) {
    textLines = getWelcomeText(workflows);
    frames: list[any] = WELCOME_ANIMATION.frames;
    if same(at(options, "animate"), False) or not canAnimate() {
        staticLines = textLines
            if truthy(at(process.stdin, "isTTY"))
            else [line for line in textLines if "Press Enter" not in line];
        process.stdout.write("\n" + renderFrame(frames[3], staticLines) + "\n\n");
        await waitForEnter();
        return;
    }
    frameIndex = 0;
    running = True;
    isFirstRender = True;
    frameHeight = max(len(frames[0]), len(textLines)) + 1;
    totalHeight = frameHeight + 1;
    process.stdout.write("\n");
    def tick {
        if not running {
            return;
        }
        if not isFirstRender {
            process.stdout.write(f"\x1b[{frameHeight}A");
        }
        isFirstRender = False;
        process.stdout.write(renderFrame(frames[frameIndex], textLines) + "\n\n");
        frameIndex = (frameIndex + 1) % len(frames);
    }
    interval = globalThis.setInterval(tick, WELCOME_ANIMATION.interval);
    await waitForEnter();
    running = False;
    globalThis.clearInterval(interval);
    process.stdout.write(
        f"\x1b[{totalHeight}A" + "\x1b[2K\n" * totalHeight + f"\x1b[{totalHeight}A"
    );
}
