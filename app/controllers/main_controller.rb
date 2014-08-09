class MainController < ApplicationController
  layout 'capacitor'
  def index
    @candidates ||= []
    @cost = 0.0
    @executions = 0
  end
  def about
  end
  def eval_performance
    workloadlist = params[:workloadlist].map!{|x| x.to_i}
    workload_attitude = params[:workload_attitude].to_sym
    configuration_attitude = params[:configuration_attitude].to_sym

    capacitor = CloudCapacitor::Capacitor.new
    capacitor.executor = CloudCapacitor::Executors::DummyExecutor.new
    capacitor.strategy = CloudCapacitor::Strategies::MCG_Strategy.new

    capacitor.strategy.attitude workload: workload_attitude, 
                                config:   configuration_attitude

    capacitor.run_for(*workloadlist)
    
    @candidates = capacitor.candidates
    @cost = capacitor.run_cost
    @executions = capacitor.executions

    render 'results'
  end
end
