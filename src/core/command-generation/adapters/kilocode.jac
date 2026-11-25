glob kilocodeAdapter: any = commandAdapter(
    "kilocode", ".kilo/command/opsx-*.md", lambda (c: any) -> str { c.body + "\n" }
);
