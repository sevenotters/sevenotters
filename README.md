# Seven Otters

**A CQRS/ES Starter Kit for the BEAM.**

## Getting Started

Refer to [Getting Started](https://hexdocs.pm/seven/getting_started.html) to have your first CQRS/ES application with Seven Otters.

## To do

With no order:

- [x] Event store
    - [x] InMemory support
    - [x] MongoDb support
    - [ ] (EventStore)[https://eventstore.com] support
    - [x] Elasticsearch support - retired
    - [x] Abstract for different stores beyond Mongo 
- [x] Event structure
- [x] Command
- [x] Command bus
- [x] Aggregate
    - [X] Snapshot implementation
    - [ ] Unit test documentation
- [x] Policy
    - [ ] Unit test documentation
- [x] Service
    - [ ] Unit test documentation
- [.] Process (WIP)
    - [ ] Review
    - [ ] Unit test documentation
- [x] Projection
    - [ ] Unit test documentation
- [x] Generic command/query API support (Plug)
    - [ ] To move to different project as helper library
- [x] Synchronous (domain related) API support
    - [ ] To move to different project as helper library
- [ ] Generating Seven Otters project template (to analyze)
- [ ] Authentication support (to a different project as helper library)
- [ ] Authorization support (to a different project as helper library)
- [ ] graphical representations among otters/commands/events
- [ ] specification test template

- [ ] Improving events management (create/read/versioning)
- [ ] Improving correlation id in events (even custom ids)
- [ ] Improving pagination reading events (with cursor? stream?)

## Feedback
Feel free to send feedback to <seven.otters.project@gmail.com>
