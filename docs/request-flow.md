# Request Flow

1. A client sends a request to the `LagrangeQueryRouter`
2. The `LagrangeQueryRouter` forwards the request to the default `QueryExecutor`
3. The `QueryExecutor` does the following:
    * Validates the request
    * Confirms with the `DatabaseManager` that the query and table are active
    * Confirms the fee paid is sufficient
    * Forwards the fee to the `FeeCollector`

```mermaid
---
title: Request Flow
---
graph TD
    %% Components
    R[Router]
    DBM[Database Manager]
    QE[Query Executor]
    FC[Fee Collector]

    %% Request Flow
    RQ((Request)) --> R
    R --> QE
    QE --> FC
    QE --> DBM
    DBM --> QE
```