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

    @candidates = capacitor.run_for(*@workloadlist)
    
    @cost = capacitor.run_cost
    @executions = capacitor.executions
    @trace = capacitor.execution_trace
    @full_trace = capacitor.results_trace

    @configs = capacitor.deployment_space.configs_by_price.clone
    @configs.sort_by! { |c| [c.category, c.price] }
    @reference = ReferenceResult.load
    
    evaluate_results_precision

    @global_precision = calculate_global_precision
    @global_recall = calculate_global_recall
    @global_f_measure = calculate_global_f_measure

    render 'results'
  end

  def about
  end

  private

    def calculate_global_precision
      (@confusion_matrix[:tp] / (@confusion_matrix[:tp] + @confusion_matrix[:fp])).round(3)
    end

    def calculate_global_recall
      (@confusion_matrix[:tp] / (@confusion_matrix[:tp] + @confusion_matrix[:fn])).round(3)
    end

    def calculate_global_f_measure
      (2 * ( (@global_precision * @global_recall) / (@global_precision + @global_recall) )).round(3)
    end

    def find_reference(workload, config)
      i = @reference.index { |r| r[0] == workload && r[1] == config}
      @reference[i][2] # returns the real execution response time
    end

    def evaluate_results_precision
      @wkl_confusion_matrix = {}
      @confusion_matrix = {tp: 0.0, fp: 0.0, tn: 0.0, fn: 0.0}

      @workloadlist.each do |wkl|
        @wkl_confusion_matrix[wkl] = {tp: 0.0, fp: 0.0, tn: 0.0, fn: 0.0}
      end

      @full_trace.each_pair do |cfg, wkl|
        wkl.each_pair do |w, exec|
          if exec != {}
            reference_value = find_reference(w, cfg)
            if exec[:met_sla] && reference_value <= @sla
              exec.update({correctness: "ok"})
              @confusion_matrix[:tp] += 1
              @wkl_confusion_matrix[w][:tp] += 1
            elsif !exec[:met_sla] && reference_value > @sla
              exec.update({correctness: "ok"})
              @confusion_matrix[:tn] += 1
              @wkl_confusion_matrix[w][:tn] += 1
            elsif !exec[:met_sla] && reference_value <= @sla
              exec.update({correctness: "nok"})
              @confusion_matrix[:fn] += 1
              @wkl_confusion_matrix[w][:fn] += 1
            elsif exec[:met_sla] && reference_value > @sla
              exec.update({correctness: "nok"})
              @confusion_matrix[:fp] += 1
              @wkl_confusion_matrix[w][:fp] += 1
            end
          end
        end
      end
      puts "Confusion Matrix = #{@confusion_matrix}"
    end

end
