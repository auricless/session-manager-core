# Session Manager Core

A framework-free Java 17 library for assigning participants and facilitators to session groups. It returns in-memory assignment results; applications own their API, persistence, and presentation layers. The published JAR has no runtime dependencies.

## Build

Use Maven 3.9+ and JDK 17+:

```sh
mvn verify
```

The build runs the existing JUnit tests and checks at least 80% line and 70% branch coverage in the assignment service package. On JDK 21, also run `mvn -Pquality verify` for formatting, Checkstyle, and SpotBugs.

## Use from Maven

Configure your Maven client to access the private AWS CodeArtifact repository described in [release setup](docs/aws-release.md), then add:

```xml
<dependency>
  <groupId>org.c3cavite</groupId>
  <artifactId>session-manager-core</artifactId>
  <version>1.0.0</version>
</dependency>
```

Call `GroupAssignmentService.assign(config, participants, facilitators)` for ordinary assignments. The overload accepting `List<FacilitatorException>` applies explicit exceptions for one run. Build a `SessionConfig` with an explicit positive `capSize`, then inspect the returned `AssignmentResult` for its state, groups, blockers, unassigned participants, and warnings. See the source types under `org.c3cavite.core.domain` for the input and result contracts.

## Release

The [CI workflow](.github/workflows/ci.yml) checks Java 17 compatibility and JDK 21 quality. Publishing is a separate, manual workflow restricted to the trusted `master` branch. [AWS release setup](docs/aws-release.md) lists the required GitHub variables, IAM permissions, and verification steps. This repository does not provision AWS resources.

The [core extraction ticket](https://app.notion.com/p/40261e61aca18185a25ac4896783195e) and [AWS release preparation ticket](https://app.notion.com/p/40261e61aca181a88cced6bccc47d879) track the migration.

## License

No license has been selected for this project yet.
