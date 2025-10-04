## Hit the Git
This repository contains a collection of `Bash` scripts that simplify and automate common `Git` operations.

### 🪄 Usage
- Run a script using bash command:
    ```bash
    source <scriptname>.sh
    ```
- Or, make it executable and run directly:
    ```bash
    chmod +x <scriptname>.sh
    ./<scriptname>.sh
    ```

### 🐳 Run in a Docker Sandbox (Optional)
Run or test the scripts in an isolated container (you may need `sudo` access):
```docker
docker build -t bash-env .
docker image prune
docker run -it --rm --privileged -v "$PWD":/hit-the-git bash-env
```
What this does:
- Builds a `Docker` image from the included `Dockerfile`
- Prunes dangling docker images after building
- Mounts the current repository into `/hit-the-git` inside the container
- Starts an interactive `Bash` environment with `Git` available

### 🛠️ Prerequisites
- [GNU Bash](https://www.gnu.org/software/bash/)
- [Git](https://git-scm.com/)
- [Docker](https://www.docker.com/)
