---
name: deploy-check
description: Validate a metadata deployment against the target org without deploying
disable-model-invocation: true
allowed-tools: Bash(sf project deploy validate *)
---

## Standard validation (Apex, Flows, objects, perm sets)
```
sf project deploy validate --source-dir force-app --target-org $ARGUMENTS --test-level RunLocalTests
```

## Experience Cloud validation
When changes include Experience Cloud metadata (`experiences/`, `sites/`, `networks/`, `navigationMenus/`, `lwc/`), validate those bundles explicitly:
```
sf project deploy validate --metadata "ExperienceBundle:RentIt,Network:RentIt,NavigationMenu" --target-org $ARGUMENTS --test-level RunLocalTests
```

## LWC-only validation
```
sf project deploy validate --source-dir force-app/main/default/lwc --target-org $ARGUMENTS --test-level NoTestRun
```

## Retrieve Experience Cloud metadata after Builder changes
```
sf project retrieve start --metadata "ExperienceBundle:RentIt" --target-org $ARGUMENTS
```

Summarize only: failures, test failures, and coverage warnings. Omit successful component listings.
