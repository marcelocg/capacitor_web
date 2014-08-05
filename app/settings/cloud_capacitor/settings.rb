require 'settingslogic'

module CloudCapacitor
  class Settings < Settingslogic
    source "#{Rails.root}/config/capacitor.yml"
  end
end
