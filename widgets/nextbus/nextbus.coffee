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

                @iconColor = 'ff0000'
                @iconBearing = 0
                @icon = null
                fetch('/bus-icon.svg')
                .then (response) ->
                        response.text()
                .then (response) =>
                        @iconSvg = response
                        @icon = @buildIcon('ff0000', 0)

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
                        if @iconSvg and (@iconColor != data.vehicle.color or @iconBearing != data.vehicle.bearing)
                                @icon = @buildIcon(data.vehicle.color, data.vehicle.bearing)
                        
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
                
        buildIcon: (color, bearing) ->
                @iconColor = color
                @iconBearing = bearing
                
                # load the svg
                xml = new DOMParser().parseFromString(@iconSvg, 'image/svg+xml')
                # update the attributes #

                # 1. the gradient
                # stop1
                stop1 = xml.querySelector('#stop958')
                stop1.style.stopColor = '#' + color
                # stop2
                stop2 = xml.querySelector('#stop960')
                stop2.style.stopColor = '#' + color
                stop2.style.stopOpacity = 0.6

                # 2. the marker
                marker = xml.querySelector('#marker')
                marker.style.stroke = '#' + color

                # 3. the bus
                bus = xml.querySelector('#bus')
                bus.style.fill = '#' + color

                # 4. the arrow + polygon
                arrow = xml.querySelector('#right_arrow')
                arrow.style.fill = '#' + color
                polygon1160 = xml.querySelector('#polygon1160')
                polygon1160.style.fill = '#' + color

                # 5. The bearing, set its rotation
                bearing = xml.querySelector('#bearing')
                bearing.setAttribute('transform', 'rotate(' + bearing + ', 250, 190)')

                serialized = new XMLSerializer().serializeToString(xml)
                url = 'data:image/svg+xml;base64,' + btoa(serialized)

                # return a leaflet icon
                icon = L.icon({
                    iconUrl: url,
                    iconSize: [60, 60],
                    iconAnchor: [30, 60],
                    popupAnchor: [0, -60]
                })

                icon


        @accessor 'edt', Dashing.AnimatedValue
        @accessor 'sdt', Dashing.AnimatedValue
        @accessor 'nextEdt', Dashing.AnimatedValue
        @accessor 'isLate', ->
                @get('edt') - @get('sdt') > 7
