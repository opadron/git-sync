#! /usr/bin/env sh

set -e

poll_interval=30

while getopts 'hfi:' c ; do
    case $c in
        h) do_help=1               ;;
        f) do_lfs=1                ;;
        i) poll_interval="$OPTARG" ;;
    esac
done

shift `echo "$OPTIND - 1" | bc`

src_repo="$1" ; shift
dst_repo="$1" ; shift

if [ -z "$src_repo" -o -z "$dst_repo" ] ; then
    do_help=1
fi

if [ "$do_help" '=' '1' ] ; then
    echo -n "Usage: $0 [-h] [-f]"
    echo " [-i POLL_INTERVAL] SOURCE_REPO DESTINATION_REPO"
    exit 2
fi

tmp="`mktemp -d`"

cleanup() {
    rm -rf "$tmp"
}

indent() {
    awk 'BEGIN { prefix="  " }
               { gsub("\r+$", "");
                 gsub("\r+", "\n" prefix);
                 gsub("\x0d\[[0-9]+(;[0-9]+)?[cfghilnrsuABCDHJKMR]", "");
                 print prefix $0 }'
}

report() {
    do_report=1
    do_check=1
    do_rm=0
    add_date=0
    header=""

    while [ -n "$*" ] ; do
        case $1 in
            -n) do_check=0              ;;
            -d) do_date=1               ;;
            -r) do_rm=1                 ;;
            *) header="${header} $1"    ;;
        esac

        shift
    done

    set +e
    read head
    set -e
    if [ "$do_check" '=' '1' ] ; then
        if [ -z "$head" ] ; then
            do_report=0
        elif [ "${head::21}" '='  'Everything up-to-date' ] ; then
            if [ -f "$tmp/eutd" ] ; then
                do_report=0
            fi
            touch "$tmp/eutd"
        elif [ "$do_rm" '=' '1' ] ; then
            rm -f "$tmp/eutd"
        fi
    fi

    if [ "$do_report" '=' '1' ] ; then
        if [ "$do_date" '=' '1' ] ; then
            if [ -f "$tmp/first_report_done" ] ; then
                echo
            else
                touch "$tmp/first_report_done"
            fi
            echo "`date -R`${header}"
        fi
        ( [ -n "$head" ] && echo "$head" ; cat ) | indent
    fi
}

trap "cleanup ; exit" INT TERM QUIT EXIT

(
    script -f -q -c "git clone --mirror $src_repo $tmp/repo" /dev/null || true \
) 2>&1 | tail -n +2 | report -d "Cloning upstream repository"

cd "$tmp/repo"
script -e -f -q -c "git remote set-url --push origin $dst_repo" /dev/null 2>&1 \
    | report -d "Setting downstream repository"

while true ; do
    if script -e -f -q -c 'git fetch -p origin' /dev/null 2>&1 \
        | report -d "Fetching updates"
    then
        lfs_fetch="0"

        if [ "$do_lfs" '=' '1' ] ; then
            lfs_fetch="1"
            if script -e -f -q -c 'git lfs fetch --all' /dev/null 2>&1 \
                | report -d "Fetching updates (LFS)"
            then
                lfs_fetch="0"
            fi
        fi

            script -e -f -q -c 'git push --mirror' /dev/null 2>&1 \
                | report -d -r "Syncing updates with downstream"

            if [ "$do_lfs" '=' '1' -a "$lfs_fetch" '=' '0' ] ; then
                script -e -f -q -c "git lfs push --all $dst_repo" 2>&1 \
                    | report -d "Syncing updates with downstream (LFS)"
            fi
    fi

    sleep "$poll_interval"
done
