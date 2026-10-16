// A single handler checks the current allocation and updates it without
// receiving another request in between, like the conditional SQL update.
machine AtomicStore {
    var used: int;
    var limit: int;

    start state Serving {
        entry (initial: Usage) {
            used = initial.used;
            limit = initial.limit;
            announce eUsage, (used = used, limit = limit);
        }
        on eReserve do (request: Request) {
            var accepted: bool;
            accepted = request.amount <= limit - used;
            if (accepted) {
                used = used + request.amount;
            }
            announce eUsage, (used = used, limit = limit);
            send request.client, eResult, accepted;
        }
    }
}

machine AtomicClient {
    start state Waiting {
        entry (config: (store: machine, amount: int)) {
            send config.store, eReserve, (client = this, amount = config.amount);
        }
        on eResult do (accepted: bool) { raise halt; }
    }
}
