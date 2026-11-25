import from "zod" { z }

type Spec = any;

glob SpecSchema: any = z.object(
    rec(
        name=z.string().min(1, VALIDATION_MESSAGES.SPEC_NAME_EMPTY),
        overview=z.string().min(1, VALIDATION_MESSAGES.SPEC_PURPOSE_EMPTY),
        requirements=z.array(RequirementSchema).min(1, VALIDATION_MESSAGES.SPEC_NO_REQUIREMENTS),
        metadata=z.object(
            rec(
                version=z.string().default("1.0.0"),
                format=z.literal("openspec"),
                sourcePath=z.string().optional(),
            ),
        ).optional(),
    ),
);
