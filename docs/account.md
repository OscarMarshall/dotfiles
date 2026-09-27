# Your account

Almost everything here uses one shared account, run by a sign-in service called **Authentik** at <https://@auth@>. Once
you're signed in there, the other services let you straight in: look for a button that says **Authentik** (or **OAuth**)
on their sign-in page, or you'll be sent to Authentik automatically.

There are **no passwords**. You sign in with Discord, a passkey, or a one-time code sent to your email.

!!! note "Plex is the exception"

    Plex uses your own Plex account, not this one. See the [Plex guide](guides/plex.md).

## Getting an account

You'll join in one of two ways. Either works; ask @admin@ which one to use.

=== "With an invite link"

    @admin@ will send you a link that looks like `https://@auth@/if/flow/invite/?itoken=…`.

    1. Open the link. (Each link only works for you — don't share it.)
    2. Choose a **username**, and enter your **name** and **email**. Use an email you can check: sign-in codes are
       sent there.
    3. Create a **passkey** when asked. Your phone or computer will ask you to confirm with your fingerprint, face,
       PIN, or security key. This is how you'll sign in from now on.
    4. That's it — you're signed in, and your account can already use every service on the
       [Services](services.md) page.

=== "With Discord"

    1. Go to <https://@auth@> and click the **Discord** button.
    2. Approve the request in Discord.
    3. Tell @admin@ you've signed up. Accounts made through Discord **can't open anything yet** until @admin@ adds
       you to the right group — until then, services will say you don't have access.

## Signing in

On the Authentik sign-in page you have three options:

- **Discord button** — if you joined with Discord, or have linked it since.
- **Log in with a passkey** — the link under the form. Your device asks for your fingerprint, face, or PIN, and you're
  in. The fastest option once it's set up.
- **Type your username or email** — Authentik emails you a short **sign-in code**. Enter it to finish. The first time
  you do this, Authentik sets email codes up for you along the way — just enter the code it sends.

You stay signed in for **30 days** on each device.

!!! tip "Passkeys on more than one device"

    A passkey saved in iCloud Keychain, Google Password Manager, or a password manager like 1Password or Bitwarden
    follows you to your other devices. If yours didn't, add another one from your account settings (below) on each
    device, or use the email code instead.

## Managing your account

Sign in at <https://@auth@> and open **Settings** (the gear icon, top right). From there you can:

- **Set up a passkey** on a new phone or computer.
- **Change your sign-in email**, where your codes are sent.
- **Link Discord**, so its button signs you in too.
- **See the apps you can open.** Authentik's home page (**My applications**) lists every service your account can use,
  and clicking one takes you straight there.

## What your account can use

Everything on the [Services](services.md) page. The other tools on this server (downloaders, monitoring, and so on) are
admin-only — if you see **"Permission denied"** or **"You don't have access to this application"**, that's why. If you
think you should have access, [ask](help.md).
