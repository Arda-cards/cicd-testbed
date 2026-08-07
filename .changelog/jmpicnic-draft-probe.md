### Fixed

- Slowed one synthetic gate so a queued entry stays in the queue long enough to
  be interfered with. Needed to answer whether GitHub ejects a pull request that
  is returned to draft while queued, which the design assumes but had never
  observed.
