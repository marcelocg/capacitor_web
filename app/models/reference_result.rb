class ReferenceResult
  def self.load
    result_for = []

    path = File.expand_path('../../../..', __FILE__)
    file = File.join( Rails.root, "db/wordpress_cpu_mem.csv" )

    CSV.foreach(file, headers: true) do |row|
      config_name = "#{row["instances"]}.#{row["provider_id"]}"
      result_for << [row["workload"].to_i, config_name, row["percentile"].to_f]
    end
    result_for
  end
end