#!/bin/bash
set -euo pipefail

if [ -z "${1:-}" ]; then
    echo "Usage: $0 <repository-name> [target-dir]"
    exit 1
fi

repo_name="$1"
remote_url="git@github.com:railmapgen/${repo_name}.git"
workspace="/root/${repo_name}"
target_dir="${2:-/www/${repo_name}}"
state_dir="/root/.release-manifests"
sanitized_target="${target_dir//\//_}"
manifest_file="${state_dir}/${repo_name}${sanitized_target}.txt"

sync_workspace_into_target() {
    local source_dir="$1"
    local destination_dir="$2"
    local previous_manifest="$3"
    local current_manifest
    local source_path
    local entry

    mkdir -p "${destination_dir}" "${state_dir}"
    current_manifest="$(mktemp)"

    if [ -f "${previous_manifest}" ]; then
        while IFS= read -r entry; do
            [ -z "${entry}" ] && continue
            if [ ! -e "${source_dir}/${entry}" ]; then
                rm -rf "${destination_dir:?}/${entry}"
            fi
        done < "${previous_manifest}"
    fi

    rm -rf "${destination_dir}/.git" \
        "${destination_dir}/.github" \
        "${destination_dir}/.gitignore" \
        "${destination_dir}/.gitattributes" \
        "${destination_dir}/.prettierrc" \
        "${destination_dir}/.prettierignore" \
        "${destination_dir}/.eslintrc" \
        "${destination_dir}/.eslintrc.dev.json" \
        "${destination_dir}/.eslintignore" \
        "${destination_dir}/.npmrc"

    shopt -s dotglob nullglob
    for source_path in "${source_dir}"/*; do
        entry="$(basename "${source_path}")"
        case "${entry}" in
            .git|.github|.gitignore|.gitattributes|.prettierrc|.prettierignore|.eslintrc|.eslintrc.dev.json|.eslintignore|.npmrc|.gitlab-ci.yml)
                continue
                ;;
        esac

        printf '%s\n' "${entry}" >> "${current_manifest}"
        rm -rf "${destination_dir:?}/${entry}"
        cp -a "${source_path}" "${destination_dir}/"
        chown -R www-data:www-data "${destination_dir}/${entry}"
    done
    shopt -u dotglob nullglob

    mv "${current_manifest}" "${previous_manifest}"
}

if [ ! -d "${workspace}" ]; then
    echo "Cloning new repository..."
    git clone --single-branch --branch gh-pages "${remote_url}" "${workspace}" --depth 1
else
    echo "Updating existing repository..."
    git -C "${workspace}" checkout .
    updated="$(git -C "${workspace}" pull --prune)"

    if echo "${updated}" | grep -q "Already up to date"; then
        echo "Repository is already at the latest commit; syncing deployment target anyway."
    fi
fi

echo "Applying changes..."
if [ -f "${workspace}/info.json" ]; then
    python3 -c "import json; f=open('${workspace}/info.json', 'r+', encoding='utf-8'); info=json.load(f); info['instance']='Org'; f.seek(0); json.dump(info, f, indent=2); f.write('\n'); f.truncate(); f.close()"
fi

echo "Syncing ${repo_name} to ${target_dir}..."
sync_workspace_into_target "${workspace}" "${target_dir}" "${manifest_file}"

echo "Update completed successfully."
