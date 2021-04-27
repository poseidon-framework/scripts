#!/usr/bin/env bash

rsync -avzP --exclude='*.zip' --exclude '.*' ~/poseidon-repos/ ~/nextcloud/poseidon-repos
