class MainController < ApplicationController
  layout 'capacitor'
  def index
    @candidates ||= []

    @sla              = CloudCapacitor::Settings.capacitor["sla"]             
    @cpu_limit        = CloudCapacitor::Settings.capacitor["cpu_limit"]       
    @mem_limit        = CloudCapacitor::Settings.capacitor["mem_limit"]       
    @low_deviation    = CloudCapacitor::Settings.capacitor["low_deviation"]   
    @medium_deviation = CloudCapacitor::Settings.capacitor["medium_deviation"]

    @workload_approach      ||= :optimistic
    @configuration_approach ||= :optimistic

  end

  def eval_performance
    @workloadlist = params[:workloadlist].map!{|x| x.to_i}
    @workload_approach = params[:workload_approach].to_sym
    @configuration_approach = params[:configuration_approach].to_sym
    
    CloudCapacitor::Settings.capacitor["sla"]              = params[:sla].to_i              if !params[:sla].empty?
    # CloudCapacitor::Settings.capacitor["cpu_limit"]        = params[:cpu_limit].to_f        if !params[:cpu_limit].empty?
    # CloudCapacitor::Settings.capacitor["mem_limit"]        = params[:mem_limit].to_f        if !params[:mem_limit].empty?
    # CloudCapacitor::Settings.capacitor["low_deviation"]    = params[:low_deviation].to_f    if !params[:low_deviation].empty?
    # CloudCapacitor::Settings.capacitor["medium_deviation"] = params[:medium_deviation].to_f if !params[:medium_deviation].empty?

    @sla              = CloudCapacitor::Settings.capacitor.sla

    case params[:graph_mode].to_sym
      when :capacity
        @graph_mode = :strict
      when :cost
        @graph_mode = :price
      else
        @graph_mode = :strict
    end

    # @cpu_limit        = CloudCapacitor::Settings.capacitor.cpu_limit
    # @mem_limit        = CloudCapacitor::Settings.capacitor.mem_limit
    # @low_deviation    = CloudCapacitor::Settings.capacitor.low_deviation
    # @medium_deviation = CloudCapacitor::Settings.capacitor.medium_deviation

    puts @graph_mode.class

    capacitor = CloudCapacitor::Capacitor.new @graph_mode
    capacitor.executor = CloudCapacitor::Executors::DummyExecutor.new
    capacitor.strategy = CloudCapacitor::Strategies::MCG_Strategy.new

    capacitor.strategy.approach workload: @workload_approach,
                                config:   @configuration_approach

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

  def report
    capacitor = CloudCapacitor::Capacitor.new

    capacitor.executor = CloudCapacitor::Executors::DummyExecutor.new
    capacitor.strategy = CloudCapacitor::Strategies::MCG_Strategy.new
    workloads = [100,200,300,400,500,600,700,800,900,1000]
    approaches = [:optimistic, :pessimistic, :conservative, :random]
    slas = (1..10).map{|i| i * 10_000}

    heuristic_name = { optimistic:
                           { optimistic:   "OO",
                             pessimistic:  "OP",
                             conservative: "OC",
                             random:       "OR" },
                       pessimistic:
                           { optimistic:   "PO",
                             pessimistic:  "PP",
                             conservative: "PC",
                             random:       "PR" },
                       conservative:
                           { optimistic:   "CO",
                             pessimistic:  "CP",
                             conservative: "CC",
                             random:       "CR" },
                       random:
                           { optimistic:   "RO",
                             pessimistic:  "RP",
                             conservative: "RC",
                             random:       "RR" }
    }

    approaches.each do |wkl_approach|
      approaches.each do |config_approach|

        heuristic = heuristic_name[wkl_approach][config_approach]

        File.open("#{heuristic}_heuristic_result.csv", "wt") do |result|

          result.puts "heuristic,workload,configuration,metsla,sla,predict" #.split(",")

          slas.each do |sla|
            CloudCapacitor::Settings.capacitor["sla"] = sla

            capacitor.strategy.approach workload: wkl_approach, config: config_approach

            puts "Running: Heuristic = #{heuristic} and SLA = #{sla}"
            capacitor.run_for(*workloads)
            puts "Run finished! Writing output"

            full_trace = capacitor.results_trace

            workloads.each do |w|
              # Format: {"1.m3_medium": {100: {met_sla: false, executed: true, execution: 1}}}
              full_trace.keys.each do |cfg|
                exec = full_trace[cfg][w]
                exec.nil? || exec == {} ? metsla  = nil : metsla  = exec[:met_sla]
                exec.nil? || exec == {} ? predict = nil : predict = !exec[:executed]
                result.puts "#{heuristic},#{w},#{cfg},#{metsla},#{sla},#{predict}" #.split(",")
              end
            end

          end

        end
      end
    end
    redirect_to action: :index
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
