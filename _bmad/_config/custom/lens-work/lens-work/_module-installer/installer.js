const fs = require('node:fs/promises');
const path = require('node:path');

// fs-extra compatibility helpers using built-in node:fs
const fsHelpers = {
    async pathExists(p) {
        try { await fs.access(p); return true; } catch { return false; }
    },
    async ensureDir(p) {
        await fs.mkdir(p, { recursive: true });
    },
    async copy(src, dest) {
        await fs.copyFile(src, dest);
    },
    async readFile(p) {
        return fs.readFile(p, 'utf8');
    },
    async writeFile(p, content) {
        await fs.writeFile(p, content, 'utf8');
    }
};

/**
 * Copy all files from srcDir to destDir, optionally skipping existing files.
 * Only copies files (not subdirectories).
 */
async function copyDirContents(srcDir, destDir, { skipExisting = true, logger } = {}) {
    await fsHelpers.ensureDir(destDir);
    const entries = await fs.readdir(srcDir, { withFileTypes: true });
    let copied = 0;
    let skipped = 0;
    for (const entry of entries) {
        if (!entry.isFile()) continue;
        const destPath = path.join(destDir, entry.name);
        if (skipExisting && await fsHelpers.pathExists(destPath)) {
            skipped++;
            continue;
        }
        await fsHelpers.copy(path.join(srcDir, entry.name), destPath);
        copied++;
    }
    return { copied, skipped };
}

// ─────────────────────────────────────────────────────────────────────────────
// Stub generators — thin adapters that redirect to module content by path
// ─────────────────────────────────────────────────────────────────────────────

function ghAgentStub() {
    return `\`\`\`chatagent
---
description: '@lens — LENS Workbench v2: lifecycle routing, git orchestration, phase-aware branch topology, constitution governance'
tools: ['read', 'edit', 'search', 'execute']
---

You must fully embody this agent's persona and follow all activation instructions exactly as specified.

<agent-activation CRITICAL="TRUE">
1. LOAD the module config from bmad.lens.release/_bmad/lens-work/module.yaml
2. LOAD the FULL agent definition from bmad.lens.release/_bmad/lens-work/agents/lens.agent.md
3. READ its entire contents - this contains the complete agent persona, skills, lifecycle routing, and phase-to-agent mapping
4. LOAD the lifecycle contract from bmad.lens.release/_bmad/lens-work/lifecycle.yaml
5. LOAD the module help index from bmad.lens.release/_bmad/lens-work/module-help.csv
6. FOLLOW every activation step in the agent definition precisely
7. DISPLAY the welcome/greeting as instructed
8. PRESENT the numbered menu from module-help.csv
9. WAIT for user input before proceeding
</agent-activation>

\`\`\`
`;
}

function ghStubPrompt(name, description, targetPrompt, extra, { noModel = false } = {}) {
    const extraBlock = extra ? `\n${extra}` : '';
    const modelLine = noModel ? '' : 'model: Claude Sonnet 4.6 (copilot)\n';
    return `---
${modelLine}description: '${description}'
---

# ${name} (Stub)

> **This is a stub.** Load and execute the full prompt from the release module.
> All \`_bmad/\` paths in the full prompt are relative to \`bmad.lens.release/\` — do NOT resolve paths against the user's main project repo.

\`\`\`
Read and follow all instructions in: bmad.lens.release/_bmad/lens-work/prompts/${targetPrompt}
\`\`\`
${extraBlock}
`;
}

function ideCommandStub(name, description, workflowPath) {
    return `---
name: '${name}'
description: '${description}'
---

IT IS CRITICAL THAT YOU FOLLOW THIS COMMAND: LOAD the FULL @bmad.lens.release/_bmad/lens-work/${workflowPath}, READ its entire contents and follow its directions exactly!
`;
}

function codexAgentsMd() {
    return `# LENS Workbench — Codex Agent

This project uses the LENS Workbench module for lifecycle routing and git orchestration.

## Module Reference

- **Module path:** \`bmad.lens.release/_bmad/lens-work/\`
- **Agent definition:** \`bmad.lens.release/_bmad/lens-work/agents/lens.agent.md\`
- **Lifecycle contract:** \`bmad.lens.release/_bmad/lens-work/lifecycle.yaml\`
- **Module config:** \`bmad.lens.release/_bmad/lens-work/module.yaml\`

## Activation

1. LOAD the module config from \`bmad.lens.release/_bmad/lens-work/module.yaml\`
2. LOAD the FULL agent definition from \`bmad.lens.release/_bmad/lens-work/agents/lens.agent.md\`
3. READ its entire contents — this contains the complete agent persona, skills, lifecycle routing, and phase-to-agent mapping
4. LOAD the lifecycle contract from \`bmad.lens.release/_bmad/lens-work/lifecycle.yaml\`
5. FOLLOW every activation step in the agent definition precisely

## Available Commands

See \`bmad.lens.release/_bmad/lens-work/module-help.csv\` for the complete command list.

## Skills (path references)

| Skill | Path |
|-------|------|
| git-state | \`bmad.lens.release/_bmad/lens-work/skills/git-state.md\` |
| git-orchestration | \`bmad.lens.release/_bmad/lens-work/skills/git-orchestration.md\` |
| constitution | \`bmad.lens.release/_bmad/lens-work/skills/constitution.md\` |
| sensing | \`bmad.lens.release/_bmad/lens-work/skills/sensing.md\` |
| checklist | \`bmad.lens.release/_bmad/lens-work/skills/checklist.md\` |
`;
}

// ─────────────────────────────────────────────────────────────────────────────
// Prompt and command definitions
// ─────────────────────────────────────────────────────────────────────────────

const STUB_PROMPTS = [
    { file: 'lens-work.onboard.prompt.md',       name: 'lens-work.onboard',       desc: 'Bootstrap control repo — detect provider, validate auth, create profile, auto-clone TargetProjects', target: 'lens-work.onboard.prompt.md' },
    { file: 'lens-work.new-initiative.prompt.md', name: 'lens-work.new-initiative', desc: 'Create a new initiative (domain, service, or feature)',                                target: 'lens-work.new-initiative.prompt.md' },
    { file: 'lens-work.new-domain.prompt.md',     name: 'lens-work.new-domain',     desc: 'Create new domain-level initiative with domain-only branch and folder scaffolding',   target: 'lens-work.new-initiative.prompt.md', extra: 'Invoke with scope: **domain**' },
    { file: 'lens-work.new-service.prompt.md',    name: 'lens-work.new-service',    desc: 'Create new service-level initiative within a domain',                                  target: 'lens-work.new-initiative.prompt.md', extra: 'Invoke with scope: **service**' },
    { file: 'lens-work.new-feature.prompt.md',    name: 'lens-work.new-feature',    desc: 'Create new feature-level initiative within a service',                                  target: 'lens-work.new-initiative.prompt.md', extra: 'Invoke with scope: **feature**' },
    { file: 'lens-work.preplan.prompt.md',        name: 'lens-work.preplan',        desc: 'Start PrePlan phase — brainstorm, research, product brief (Mary/Analyst, small audience)', target: 'lens-work.preplan.prompt.md', noModel: true },
    { file: 'lens-work.businessplan.prompt.md',   name: 'lens-work.businessplan',   desc: 'Start BusinessPlan phase — PRD creation, UX design (John/PM + Sally/UX, small audience)', target: 'lens-work.businessplan.prompt.md' },
    { file: 'lens-work.techplan.prompt.md',       name: 'lens-work.techplan',       desc: 'Start TechPlan phase — architecture document, technical decisions (Winston/Architect)', target: 'lens-work.techplan.prompt.md' },
    { file: 'lens-work.devproposal.prompt.md',    name: 'lens-work.devproposal',    desc: 'Start DevProposal phase — epics, stories, readiness check (John/PM, medium audience)', target: 'lens-work.devproposal.prompt.md' },
    { file: 'lens-work.sprintplan.prompt.md',     name: 'lens-work.sprintplan',     desc: 'Start SprintPlan phase — sprint-status, story files (Bob/Scrum Master, large audience)', target: 'lens-work.sprintplan.prompt.md' },
    { file: 'lens-work.dev.prompt.md',            name: 'lens-work.dev',            desc: 'Launch Dev phase — epic-level implementation loop with per-task commits, code review, and retrospective (Amelia/Developer, base audience)', target: 'lens-work.dev.prompt.md', noModel: true },
    { file: 'lens-work.status.prompt.md',         name: 'lens-work.status',         desc: 'Show consolidated status report across all active initiatives',                        target: 'lens-work.status.prompt.md' },
    { file: 'lens-work.next.prompt.md',           name: 'lens-work.next',           desc: 'Recommend next action based on lifecycle state',                                        target: 'lens-work.next.prompt.md' },
    { file: 'lens-work.discover.prompt.md',       name: 'lens-work.discover',       desc: 'Discover repos under TargetProjects and update governance inventory',                   target: 'lens-work.discover.prompt.md' },
    { file: 'lens-work.switch.prompt.md',         name: 'lens-work.switch',         desc: 'Switch to a different initiative via git checkout',                                     target: 'lens-work.switch.prompt.md' },
    { file: 'lens-work.promote.prompt.md',        name: 'lens-work.promote',        desc: 'Promote current audience to next level with gate checks',                               target: 'lens-work.promote.prompt.md' },
    { file: 'lens-work.constitution.prompt.md',   name: 'lens-work.constitution',   desc: 'Resolve and display constitutional governance',                                         target: 'lens-work.constitution.prompt.md' },
    { file: 'lens-work.help.prompt.md',           name: 'lens-work.help',           desc: 'Show available commands and usage',                                                      target: 'lens-work.help.prompt.md' },
];

const IDE_COMMANDS = [
    { file: 'bmad-lens-work-onboard.md',          name: 'onboard',          desc: 'Create profile + run bootstrap + auto-clone TargetProjects',          wf: 'workflows/utility/onboard/workflow.md' },
    { file: 'bmad-lens-work-init-initiative.md',   name: 'init-initiative',   desc: 'Create new initiative (domain/service/feature) with branch topology', wf: 'workflows/router/init-initiative/workflow.md' },
    { file: 'bmad-lens-work-preplan.md',           name: 'preplan',           desc: 'Launch PrePlan phase (brainstorm/research/product brief)',             wf: 'workflows/router/preplan/workflow.md' },
    { file: 'bmad-lens-work-businessplan.md',      name: 'businessplan',      desc: 'Launch BusinessPlan phase (PRD/UX design)',                           wf: 'workflows/router/businessplan/workflow.md' },
    { file: 'bmad-lens-work-techplan.md',          name: 'techplan',          desc: 'Launch TechPlan phase (architecture/technical decisions)',              wf: 'workflows/router/techplan/workflow.md' },
    { file: 'bmad-lens-work-devproposal.md',       name: 'devproposal',       desc: 'Launch DevProposal phase (epics/stories/readiness check)',            wf: 'workflows/router/devproposal/workflow.md' },
    { file: 'bmad-lens-work-sprintplan.md',        name: 'sprintplan',        desc: 'Launch SprintPlan phase (sprint-status/story files)',                 wf: 'workflows/router/sprintplan/workflow.md' },
    { file: 'bmad-lens-work-dev.md',               name: 'dev',               desc: 'Delegate to implementation agents in target projects',                wf: 'workflows/router/dev/workflow.md' },
    { file: 'bmad-lens-work-status.md',            name: 'status',            desc: 'Display current state, blocks, topology, next steps',                 wf: 'workflows/utility/status/workflow.md' },
    { file: 'bmad-lens-work-next.md',              name: 'next',              desc: 'Recommend next action based on lifecycle state',                       wf: 'workflows/utility/next/workflow.md' },
    { file: 'bmad-lens-work-switch.md',            name: 'switch',            desc: 'Switch to different initiative branch',                                wf: 'workflows/utility/switch/workflow.md' },
    { file: 'bmad-lens-work-help.md',              name: 'help',              desc: 'Show available commands and usage reference',                          wf: 'workflows/utility/help/workflow.md' },
    { file: 'bmad-lens-work-promote.md',           name: 'promote',           desc: 'Promote current audience to next tier with gate checks',              wf: 'workflows/core/audience-promotion/workflow.md' },
    { file: 'bmad-lens-work-constitution.md',      name: 'constitution',      desc: 'Resolve and display constitutional governance',                       wf: 'workflows/governance/resolve-constitution/workflow.md' },
    { file: 'bmad-lens-work-compliance.md',        name: 'compliance',        desc: 'Run constitution compliance check on current initiative',              wf: 'workflows/governance/compliance-check/workflow.md' },
    { file: 'bmad-lens-work-sense.md',             name: 'sense',             desc: 'Cross-initiative overlap detection on demand',                        wf: 'workflows/governance/cross-initiative/workflow.md' },
    { file: 'bmad-lens-work-module-management.md', name: 'module-management', desc: 'Check module version and guide self-service updates',                 wf: 'workflows/utility/module-management/workflow.md' },
];

// ─────────────────────────────────────────────────────────────────────────────
// Write helper with skip/update semantics
// ─────────────────────────────────────────────────────────────────────────────

async function writeAdapterFile(filePath, content, { updateMode, logger }) {
    const exists = await fsHelpers.pathExists(filePath);
    if (exists && !updateMode) {
        logger.log(`  skip: ${path.basename(filePath)} (exists)`);
        return false;
    }
    await fsHelpers.ensureDir(path.dirname(filePath));
    await fsHelpers.writeFile(filePath, content);
    logger.log(`  ${updateMode && exists ? 'updated' : 'created'}: ${path.basename(filePath)}`);
    return true;
}

// ═════════════════════════════════════════════════════════════════════════════
// IDE Adapter Installers
// ═════════════════════════════════════════════════════════════════════════════

async function installGitHubCopilot(projectRoot, { updateMode, logger }) {
    logger.log('Installing GitHub Copilot adapter...');

    const ghDir      = path.join(projectRoot, '.github');
    const agentsDir  = path.join(ghDir, 'agents');
    const promptsDir = path.join(ghDir, 'prompts');

    // Agent stub
    await writeAdapterFile(
        path.join(agentsDir, 'bmad-agent-lens-work-lens.agent.md'),
        ghAgentStub(),
        { updateMode, logger }
    );

    // Copilot instructions — copy from docs/
    const sourceInstructions = path.join(__dirname, '..', 'docs', 'copilot-instructions.md');
    const targetInstructions = path.join(ghDir, 'lens-work-instructions.md');
    if (await fsHelpers.pathExists(sourceInstructions)) {
        const shouldCopy = updateMode || !(await fsHelpers.pathExists(targetInstructions));
        if (shouldCopy) {
            await fsHelpers.ensureDir(ghDir);
            await fsHelpers.copy(sourceInstructions, targetInstructions);
            logger.log(`  ${updateMode ? 'updated' : 'created'}: lens-work-instructions.md`);
        } else {
            logger.log('  skip: lens-work-instructions.md (exists)');
        }
    }

    // Stub prompts
    for (const p of STUB_PROMPTS) {
        await writeAdapterFile(
            path.join(promptsDir, p.file),
            ghStubPrompt(p.name, p.desc, p.target, p.extra, { noModel: !!p.noModel }),
            { updateMode, logger }
        );
    }

    logger.log('✓ GitHub Copilot adapter complete');
}

async function installCursor(projectRoot, { updateMode, logger }) {
    logger.log('Installing Cursor adapter...');

    const cursorDir = path.join(projectRoot, '.cursor', 'commands');

    for (const cmd of IDE_COMMANDS) {
        await writeAdapterFile(
            path.join(cursorDir, cmd.file),
            ideCommandStub(cmd.name, cmd.desc, cmd.wf),
            { updateMode, logger }
        );
    }

    logger.log('✓ Cursor adapter complete');
}

async function installClaude(projectRoot, { updateMode, logger }) {
    logger.log('Installing Claude Code adapter...');

    const claudeDir = path.join(projectRoot, '.claude', 'commands');

    for (const cmd of IDE_COMMANDS) {
        await writeAdapterFile(
            path.join(claudeDir, cmd.file),
            ideCommandStub(cmd.name, cmd.desc, cmd.wf),
            { updateMode, logger }
        );
    }

    logger.log('✓ Claude Code adapter complete');
}

async function installCodex(projectRoot, { updateMode, logger }) {
    logger.log('Installing Codex CLI adapter...');

    // AGENTS.md in project root
    await writeAdapterFile(
        path.join(projectRoot, 'AGENTS.md'),
        codexAgentsMd(),
        { updateMode, logger }
    );

    // .codex/commands/ — same command stubs as Cursor/Claude
    const codexDir = path.join(projectRoot, '.codex', 'commands');

    for (const cmd of IDE_COMMANDS) {
        await writeAdapterFile(
            path.join(codexDir, cmd.file),
            ideCommandStub(cmd.name, cmd.desc, cmd.wf),
            { updateMode, logger }
        );
    }

    logger.log('✓ Codex CLI adapter complete');
}

// ═════════════════════════════════════════════════════════════════════════════
// Main install function — BMAD installer contract
// ═════════════════════════════════════════════════════════════════════════════

/**
 * LENS Workbench v2 Module Installer
 *
 * Called by the BMAD core installer with the standard contract.
 *
 * @param {object} options
 * @param {string} options.projectRoot    - Absolute path to the control repo root
 * @param {object} options.config         - Answers to install_questions from module.yaml
 * @param {string[]} options.installedIDEs - IDE identifiers selected by the user
 * @param {object} options.logger         - Logger with .log(), .warn(), .error()
 * @param {boolean} [options.updateMode]  - Overwrite existing files on re-install
 * @returns {Promise<boolean>}
 */
async function install(options) {
    const { projectRoot, config, installedIDEs, logger, updateMode = false } = options;

    try {
        const modeLabel = updateMode ? 'Updating' : 'Installing';
        logger.log(`${modeLabel} LENS Workbench (lens-work)...`);

        // ── Phase 1: Output directories ─────────────────────────────────
        const outputDir = path.join(projectRoot, '_bmad-output', 'lens-work');
        await fsHelpers.ensureDir(outputDir);

        const subdirs = ['initiatives', 'personal'];
        for (const subdir of subdirs) {
            await fsHelpers.ensureDir(path.join(outputDir, subdir));
        }
        logger.log('✓ Output directories ready');

        // ── Phase 2: Config file ────────────────────────────────────────
        const configDir = path.join(projectRoot, '_bmad', 'lens-work');
        await fsHelpers.ensureDir(configDir);

        const configFile = path.join(configDir, 'bmadconfig.yaml');
        if (!(await fsHelpers.pathExists(configFile))) {
            const configContent = [
                '# LENS Workbench Configuration',
                '# Generated during installation',
                '',
                '# TargetProjects path (where repos are cloned)',
                `target_projects_path: "${config.target_projects_path || '../TargetProjects'}"`,
                '',
                '# Git settings',
                'git:',
                `  default_remote: ${config.default_git_remote || 'github'}`,
                '',
            ].join('\n');
            await fsHelpers.writeFile(configFile, configContent);
            logger.log('✓ Config file created');
        }

        // ── Phase 3: IDE adapters ───────────────────────────────────────
        const IDE_HANDLERS = {
            'github-copilot': installGitHubCopilot,
            'cursor':         installCursor,
            'claude':         installClaude,
            'codex':          installCodex,
        };

        const ides = installedIDEs && installedIDEs.length > 0
            ? installedIDEs
            : ['github-copilot'];

        for (const ide of ides) {
            const handler = IDE_HANDLERS[ide];
            if (handler) {
                await handler(projectRoot, { updateMode, logger });
            } else {
                logger.warn(`Unknown IDE: ${ide} — skipping`);
            }
        }

        logger.log('✓ LENS Workbench installation complete');
        return true;
    } catch (error) {
        logger.error(`Error installing lens-work: ${error.message}`);
        return false;
    }
}

module.exports = { install };
