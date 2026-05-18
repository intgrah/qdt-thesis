#!/usr/bin/env fish

set -l here (status dirname)
set -l code (set -q QDT_CODE; and echo $QDT_CODE; or echo $here/../ii/code)
cd $code

function count
    cloc --quiet --force-lang="Lean",qdt --json $argv | jq -r '.SUM.code // 0'
end

function count_dir
    cloc --vcs=git --quiet --force-lang="Lean",qdt --json $argv | jq -r '.SUM.code // 0'
end

set incremental (count Incremental/*.lean)
set incremental_shake (count_dir Incremental/Shake)
set incremental_test (count_dir Incremental/Test)
set incremental_c (count_dir Incremental/c)
set shake_c (count Incremental/c/shake.c)
set salsa_c (count Incremental/c/salsa.c)
set qdt_theory (count Qdt/Theory/Syntax.lean Qdt/Theory/Universe.lean Qdt/Theory/Universe/Denotation.lean Qdt/Theory/Universe/LE.lean Qdt/Theory/Global.lean)
set qdt_frontend (count Qdt/Frontend/Ast.lean Qdt/Frontend/Cst.lean Qdt/Frontend/Desugar.lean Qdt/Frontend/Parser.lean Qdt/Frontend/Parser/Core.lean)
set qdt (count Qdt/*.lean)
set qdt_incremental (count_dir Qdt/Incremental)
set qdt_test (count_dir Qdt/Test)
set qdt_lsp (count_dir Qdt/Lsp)
set fswatch (count FSWatch/INotify.lean FSWatch/Manager.lean FSWatch/Types.lean FSWatch/c/inotify.c)
set root (count Main.lean Lsp.lean FSWatch.lean Qdt.lean lakefile.lean)
set vscode (count vscode-qdt/src/* vscode-qdt/syntaxes/qdt.json vscode-qdt/language-configuration.json)
set examples_lean2hott (count examples/lean2-hott/Lean2Export.lean examples/lean2-hott/port.sh examples/lean2-hott/build-lean2.sh)
set examples_other (count_dir examples/stdlib examples/long)
set bench (count bench/lib.fish bench/cold.fish bench/cold-hott.fish bench/chain.fish bench/scatter.fish bench/incremental.fish bench/conversion.fish bench/variants/Conversion.WithFlex.lean bench/variants/Conversion.NoFlex.lean)

set total (math $incremental + $incremental_shake + $incremental_test + $incremental_c + $qdt_theory + $qdt_frontend + $qdt + $qdt_incremental + $qdt_test + $qdt_lsp + $fswatch + $root + $vscode + $examples_lean2hott + $examples_other + $bench)

set stdlib_files (git ls-files examples/stdlib | wc -l | string trim)
set stdlib_lines (git ls-files examples/stdlib | xargs cat 2>/dev/null | wc -l | string trim)
set lean2hott_files (find examples/lean2-hott/build -name '*.qdt' 2>/dev/null | wc -l | string trim)
set lean2hott_lines (find examples/lean2-hott/build -name '*.qdt' 2>/dev/null | xargs cat 2>/dev/null | wc -l | string trim)

jq -n \
    --argjson total $total \
    --argjson incremental $incremental \
    --argjson incremental_shake $incremental_shake \
    --argjson incremental_test $incremental_test \
    --argjson incremental_c $incremental_c \
    --argjson shake_c $shake_c \
    --argjson salsa_c $salsa_c \
    --argjson qdt_theory $qdt_theory \
    --argjson qdt_frontend $qdt_frontend \
    --argjson qdt $qdt \
    --argjson qdt_incremental $qdt_incremental \
    --argjson qdt_test $qdt_test \
    --argjson qdt_lsp $qdt_lsp \
    --argjson fswatch $fswatch \
    --argjson root $root \
    --argjson vscode $vscode \
    --argjson examples_lean2hott $examples_lean2hott \
    --argjson examples_other $examples_other \
    --argjson bench $bench \
    --argjson stdlib_files $stdlib_files \
    --argjson stdlib_lines $stdlib_lines \
    --argjson lean2hott_files $lean2hott_files \
    --argjson lean2hott_lines $lean2hott_lines \
    '{
        total: $total,
        rows: {
            incremental: $incremental,
            incremental_shake: $incremental_shake,
            incremental_test: $incremental_test,
            incremental_c: $incremental_c,
            shake_c: $shake_c,
            salsa_c: $salsa_c,
            qdt_theory: $qdt_theory,
            qdt_frontend: $qdt_frontend,
            qdt: $qdt,
            qdt_incremental: $qdt_incremental,
            qdt_test: $qdt_test,
            qdt_lsp: $qdt_lsp,
            fswatch: $fswatch,
            root: $root,
            vscode: $vscode,
            examples_lean2hott: $examples_lean2hott,
            examples_other: $examples_other,
            bench: $bench
        },
        corpora: {
            stdlib_files: $stdlib_files,
            stdlib_lines: $stdlib_lines,
            lean2hott_files: $lean2hott_files,
            lean2hott_lines: $lean2hott_lines
        }
    }' >$here/metrics.json
