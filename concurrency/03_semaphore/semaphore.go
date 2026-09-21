package semaphore

import (
	"primitives/internal/futex"
	"sync/atomic"
)

type Semaphore struct {
	permits uint32
}

func New(n int) *Semaphore {
	if n < 0 {
		panic("negative semaphore size")
	}

	return &Semaphore{
		permits: uint32(n),
	}
}

func (s *Semaphore) Acquire() {
	for {
		old := atomic.LoadUint32(&s.permits)

		if old == 0 {
			futex.Wait(&s.permits, 0)

		} else if atomic.CompareAndSwapUint32(&s.permits, old, old-1) {
			return
		}
	}
}

func (s *Semaphore) TryAcquire() bool {
	old := atomic.LoadUint32(&s.permits)
	if old == 0 {
		return false
	}
	return atomic.CompareAndSwapUint32(&s.permits, old, old-1)
}

func (s *Semaphore) Release() {
	atomic.AddUint32(&s.permits, 1)
	futex.Wake(&s.permits)
}

func (s *Semaphore) Available() int {
	return int(atomic.LoadUint32(&s.permits))
}
