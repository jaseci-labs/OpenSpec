import from "yaml" { stringify }

def:priv formatFile(c: any) -> str {
    takes = found(c.body, "^\\*\\*Input\\*\\*:", "m");
    description = stringify(rec(description=c.description), rec(lineWidth=0, blockQuote=False));
    arguments = "\n**Provided arguments**: $ARGUMENTS\n" if takes else "";
    return f"---\nname: opsx-{c.id}\n{description}args: {'optional' if takes else 'none'}\n---\n{arguments}\n{c.body}\n";
}

glob atomcodeAdapter: any = commandAdapter("atomcode", ".atomcode/commands/opsx-*.md", formatFile);
