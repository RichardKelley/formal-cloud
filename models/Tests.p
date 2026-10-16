// Finite one-shot scenarios: two clients each request 20 from a 70/100 quota.
// No barrier chooses the race here: the checker explores message schedules.
machine TestNonAtomic {
    start state Init {
        entry {
            var store: machine;
            store = new NonAtomicStore((used = 70, limit = 100));
            new NonAtomicClient((store = store, amount = 20, limit = 100));
            new NonAtomicClient((store = store, amount = 20, limit = 100));
        }
    }
}

machine TestAtomic {
    start state Init {
        entry {
            var store: machine;
            store = new AtomicStore((used = 70, limit = 100));
            new AtomicClient((store = store, amount = 20));
            new AtomicClient((store = store, amount = 20));
        }
    }
}

test tcNonAtomic [main=TestNonAtomic]:
    assert QuotaInvariant in { TestNonAtomic, NonAtomicStore, NonAtomicClient };
test tcAtomic [main=TestAtomic]:
    assert QuotaInvariant in { TestAtomic, AtomicStore, AtomicClient };
