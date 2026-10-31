# Open DS MCP Server

**Let Claude build with the WPP Open Design System. A local MCP server for Claude Desktop and Claude Code: it reads the Open DS Storybook, checks each page and the code Claude writes against the release you use, and brings step-by-step workflows for building, reviewing and upgrading Open DS apps and for mocking them up in Claude Design.**

Version **0.6.3** · macOS · Claude Desktop extension and Claude Code server

- [Install: for people](#install-for-people)
- [Install: for AI agents](#install-for-ai-agents)
- [What you can do](#what-you-can-do)
- [Questions to try](#questions-to-try)
- [Tools](#tools)
- [Choosing a release](#choosing-a-release)
- [Using Open DS in React](#using-open-ds-in-react)
- [Update and remove](#update-and-remove)
- [Security and privacy](#security-and-privacy)
- [Troubleshooting](#troubleshooting)

---

## Install: for people

Open Terminal and run:

```bash
curl -fsSL https://wpp-jamie-mills.github.io/open-ds-mcp-site/install.sh | bash
```

Then:

1. Click **Install** in the dialog Claude Desktop opens.
2. In a new chat, ask Claude something like "Which Open DS component should I use for a date range?". The first time, it signs you in to the Storybook with your WPP session; while that session is valid this happens by itself, otherwise a WPP sign-in page opens in your browser: finish it, then ask again.

After that it keeps itself up to date: once a day it checks for a new version, and Claude offers it on an update card
in the chat. Click Update now, then Install in Claude Desktop's dialog; nothing is installed until you do. Running the
same command again also updates.

## Install: for AI agents

Use these steps if you are an AI agent installing this for a user.

1. **Check the machine.** Continue only if `uname -s` prints `Darwin` and the user has Claude Desktop (`/Applications/Claude.app`) or Claude Code (`claude` on the PATH, with Node.js 20 or later). Otherwise tell the user what it needs.
2. **Run the installer** with this one command. It downloads the extension, checks its SHA-256 (nothing changes before the check passes), opens Claude Desktop's install dialog and adds the server to Claude Code. With no terminal it never prompts and answers no to every question. It exits non-zero, with the reason on stderr, if anything fails.

```bash
curl -fsSL https://wpp-jamie-mills.github.io/open-ds-mcp-site/install.sh | OPEN_DS_INSTALL_TTY=/dev/null bash
```

3. **Verify.** Run the installer again with `--status` (after `bash -s --`). It shows the Claude Desktop extension once the user has clicked Install, the Claude Code entry and whether the WPP sign-in is saved. The user clicks Install and finishes the sign-in in their browser; you can't do either for them.
4. **Updates look after themselves.** Once a day the extension checks for a new version and Claude shows the user an update card. Only the user can click Update now and then Install; to update straight away, run the install command again.

## What you can do

- **Find the right component.** Ask for what you need ("a date range", "a toast with an action") and Claude searches every component page and guide, then reads the one that fits.
- **Write React with the real API.** Each component comes with its React usage, properties with their types and defaults, events (as `onWpp…` props), methods, slots, CSS parts and custom properties. Claude is told to use only what is documented.
- **See the examples.** Any story's source from the Storybook, with a link to open it.
- **Set up a project.** The install command for your release, and the getting-started and theming guides.
- **Stay on your release.** Choose a release ("use Open DS 4.5.0") and every answer follows it. Each page is checked against that release's package types, so a property the page doesn't document yet is flagged.
- **Find the docs, code and Figma files.** Ask for the developer docs, the npm packages, the repository or git remote of the web components or the React wrappers (with the clone command for your release), or the Figma libraries (Components, Foundations, Icons & Images) of any release.
- **Check code against a release.** Claude checks the code it writes, or any file, folder or Claude Design artboard, against your release's real API without installing anything: components, wrappers and props that don't exist, values a prop doesn't take, deprecated props, React habits that don't work with these web components (`onChange`, `event.target.value`, string booleans, `aria-*` that never reaches the control), hard-coded colours that are theme tokens (and, when upgrading, colours of the old theme), invented `--wpp-*` variables, CSS that selects a component by tag name, fonts other than WPP, pages and artboards that get no bundle, theme variables or WPP font (reading the local stylesheets they link), and native elements Open DS has a component for. It says what it can't check, and never calls a run clean when it found no Open DS components.
- **Compare releases.** What changed between two releases: components and icons added and removed, props added, removed, retyped or deprecated, theme token changes, and the release notes to read.
- **Use the theme.** Every `--wpp-*` token of a release (colours, type styles, radii, shadows), the spacing steps, the font, and the token for any colour.

## Questions to try

Once it's installed, ask Claude in any new chat:

```text
Which Open DS component should I use for a date range?
Build a settings form with WppInput, WppSelect and WppButton.
What events does WppSelect fire, and what is in event.detail?
How do I install Open DS in my Vite app?
Use Open DS 4.5.0.
Review how this app uses Open DS.
Upgrade this project to the latest Open DS release.
What changed in Open DS between 4.4.0 and 4.6.0?
Mock up a "create campaign" side modal in Claude Design with our kit.
```

## Workflows

For whole jobs, the server brings step-by-step workflows. Claude loads the right one when you ask for the job; you can also start one yourself, in Claude Code as `/mcp__open-ds__<name>` and in Claude Desktop from the **+** menu.

| Workflow | What it does |
| --- | --- |
| `build-ui` | Builds or changes a React screen, form or component with Open DS, at the release your project pins, and checks it before finishing |
| `review` | Reviews how a project, some files or a Claude Design canvas uses Open DS, and reports each problem with its fix |
| `upgrade` | Moves a project to another release: what changes, what breaks in your code before you install, then the upgrade, the fixes and the checks |
| `mock` | Mocks up screens in Claude Design with the real components of a kit (a Claude Design design system built from Open DS), keeping to the kit's release |
| `sync-kit` | Brings such a kit up to a new release through the kit's own build, and publishes only when you say so |

`mock` and `sync-kit` work with your kit. Save it once ("Use https://claude.ai/artifact/… as my Open DS kit") and both use it from then on, in every session and both apps; without one saved, Claude tells you once about the team's kit, WPP Open x Unified Kit (built from Open DS 4.4.0, with Unified Activation's page templates and patterns), and offers to save it, with its release and pin; ask Claude "where's the Open DS kit?" any time. If its link doesn't open for you, ask Jamie Mills for access. Claude also saves the release the kit is built from. If your kit has to stay on a release, for example because it mirrors an app that pins one, say so ("my kit is pinned to the release the app uses"): Claude then never suggests moving it to a newer release, and `sync-kit` moves it only when the app does.

## Tools

| Tool | What it gives |
| --- | --- |
| `open_ds_search` | Full-text search over every component page and guide, plus element names in the package |
| `open_ds_list_components` | Components by category with tag and React name; icons and sub-parts on request |
| `open_ds_get_component` | One component: usage for your framework (React by default), properties, events, methods, slots, CSS parts and custom properties, changes in your release, stories |
| `open_ds_get_story` | A story's source code (lit-html with web components) and its link |
| `open_ds_list_guides` | Getting started, theming, migration, release notes and the other pages |
| `open_ds_read_doc` | Any docs page as Markdown |
| `open_ds_status` | Sign-in state, what the Storybook documents, your release and the latest, and the React install command |
| `open_ds_set_version` | Choose the release to use (`4.5.0`, or `latest`); kept for every session and both apps |
| `open_ds_resources` | The developer docs, the npm packages, the GitHub repositories with their git remotes and clone commands, and the Figma libraries of any release (or every release) |
| `open_ds_check` | Checks code (files, folders, or source such as a Claude Design artboard) against a release's API, and lists each problem at its line; `from` adds colours of an older release's theme |
| `open_ds_compare` | What changed between two releases, and the release notes in between |
| `open_ds_tokens` | A release's theme tokens, spacing steps and font, and the token for a colour |
| `open_ds_workflow` | Loads a workflow (above) for Claude to follow |
| `open_ds_set_kit` | Saves your kit's link (or forgets it, with `none`) for `mock` and `sync-kit`; kept for every session and both apps |

## Choosing a release

By default it follows the newest release. To use another, ask Claude ("use Open DS 4.5.0"). The choice is saved on your Mac, so it lasts across sessions and applies in both Claude Desktop and Claude Code, until you choose another or `latest`. It changes the install command and the release each component page is checked against. The Storybook itself is one build and doesn't change; each release's notes stay readable ("show the release notes for 4.4.0").

In your React app, the release is the `#vX.Y.Z` at the end of both git URLs in `package.json`. Keep the two packages on the same tag.

## Using Open DS in React

The packages are `@wppopen/components-library` (the web components) and `@wppopen/components-library-react` (the React wrappers). Since v3.6.0 they are released only as git tags on GitHub, not to any registry, so a plain `npm install @wppopen/components-library` doesn't find current releases, and no token is needed. The Storybook's "Getting Started/Developers" guide still shows an old private-registry `.npmrc` step; skip it. Ask Claude for the install command (it comes for your release), or:

```bash
npm install \
  "@wppopen/components-library@git+https://github.com/WPP-Public/wpp--os--platform-ui-kit.git#v4.6.0" \
  "@wppopen/components-library-react@git+https://github.com/WPP-Public/wpp--os--platform-ui-kit-react.git#v4.6.0"
```

The React bindings support React 17 and 18 (their peer range) and need a bundler such as Vite or webpack. Import the theme once:

```tsx
import "@wppopen/components-library/dist/platform-ui-kit/wpp-theme.css";
import "@wppopen/components-library/dist/platform-ui-kit/global.css";
import { WppButton } from "@wppopen/components-library-react";
```

## Update and remove

- **Update now.** Once a day the extension checks for a newer version. When there is one, Claude shows an update card: **Update now** downloads it, checks its SHA-256 and opens Claude Desktop's install dialog, where you click **Install**. Your settings are kept.
- **Not now.** Hides that version for a week; a newer one is offered as usual.
- **Check any time.** Ask Claude "Check for updates to Open DS MCP Server".
- **Turn the check off.** Claude Desktop → Settings → Extensions → Open DS MCP Server → Check for updates.
- **Claude Code.** Its copy updates when you run the install command again.
- **See what's installed.** `curl -fsSL https://wpp-jamie-mills.github.io/open-ds-mcp-site/install.sh | bash -s -- --status`
- **Remove.** Add `--uninstall` instead of `--status`: it removes the Claude Code entry and the data folder (`~/.open-ds-mcp`: the saved extension, the cache and your chosen release). Remove the extension itself in Claude Desktop → Settings → Extensions.

## Security and privacy

- **Read-only.** Every tool reads. The two exceptions save a choice in `~/.open-ds-mcp/settings.json`: the release you choose, and the link of your kit.
- **Your files.** Only `open_ds_check` reads files on your Mac: the files and folders Claude passes it, and in folders only source files (`.tsx`, `.jsx`, `.ts`, `.js`, `.html`, `.css`), leaving out `node_modules` and build output. It never changes them, and nothing it reads leaves your Mac.
- **Signs in as you.** The Storybook (components.os.wpp.com) is behind Cloudflare Access. The server signs you in the way Cloudflare's own `cloudflared` does: WPP's sign-in opens in your browser, and Cloudflare hands the Storybook's token back sealed to a key made for that one sign-in, which only the server holds. Before starting, it checks that the Storybook's Cloudflare Access details are signed by WPP's Cloudflare Access domain. The token is kept in your macOS login Keychain (service `open-ds-mcp`), written and read through macOS's `security` tool so it never appears in a command line, and while the server runs, in memory. It is sent only to the Storybook, and never logged or shown to Claude. It lasts as long as your WPP session for the Storybook (up to 24 hours).
- **What it fetches.** Storybook files, with your sign-in, and public files from GitHub (the release list, and each release's component types, theme stylesheets and list of React wrappers), with no credentials. Asked for Figma libraries, it checks each file is there with a HEAD request to public-assets.os.wpp.com, also without credentials.
- **What it keeps.** A cache of those files in `~/.open-ds-mcp/cache`, readable only by you, and your chosen release. Once a day, the update check's result in `~/Library/Caches/open-ds-mcp`.
- **The update check.** It fetches `latest.version` from the address the installer downloads from; nothing about you is sent. Only Update now downloads the extension, and it is opened only if it matches the published SHA-256 and is this extension at that version.
- **The installer.** It checks the download's SHA-256 before changing anything, only asks questions in a terminal, and with no terminal answers no.

## Troubleshooting

- **"A WPP sign-in page has opened"**: finish it in your browser, then ask again. Sign-ins last up to 24 hours; while your browser is still signed in to WPP the page finishes by itself in a few seconds. If no page opened, the answer includes its address to open.
- **"Couldn't save the WPP sign-in in the macOS Keychain"**: unlock your login keychain (Keychain Access) and ask again; until then the sign-in lasts only until Claude restarts.
- **Claude doesn't see the tools**: start a new chat; chats opened before the install don't get them. In Claude Code, start a new session.
- **"Checksum mismatch — nothing was installed"**: a new release can take up to about 10 minutes to reach every server; run the command again.
- **Claude Code already has an `open-ds` server**: the installer asks before replacing it, and with no terminal leaves it alone. Remove it with `claude mcp remove --scope user open-ds`, then run the installer again.
- **A page doesn't mention a property**: the Storybook can lag the release. The component's answer lists what your release adds.
- **"has no React wrapper"**: a few elements (seven icons, such as `wpp-icon-play-filled`) are web components only in every release so far. The answer says how to use the element in React instead.

---

<sub>Generated from the project README for version 0.6.3. It is rebuilt automatically with each release.</sub>
