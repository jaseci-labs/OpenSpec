# Github Workflows

## Testing CI Locally

Test GitHub Actions workflows locally using [act](https://nektosact.com/):

```bash
# Test all PR checks
act pull_request

# Test specific job
act pull_request -j nix-flake-validate

# Dry run to see what would execute
act pull_request --dryrun
```

The `.actrc` file configures act to use the appropriate Docker image.



## Building with neojac

The CLI's source is Jac. `neojac` (Linux and macOS only) compiles it, so each
workflow has one Linux job that runs `.github/actions/setup-neojac` and
`neojac npm run build`, then archives the tree neojac lays out
(`.jac/test/spaces/openspec`: the emitted JavaScript beside the TypeScript
forwarders). Jobs on other systems, and every test job, unpack that tree with
`.github/actions/laid-tree` and run it with plain npm and their own Node.

The Nix flake still builds from source with pnpm and tsc, which cannot compile
the Jac modules; `nix-flake-validate` will fail until the flake builds the
laid-out tree instead (neojac has no Nix package yet).
