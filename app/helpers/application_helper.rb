module ApplicationHelper
  def execution_class(exec)
    css_class =  (exec[:executed] ? "executed" : "predicted")
    css_class << (exec[:met_sla]  ? " met_sla" : " not_met_sla")
    css_class      
  end
end
