package semaphore

type Semaphore struct {
	permits uint32
}

func New(n int) *Semaphore {
	if n < 0 {
		panic("negative semaphore size")
	}
}

func (s *Semaphore) Acquire() {
	for {
		old :=
	}
}

func (s *Semaphore) TryAcquire() bool {
	panic("не реализовано")
}

func (s *Semaphore) Release() {
	panic("не реализовано")
}

func (s *Semaphore) Available() int {
	panic("не реализовано")
}
