osmosis --read-xml G:/PUBLIC/GIS_Projects/Development_Around_Lightrail/osm_data/or-wa.osm --wkv keyValueList=highway.motorway,highway.motorway_link,highway.trunk,highway.trunk_link,highway.primary,highway.primary_link,highway.secondary,highway.secondary_link,highway.tertiary,highway.tertiary_link,highway.residential,highway.residential_link,highway.unclassified,highway.service,highway.track,highway.road,highway.construction,highway.footway,highway.pedestrian,highway.path,highway.steps,highway.cycleway,highway.bridleway --tt G:/PUBLIC/GIS_Projects/Development_Around_Lightrail/github/dev-near-lightrail/osmosis/tagtransform.xml --write-pgsimp-0.6 user=postgres password=gh082983 database=osmosis_ped