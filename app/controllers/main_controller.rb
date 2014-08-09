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
    
    puts "WORKLOAD ATTITUDE: #{@workload_attitude}"

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

    puts "Vars @sla              #{@sla             } Settings sla             : #{CloudCapacitor::Settings.capacitor.sla}             "
    puts "Vars @cpu_limit        #{@cpu_limit       } Settings cpu_limit       : #{CloudCapacitor::Settings.capacitor.cpu_limit}       "
    puts "Vars @mem_limit        #{@mem_limit       } Settings mem_limit       : #{CloudCapacitor::Settings.capacitor.mem_limit}       "
    puts "Vars @low_deviation    #{@low_deviation   } Settings low_deviation   : #{CloudCapacitor::Settings.capacitor.low_deviation}   "
    puts "Vars @medium_deviation #{@medium_deviation} Settings medium_deviation: #{CloudCapacitor::Settings.capacitor.medium_deviation}"


    capacitor = CloudCapacitor::Capacitor.new
    capacitor.executor = CloudCapacitor::Executors::DummyExecutor.new
    capacitor.strategy = CloudCapacitor::Strategies::MCG_Strategy.new

    capacitor.strategy.attitude workload: @workload_attitude, 
                                config:   @configuration_attitude

    capacitor.run_for(*@workloadlist)
    
    @candidates = capacitor.candidates
    @cost = capacitor.run_cost
    @executions = capacitor.executions

    render 'results'
  end

  def about
  end

end
