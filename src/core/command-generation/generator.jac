def generateCommand(content: any, adapter: any) -> any {
    invocation = getInvocationForAdapter(adapter);
    return rec(
        path=adapter.getFilePath(content.id),
        fileContent=adapter.formatFile(
            merge(content, rec(body=transformCommandInvocations(content.body, invocation)))
                if needsInvocationRewrite(invocation)
                else content,
        ),
    );
}

def generateCommands(contents: any, adapter: any) -> any {
    return [generateCommand(c, adapter) for c in contents];
}
