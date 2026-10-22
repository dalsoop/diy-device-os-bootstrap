# Verification Reports

This folder holds verification reports for source checks, simulations, and VM
qualification runs of this World, one Markdown file per run named
`YYYY-MM-DD-<subject>.md`.

A report names the exact source commit, the evidence state it reached, and
what it does not prove. A source check or VM run is not physical USB, firmware,
or installation evidence. Reports are records: add a new file for each run and
never edit or remove an earlier one.

Reports follow the documentation rule in `docs/standards.md`: they name roles
such as the build host or VM host, never specific machines, people, or personal
paths.
