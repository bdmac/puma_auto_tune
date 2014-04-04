require 'delegate'

module PumaAutoTune

  class Memory
    attr_accessor :master, :workers

    def initialize(master = PumaAutoTune::Master.new)
      @master = master
    end

    def name
      "resource_ram_mb"
    end

    def amount
      @mb ||= begin
        # 6. Calling amount to send in args to hook.call theoretically
        # expects a restarting worker to return 0 memory but we reset
        # the worker instances so the restarting flag is no longer set
        # and the restarted worker does not return 0...
        worker_memory = workers.map {|w| w.memory }.inject(&:+) || 0
        worker_memory + @master.get_memory
      end
    end

    def largest_worker
      workers.last
    end

    def smallest_worker
      workers.first
    end

    def workers
      # 5. Calling #workers will gather them again from the
      # master process because reset will set @workers nil
      # Actually this method DOES NOT actually memoize because
      # we're not using @workers ||= here, not that it matters
      # in this specific case because we called #reset already.
      workers ||= @master.workers.sort_by! {|w| w.get_memory }
    end

    def reset
      raise "must set master" unless @master
      @workers      = nil
      @mb           = nil
    end
  end
end
