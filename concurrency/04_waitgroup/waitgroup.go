package waitgroup

import (
	"primitives/internal/futex"
	"sync/atomic"
)

type WaitGroup struct {
	count uint32
}

func (wg *WaitGroup) Add(delta int) {
	for {
		old := atomic.LoadUint32(&wg.count)
		new := int64(old) + int64(delta)

		if new < 0 {
			panic("negative WaitGroup counter")
		}

		if atomic.CompareAndSwapUint32(&wg.count, old, uint32(new)) {
			if new == 0 {
				futex.WakeAll(&wg.count)
			}
			return
		}
	}
}

func (wg *WaitGroup) Done() {
	wg.Add(-1)
}

func (wg *WaitGroup) Wait() {
	for {
		count := atomic.LoadUint32(&wg.count)
		if count == 0 {
			return
		}

		futex.Wait(&wg.count, count)
	}
}
