# Smashing-Nextbus

https://github.com/line72/smashing-nextbus

(c) 2019 - Marcus Dillavou <line72@line72.net>

Smashing-Nextbus is licensed under the terms of the MIT license.

![Screenshot](/screenshot.png?raw=true "Real time Bus Arrivals for Smashing")

## About

This is a widget for the [Smashing
Dashboard](https://smashing.github.io/) that shows the real time,
estimated arrivals for buses. This works for any bus system that
utilizes [Nextbus](https://nextbus.com/).

## Installation

Copy all the files to the appropriate location of your smashing dashboard.

After installing, you first need to configure your stop locations and agency. Edit the `jobs/nextbus.rb` file. Make sure you update the `AGENCY_ID` and the `STOP_IDS` list.

```
AGENCY_ID="lametro"
STOP_IDS = ['2492', '1464', '1430']
```

You then need to add the widget to your dashboard. There are a few important things to know:

1. The `data-sizey` needs to be `2` or there isn't room for the map. You can optionally make the `data-sizex="2"` also.
1. You can have multiple widgets for different buses and/or different stops. Just make sure ALL the needed stop ids are in the `jobs/nextbus.rb` and make sure you set the `data-stop_tag` and `data-route_id`.
1. Stop Ids are not necessarily unique. For example a metro station may have a single stop id, but you have a north-bound and south-bound train. Each stop ids will have one or more unique stop tags associated with them. You will need to use this stop tag (sometimes the same as the stop id) to correctly identify which predictions you want to see.

```
<li data-row="1" data-col="3" data-sizex="1" data-sizey="2">
  <div data-id="nextbus" data-view="Nextbus" data-title="#44" data-sub_title="20th & Morris" data-stop_tag=1430_0 data-route_id=44 data-addclass-danger="isLate"></div>
</li>
```

