require 'net/http'
require 'uri'
require 'open-uri'
require 'nokogiri'

BASE_URL="http://webservices.nextbus.com/service/publicXMLFeed"

# LA Metro
AGENCY_ID="lametro-rail"
STOP_IDS = ["80122"]

# # LA Bus
# AGENCY_ID="lametro"
# STOP_IDS = ["8033", "805"]

UPDATE_INTERVAL = '30s'

class Nextbus

  class Stop
    def initialize(id, tag, name, latitude, longitude)
      @id = id
      @tag = tag
      @name = name
      @latitude = latitude
      @longitude = longitude
    end

    def id
      return @id
    end
    def tag
      return @tag
    end
    def name
      return @name
    end
    def latitude
      return @latitude
    end
    def longitude
      return @longitude
    end
  end

  class Route
    def initialize(tag, color, path)
      @id = tag
      @color = color
      @path = path
    end

    def tag
      return @tag
    end
    def color
      return @color
    end
    def path
      return @path
    end
  end
  
  class Prediction
    def initialize(route_tag, stop_id, stop_tag, time, vehicle_id)
      @route_tag = route_tag
      @stop_id = stop_id
      @stop_tag = stop_tag
      @time = time
      @vehicle_id = vehicle_id

      def route_tag
        return @route_tag
      end
      def stop_id
        return @stop_id
      end
      def stop_tag
        return @stop_tag
      end
      def time
        return @time
      end
      def vehicle_id
        return @vehicle_id
      end
    end
  end

  class Vehicle
    def initialize(id, route_tag, latitude, longitude, heading, speed)
      @id = id
      @route_tag = route_tag
      @latitude = latitude
      @longitude = longitude
      @heading = heading
      @speed = speed
    end

    def id
      return @id
    end
    def route_tag
      return @route_tag
    end
    def latitude
      return @latitude
    end
    def longitude
      return @longitude
    end
    def heading
      return @heading
    end
    def speed
      return @speed
    end
  end
  
  def initialize(options)
    @stop_ids = options[:stop_ids]
    @agency_id = options[:agency_id]

    @routes = Hash.new
    @stops = Hash.new
  end

  def update
    arrivals = Hash.new
    predictions = Array.new
    vehicles = Hash.new

    begin
      found_routes = Hash.new
      
      # for each stop, get the
      #  1. Information about that stop (if we don't have it cached)
      #  2. The routes that use that stop, and their information (if we don't have it cached)
      #  3. The predicted arrivals for any vehicles that go through that stop
      @stop_ids.each do |stop_id|
        puts "fetching predictions for stop: #{stop_id}"

        # Get the upcoming predictions for this stop
        uri = URI.open(BASE_URL + "?command=predictions&a=#{@agency_id}&stopId=#{stop_id}")
        r = Nokogiri::XML(uri)

        r.xpath("//predictions").each do |pr|
          #puts "predictions=#{pr.children}"
          route_tag = pr['routeTag']

          # We want to get any stop and route information, but we can't
          #  get stop information globally, just based on its ID. Instead,
          #  we must first figure out which route it is a part of, then get
          #  the route information, which is a heavy operation.
          # So, we will gather all the routes that any of our stops can be
          #  a part of, get their information and fill in the stops according.
          found_routes[route_tag] = true
          
          # get all the predictions under this route
          pr.xpath("direction/prediction").each do |pr2|
            #puts("pr2=#{pr2}")
            predictions << Prediction.new(route_tag, stop_id.to_s, pr['stopTag'],
                                          pr2['minutes'].to_i, pr2['vehicle'])
          end
        end
      end

      # go through all the routes that we found and get their information
      #  Store it, and also, store the stop information for any stops we
      #  care about along that route
      found_routes.each_key do |route_tag|
        #puts "looking up #{route_id}"
        # if we already have this cached, pass over
        unless @routes.has_key?(route_tag)
          puts "fetching info for route #{route_tag}"
          uri = URI.open(BASE_URL + "?command=routeConfig&a=#{@agency_id}&r=#{route_tag}")
          r = Nokogiri::XML(uri)

          route = r.xpath("//route").first()
          if route
            # get the path of this route
            #  it is a multi-dimensional array
            route_path = route.xpath("path").map do |path|
              path.xpath("point").map do |point|
                [point['lat'].to_f, point['lon'].to_f]
              end
            end
            
            @routes[route_tag] = Route.new(route_tag, route['color'], route_path)

            # iterate through all the stops and fill in any missing ones
            route.xpath("stop").each do |s|
              s_id = s['stopId']
              s_tag = s['tag']
              #puts "checking stop #{s_id} #{STOP_IDS.include?(s_id)} #{@stops.has_key?(s_id)}"
              if @stop_ids.include?(s_id) and not @stops.has_key?(s_id)
                #puts "making new stop #{s_id}"
                @stops[s_id] = Stop.new(s_id,
                                        s_tag,
                                        s['title'],
                                        s['lat'].to_f,
                                        s['lon'].to_f)
              end
            end
          end
        end
      end

      #puts("stops=#{@stops}")
      #puts("routes=#{@routes}")
      
      # For each route
      #  1. Get the locations of the vehicles and cache it
      @routes.each do |route_tag, route|
        puts "fetching vehicle locations for #{route_tag}"
        uri = URI.open(BASE_URL + "?command=vehicleLocations&a=#{@agency_id}&r=#{route_tag}&t=0")
        r = Nokogiri::XML(uri)
        #puts(r)

        r.xpath("//vehicle").each do |v|
          v_id = v['id']
          
          vehicles[v_id] = Vehicle.new(v_id, route_tag,
                                       v['lat'].to_f, v['lon'].to_f,
                                       v['heading'].to_i, v['speedKmHr'].to_f)
        end
      end

      #puts("vehicles=#{vehicles}")

      # For each prediction
      #  1. Create a new Arrival and store it in our arrivals
      #puts "iterating predictions"
      predictions.each do |prediction|
        #puts "prediction=#{prediction}"
        arrival = {
          "edt" => prediction.time,
          "sdt" => prediction.time,
          "stop" => {
            "name" => @stops[prediction.stop_id].name,
            "latitude" => @stops[prediction.stop_id].latitude,
            "longitude" => @stops[prediction.stop_id].longitude
          },
          "color" => @routes[prediction.route_tag].color,
          "path" => @routes[prediction.route_tag].path,
          "vehicle_id" => prediction.vehicle_id,
          "vehicle" => nil
        }
        if vehicles.has_key?(prediction.vehicle_id)
          vehicle = vehicles[prediction.vehicle_id]
          if vehicle
            arrival["vehicle"] = {
              "latitude" => vehicle.latitude,
              "longitude" => vehicle.longitude,
              "iconUrl" => build_icon_url(@routes[prediction.route_tag].color, vehicle.heading)
            }
          end
        end

        # make sure our keys exists
        unless arrivals.has_key?(prediction.stop_tag)
          arrivals[prediction.stop_tag] = Hash.new
        end
        unless arrivals[prediction.stop_tag].has_key?(prediction.route_tag)
          arrivals[prediction.stop_tag][prediction.route_tag] = Array.new
        end

        # append the arrival
        arrivals[prediction.stop_tag][prediction.route_tag] << arrival
        # sort by edit ascending (in-place)
        arrivals[prediction.stop_tag][prediction.route_tag].sort! { |a,b| a['edt'] <=> b['edt'] }
        # remove duplicates
        arrivals[prediction.stop_tag][prediction.route_tag].uniq! { |i| [i['edt'], i['vehicle_id']] }
      end

      #puts("arrivals #{arrivals}")
    rescue StandardError => e
      puts e.inspect
      puts "\e[33mUnable to retrieve nextbus data\e[0m"
    end

    arrivals
  end

  def build_icon_url(color, heading)
    #AGENCY_URL + "/IconFactory.ashx?library=busIcons%5Cmobile&colortype=hex&color=" + color + "&bearing=" + heading.to_s
    "https://realtimebjcta.availtec.com/InfoPoint" + "/IconFactory.ashx?library=busIcons%5Cmobile&colortype=hex&color=" + color + "&bearing=" + heading.to_s
  end
  
  def parse_json_datetime(datetime)
    #
    # from: https://stackoverflow.com/a/34059193/4122137
    #
    
    # "/Date(-62135575200000-0600)/" seems to be the default date returned
    # if the value is null:
    if datetime == "/Date(-62135575200000-0600)/"
      # Return nil because it is probably a null date that is defaulting to 0.
      # To be more technically correct you could just return 0 here if you wanted:
      return nil
    elsif datetime =~ %r{/Date\(([-+]?\d+)([-+]\d+)?\)/}
      # We've now parsed the string into:
      # - $1: Number of milliseconds since the 1/1/1970 epoch.
      # - $2: [Optional] timezone offset.
      # Divide $1 by 1000 because it is in milliseconds and Time uses seconds:
      seconds_since_epoch = $1.to_i / 1000.0
      time = Time.at(seconds_since_epoch.to_i).utc 
      # We now have the exact moment in history that this represents,
      # stored as a UTC-based "Time" object.
      
      if $2
        # We have a timezone, so convert its format (adding a colon)...
        timezone = $2.gsub(/(...)(..)/, '\1:\2')
        # ...then apply it to the Time object:
        time = time.getlocal(timezone)
      end
      time
    else
      raise "Unrecognized date format."
    end
  end
  
end

# Mutliple Nextbus Arrivers can be created with different agency_ids and stop_ids
# You just need to merge the update results into a hash keyed by agency id
@Arriver = Nextbus.new({agency_id: AGENCY_ID, stop_ids: STOP_IDS})

# :first_in sets how long it takes before the job is first run. In this case, it is run immediately
SCHEDULER.every UPDATE_INTERVAL, :first_in => 0 do |job|
  arrivals = Hash.new
  arrivals[AGENCY_ID] = @Arriver.update

  send_event('nextbus', arrivals)
end
