{ inputs, ... }: {
  flake-file.inputs.ponytail = {
    url = "github:DietrichGebert/ponytail/2ed6c52c9d7e5e56942508591085fd45dea277d3";
    flake = false;
  };

  # Ponytail - "lazy senior dev" YAGNI skill. The upstream tree ships a manifest
  # for ~20 agents (`.claude-plugin/`, `.codex-plugin/`, ...) off the same
  # source, so it's wired into every AI CLI this config installs (pulled in by
  # `my.claude` and `my.openai`) rather than being a single work-only tool.
  # Setting `programs.codex.plugins` is harmless where Codex is disabled - the
  # module only acts on it behind `enable`.
  my.ponytail.homeManager.programs = {
    claude-code.plugins.ponytail = inputs.ponytail;
    codex.plugins = [ inputs.ponytail ];
  };
}
