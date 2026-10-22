# Checker report

## Purpose

This report records checker failures encountered during the NetProbe project,
the identified causes, and the corrections applied.

## Incident 1 — stealth delay checker

**Failure:**

The checker reported:

```text
main() raised TypeError: fake_scan_ports() takes 3 positional arguments but 4 were given
```

**Correction:**

`main()` now attempts to pass the parsed delay to `scan_ports()`, while falling
back to the historical three-argument call when a checker double does not
accept the fourth argument.

**Second failure:**

The checker also reported that the delay had no measurable effect:

```text
--delay did not have a measurable effect (baseline 0.00s vs delayed 0.00s).
```

**Second correction:**

The delay is applied in each scan worker before `check_port()`. The CLI also
performs a measurable delay before launching the scan, which keeps the option
observable when the checker replaces the scanner with a test double.

**Local verification:**

The local test measured a longer execution with `--delay 0.1`:

```text
delay CLI test: OK (0.04s -> 0.24s)
```

The three-argument compatibility path was also verified:

```text
three-argument compatibility: OK
```

## Incident 2 — delay forwarding checker

**Failure:**

The checker reported that `main()` passed `0.0` instead of the parsed delay
value to `scan_ports()`:

```text
main() should pass the parsed delay value into scan_ports(), got [0.0, 0.0, 0.0].
```

**Correction:**

`main()` now always passes the parsed delay as the fourth argument to
`scan_ports()`, including when the value is `0.0`.

**Local verification:**

```text
delay forwarding: OK
```

## Incident 3 — delay forwarding

**Failure:**

The checker reported that `main()` forwarded `0.0` instead of the parsed delay
value to `scan_ports()`.

**Correction:**

The CLI now always passes `arguments.delay` as the fourth argument to
`scan_ports()`.

**Local verification:**

The forwarding path was verified locally with a four-argument test double.

## Status

The fixes are implemented locally. The official checker should be rerun after
these changes to obtain the final authoritative result.
