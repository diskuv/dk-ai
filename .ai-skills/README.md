# dk-ai skills and agents

This directory holds the dk-ai plugin's skills and agents in the Agent Skills open-standard layout:

- `<skill-name>/SKILL.md` -- one directory per skill, auto-discovered when the plugin is enabled.
- `agents/<name>.agent.md` -- the agents.
- `.claude-plugin/plugin.json` -- the plugin manifest (`"skills": ["."]`).

The marketplace manifest at the repository root (`.claude-plugin/marketplace.json`) points its plugin
`source` at this directory (`./.ai-skills`). Keeping the plugin's files in this subdirectory means only
this directory is copied into the plugin cache when the plugin is installed, not the whole repository,
which keeps the installed footprint small.

Edit skills and agents here; these are the single authoritative locations. Do not copy or symlink their
content into `.claude/skills/`, `~/.claude/skills/`, or another repository.
