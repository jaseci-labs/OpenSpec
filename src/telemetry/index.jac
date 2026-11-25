import from "crypto" { randomUUID }

glob:priv POSTHOG_API_KEY: str = "phc_Hthu8YvaIJ9QaFKyTG4TbVwkbd5ktcAFzVTKeMmoW2g",
          POSTHOG_HOST: str = "https://edge.openspec.dev",
          TELEMETRY_REQUEST_TIMEOUT_MS: int = 1000,
          anonymousId: any = None,
          pendingEvents: any = new(globalThis.Set);

async def:priv safeTelemetryFetch(url: str, options: any) -> any {
    try {
        response = await globalThis.fetch(url, options);
        if truthy(response.body) {
            await response.body.cancel();
        }
        if response.ok {
            return response;
        }
    } except Exception {}
    return new(globalThis.Response, JsNull, rec(status=204));
}

def isTelemetryEnabled -> bool {
    return not (
        isTelemetryOptedOutByEnv()
        or isCiEnvironment()
        or same(at(getGlobalConfig(), "telemetry", "enabled"), False)
        or isGlobalConfigUnreadable()
    );
}

async def getOrCreateAnonymousId -> str {
    if anonymousId {
        return anonymousId;
    }
    anonymousId = (await getTelemetryConfig())["anonymousId"];
    if not anonymousId {
        anonymousId = randomUUID();
        await updateTelemetryConfig(rec(anonymousId=anonymousId));
    }
    return anonymousId;
}

def:priv sendEvent(distinctId: str, event: str, properties: any) {
    body = globalThis.JSON.stringify(
        rec(
            api_key=POSTHOG_API_KEY,
            batch=[
                rec(
                    type="capture",
                    event=event,
                    distinct_id=distinctId,
                    properties=properties,
                    timestamp=new(globalThis.Date).toISOString(),
                ),
            ],
        ),
    );
    request = promise(
        safeTelemetryFetch(
            f"{POSTHOG_HOST}/batch/",
            rec(
                method="POST",
                headers=rec(**{"content-type": "application/json"}),
                body=body,
                signal=globalThis.AbortSignal.timeout(TELEMETRY_REQUEST_TIMEOUT_MS),
            ),
        ),
    );
    pendingEvents.add(request);
    request.finally(lambda -> any { pendingEvents.delete(request) });
}

async def trackCommand(commandName: str, version: str) {
    if not isTelemetryEnabled() {
        return;
    }
    try {
        if not (await getTelemetryConfig())["noticeSeen"] {
            return;
        }
        properties = rec(command=commandName, version=version, surface="cli");
        properties["$ip"] = JsNull;
        sendEvent(await getOrCreateAnonymousId(), "command_executed", properties);
    } except Exception {}
}

async def maybeShowTelemetryNotice(options: any = None) {
    if not isTelemetryEnabled() {
        return;
    }
    try {
        if (await getTelemetryConfig())["noticeSeen"] or at(options, "silent") {
            return;
        }
        globalThis.console.error(
            "Note: OpenSpec collects anonymous usage stats. Opt out: OPENSPEC_TELEMETRY=0 or openspec config set telemetry.enabled false",
        );
        await updateTelemetryConfig(rec(noticeSeen=True));
    } except Exception {}
}

async def shutdown {
    if pendingEvents.size == 0 {
        return;
    }
    try {
        await globalThis.Promise.allSettled(globalThis.Array.from(pendingEvents));
    } except Exception {} finally {
        pendingEvents.clear();
    }
}
