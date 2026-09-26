# Seerr

Seerr is where you ask for movies and shows that aren't in the library yet. Search for something, click **Request**, and
it's downloaded and added to [Jellyfin](jellyfin.md) automatically — usually within a few hours for anything recent and
popular.

**Address:** <https://seerr.@domain@>

## Signing in

1. Go to <https://seerr.@domain@>.
2. Click **Sign in with Authentik**.

## Making a request

1. Search for a movie or show using the search bar at the top, or browse the **Trending**, **Popular**, and **Upcoming**
   rows on the home page.
2. Open it and click **Request**.
3. For a show, pick which **seasons** you want (or all of them) and click **Request** again.

That's it. The poster gets a badge showing where it's up to:

| Badge                   | Meaning                                      |
| ----------------------- | -------------------------------------------- |
| **Requested / Pending** | Your request is in.                          |
| **Processing**          | It's being found and downloaded.             |
| **Partially Available** | Some episodes or seasons are ready to watch. |
| **Available**           | It's in Jellyfin — go watch it.              |

## Tips

- **Already in the library?** Things you can already watch show **Available** — there's a **Play** button that opens it
  in Jellyfin.
- **Not out yet?** You can still request it. It's picked up automatically on release.
- **Waiting a long time?** Older or less popular titles can take longer to find, and some can't be found at all. If a
  request has been stuck for more than a few days, [let @admin@ know](../help.md).
- **Your requests** — see everything you've asked for under **Requests** in the sidebar.
