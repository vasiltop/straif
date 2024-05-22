# Straif

Straif is a fast-paced time trial game inspired by the movement mechanics of the Source Engine games like Counter-Strike: Source. It will include multiple gamemodes / maps, and has a global leaderboard, giving players the chance to compete for the best times.

## Quick Links
- [Images](#Images)
- [Installation](#installing)
- [Private Servers](#hosting-a-private-server)

## Images

![image 1](./images/game1.png)
![image 2](./images/game3.png)
## Installing
### Prerequisites

- [Godot Steamworks (4.2.2)](https://github.com/GodotSteam/GodotSteam/releases/tag/v4.7)

```bash
git clone https://github.com/vasiltop/straif
cd straif
godot -e
```

In godot, make a new script called settings.gd (in the root folder). In the settings.gd file, we must add a few variables for configuration, here is an example.

```python
extends Node

var sens = 0.001
var base_url = "http://localhost:8000/"
var password = "password" #your servers password

var save_file = "user://runs.save"
var volume = 0
```

Make sure it is in this exact format, or the game might not run properly.
Then we can run the game (Steam must be running).

```bash
godot
```

## Hosting a private server

### Prerequisites

- [Rust (nightly)](https://www.rust-lang.org/)
- [Postgres](https://www.postgresql.org/)

```bash
git clone https://github.com/vasiltop/straif
cd straif/server
vim .env
```

Add the following into the .env file.

```python
PASSWORD="example" #Must match the password in the client
DATABASE_URL="postgres://example:example@example:0000/straif" #Url of your postgres server
STEAM_API_KEY="steam-web-api-key"
```

Now we setup the database and run our server.

```bash
cargo install sqlx-cli
sqlx database create
sqlx migrate run
cargo run --release
```
