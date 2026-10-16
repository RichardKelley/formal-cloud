//! Deterministic schedule of the vulnerable read/check/increment protocol.
use quota_core::{reserve, Quota};
use std::sync::{Arc, Barrier, Mutex};

fn main() {
    let stored = Arc::new(Mutex::new(70u32));
    let checked = Arc::new(Barrier::new(2));
    std::thread::scope(|s| {
        for client in ["A", "B"] {
            let stored = Arc::clone(&stored);
            let checked = Arc::clone(&checked);
            s.spawn(move || {
                let snapshot = *stored.lock().unwrap();
                let proposed = reserve(
                    Quota {
                        used: snapshot,
                        limit: 100,
                    },
                    20,
                )
                .unwrap();
                println!(
                    "{client}: read {snapshot}; sequential reserve returned {}",
                    proposed.used
                );
                checked.wait(); // Both checks finish before either increment.
                let mut used = stored.lock().unwrap();
                *used += 20; // Atomic increment alone is insufficient!
                println!("{client}: incremented stored allocation to {used}");
            });
        }
    });
    let final_used = *stored.lock().unwrap();
    assert_eq!(final_used, 110);
    println!(
        "INVARIANT VIOLATED: {final_used} > 100. Each sequential call returned a valid quota."
    );
}
