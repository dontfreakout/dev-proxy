#!/usr/bin/env bash
set -e

VERSION=1.0.5
NETWORK_NAME=proxy_network
CONTAINER_NAME=dev-proxy
IMAGE_NAME=dontfreakout/dev-proxy:latest
CONFIG_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/dev-proxy
USER_ID=$(id -u)

bold=$(tput bold)
normal=$(tput sgr0)
italic=$(tput sitm)

_parse_args() {
	VALID_ARGS=$(getopt -o s:i:n:c:hv -l secure:,insecure:,network,container,help,version --name "$0" -- "$@")
	if [[ $? -ne 0 ]]; then
		exit 1
	fi

	eval set -- "$VALID_ARGS"
	while [ : ]; do
		case "$1" in
		-s | --secure)
			SECURE_PORT="$2"
			shift 2
			;;
		-i | --insecure)
			INSECURE_PORT="$2"
			shift 2
			;;
		-n | --network)
			NETWORK_NAME="$2"
			shift 2
			;;
		-c | --container)
			CONTAINER_NAME="$2"
			shift 2
			;;
		-h | --help)
			_usage
			exit 0
			;;
		-v | --version)
			echo "dev-proxy version $VERSION"
			exit 0
			;;
		--)
			shift
			break
			;;
		*)
			echo "Internal error!"
			exit 1
			;;
		esac
	done
}

_usage() {
	cat <<-EOF
	${bold}Usage:${normal} $0 [options] [command]
	Starts a dev-proxy container

	${bold}Commands:${normal}
	  stop                     Stop the container
	  update                   Update the proxy container
	  uninstall                Remove the proxy container and network

	${bold}Options:${normal}
	  -s, --secure <port>      Secure port (defaults to 443)
	  -i, --insecure <port>    Insecure port (defaults to 80)
	  -n, --network <name>     Network name (defaults to proxy_network)
	  -c, --container <name>   Container name (defaults to dev-proxy)
	  -h, --help               Show this help
	  -v, --version            Show version

		${bold}docker-compose.yml configuration:${normal}
		add network to docker-compose.yml:
		-----------------------------------------
		${italic}
		networks:
		  proxy:
		    name: $NETWORK_NAME
		${normal}
		add network to services:
		-----------------------------------------
		${italic}
		services:
		  my-service:
		    networks:
		      proxy:
		${normal}
		add environment variables to services:
		-----------------------------------------
		${italic}
		services:
		  my-service:
		    environment:
		      VIRTUAL_HOST: example.localhost
		      VIRTUAL_PORT: 80 # port of the service
		      VIRTUAL_PROTO: http # (valid options are ${bold}https${normal} or ${bold}http${normal}) if using https, you probably want to use VIRTUAL_PORT: 443

		-----------------------------------------
		${bold}Multiple hosts on one container:${normal}
		Just separate the VIRTUAL_HOST values with a comma.
		Ex: ${italic}VIRTUAL_HOST: example.localhost,example2.localhost${normal}

	EOF
}
############################### Checks ########################################

_check_script_verion() {
	if [ $((RANDOM % 100)) -ne 0 ]; then
		return
	fi

	curl -s https://raw.githubusercontent.com/dontfreakout/dev-proxy/master/start-proxy.sh > /tmp/start-proxy.sh
	if ! cmp -s "$0" /tmp/start-proxy.sh; then
		echo "Updating script to latest version"
		mv /tmp/start-proxy.sh "$0"
		chmod +x "$0"
		echo "Restarting script..."
		exec "$0" "$@"
	fi
}

_network_exists() {
	if ! $RUNNER network inspect $NETWORK_NAME >/dev/null 2>&1; then
		echo "Network $NETWORK_NAME not found. Creating..."
		$RUNNER network create $NETWORK_NAME
	fi
}

_container_exists() {
	if $RUNNER container inspect $CONTAINER_NAME >/dev/null 2>&1; then
		return 0
	else
		return 1
	fi
}

_is_podman_rootless() {
	if [ -S /run/user/${USER_ID}/podman/podman.sock ]; then
		#echo "Podman rootless detected"
		return 0
	else
		return 1
	fi
}

_is_container_running() {
	CONTAINER_STATE=$($RUNNER inspect --format="{{.State.Status}}" $CONTAINER_NAME 2>/dev/null)
	if [ "$CONTAINER_STATE" == "running" ]; then
		return 0
	else
		return 1
	fi
}

############################### Runner Config #########################################

_podman_config() {
	RUNNER=podman

	if _is_podman_rootless; then
		SOCKET=/run/user/${USER_ID}/podman/podman.sock
		SECURE_PORT=${SECURE_PORT:-8443}
		INSECURE_PORT=${INSECURE_PORT:-8080}
	else
		SOCKET=/run/podman/podman.sock
	fi
}

_docker_config() {
	RUNNER=docker
	SOCKET=/var/run/docker.sock
	SECURE_PORT=${SECURE_PORT:-443}
	INSECURE_PORT=${INSECURE_PORT:-080}
}

############################### Commands #########################################

_init() {
	if command -v podman >/dev/null 2>&1; then
		_podman_config
	elif command -v docker >/dev/null 2>&1; then
		_docker_config
	else
		echo "Neither podman nor docker executable found in PATH" >&2
		exit 1
	fi

	if [ ! -S ${SOCKET} ]; then
		echo "Socket ${SOCKET} not found" >&2
		exit 1
	fi

	if [ ! -d ${CONFIG_DIR} ]; then
		mkdir -p ${CONFIG_DIR}
	fi
}

_update() {
	_uninstall
	$RUNNER pull $IMAGE_NAME
	_start
}

_uninstall() {
	if _container_exists; then
		_stop
		echo "Removing container $CONTAINER_NAME"
		$RUNNER rm -f "$CONTAINER_NAME"
	fi

	if _network_exists; then
		echo "Removing network $NETWORK_NAME"
		$RUNNER network rm -f "$NETWORK_NAME" 2>/dev/null || true
	fi
}

_stop() {
	if _container_exists; then
		echo "Stopping container $CONTAINER_NAME"
		$RUNNER stop "$CONTAINER_NAME" 2>/dev/null
	fi
}

_start() {
	if ! _container_exists; then
  	echo "Container $CONTAINER_NAME not found. Creating..."
  	_full_start
  	exit 0
  fi

  if ! _is_container_running; then
  	echo "Container $CONTAINER_NAME not running. Starting..."
  	$RUNNER start "$CONTAINER_NAME"
  	exit 0
  else
  	echo "Container $CONTAINER_NAME already running"
  fi
}

_full_start() {
	_network_exists
	$RUNNER run -d --name "$CONTAINER_NAME" --net "$NETWORK_NAME" --security-opt label=disable -p "${INSECURE_PORT}:80" -p "${SECURE_PORT}:443" -e AUTOCERT=shared -v "${SOCKET}:/tmp/docker.sock:ro" -v "${CONFIG_DIR}/certs:/etc/nginx/certs:z" $IMAGE_NAME
}

_parse_args "$@"

_init

case "$1" in
update)
	_update
	exit 0
	;;
uninstall)
	_uninstall
	exit 0
	;;
stop)
	_stop
	exit 0
	;;
esac

_start
