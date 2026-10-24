---
name: cleanup
description: Clean up Docker/K8s resources created by the game. Use when the user wants to clean up or reset.
---

# Cleanup Game Resources

## Step 1: Show What Exists
List all learn-* containers, networks, volumes, images, and K8s namespaces.

## Step 2: Confirm
Show what will be removed. If player has in-progress work, warn them.

## Step 3: Clean
Run `bash engine/cleanup.sh` and report what was removed.

## Step 4: Update Progress (if needed)
If cleaning a specific chapter, reset that chapter's challenges in progress.yaml.
