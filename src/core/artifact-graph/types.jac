import from "node:path" { posix, win32 }

glob:priv z: any = need("zod").z;

type Artifact = any;
type SchemaYaml = any;
type CompletedSet = any;
type BlockedArtifacts = any;

def:priv relativePathSchema(fieldName: str) -> any {
    def refine(value: str, ctx: any) {
        if posix.isAbsolute(value)
            or win32.isAbsolute(value)
            or found(value, "^[A-Za-z]:|(^|[\\\\/])\\.\\.([\\\\/]|$)|\\0", "u")
        {
            ctx.addIssue(
                rec(
                    code="custom",
                    message=f"{fieldName} must be a relative path inside its allowed directory",
                ),
            );
        }
    }
    return z.string().min(1, rec(error=f"{fieldName} is required")).superRefine(refine);
}

glob:priv MAX_ARTIFACTS: int = 1000;

glob ArtifactSchema: any = z.object(
         rec(
             id=z.string().min(1, rec(error="Artifact ID is required")),
             generates=relativePathSchema("generates field"),
             description=z.string(),
             template=relativePathSchema("template field"),
             instruction=z.string().optional(),
             requires=z.array(z.string()).default([]),
         ),
     ),
     ApplyPhaseSchema: any = z.object(
         rec(
             requires=z.array(z.string()).min(1, rec(error="At least one required artifact")),
             tracks=relativePathSchema("apply.tracks").nullable().optional(),
             instruction=z.string().optional(),
         ),
     ),
     SchemaYamlSchema: any = z.object(
         rec(
             name=z.string().min(1, rec(error="Schema name is required")),
             version=z.number().int().positive(rec(error="Version must be a positive integer")),
             description=z.string().optional(),
             artifacts=z.array(ArtifactSchema).min(
                 1, rec(error="At least one artifact required")
             ).max(
                 MAX_ARTIFACTS, rec(error=f"A schema may declare at most {MAX_ARTIFACTS} artifacts")
             ),
             apply=ApplyPhaseSchema.optional(),
         ),
     );
