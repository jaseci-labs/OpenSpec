type DeltaOperation = any;

type Delta = any;

type Change = any;

glob:priv z: any = need("zod").z;

glob DeltaOperationType: any = z.enum(["ADDED", "MODIFIED", "REMOVED", "RENAMED"]);

glob DeltaSchema: any = z.object(
    rec(
        spec=z.string().min(1, VALIDATION_MESSAGES.DELTA_SPEC_EMPTY),
        operation=DeltaOperationType,
        description=z.string().min(1, VALIDATION_MESSAGES.DELTA_DESCRIPTION_EMPTY),
        requirement=RequirementSchema.optional(),
        requirements=z.array(RequirementSchema).optional(),
        rename=z.object(
            globalThis.Object.fromEntries([["from", z.string()], ["to", z.string()]])
        ).optional(),
    ),
);

glob ChangeSchema: any = z.object(
    rec(
        name=z.string().min(1, VALIDATION_MESSAGES.CHANGE_NAME_EMPTY),
        why=z.string().min(MIN_WHY_SECTION_LENGTH, VALIDATION_MESSAGES.CHANGE_WHY_TOO_SHORT).max(
            MAX_WHY_SECTION_LENGTH, VALIDATION_MESSAGES.CHANGE_WHY_TOO_LONG
        ),
        whatChanges=z.string().min(1, VALIDATION_MESSAGES.CHANGE_WHAT_EMPTY),
        deltas=z.array(DeltaSchema).min(1, VALIDATION_MESSAGES.CHANGE_NO_DELTAS).max(
            MAX_DELTAS_PER_CHANGE, VALIDATION_MESSAGES.CHANGE_TOO_MANY_DELTAS
        ),
        metadata=z.object(
            rec(
                version=z.string().default("1.0.0"),
                format=z.literal("openspec-change"),
                sourcePath=z.string().optional(),
            ),
        ).optional(),
    ),
);
