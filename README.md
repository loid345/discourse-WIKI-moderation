# Discourse Wiki Moderation Plugin

Adds moderation for wiki edits with an approve/reject flow via the Discourse review queue.

## How it works

- When a non-exempt user edits a wiki post, the change is captured and reverted.
- A reviewable item is created for staff to approve or reject the edit.
- Optional notifications are sent to moderators and/or the original editor.

## Settings

All settings live under **Admin → Settings → Plugins → Wiki moderation**.

- `wiki_moderation_enabled`: enable moderation for wiki edits.
- `wiki_moderation_ignore_staff`: allow staff to edit without approval.
- `wiki_moderation_exempt_groups`: groups that can edit without approval.
- `wiki_moderation_notify_moderators`: send staff notifications for pending edits.
- `wiki_moderation_notify_authors`: notify authors on approval/rejection.
