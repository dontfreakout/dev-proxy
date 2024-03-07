<a name="readme-top"></a>

<br />
<div align="center">
<h3 align="center">Local Docker Reverse Proxy</h3>

  <p align="center">
    Reverse proxy for local development with Docker or Podman
    <br />
    <a href="https://github.com/github_username/repo_name"><strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://github.com/github_username/repo_name/issues">Report Bug</a>
    ·
    <a href="https://github.com/github_username/repo_name/issues">Request Feature</a>
  </p>
</div>

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation">Installation</a></li>
      </ul>
    </li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#roadmap">Roadmap</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#acknowledgments">Acknowledgments</a></li>
  </ol>
</details>

## Getting Started

### Prerequisites
To use this project you need to have Docker or Podman installed. No other dependencies are required.

### Installation
You can download the script and run it from there. Alternatively you can clone the repository and run the script from there

#### Download the script
```sh
curl -O https://raw.githubusercontent.com/dontfreakout/repo/master/start-proxy.sh
```

#### Change permission
```sh
chmod +x start-proxy.sh
```

#### Optional: move the script to a directory in your PATH
for example:
```sh
mv start-proxy.sh ~/.local/bin/dev-proxy
```

## Usage

### Configure containers you want to  proxy
You have to configure the containers you want to proxy in the `docker-compose.yml` file. 
You need to add the hostname, port and protocol to the environment variables of the container.
Also, you need to add the container and the service to the proxy network.


Example configuration:
```yaml
version: "3.9"
services:
  my-service:
    networks:
      proxy:
    environment:
      VIRTUAL_HOST: example.localhost
      VIRTUAL_PORT: 80 # port of the service
      VIRTUAL_PROTO: http # (valid options are https or http) if using https, you probably want to use VIRTUAL_PORT: 443

networks:
  proxy:
    name: proxy_network # name of the proxy network needs to be the same as in the script
```

### Configure domains
If you want to use multiple domains on one service you can separate them with a comma.
```yaml
VIRTUAL_HOST: example.localhost,example2.localhost
```


### Run the script
You can run the script using the following command. 
This will download docker image and start the proxy with default settings.

```sh
./start-proxy.sh
```

### Command line options
**Usage:** `./start-proxy.sh [options] [command]`

#### Commands:
| Command     | Description                            |
|-------------|----------------------------------------|
| `list`      | List currently available vhost urls    |
| `stop`      | Stop the proxy                         |
| `update`    | Update proxy container                 |
| `uninstall` | Remove the proxy container and network |

#### Exposed ports:
The proxy is by default available to local machine on port 80 and 443. You can change this with parameters.
```sh
./start-proxy.sh -s 8443 -i 8080
```

#### All options:
| Option              | Description                 | Default value                            |
|---------------------|-----------------------------|------------------------------------------|
| `-s`, `--secure`    | Port for https              | 443 for docker, 8443 for rootless podman |
| `-i`, `--insecure`  | Port for http               | 80 for docker, 8080 for rootless podman  |
| `-n`, `--network`   | Name of the proxy network   | proxy_network                            |
| `-c`, `--container` | Name of the proxy container | dev-proxy                                |
| `-h`, `--help`      | Show help                   |                                          |
| `-v`, `--version`   | Show version                |                                          |


### SSL certificate
The proxy uses a self-signed certificate. To add it to your browser and get rid of the warning you need to import the root certificate.
You can follow the steps below to import the certificate.

#### Chrome
1. Open Chrome and go to `chrome://settings/certificates`
2. Click on `Authorities` tab
3. Click on `Import`
4. Select Root certificate from config folder
    - Linux: `~/.config/dev-proxy/certs/rootCA.crt`
    - MacOS: `~/Library/Application Support/dev-proxy/certs/rootCA.crt`
5. Click on `Trust this certificate for identifying websites`
6. Click on `OK`

#### Firefox
1. Open Firefox and go to `about:preferences#privacy`
2. Scroll down and click on `View Certificates`
3. Click on `Authorities`
4. Click on `Import`
5. Select Root certificate from config folder
    - Linux: `~/.config/dev-proxy/certs/rootCA.crt`
    - MacOS: `~/Library/Application Support/dev-proxy/certs/rootCA.crt`
6. Click on `OK`


## Roadmap
 - add option to install as docker service
 - possibility to install certificate system-wide
 - check for new version and self update

See the [open issues]() for a list of proposed features (and known issues).

## Change log
See [CHANGELOG.md](CHANGELOG.md) for more information on what has changed recently.

## Contributing
Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

## License
Distributed under the MIT License. See `LICENSE` for more information.

## Acknowledgments
* [nginx-proxy](https://github.com/nginx-proxy/nginx-proxy)
