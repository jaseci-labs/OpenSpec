glob:priv z: any = need("zod").z;

type ChangeMetadata = any;

def:priv kebab(label: str) -> any {
    def refine(value: str, ctx: any) {
        if not isKebabId(value) {
            ctx.addIssue(
                rec(
                    code="custom",
                    message=f"{label} must be kebab-case with lowercase letters, numbers, and single hyphen separators",
                ),
            );
        }
    }
    return z.string().superRefine(refine);
}

glob InitiativeLinkSchema: any = z.object(
         rec(store=kebab("Store id"), id=kebab("Initiative id"))
     ).strict(),
     CHANGE_METADATA_KNOWN_KEYS: list[str] = [
         "schema",
         "created",
         "goal",
         "affected_areas",
         "initiative",
         "skip_specs",
         "retire_capabilities",
     ],
     ChangeMetadataSchema: any = z.object(
         rec(
             schema=z.string().min(1, rec(message="schema is required")),
             created=z.string().regex(
                 rx("^\\d{4}-\\d{2}-\\d{2}$"), rec(message="created must be YYYY-MM-DD format")
             ).optional(),
             goal=z.string().min(1).optional(),
             affected_areas=z.array(z.string().min(1)).optional(),
             initiative=InitiativeLinkSchema.optional(),
             skip_specs=z.boolean().optional(),
             retire_capabilities=z.boolean().optional(),
         ),
     );
