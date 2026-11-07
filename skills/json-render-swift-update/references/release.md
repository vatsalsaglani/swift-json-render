# Release

Contents: versions, changelog, docs, skills, who tags.

## Versions

The package tracks upstream json-render by minor: `0.22.x` follows upstream 0.22. Pre-release tags are `0.22.0-alpha.N`. The tag `0.22.0-alpha.0` marks wave 1 (core). A release moves to the next upstream minor only with new fixtures and a new importer pin (`parity.md`).

Rules for the version number:

- Patch: bug fixes and text fixes that do not move a prompt fixture line.
- Minor: new components, props, charts, directives, rules; prompt text additions. Nothing removed.
- A removal or rename of an upstream name, a prop, a param or an expression changes semantics. It is not allowed inside a minor.

## Changelog

`CHANGELOG.md` has one owner: the coordinator. An agent does not edit it; the handoff carries a **CHANGELOG line** for each change, in this shape: `Added|Changed|Fixed|Deprecated: <what a user sees> (<component or area>)`. Name any prompt text change, any new validator rule, and any new public type. <!-- verify at release: CHANGELOG.md is not on main yet -->

## Docs

- DocC for the public API: every public type and method has a doc comment that says what it does, what it throws, and what it never logs. <!-- verify at release: DocC catalog -->
- The README, `NOTICE`, `AGENTS.md` and `docs/**` have single owners; a needed edit is a request to the coordinator.
- A reusable nuance (a platform quirk, a limit, a decision) goes into a reference note or a decision record in the same change; the coordinator or documentor owns the files under `docs/`.

## The skills

- Both skills live in `skills/`. `skills/scripts/check-skills.sh` validates them: frontmatter, names equal folders, body length, links, examples decode. Run it after every skill edit.
- `.claude/skills/json-render-swift-update` is a symlink to `skills/json-render-swift-update`, so a clone has the update skill ready. Keep it a symlink.
- At release, run `skills/scripts/refresh-catalog-reference.sh` so the component and chart lists match the code, then `skills/scripts/check-skills.sh`.
- Install check: `npx skills add vatsalsaglani/swift-json-render --skill json-render-swift-use` and `--skill json-render-swift-update` into a scratch project; open the installed `SKILL.md` and follow one link.
- The use skill must stay correct: when a public name, a prop, a limit or a default changes, change the matching reference in the same commit.

## Tagging and publishing

Tagging, pushing, creating a pull request and publishing a release are the coordinator's and the user's actions. An agent does not tag, push or publish. As a last step in a worktree, after the gates pass and the commit is made: `rm -rf .build`.
