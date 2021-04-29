class Dashing.Nextbus extends Dashing.Widget
        
        ready: ->
                # This is fired when the widget is done being rendered
                @element = $(@node).find('#mapid')[0]
                @map = L.map(@element, {
                        zoomControl: false,
                        attributionControl: false,
                        attributionControl: false,
                        dragging: false,
                        doubleClickZoom: false,
                        boxZoom: false,
                        scrollWheelZoom: false,
                        tap: false,
                        touchZoom: false
                }).setView([33.5084801, -86.8006611], 13)
                L.tileLayer('https://stamen-tiles-{s}.a.ssl.fastly.net/toner/{z}/{x}/{y}.png', {
                        id: 'mapbox.streets',
                }).addTo(@map)

                @stopIcon = L.icon({
                        iconUrl: "/marker-icon.png",
                        iconSize: [25, 41],
                        iconAnchor: [12, 41],
                        shadowUrl: "/marker-shadow.png",
                        shadowSize: [41, 41],
                        shadowAnchor: [15, 41]
                })

                @iconUrl = "https://realtimebjcta.availtec.com/InfoPoint/IconFactory.ashx?library=busIcons%5Cmobile&colortype=hex&color=12AB89&bearing=154"
                @icon = L.icon({
                        iconUrl: @iconUrl,
                        iconSize: [39, 50],
                        iconAnchor: [20, 50],
                        popupAnchor: [0, -50]
                })

                @routePath = null
                
                @stopMarker = null
                @marker = null
                
        onData: (data) ->
                # Handle incoming data
                # You can access the html node of this widget with `@node`
                # Example: $(@node).fadeOut().fadeIn() will make the node flash each time data comes in.

                if !@map or Object.keys(data).length == 0
                        return

                if !@routePath
                        @routePath = L.polyline(data.path, {color: '#' + data.color, weight: 8}).addTo(@map)

                if !@stopMarker
                        @stopMarker = L.marker([data.latitude, data.longitude], {icon: @stopIcon}).addTo(@map)

                        
                if 'vehicle' of data and data.vehicle
                        if @iconUrl != data.vehicle.iconUrl
                                @iconUrl = data.vehicle.iconUrl
                                @icon = L.icon({
                                        iconUrl: @iconUrl
                                        iconSize: [39, 50],
                                        iconAnchor: [20, 50],
                                        popupAnchor: [0, -50]
                                })
                        
                        if !@marker
                                @marker = L.marker([data.vehicle.latitude, data.vehicle.longitude], {icon: @icon}).addTo(@map)
                        else
                                @marker.setLatLng([data.vehicle.latitude, data.vehicle.longitude])
                                @marker.setIcon(@icon)
        
                        # zoom
                        @map.fitBounds([[data.latitude, data.longitude], [data.vehicle.latitude, data.vehicle.longitude]], {padding: [30, 30]})
                else
                        if @marker
                                @marker.remove()
                                @marker = null
                        

        select: (all_data) ->
                updatedData = {}

                agency_id = @get('agency_id')
                stop_tag = @get('stop_tag')
                route_id = @get('route_id')

                if agency_id of all_data
                        # only look at data for the current agency
                        data = all_data[agency_id]
                        
                        if stop_tag of data
                                if route_id of data[stop_tag]
                                        edt = data[stop_tag][route_id][0]["edt"]
                                        sdt = data[stop_tag][route_id][0]["sdt"]
                                        nextEdt = '?'
                                        vehicle = data[stop_tag][route_id][0]["vehicle"]
        
                                        if data[stop_tag][route_id].length > 1
                                                nextEdt = data[stop_tag][route_id][1]["edt"]
                                                
                                        @set 'edt', edt
                                        @set 'sdt', sdt
                                        @set 'nextEdt', nextEdt
        
                                        latitude = data[stop_tag][route_id][0]["stop"].latitude
                                        longitude = data[stop_tag][route_id][0]["stop"].longitude
                                        path = data[stop_tag][route_id][0]["path"]
                                        color = data[stop_tag][route_id][0]["color"]
        
                                        if Math.abs(latitude) < 0.01 or Math.abs(longitude) < 0.01
                                                # invalid latitude/longitude
                                                updatedData = {}
                                        else
                                                updatedData = {
                                                        edt: edt,
                                                        sdt: sdt,
                                                        nextEdt: nextEdt,
                                                        latitude: latitude,
                                                        longitude: longitude,
                                                        color: color,
                                                        path: path,
                                                        vehicle: vehicle
                                                }

                updatedData
                

        @accessor 'edt', Dashing.AnimatedValue
        @accessor 'sdt', Dashing.AnimatedValue
        @accessor 'nextEdt', Dashing.AnimatedValue
        @accessor 'isLate', ->
                @get('edt') - @get('sdt') > 7
