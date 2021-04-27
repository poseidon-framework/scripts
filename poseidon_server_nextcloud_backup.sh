#!/usr/bin/env bash

rsync -avzP --exclude='*.zip' --exclude '.*' gwdg:poseidon-repos/ ~/Nextcloud-EVA/poseidon-repos
