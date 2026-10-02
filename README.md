# dk-ai

Custom AI agents and skills for building software with **dk** and the **dk0** build
tool. They teach a coding agent (Claude, Copilot, Cursor, and similar) to analyze dk
projects, create and repair dk packages, and turn a plain-language software request
into a build plan that ships through `dk0 remote`.

The `given-user-prompt-make-new-prompt-that-uses-dk` agent is also the system prompt
behind the **dk Prompt Studio** prompt bar on https://diskuv.com (it runs there on
Amazon Nova Micro). The mini-plans the Studio produces tell a user's agent to install
these skills, so this repository is where that install points.

## Layout

The agents and skills live under `.ai-skills/`, so installing the plugin copies only
that directory, not the whole repository:

- `.ai-skills/<name>/SKILL.md` - reusable skills the agents (and you) invoke.
- `.ai-skills/agents/<name>.agent.md` - task agents (see the live inventory in `AGENTS.md`).
- `.ai-skills/.claude-plugin/plugin.json` - the Claude Code plugin manifest.
- `AGENTS.md` - the authoring conventions and the current inventory of what is here.

## Install

The files use the Claude agent/skill format (`.ai-skills/agents/*.agent.md`,
`.ai-skills/*/SKILL.md`). Exact discovery rules vary by tool and version, so pick the
closest path below; when in doubt, the "other agents" path always works.

### Claude Code

This repository is a Claude Code plugin. Add it as a marketplace and install the plugin:

```text
/plugin marketplace add diskuv/dk-ai
/plugin install dk-ai@dk-ai
```

Or clone it and copy the agents and the skills you want where Claude Code looks for them:

```sh
git clone https://github.com/diskuv/dk-ai
mkdir -p .claude/agents .claude/skills
cp -r dk-ai/.ai-skills/agents/* .claude/agents/
# each skill is a directory under .ai-skills/; copy the ones you want by name:
cp -r dk-ai/.ai-skills/analyze-dk-project .claude/skills/
```

Reload Claude Code so it discovers them.

### Claude Desktop / claude.ai

Add each skill directory under `.ai-skills/` (every subdirectory except `agents/` and
`.claude-plugin/`) through the Skills feature. For an agent, paste the body of the
relevant `.ai-skills/agents/*.agent.md` as your project instructions.

### Cursor, GitHub Copilot, OpenAI, and other agents

There is no cross-tool standard for installing skills, so point your agent at the
files directly. The most reliable way is to clone the repo into your project and ask
your agent to read the skill or agent it needs:

```sh
git clone https://github.com/diskuv/dk-ai
# then tell your agent: "read dk-ai/.ai-skills/analyze-dk-project/SKILL.md and follow it"
```

If your agent has a web or fetch tool, it can pull a skill into context without
cloning:

```text
https://raw.githubusercontent.com/diskuv/dk-ai/main/.ai-skills/<name>/SKILL.md
https://raw.githubusercontent.com/diskuv/dk-ai/main/.ai-skills/agents/<name>.agent.md
```

This three-step fallback (install the skills, else fetch them with a web tool, else
clone and read them) is exactly what the dk Prompt Studio mini-plans tell a user's
agent to do, so any of these paths satisfies a generated mini-plan.

## What is here

See `AGENTS.md` for the self-maintained inventory of every agent and skill, each with
a one-line "use when" and its hard-stop rules.
