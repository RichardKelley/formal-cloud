// Each read and increment is serialized by the store, but their combination
// is not atomic. A client can authorize an increment using a stale snapshot.
machine NonAtomicStore {
    var used: int;
    var limit: int;

    start state Serving {
        entry (initial: Usage) {
            used = initial.used;
            limit = initial.limit;
            announce eUsage, (used = used, limit = limit);
        }
        on eRead do (client: machine) {
            send client, eSnapshot, used;
        }
        on eIncrement do (request: Request) {
            used = used + request.amount;
            announce eUsage, (used = used, limit = limit);
            send request.client, eResult, true;
        }
    }
}

machine NonAtomicClient {
    var store: machine;
    var amount: int;
    var limit: int;

    start state Reading {
        entry (config: (store: machine, amount: int, limit: int)) {
            store = config.store;
            amount = config.amount;
            limit = config.limit;
            send store, eRead, this;
        }
        on eSnapshot do (snapshot: int) {
            print format("Read used={0}; request={1}", snapshot, amount);
            if (amount <= limit - snapshot) {
                send store, eIncrement, (client = this, amount = amount);
                goto Waiting;
            } else {
                raise halt;
            }
        }
    }
    state Waiting {
        on eResult do (accepted: bool) { raise halt; }
    }
}
