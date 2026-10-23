# Session Manager Core guidance

- Keep this Java 17 library independent of HTTP, Spring, persistence, and serialization configuration.
- Preserve immutable assignment results and independently evaluated runs.
- Preserve participant counts, age boundaries, demographic and life-stage separation, the hard cap, minimum group size, Youth priority, and unique facilitator use.
- Every final group requires a Leader. Staffing shortages remain proposals with actionable blockers. Empty input returns a final empty assignment.
- Facilitator exceptions must be explicit, visible, and run-scoped; they cannot waive role, participant, or hard-cap rules.
- Run `mvn verify` and, on JDK 21, `mvn -Pquality verify` for changes to Java sources or build configuration.
