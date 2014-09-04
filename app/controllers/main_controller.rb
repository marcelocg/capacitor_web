class MainController < ApplicationController
  layout 'capacitor'
  def index
    @candidates ||= []

    @sla              = CloudCapacitor::Settings.capacitor["sla"]             
    @cpu_limit        = CloudCapacitor::Settings.capacitor["cpu_limit"]       
    @mem_limit        = CloudCapacitor::Settings.capacitor["mem_limit"]       
    @low_deviation    = CloudCapacitor::Settings.capacitor["low_deviation"]   
    @medium_deviation = CloudCapacitor::Settings.capacitor["medium_deviation"]

    @workload_attitude      ||= :optimistic    
    @configuration_attitude ||= :optimistic

  end

  def eval_performance
    @workloadlist = params[:workloadlist].map!{|x| x.to_i}
    @workload_attitude = params[:workload_attitude].to_sym
    @configuration_attitude = params[:configuration_attitude].to_sym
    
    CloudCapacitor::Settings.capacitor["sla"]              = params[:sla].to_i              if !params[:sla].empty?
    CloudCapacitor::Settings.capacitor["cpu_limit"]        = params[:cpu_limit].to_f        if !params[:cpu_limit].empty?
    CloudCapacitor::Settings.capacitor["mem_limit"]        = params[:mem_limit].to_f        if !params[:mem_limit].empty?
    CloudCapacitor::Settings.capacitor["low_deviation"]    = params[:low_deviation].to_f    if !params[:low_deviation].empty?
    CloudCapacitor::Settings.capacitor["medium_deviation"] = params[:medium_deviation].to_f if !params[:medium_deviation].empty?

    @sla              = CloudCapacitor::Settings.capacitor.sla
    @cpu_limit        = CloudCapacitor::Settings.capacitor.cpu_limit
    @mem_limit        = CloudCapacitor::Settings.capacitor.mem_limit
    @low_deviation    = CloudCapacitor::Settings.capacitor.low_deviation
    @medium_deviation = CloudCapacitor::Settings.capacitor.medium_deviation

    capacitor = CloudCapacitor::Capacitor.new
    capacitor.executor = CloudCapacitor::Executors::DummyExecutor.new
    capacitor.strategy = CloudCapacitor::Strategies::MCG_Strategy.new

    capacitor.strategy.attitude workload: @workload_attitude, 
                                config:   @configuration_attitude

    capacitor.run_for(*@workloadlist)
    
    @candidates = capacitor.candidates
    @cost = capacitor.run_cost
    @executions = capacitor.executions
    @trace = capacitor.execution_trace
    @full_trace = capacitor.results_trace

    @configs = capacitor.deployment_space.configs_by_price.clone
    @configs.sort_by! { |c| [c.category, c.price] }
    @reference = ReferenceResult.load
    
    evaluate_results_precision

    render 'results'
  end

  def about
  end

  private
    def find_reference(workload, config)
      i = @reference.index { |r| r[0] == workload && r[1] == config}
      @reference[i][2] # returns the real execution response time
    end

    def evaluate_results_precision
      @full_trace.each_pair do |cfg, wkl|
        wkl.each_pair do |w, exec|
          if exec != {}
            reference_value = find_reference(w, cfg)
            if ( (reference_value <= @sla && exec[:met_sla]) ||
                 (reference_value >  @sla && !exec[:met_sla]) )
              exec.update({correctness: "ok"})
            else
              exec.update({correctness: "nok"})
            end
          end
        end
      end
    end

end
