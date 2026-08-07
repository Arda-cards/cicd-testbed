### Fixed

- Assembly now bounds its range by the last release tag rather than by the last
  assembly commit. A repository adopting the model has no assembly commit, so
  the previous reading made the first range the entire history — including
  merges that predate the model and carry no entry to collect. The first run in
  this repository failed exactly that way. In steady state the two readings
  agree, because assembly is what creates the tag.
