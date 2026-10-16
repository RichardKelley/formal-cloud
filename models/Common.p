// One tenant. Clients and the store communicate through asynchronous events.
type Usage = (used: int, limit: int);
type Request = (client: machine, amount: int);
event eRead: machine;
event eSnapshot: int;
event eIncrement: Request;
event eReserve: Request;
event eResult: bool;
event eUsage: Usage;

// Both protocols announce every change to the authoritative allocation.
spec QuotaInvariant observes eUsage {
    start state Watching {
        on eUsage do (q: Usage) {
            assert 0 <= q.used && q.used <= q.limit,
                format("QuotaInvariant: used={0} limit={1}", q.used, q.limit);
        }
    }
}
