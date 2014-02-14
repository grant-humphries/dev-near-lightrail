--Taxlots

--Spatially join taxlots and the isocrones that were created by based places that can be reached
--within a given walking distance from MAX stops.  The output is taxlots joined to attribute information
--of the isocrones that they intersect.  Note that there will duplicates in this table if a taxlot is 
--within walking distance multiple stops that are in different 'MAX Zones'
DROP TABLE IF EXISTS taxlots_in_isocrones CASCADE;
CREATE TABLE taxlots_in_isocrones WITH OIDS AS
	SELECT tl.gid, tl.geom, tl.tlid, tl.totalval, tl.prop_code, tl.landuse, iso.max_zone, 
		iso.walk_dist, tl.yearbuilt, min(incpt_year) AS max_inception_year
	FROM taxlot tl
		JOIN isocrones iso
		--This command joins two features only if they intersect
		ON ST_INTERSECTS(tl.geom, iso.geom)
	GROUP BY tl.gid, tl.geom, tl.tlid, tl.totalval, tl.yearbuilt, tl.prop_code, tl.landuse, 
		iso.max_zone, iso.walk_dist;

--A comparison will be done later on the gid from this table and gid in comparison_taxlots.
--This index will speed that computation
DROP INDEX IF EXISTS tl_in_isos_gid_ix CASCADE;
CREATE INDEX tl_in_isos_gid_ix ON taxlots_in_isocrones USING BTREE (gid);

--Temp table will turn the 9 most populous cities in the TM district into a single geometry
DROP TABLE IF EXISTS nine_cities CASCADE;
CREATE TEMP TABLE nine_cities AS
	SELECT ST_UNION(geom) AS geom
	FROM (SELECT city.gid, city.geom, 1 AS collapser
 		FROM city
 		WHERE cityname IN ('Portland', 'Gresham', 'Hillsboro', 'Beaverton', 
 			'Tualatin', 'Tigard', 'Lake Oswego', 'Oregon City', 'West Linn')) AS collapsable_city
	GROUP BY collapser;

--Derived from (http://gis.stackexchange.com/questions/52792/calculate-min-distance-between-points-in-postgis)
DROP TABLE IF EXISTS comparison_taxlots CASCADE;
CREATE TABLE comparison_taxlots WITH OIDS AS
	SELECT tl.gid, tl.geom, tl.tlid, tl.totalval, tl.yearbuilt, tl.prop_code, tl.landuse, 
		--Finds nearest neighbor in the max stops data set for each taxlot and returns the stop's 
		--corresponding 'MAX Zone'
		(SELECT mxs.max_zone 
			FROM max_stops mxs 
			ORDER BY tl.geom <-> mxs.geom 
			LIMIT 1) AS max_zone, 
		--Returns True if a taxlot intersects the urban growth boundary
		(SELECT ST_INTERSECTS(geom, tl.geom)
			FROM ugb) AS ugb,
		--Returns True if a taxlot intersects the TriMet's service district boundary
		(SELECT ST_INTERSECTS(geom, tl.geom)
			FROM tm_district) AS tm_dist,
		--Returns True if a taxlot intersects one of the nine most populous cities in the TM dist
		(SELECT ST_INTERSECTS(geom, tl.geom)
			FROM nine_cities) AS nine_cities
	FROM taxlot tl;

--A comparison will be done later on the gid from this table and gid in taxlots_in_iscrones.
--This index will speed that computation
DROP INDEX IF EXISTS tl_compare_gid_ix CASCADE;
CREATE INDEX tl_compare_gid_ix ON comparison_taxlots USING BTREE (gid);

--Add and populate an attribute indicating whether taxlots from taxlots_in_isocrones are in 
--are in comparison_taxlots
ALTER TABLE comparison_taxlots DROP COLUMN IF EXISTS near_max CASCADE;
ALTER TABLE comparison_taxlots ADD near_max text DEFAULT 'no';

UPDATE comparison_taxlots ct SET near_max = 'yes'
	WHERE ct.gid IN (SELECT ti.gid FROM taxlots_in_isocrones ti);

-----------------------------------------------------------------------------------------------------------------
--Now do the same for Multi-Family Housing Units

DROP TABLE IF EXISTS multifam_in_isocrones CASCADE;
CREATE TABLE multifam_in_isocrones WITH OIDS AS
	SELECT mf.gid, mf.geom, mf.metro_id, mf.units, mf.unit_type, mf.mixed_use, iso.max_zone, 
		iso.walk_dist, mf.yearbuilt, min(iso.incpt_year) AS max_inception_year
	FROM multi_family mf
		JOIN isocrones iso
		ON ST_INTERSECTS(mf.geom, iso.geom)
	GROUP BY mf.gid, mf.geom, mf.metro_id, mf.units, mf.yearbuilt, mf.unit_type, mf.mixed_use,
		iso.max_zone, iso.walk_dist;

DROP INDEX IF EXISTS mf_in_isos_gid_ix CASCADE;
CREATE INDEX mf_in_isos_gid_ix ON multifam_in_isocrones USING BTREE (gid);

DROP TABLE IF EXISTS comparison_multifam CASCADE;
CREATE TABLE comparison_multifam WITH OIDS AS
	SELECT mf.gid, mf.geom, mf.metro_id, mf.units, mf.yearbuilt, mf.unit_type, mf.mixed_use, 
		(SELECT mxs.max_zone 
			FROM max_stops mxs 
			ORDER BY mf.geom <-> mxs.geom 
			LIMIT 1) AS max_zone, 
		(SELECT ST_INTERSECTS(geom, mf.geom)
			FROM ugb) AS ugb,
		(SELECT ST_INTERSECTS(geom, mf.geom)
			FROM tm_district) AS tm_dist,
		(SELECT ST_INTERSECTS(geom, mf.geom)
			FROM nine_cities) AS nine_cities
	FROM multi_family mf;

--Temp table is no longer needed
DROP TABLE nine_cities CASCADE;

DROP INDEX IF EXISTS mf_compare_gid_ix CASCADE;
CREATE INDEX mf_compare_gid_ix ON comparison_multifam USING BTREE (gid);

ALTER TABLE comparison_multifam DROP COLUMN IF EXISTS near_max CASCADE;
ALTER TABLE comparison_multifam ADD near_max text DEFAULT 'no';

UPDATE comparison_multifam cmf SET near_max = 'yes'
	WHERE cmf.gid IN (SELECT mfi.gid FROM multifam_in_isocrones mfi);