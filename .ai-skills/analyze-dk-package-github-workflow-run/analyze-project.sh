#!/bin/sh
set -eu

usage() {
    echo "usage: $0 [--run-id RUN_ID] [--workflow WORKFLOW] --checkout CHECKOUT_PATH [--repository REPOSITORY]" >&2
    echo "       $0 RUN_ID CHECKOUT_PATH [REPOSITORY]   (positional back-compat)" >&2
    exit 2
}

run_id=
workflow=
checkout=
repo=
positional=

while [ "$#" -gt 0 ]; do
    case "$1" in
        --run-id) run_id=$2; shift 2 ;;
        --workflow) workflow=$2; shift 2 ;;
        --checkout) checkout=$2; shift 2 ;;
        --repository) repo=$2; shift 2 ;;
        --) shift; break ;;
        -*) echo "unknown option: $1" >&2; usage ;;
        *) positional="$positional $1"; shift ;;
    esac
done

# Positional back-compat: RUN_ID CHECKOUT_PATH [REPOSITORY]
if [ -n "$positional" ]; then
    # shellcheck disable=SC2086
    set -- $positional
    if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
        usage
    fi
    [ -n "$run_id" ] || run_id=$1
    [ -n "$checkout" ] || checkout=$2
    [ -n "$repo" ] || repo=${3:-}
fi

if [ -z "$checkout" ]; then
    echo "checkout path is required (--checkout CHECKOUT_PATH)" >&2
    exit 2
fi

if [ -n "$run_id" ] && [ -n "$workflow" ]; then
    echo "supply only one of --run-id or --workflow, not both" >&2
    exit 2
fi
if [ -z "$run_id" ] && [ -z "$workflow" ]; then
    echo "supply --run-id for a specific run, or --workflow to use that workflow's latest run" >&2
    exit 2
fi

script_root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
helper=$script_root/apply-workflow-patches.js

if [ ! -f "$helper" ]; then
    echo "missing helper script: $helper" >&2
    exit 1
fi

if [ ! -f "$checkout/dk.u" ]; then
    echo "missing dk.u in checkout root: $checkout" >&2
    exit 1
fi

if [ -z "$repo" ]; then
    remote=$(git -C "$checkout" remote get-url origin 2>/dev/null || true)
    if [ -z "$remote" ]; then
        echo "repository slug was not provided and origin remote could not be resolved" >&2
        exit 1
    fi
    case "$remote" in
        git@*:* )
            repo=${remote#*:}
            repo=${repo%.git}
            ;;
        https://*/* )
            repo=${remote#https://}
            repo=${repo#*/}
            repo=${repo%.git}
            ;;
        ssh://git@*/* )
            repo=${remote#ssh://git@}
            repo=${repo#*/}
            repo=${repo%.git}
            ;;
        * )
            echo "could not derive a GitHub repository slug from origin remote: $remote" >&2
            exit 1
            ;;
    esac
fi

case "$repo" in
    */*)
        owner=${repo%%/*}
        repo_name=${repo#*/}
        ;;
    *)
        echo "could not split repository slug into owner and repository name: $repo" >&2
        exit 1
        ;;
esac

resolved_latest=0
if [ -n "$workflow" ]; then
    run_id=$(gh run list --repo "$repo" --workflow "$workflow" --limit 1 --json databaseId --jq '.[0].databaseId')
    if [ -z "$run_id" ]; then
        echo "no runs found for workflow '$workflow' in $repo" >&2
        exit 1
    fi
    resolved_latest=1
fi

workflow_id=$(gh api "repos/$repo/actions/runs/$run_id" --jq '.workflow_id')
if [ -z "$workflow_id" ]; then
    echo "could not determine workflow id for run $run_id in $repo" >&2
    exit 1
fi

printf '%s\n' 'GitHub workflow run:'
printf '%s\n' "- owner: $owner"
printf '%s\n' "- repository: $repo_name"
if [ "$resolved_latest" -eq 1 ]; then
    printf '%s\n' "- workflow: $workflow"
    printf '%s\n' "- run selection: latest run of workflow"
fi
printf '%s\n' "- workflow id: $workflow_id"
printf '%s\n' "- run id: $run_id"

temp_root=$(mktemp -d "${TMPDIR:-/tmp}/dk-ai-workflow-run.${run_id}.XXXXXX")
trap 'rm -rf "$temp_root"' EXIT HUP INT TERM

artifact_query='.artifacts[] | select(.name == "patches") | [.id, .archive_download_url] | @tsv'
artifact_lines=$(gh api "repos/$repo/actions/runs/$run_id/artifacts" --paginate --jq "$artifact_query")
if [ -z "$artifact_lines" ]; then
    echo "no artifacts named patches were found for run $run_id in $repo" >&2
    exit 1
fi

token=$(gh auth token)
artifact_list="$temp_root/artifacts.tsv"
printf '%s\n' "$artifact_lines" > "$artifact_list"
patch_exit=0

while IFS="$(printf '\t')" read -r artifact_id artifact_url; do
    [ -n "$artifact_id" ] || continue
    zip_file=$temp_root/artifact-$artifact_id.zip
    extract_dir=$temp_root/artifact-$artifact_id
    mkdir -p "$extract_dir"
    curl -sS -f -L -H "Authorization: Bearer $token" -H "Accept: application/vnd.github+json" -o "$zip_file" "$artifact_url" >/dev/null
    unzip -q "$zip_file" -d "$extract_dir"
done < "$artifact_list"

set +e
node "$helper" --checkout "$checkout" --patch-root "$temp_root"
patch_exit=$?
set -e

if [ "$patch_exit" -ne 0 ] && [ "$patch_exit" -ne 1 ]; then
    echo "patch application failed with exit code $patch_exit" >&2
    exit "$patch_exit"
fi

exit "$patch_exit"
