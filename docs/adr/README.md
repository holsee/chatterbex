# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) for Chatterbex.

## What is an ADR?

An ADR is a document that captures an important architectural decision made along with its context and consequences. ADRs help teams understand why certain decisions were made and provide historical context for future maintainers.

## ADR Index

| ID | Title | Status | Date |
|----|-------|--------|------|
| [ADR-0001](0001-erlang-ports-for-python-interop.md) | Use Erlang Ports for Python Interoperability | Accepted | 2024-12-25 |
| [ADR-0002](0002-genserver-per-model-instance.md) | GenServer Per Model Instance | Accepted | 2024-12-25 |
| [ADR-0003](0003-json-base64-ipc-protocol.md) | JSON with Base64 for IPC Protocol | Accepted | 2024-12-25 |
| [ADR-0004](0004-mix-task-for-python-setup.md) | Mix Task for Python Dependency Setup | Accepted | 2024-12-25 |

## ADR Template

New ADRs should follow the template in [template.md](template.md).

## Statuses

- **Proposed** - Under discussion
- **Accepted** - Approved and implemented
- **Deprecated** - No longer valid, superseded by another ADR
- **Superseded** - Replaced by a newer ADR (link to replacement)

## Contributing

When making significant architectural decisions:

1. Copy `template.md` to a new file with the next sequential number
2. Fill in all sections
3. Submit for review
4. Update the index once accepted
