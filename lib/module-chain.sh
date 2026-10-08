#!/usr/bin/env bash

##############################################################################
# load_module_chain
#
# Load a hierarchical Lmod module and its prerequisites.
#
# Usage:
#
#     load_module_chain <module>/<version>
#
# Example:
#
#     load_module_chain orca/6.1.1
#
# The function queries `module spider` to determine the prerequisite chain
# required to make the requested module available. It then loads the
# prerequisite modules in order, followed by the requested module.
#
# This avoids hard-coding compiler, MPI, or other dependency versions in
# job-submission scripts. Dependency information is instead obtained from
# the Lmod module hierarchy.
#
# For example, if:
#     module spider orca/6.1.1
#
# reports:
#     gcc/13.3.0  openmpi/4.1.8
#
# then:
#     load_module_chain orca/6.1.1
#
# is equivalent to:
#
#     module load gcc/13.3.0
#     module load openmpi/4.1.8
#     module load orca/6.1.1
#
# If `module spider` cannot determine a prerequisite chain, the function
# prints the spider output and returns a non-zero status.
#
# Currently, when multiple prerequisite chains are reported, the first
# available chain is selected.
#
##############################################################################
load_module_chain() {

    local target="$1"

    if [[ -z "$target" ]]; then
        echo "load_module_chain: missing module name" >&2
        return 1
    fi

    local spider_output
    spider_output="$(module spider "$target" 2>&1)" || {
        echo "$spider_output" >&2
        return 1
    }

    local chain

    chain="$(
        awk '
            /You will need to load all module\(s\) on any one of the lines below/ {
                in_requirements=1
                next
            }

            in_requirements && /^[[:space:]]+Help:/ {
                exit
            }

            in_requirements &&
            /^[[:space:]]+[A-Za-z0-9_.+-]+\/[A-Za-z0-9_.+-]+([[:space:]]+[A-Za-z0-9_.+-]+\/[A-Za-z0-9_.+-]+)*[[:space:]]*$/ {
                sub(/^[[:space:]]+/, "")
                print
                exit
            }
        ' <<< "$spider_output"
    )"

    if [[ -z "$chain" ]]; then
        echo "load_module_chain: could not determine prerequisites for $target" >&2
        echo "$spider_output" >&2
        return 1
    fi

    echo "Loading pre-requisite module chain: $chain" >&2

    local module
    read -ra modules <<< "$chain"


    for module in "${modules[@]}"; do
        module load "$module" || return 1
    done

    echo
    echo "Loading $target"

    module load "$target" || return 1
    echo
    echo "Success"
}