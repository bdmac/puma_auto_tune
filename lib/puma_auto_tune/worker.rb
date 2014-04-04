module PumaAutoTune
  class Worker

    def initialize(worker)
      @worker = worker
    end

    def memory
      @memory || get_memory
    end
    alias :mb :memory

    def get_memory
      @memory = if restarting?
        0
      else
        ::GetProcessMem.new(self.pid).mb
      end
    end

    def reset_memory
      # Reset memory so we recalculate how much we're using.
      # This also allows subsequent calls to #memory to call
      # into #get_memory which will start returning 0 when
      # this worker is restarting.
      @memory = nil
    end

    def restarting?
      @restarting
    end


    def restart
      @restarting = true
      @worker.term
    end

    def pid
      @worker.pid
    end
  end
end
