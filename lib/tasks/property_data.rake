require 'csv'

namespace :property_data do
  desc "Import data from the property data file and create an addresses JSON file for typeahead search"
  task :import => :environment do
    property_data_path = "/tmp/Vacant_and_Abandoned_Property_Data.csv"
    unless File.exist?(property_data_path)
      p "Downloading property data..."
      system("cd /tmp && curl -O https://s3-us-west-1.amazonaws.com/south-bend-secrets/Vacant_and_Abandoned_Property_Data.csv")
    end
    centroid_path = "/tmp/cityparcelscentroids_abandoned_latlon_CLEAN.csv"
    unless File.exist?(centroid_path)
      p "Downloading centroids..."
      system("cd /tmp && curl -O https://s3-us-west-1.amazonaws.com/south-bend-secrets/cityparcelscentroids_abandoned_latlon_CLEAN.csv")
    end
    table = CSV.read(property_data_path, :headers => true)
    lat_long_table = CSV.read(centroid_path, :headers => true)
    all_address_array = []
    lats_and_longs_array = []
    if ENV["MONROE_PILOT"]
      monroe_address_array = ["519 S St.", "523 S St.", "213 E South", "614 S St.", "615 Fellows", "624 Fellows", "616 Clinton", "620 Columbia", "520 Columbia"]
    end
    table.each do |row|
      if ENV["MONROE_PILOT"]
        next unless monroe_address_array.any? { |monroe_addr| row["Location 1"].include?(monroe_addr)  }
      end
      parcel_id = row["Parcel ID"]
      puts "Processing #{parcel_id}"
      target_property = Property.find_by_parcel_id(parcel_id)
      address = row["Location 1"][0, row["Location 1"].index("\n")]
      # Remove periods from addresses
      clean_address = address.gsub(".", "")
      if clean_address == "520 Columbia" || clean_address == "620 Columbia"
        clean_address.gsub!("Columbia", "Carroll")
      end
      all_address_array << clean_address
      if target_property == nil
        target_property = Property.create(:parcel_id => parcel_id, :name => clean_address)
      elsif target_property.name != clean_address 
        target_property.update_attribute(:name, clean_address)
      end
      # Replace Socrata latlong code with parsing of centroid file
      #latlong = row["Location 1"][/\((.*)\)/]
      #lat = latlong[/\((.*)[,]/].gsub(/([\(]|[,])/, "")
      #long = latlong[/\s(.*)$/].gsub(/(\s|\))/, "")
      lat = lat_long_table.find { |lat_long_row| lat_long_row["parcelid"] == parcel_id }["latitude_0"]
      long = lat_long_table.find { |lat_long_row| lat_long_row["parcelid"] == parcel_id }["longitude_0"]
      if clean_address == "520 Carroll"
        lat, long = "41.670489", "-86.246904"
      end
      if clean_address == "620 Carroll"
        lat, long = "41.669233", "-86.246934"
      end
      lats_and_longs_array << [clean_address,lat,long]
      recommendation = nil
      ["Repair","Demo","Deconstruct","Hold"].each do |key|
        if (recommendation && row[key])
          puts "Warning! #{row["Parcel ID"]} has multiple recommendations"
          binding.pry
        end
        recommendation = key if row[key] == "1"
      end
      outcome = nil
      ["Repaired","Demolished","Deconstructed","Occupied / Repaired","Occupied / Not Repaired","Legal Hold"].each do |key|
        if (outcome && row[key])
          puts "Warning! #{row["Parcel ID"]} has multiple outcomes"
          binding.pry
        end
        outcome = key if row[key] == "1"
      end
      outcome = "Vacant and Abandoned" if outcome == nil
      if target_property.property_info_set
        target_property.property_info_set.update_attributes(:condition_code => row["Condition Code"].to_i, :condition => row["Condition (auto populates)"], :estimated_cost_exterior=> row["Estimated cost (Exterior)"], :estimated_cost_interior => row["Estimated cost (Interior - if able)"], :demo_order => row["Demo order? (Affirmed/Expired)"], :recommendation => recommendation, :outcome => outcome, :lat => lat, :long => long)
      else # Already has property info set
        target_property.property_info_set = PropertyInfoSet.create(:condition_code => row["Condition Code"].to_i, :condition => row["Condition (auto populates)"], :estimated_cost_exterior=> row["Estimated cost (Exterior)"], :estimated_cost_interior => row["Estimated cost (Interior - if able)"], :demo_order => row["Demo order? (Affirmed/Expired)"], :recommendation => recommendation, :outcome => outcome, :lat => lat, :long => long)
      end
    end
    address_json_path = "#{Rails.root}/public/assets/property_addresses.json"
    File.delete(address_json_path) if File.exist?(address_json_path)
    File.open(address_json_path, 'w') { |file| file.write(all_address_array.to_json) }
    lats_and_longs_array_path = "#{Rails.root}/public/assets/lats_longs.json"
    File.delete(lats_and_longs_array_path) if File.exist?(lats_and_longs_array_path)
    File.open(lats_and_longs_array_path, 'w') { |file| file.write(lats_and_longs_array.to_json) }
  end

  desc "PENDING - Pull down CSV data from Socrata and store in /tmp"
  task :download_from_socrata do
    # Pending
  end

  desc "Adds for Monroe Park"
  task :add_monroe_phone_codes => :environment do
    monroe_park_codes = { "519 S St Joseph" => "2345", "523 S St Joseph" => "3456", "213 E South" => "4567", "614 S St Joseph" => "5678", "520 Carroll" => "6789", "620 Carroll" => "7891", "615 Fellows" => "8912", "624 Fellows" => "9123", "616 Clinton" => "1234" }
    # Test to check they're all good
    #monroe_park_codes.each_pair { |key,value| p "uh oh: #{key} #{value}" if Property.find_all_by_name(key).count == 0 }
    monroe_park_codes.each_pair do |prop_address, prop_code|
     target = Property.find_by_name(prop_address)
     if target.property_code
       p "#{target.name} already has a property code"
     else
       target.update_attribute(:property_code, prop_code)
       p "Added property code #{prop_code} to #{target.name}"
     end
    end
  end
end

