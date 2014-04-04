## This is the default algorithm
PumaAutoTune.hooks(:ram) do |auto|
  # Runs in a continual loop controlled by PumaAutoTune.frequency
  auto.set(:cycle) do |memory, master, workers|
    if memory > PumaAutoTune.ram # mb
      auto.call(:out_of_memory)
    else
      auto.call(:under_memory) if memory + workers.last.memory
    end
  end

  # Called repeatedly for `PumaAutoTune.reap_duration`.
  # call when you think you may have too many workers
  auto.set(:reap_cycle) do |memory, master, workers|
    # 7. Finally we arrive in reap_cycle but memory still includes the
    # restarted worker's memory usage which means that
    # memory is certainly still going to be > PumaAutoTune.ram since
    # that's how we got here in the first place. This means we will
    # trigger :remove_worker.
    if memory > PumaAutoTune.ram
      auto.call(:remove_worker)
    end
  end

  # Called when puma is using too much memory
  auto.set(:out_of_memory) do |memory, master, workers|
    largest_worker = workers.last # ascending worker size
    auto.log "Potential memory leak. Reaping largest worker", largest_worker_memory_mb: largest_worker.memory
    # 1. We restart the largest worker which sets restarting to true to report 0 memory usage by that worker
    largest_worker.restart
    # 2. We start a reap_cycle using #call
    auto.call(:reap_cycle)
  end

  # Called when puma is not using all available memory
  # PumaAutoTune.max_workers is tracked automatically by `remove_worker`
  auto.set(:under_memory) do |memory, master, workers|
    theoretical_max_mb = memory + workers.first.memory # assending worker size
    if theoretical_max_mb < PumaAutoTune.ram && workers.size + 1 < PumaAutoTune.max_workers
      auto.call(:add_worker)
    else
      auto.log "All is well"
    end
  end

  # Called to add an extra worker
  auto.set(:add_worker) do |memory, master, workers|
    auto.log "Cluster too small. Resizing to add one more worker"
    master.add_worker
    auto.call(:reap_cycle)
  end

  # Called to remove 1 worker from pool. Sets maximum size
  auto.set(:remove_worker) do |memory, master, workers|
    auto.log "Cluster too large. Resizing to remove one worker"
    master.remove_worker
    # 8. And now we trigger another :reap_cycle... It appears that
    # we can trigger multiple reap_cycles to run concurrently this
    # way leaading to the log flooding we see.  The :reap_cycles
    # stack up because memory is still going to be > PumaAutoTune.ram.
    # This will continue until master.remove_worker's TTOU signal
    # is processed and the worker is actually stopped releasing its
    # memory.
    auto.call(:reap_cycle)
  end
end
