#include "kern.h"

void spinlock_init(spinlock_t *lock)
{
    lock->locked = 0;
}

void spinlock_lock(spinlock_t *lock)
{
    while (sync_lock_test_and_set(&lock->locked))
        ; /* wait */
}

void spinlock_unlock(spinlock_t *lock)
{
    sync_lock_release(&lock->locked);
}

int spinlock_trylock(spinlock_t *lock)
{
    return sync_lock_test_and_set(&lock->locked) == 0;
}
