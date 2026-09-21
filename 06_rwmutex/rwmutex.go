package rwmutex

import "sync/atomic"

const writer = 1 << 31

type RWMutex struct {
	state uint32
}

func (rw *RWMutex) RLock() {
	for {
		state := atomic.LoadUint32(&rw.state)
		if state&writer == 0 && atomic.CompareAndSwapUint32(&rw.state, state, state+1) {
			return
		}
	}
}

func (rw *RWMutex) RUnlock() {
	for {
		state := atomic.LoadUint32(&rw.state)
		if state&writer != 0 || state == 0 {
			panic("RUnlock of unlocked RWMutex")
		}
		if atomic.CompareAndSwapUint32(&rw.state, state, state-1) {
			return
		}
	}

}

func (rw *RWMutex) Lock() {
	for !atomic.CompareAndSwapUint32(&rw.state, 0, writer) {
	}
}

func (rw *RWMutex) Unlock() {
	if atomic.CompareAndSwapUint32(&rw.state, writer, 0) {
		return
	}

	panic("Unlock of unlocked RWMutex")
}
