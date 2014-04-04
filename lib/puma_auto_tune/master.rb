module PumaAutoTune
  class Master
    def initialize(master = nil)
      @master = master || get_master
    end

    def running?
      @master && workers.any?
    end

    # https://github.com/puma/puma/blob/master/docs/signals.md#puma-signals
    def remove_worker
      send_signal("TTOU")
    end

    # https://github.com/puma/puma/blob/master/docs/signals.md#puma-signals
    def add_worker
      send_signal("TTIN")
    end

    # less cryptic interface
    def send_signal(signal, pid = Process.pid)
      Process.kill(signal, pid)
    end

    def memory
      @memory
    end
    alias :mb :memory

    def get_memory
      @memory = ::GetProcessMem.new(Process.pid).mb
    end

    def workers
      @master.instance_variable_get("@workers").map {|w| cached_wrapped_worker(w) }
    end

    private

    # Always returns an existing PumaAutoTune::Worker instance if we have
    # seen this puma_worker (by its pid). This allows the restarting flag
    # to persist.
    def cached_wrapped_worker(puma_worker)
      @worker_cache ||= {}
      @worker_cache.fetch(puma_worker.pid) { PumaAutoTune::Worker.new(puma_worker) }
    end

    def get_master
      ObjectSpace.each_object(Puma::Cluster).first if defined?(Puma::Cluster)
    end
  end
end
