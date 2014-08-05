class MainController < ApplicationController
  layout 'capacitor'
  def index
    @candidates ||= []
  end
  def about
  end
  def eval_performance
    workloadlist = params[:workloadlist].map!{|x| x.to_i}
    workload_attitude = params[:workload_attitude].to_sym
    configuration_attitude = params[:configuration_attitude].to_sym

    puts "Attitudes: WKL=#{workload_attitude} CFG=#{configuration_attitude}"
    
    capacitor = CloudCapacitor::Capacitor.new
    capacitor.executor = CloudCapacitor::Executors::DummyExecutor.new
    capacitor.strategy = CloudCapacitor::Strategies::MCG_Strategy.new

    capacitor.strategy.attitude workload: workload_attitude, 
                                config:   configuration_attitude

    capacitor.run_for(*workloadlist)
    @candidates = capacitor.candidates
    render 'index'
  end
end
