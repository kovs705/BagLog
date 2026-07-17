# BagLog backend

This directory contains the design-first foundation for the BagLog backend.
The executable service and deployment manifests should be added after the
third-party runtime dependencies are approved.

Start with:

- [Backend architecture](../Docs/BACKEND_ARCHITECTURE.md)
- [Initial PostgreSQL schema](Database/Migrations/000001_initial_schema.sql)
- [HTTP API contract](OpenAPI/baglog-v1.yaml)

Release 1.0 of the iOS app remains local-only. Backend integration belongs to a
later release and must preserve the offline SwiftData workflow.

