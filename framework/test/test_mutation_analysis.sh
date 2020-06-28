#!/usr/bin/env bash
################################################################################
#
# This script tests the D4J's mutation analysis script.
#
################################################################################
# TODO: There is some code duplication in this test script, which we can avoid
# by extracting the mutation analysis workflow into a parameterized function. 

HERE=$(cd `dirname $0` && pwd)

# Import helper subroutines and variables, and init Defects4J
source "$HERE/test.include" || exit 1
init

# Any version should work, but the test cases below are specific to this version
pid="Lang"
bid="6f"
pid_bid_dir="$TMP_DIR/$pid-$bid"
rm -rf "$pid_bid_dir"

# Files generated by Major
summary_file="$pid_bid_dir/summary.csv"
mutants_file="$pid_bid_dir/mutants.log"
kill_file="$pid_bid_dir/kill.csv"

################################################################################
#
# Check whether the mutation analysis results (summary.csv) match the expectations.
#
_check_mutation_result() {
    [ $# -eq 3 ] || die "usage: ${FUNCNAME[0]} \
            <expected_mutants_generated> \
            <expected_mutants_covered> \
            <expected_mutants_killed>"
    local exp_mut_gen=$1
    local exp_mut_cov=$2
    local exp_mut_kill=$3

    # Make sure Major generated the expected data files
    [ -s "$mutants_file" ] || die "'$mutants_file' doesn't exist or is empty!"
    [ -s "$summary_file" ] || die "'$summary_file' doesn't exist or is empty!"
    [ -s "$kill_file" ] || die "'$kill_file' doesn't exist or is empty!"

    # The last row of 'summary.csv' does not have an end of line character.
    # Otherwise, using wc would be more intuitive.
    local num_rows=$(grep -c "^" "$summary_file")
    [ "$num_rows" -eq "2" ] || die "Unexpected number of lines in '$summary_file'!"

    # Columns of summary (csv) file:
    # MutantsGenerated,MutantsCovered,MutantsKilled,MutantsLive,RuntimePreprocSeconds,RuntimeAnalysisSeconds
    local act_mut_gen=$(tail -n1 "$summary_file" | cut -f1 -d',')
    local act_mut_cov=$(tail -n1 "$summary_file" | cut -f2 -d',')
    local act_mut_kill=$(tail -n1 "$summary_file" | cut -f3 -d',')

    [ "$act_mut_gen"  -eq "$exp_mut_gen" ] || die "Unexpected number of mutants generated (expected: $exp_mut_gen, actual: $act_mut_gen)!"
    [ "$act_mut_cov"  -eq "$exp_mut_cov" ] || die "Unexpected number of mutants covered (expected: $exp_mut_cov, actual: $act_mut_cov)!"
# TODO: The CI runs lead to additional timeouts for some mutants, which breaks
# this test. Change the test to check the kill results themselves and ignore
# timeouts when counting the expected number of detected mutants.
#    [ "$act_mut_kill" -eq "$exp_mut_kill" ] || die "Unexpected number of mutants killed (expected: $exp_mut_kill, actual: $act_mut_kill)!"

    # TODO Would be nice to test the number of excluded mutants. In order to do it
    # Major has to write that number to the '$pid_bid_dir/summary.csv' file.
}
################################################################################

# Checkout project-version
defects4j checkout -p "$pid" -v "$bid" -w "$pid_bid_dir" || die "It was not possible to checkout $pid-$bid to '$pid_bid_dir'!"

######################################################
# Test mutation analysis without excluding any mutants

# Remove the summary file to ensure it is regenerated
rm -f "$summary_file"

defects4j mutation -w "$pid_bid_dir" -r || die "Mutation analysis (including all mutants) failed!"
_check_mutation_result 42 42 36

###################################################
# Test mutation analysis when excluding all mutants

# Remove the summary file to ensure it is regenerated
rm -f "$summary_file"

# Exclude all generated mutants
exclude_file="$pid_bid_dir/exclude_all_mutants.txt"
cut -f1 -d':' "$mutants_file" > "$exclude_file"

defects4j mutation -w "$pid_bid_dir" -r -e "$exclude_file" || die "Mutation analysis (excluding all mutants) failed!"
_check_mutation_result 42 0 0

##########################################################################
# Test mutation analysis when explicitly providing a subset of operators

# Remove the summary file to ensure it is regenerated
rm -f "$summary_file"

# Use three mutation operators (test space and newline separation)
mut_ops_file="$pid_bid_dir/mut_ops.txt"
echo "AOR LVR" > "$mut_ops_file"
echo "ROR" >> "$mut_ops_file"

defects4j mutation -w "$pid_bid_dir" -r -m "$mut_ops_file" || die "Mutation analysis (subset of mutation operators) failed!"
_check_mutation_result 36 36 30


##########################################################################
# Test mutation analysis when explicitly providing the class(es) to mutate

# Remove the summary file to ensure it is regenerated
rm -f "$summary_file"

# Mutate an arbitrary, non-modified class
instrument_classes="$pid_bid_dir/instrument_classes.txt"
echo "org.apache.commons.lang3.text.translate.UnicodeEscaper" > "$instrument_classes"

defects4j mutation -w "$pid_bid_dir" -r -i "$instrument_classes" || die "Mutation analysis (instrument UnicodeEscaper) failed!"
_check_mutation_result 57 54 43

# Clean up
rm -rf "$pid_bid_dir"
