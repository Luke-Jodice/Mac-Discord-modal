# Discord Bar

A macOS menu bar app: click the paper-plane icon at the top of your screen,
type a message, and send it to a Discord channel.

It uses **Discord webhooks** — the safe, supported way to post to a channel.
No bot, no logging in with your account (which would violate Discord's terms).

## What it does

- Lives in the menu bar (no Dock icon).
- Click it → a small popover opens with:
  - a **channel picker** (each channel = one webhook URL you add),
  - your **2 most recently sent** messages,
  - a **text box + Send** button (also sends with ⌘↩).
- A gear button opens settings to add/remove channels and set a display name.

### What it can't do
Webhooks are send-only, so the app **cannot read other people's messages** or
list a server's channels. "Recently sent" shows only what *you* sent from here.
Reading live chat would require a Discord bot added to a server you control —
ask if you want that version instead.

## Get a webhook URL (one per channel)

1. In Discord, open the channel you want to post to.
2. **Edit Channel → Integrations → Webhooks → New Webhook**.
3. **Copy Webhook URL**. (You need "Manage Webhooks" permission on that channel.)
4. Paste it into the app's settings, give it a name, click **Add channel**.

## Build & run

Requires the Swift toolchain (Xcode Command Line Tools is enough).

```bash
./build-app.sh        # builds DiscordBar.app
open DiscordBar.app    # launches it; look in the menu bar
```

For quick development without bundling:

```bash
swift run
```

The first time you open the `.app`, macOS Gatekeeper may warn it's unsigned —
right-click the app → **Open**, then confirm.

## Start automatically at login (optional)

System Settings → General → Login Items → **+** → choose `DiscordBar.app`.
# Mac-Discord-modal
