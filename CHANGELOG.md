# Changelog

## 1.2.11
### Enhancements
- Added SSL certificate download functionality from the vhost page (see help button)
- Improved mobile responsiveness
- Updated DevProxy logo

## 1.2.10
### Enhancements
    - Add database icon support and expand frontend-related icon mappings on the vhost page

## 1.2.9
### Enhancements
 - Added a default [localhost](https://localhost) page showing all available vhosts when accessing the root URL
 - Added `--json` option to `show-vhosts.sh` command to output vhosts in JSON format
 - Added `--list` option to `show-vhosts.sh` command to list vhosts without formatting

## 1.2.2
### Enhancements
 - Replace tput with ANSI escape codes for better compatibility

## 1.2.1
### Enhancements
 - Improved `_check_image_version` function in `start-proxy.sh` to use `perl` instead of `grep` for better compatibility on MacOS

### Bug fixes
 - Fixed the issue with the `list` command not working immediately after proxy start
 - Fixed HTTPS port hadling in `list` command
 - Fixed the `_start function` in `start-proxy.sh` to ensure the network always exists before starting the container (resolves [#3](https://github.com/dontfreakout/dev-proxy/issues/3), thanks [@DominikVisek](https://github.com/DominikVisek) for reporting)

## 1.2.0
### Enhancements
- Improved `_check_image_version` function in `start-proxy.sh` to use `grep` instead of `jq` _(**fewer dependencies**)_.
- Enhanced `list` command - retry fetching server names with configurable retry interval and max attempts.
- Updated `Makefile` to support multi-platform Docker builds and push Docker manifests.
- Added `CONTAINER_TAGS_URL` variable to get rid of hardcoded url in the script.
### Bug fixes
- Updated README.md with correct repository links and additional MacOS certificate path.

## 1.1.2
### Bug fixes
 - Fix check for running container on first run

## 1.1.1
### New features
 - enable check for script updates

## 1.1.0
### New features
 - The updated script now uses awk to better sort and list out domains. The output now includes better-segregated and colored results to enhance readability.

## 1.0.17
### Bug fixes
- Fix nginx configuration for unlimited content size

## 1.0.16
### New features
- Allow unlimited content size in requests

## 1.0.14
### New features
- Better automatic update of the proxy container

## 1.0.12
### Bug fixes
- Remove 60s proxy read and send timeout

## 1.0.11
### New features
- Command to list available vhost urls `./dev-proxy.sh list`
- Automatically check if docker image is up-to-date with the latest version and pull it if not

## 1.0.6
 - Initial release
