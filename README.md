# acl2-acl2r-docker

A reproducible Docker environment with **ACL2 8.7** and **ACL2(r) 8.7** (the
variant with real numbers / nonstandard analysis) side by side, with the
community books that formal-verification projects typically need already
certified. Build it once and nothing has to be recertified afterwards.

Built to reproduce the machine-checked results of two verification projects
(three-phase AC machine model and rectifier checks), and to be usable as the
ACL2 engine behind MCP servers such as
[pcayuela/acl2-mcp](https://github.com/pcayuela/acl2-mcp).

## What is in the image

| | Plain ACL2 | ACL2(r) |
|---|---|---|
| Location | `/opt/acl2` | `/opt/acl2r` |
| Executable | `acl2` → `/opt/acl2/saved_acl2` | `acl2r` → `/opt/acl2r/saved_acl2r` |
| Certified books | `arithmetic-5/top` | `arithmetic-5/top`, `nonstd/nsa/nsa`, `nonstd/nsa/trig`, and the `reid-gamboa-differentiator` support books (`exp-minimal`, `differentiator`) |

Both use ACL2 commit `4cab4f162b44fd6f01b8a3fb2e3d39be57ee2a3f` (ACL2 8.7) and
SBCL 2.6.5, built from source on Ubuntu 24.04.

**Why two trees?** ACL2 and ACL2(r) certificates are mutually incompatible
("ACL2 books may not be processed by ACL2(r) or vice versa"; certificates record
`ACL2 Version 8.7` versus `8.7(r)`), and the system-books path is baked into
each saved executable. Each flavor therefore has its own books tree, so the
certificates of one never overwrite the other's.

Only the books listed above are certified, not the whole community library; this
keeps the image at about 4.6 GB and the build short. To add books, extend
`PLAIN_BOOKS` / `REAL_BOOKS` in the `Dockerfile` (they are space-separated
`cert.pl` targets, relative to `books/`).

## Build and test

```bash
docker build -t acl2-pcayuela .     # takes a while: SBCL and ACL2 are compiled from source and books are certified
./test.sh acl2-pcayuela            # loads certified books and proves a theorem in each flavor
```

Build arguments: `ACL2_COMMIT`, `SBCL_VERSION`, `JOBS`, `PLAIN_BOOKS`,
`REAL_BOOKS`.

Use it interactively:

```bash
docker run --rm -it acl2-pcayuela acl2     # plain ACL2
docker run --rm -it acl2-pcayuela acl2r    # ACL2(r)
```

## Recertify a project from clean sources

`verify-project.sh` copies only the sources (`*.lisp`, `*.acl2`, `*.lsp`) of a
project to a temporary directory, runs `cert.pl` on a top book inside the
container, and checks that the certificate was produced by the expected flavor.
Existing `.cert` files are never used and the project directory is not modified.

```bash
./verify-project.sh /path/to/project plain top          # plain ACL2
./verify-project.sh /path/to/project real  top-acl2r    # ACL2(r)
```

## Using the image as the engine of an MCP server

`acl2-docker` and `acl2r-docker` are wrapper scripts that start the matching
executable in a container, with a pseudo-terminal, so they can be passed as the
ACL2 executable of an MCP server. The current directory is mounted at the **same
absolute path** inside the container, so absolute host paths work, and the
container runs as your user so the files ACL2 writes (`.cert`, `.fasl`, …) belong
to you.

```bash
# full-featured server (pcayuela/acl2-mcp), ACL2(r) in Docker
claude mcp add acl2r-docker \
  -e ACL2_MCP_EXECUTABLE=/path/to/acl2-acl2r-docker/acl2r-docker \
  -e ACL2_MCP_NAME=acl2r-docker \
  -- /path/to/acl2-mcp/venv/bin/acl2-mcp
```

- Extra directories to mount: `ACL2_DOCKER_MOUNTS="/path/a:/path/b"`.
- Start sessions with `cwd` set to the project directory (or add it to
  `ACL2_DOCKER_MOUNTS`); a path that is not mounted does not exist inside the
  container.
- Each MCP session starts a fresh, throw-away container (`--rm`): in-memory
  definitions are lost when the session ends, as with a local ACL2. Files written
  to mounted directories persist.
- Image name defaults to `acl2-pcayuela`; override with `ACL2_DOCKER_IMAGE`.

Tested with the full `acl2-mcp` server (plain ACL2 and ACL2(r)) and with the
minimal `acl2r-mcp` server.

## Verification status

The following were recertified from clean sources inside this image
(certificates: `ACL2 Version 8.7` for the plain chain, `8.7(r)` for the others):
the `top` books of `ACL2-ACmotormodel-check` (plain chain `00`–`07`),
`top-acl2r` of the same project, and the `top` book of `ACL2-rectifiers-check`.

## Licenses and credits

The files in this repository (Dockerfile, scripts, documentation) are under the
BSD 3-Clause license (see `LICENSE`). They do not contain code from ACL2 or SBCL:
the image downloads and builds [ACL2](https://github.com/acl2/acl2) (BSD-3-Clause,
© the ACL2 authors) and [SBCL](http://www.sbcl.org/) (public domain, with some
BSD-licensed parts) at build time. The Dockerfile's multi-stage structure
(SBCL builder, pinned ACL2 commit, `WITH_REAL` option) was inspired by
[jimwhite/acl2-jupyter](https://github.com/jimwhite/acl2-jupyter); no code was
copied.
