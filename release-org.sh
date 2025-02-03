#!/bin/bash

# Check if repository name is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <repository-name>"
    exit 1
fi

repo_name="$1"
remote_url="git@github.com:railmapgen/${repo_name}.git"
workspace="/tmp/${repo_name}"
target_dir="/www/${repo_name}"

# Clone or pull repository
if [ ! -d "${workspace}" ]; then
    echo "Cloning new repository..."
    git clone --single-branch --branch gh-pages "${remote_url}" "${workspace}" --depth 1
else
    echo "Updating existing repository..."
    cd "${workspace}"
    git checkout .
    updated=$(git pull --prune)
    
    if echo "$updated" | grep -q "Already up to date"; then
        echo "Already at the latest commit of ${repo_name}. Exiting."
        exit 0
    fi
    cd -
fi

# Process updates
echo "Applying changes..."
python3 -c "import json;f=open('${workspace}/info.json', 'r+');info=json.load(f);info['instance']='ORG';f.seek(0);json.dump(info,f,indent=2);f.truncate();f.close()"

# Copy new files to www
rm -rf "${target_dir}"
cp -r "${workspace}/" "${target_dir}"
chown -R www-data:www-data /www

echo "Update completed successfully."
