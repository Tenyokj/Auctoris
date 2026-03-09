**DEXErrors**

**Summary**
Shared custom error library for all protocol modules.

**Role In System**
1. Standardizes revert reasons across contracts
2. Improves gas vs long revert strings
3. Simplifies debugging and test assertions

**Usage**
Imported/inherited by core, governance, treasury, oracle, and extension modules.
