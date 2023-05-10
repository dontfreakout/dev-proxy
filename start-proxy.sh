#!/usr/bin/env bash
set -e

VERSION=1.0.17
NETWORK_NAME=proxy_network
CONTAINER_NAME=dev-proxy
IMAGE_NAME=dontfreakout/dev-proxy:latest
CONFIG_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/dev-proxy
USER_ID=$(id -u)
SCRIPT_URL=https://raw.githubusercontent.com/dontfreakout/dev-proxy/master/start-proxy.sh

bold=$(tput bold)
normal=$(tput sgr0)
italic=$(tput sitm)

_usage() {
	cat <<-EOF
	${bold}Usage:${normal} $0 [options] [command]
	Starts a dev-proxy container

	${bold}Commands:${normal}
	  list					   List currently available vhost urls
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

_check_script_version() {
	# Check if script is up to date
	SCRIPT_VERSION=$(curl -s $SCRIPT_URL | grep -m 1 "VERSION=" | cut -d "=" -f 2 | tr -d '"')

	if [ $(_version_compare $VERSION) -ge $(_version_compare $SCRIPT_VERSION) ]; then
		#echo "Script is up to date."
		return
	fi

	echo "Script is out of date. Run '${bold}$0 update${normal}' to update."
}

_update_script() {
	curl -s $SCRIPT_URL > /tmp/start-proxy.sh
	mv /tmp/start-proxy.sh "$0"
	chmod +x "$0"
	echo "Script updated to version $SCRIPT_VERSION"
}

# Check if docker image is up to date, ignore latest tag
_check_image_version() {
    REMOTE_VERSION=$(curl -s https://registry.hub.docker.com/v2/repositories/dontfreakout/dev-proxy/tags/ | jq -r '.results[] | select(.name != "latest") | .name' | sort -V | tail -n 1)
    LOCAL_VERSION=$( $RUNNER inspect --format="{{.Config.Labels.version}}" "$CONTAINER_NAME" 2>/dev/null )

    # If no local version, pull image
    if [ -z "$LOCAL_VERSION" ]; then
        echo "No local version found. Pulling latest image."
        $RUNNER pull $IMAGE_NAME
        return
    fi

    if [ $(_version_compare $LOCAL_VERSION) -ge $(_version_compare $REMOTE_VERSION) ]; then
    		echo "Docker image is up to date."
    		return
		fi

    # If local version is less than remote version and remote short version is same as script version, pull image
    if [ $? = 1 ] && [ "${REMOTE_VERSION%.*}" = "${VERSION%.*}" ]; then
        echo "Pulling latest image"
        $RUNNER pull $IMAGE_NAME
    fi
}

_check_internet_connection() {
		if ping -q -c 1 -W 1 google.com >/dev/null; then
			return 0
		fi

		echo "No internet connection"
		return 1
}

_check_for_updates() {
	if _check_internet_connection; then
		_check_script_version
		_check_image_version
	fi
}

_version_compare() {
    # https://apple.stackexchange.com/questions/83939/compare-multi-digit-version-numbers-in-bash/123408#123408
    # Usage:
    # if [ $(version $VAR) -ge $(version "6.2.0") ]; then
    #    echo "Version is up to date"
    #fi
    echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }';
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
	_migrate
	_start
}

_migrate() {
	if [ ! -d "${CONFIG_DIR}/certs/" ]; then
  		mkdir -p "${CONFIG_DIR}/certs"
	fi

	# move root cert to new location
	if [ -f "${CONFIG_DIR}/rootCA.pem" ]; then
		mv "${CONFIG_DIR}/rootCA.*" "${CONFIG_DIR}/certs/"
	fi
}

_uninstall() {
	if _container_exists; then
		_stop
		echo "Removing container $CONTAINER_NAME"
		$RUNNER rm -f "$CONTAINER_NAME"
	fi

	if _network_exists; then
		echo "Removing network $NETWORK_NAME"
		$RUNNER network rm "$NETWORK_NAME" 2>/dev/null || true
	fi
}

_show_vhosts() {
	if _is_container_running; then
		echo "Showing available vhosts"
		echo "-----------------------------------------------"
		$RUNNER exec -it "$CONTAINER_NAME" /bin/bash -c "/app/show-vhosts.sh"
		echo "-----------------------------------------------"
	else
		echo "Service not running. You can start it with ${bold}$0${normal}"
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
	$RUNNER run -d --name "$CONTAINER_NAME" --net "$NETWORK_NAME" --security-opt label=disable -p "${INSECURE_PORT}:${INSECURE_PORT}" -p "${SECURE_PORT}:${SECURE_PORT}" -e HTTP_PORT="${INSECURE_PORT}" -e HTTPS_PORT="${SECURE_PORT}" -e AUTOCERT=shared -v "${SOCKET}:/tmp/docker.sock:ro" -v "${CONFIG_DIR}/certs:/etc/nginx/certs:z" $IMAGE_NAME
}

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

_parse_args "$@"

_init

# Check for updates in random intervals
#if [ $((RANDOM % 2)) -eq 0 ]; then
	_check_for_updates
#fi

case "$1" in
list)
	_show_vhosts
	exit 0
	;;
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
