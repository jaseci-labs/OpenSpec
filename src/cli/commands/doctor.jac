import from "node:path" { join }
import from "node:url" { pathToFileURL }

async def:priv runDoctor(options: any) {
    implementation = await load(
        pathToFileURL(join(packageRoot(), "dist", "commands", "doctor.js")).href
    );
    await implementation.doctorCommand(options);
}

def registerDoctorCommand(program: any) {
    described = [c.description for c in COMMAND_REGISTRY if c.name == "doctor"];
    program.command("doctor").description(
        described[0] if described else "Report relationship health for the resolved OpenSpec root"
    ).option("--store <id>", COMMON_FLAGS.store.description).addOption(
        new(
            pick("commander", "Option"),
            "--store-path <path>",
            "Removed; register the store and use --store",
        ).hideHelp(),
    ).option("--json", "Output as JSON").action(runDoctor);
}
