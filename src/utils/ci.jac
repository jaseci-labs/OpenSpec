import from "node:process" { default as process }

glob:priv CI_DISABLED_VALUES: list[str] = ["", "false", "0", "no", "off"];

def isCiEnvironment(env: any = None) -> bool {
    value: any = (env ?? process.env)["CI"];
    return value is not None and value.trim().toLowerCase() not in CI_DISABLED_VALUES;
}
