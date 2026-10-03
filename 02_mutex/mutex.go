package mutex

import (
	"sync/atomic"

	"primitives/internal/futex"
)

const (
	free = iota
	held
	contended
)

var TRIES = 5

type Mutex struct {
	state uint32
}

func (m *Mutex) Lock() {
	for range TRIES {
		if atomic.LoadUint32(&m.state) == free &&
			atomic.CompareAndSwapUint32(&m.state, free, held) {
			return
		}
	}

	m.slowLock()
}

func (m *Mutex) slowLock() {
	for {
		c := atomic.SwapUint32(&m.state, contended)
		if c == free {
			return
		}
		futex.Wait(&m.state, contended)
	}
}

func (m *Mutex) TryLock() bool {
	return atomic.CompareAndSwapUint32(&m.state, free, held)
}

func (m *Mutex) Unlock() {
	old := atomic.SwapUint32(&m.state, free)
	switch old {
	case free:
		panic("unlock of unlocked mutex")
	case held:
		return
	case contended:
		futex.Wake(&m.state)
	}
}
