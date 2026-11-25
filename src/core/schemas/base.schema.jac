type Scenario = any;

type Requirement = any;

glob:priv z: any = need("zod").z;

glob ScenarioSchema: any = z.object(
    rec(name=z.string().optional(), rawText=z.string().min(1, VALIDATION_MESSAGES.SCENARIO_EMPTY))
);

glob RequirementSchema: any = z.object(
    rec(
        name=z.string().optional(),
        text=z.string().min(1, VALIDATION_MESSAGES.REQUIREMENT_EMPTY),
        scenarios=z.array(ScenarioSchema).min(1, VALIDATION_MESSAGES.REQUIREMENT_NO_SCENARIOS),
    ),
);
