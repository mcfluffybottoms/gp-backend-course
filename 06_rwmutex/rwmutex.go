package rwmutex

import (
	"sync/atomic"

	"primitives/internal/futex"
)

const writer = 1 << 31
const maxReaders = 1 << 30

type RWMutex struct {
	state uint32
	//readerSem semaphore.Semaphore
	//writerSem semaphore.Semaphore
}

func (rw *RWMutex) RLock() {
	for {
		state := atomic.LoadUint32(&rw.state)
		if state&writer != 0 {
			futex.Wait(&rw.state, state)
			continue
		}
		if atomic.CompareAndSwapUint32(&rw.state, state, state+1) {
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
			futex.WakeAll(&rw.state)
			return
		}
	}

}

func (rw *RWMutex) Lock() {
	for {
		state := atomic.LoadUint32(&rw.state)
		if state == 0 && atomic.CompareAndSwapUint32(&rw.state, 0, writer) {
			return
		}
		futex.Wait(&rw.state, state)
	}
}

func (rw *RWMutex) Unlock() {
	if atomic.CompareAndSwapUint32(&rw.state, writer, 0) {
		futex.WakeAll(&rw.state)
		return
	}

	panic("Unlock of unlocked RWMutex")
}

/*
Можно запретить новым читателям присоединяться,
если поступил запрос на запись -- читатели,
запросившие доступ после запроса от писателя, должны получить
доступ уже после того, как отработает писатель.

Как вариант можно завести бит "писатель работает" на то,
какое количество писателей запросило доступ.

Такое решение, в свою очередь, может привести к тому,
что тогда своей очереди не смогут дождаться читатели.
Читателям нужно также сделать так,
чтобы писатели после них не могли занимать очередь.

Для более справедливого распределения нагрузки потребуетмся
Решением данной задачи может являться введение двух семафоров
--
*/
