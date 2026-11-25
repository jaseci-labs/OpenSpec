async def:priv runDoctor(options: any) {
    import from src.commands.doctor { doctorCommand }
    await doctorCommand(options);
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
