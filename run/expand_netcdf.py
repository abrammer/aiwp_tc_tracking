import xarray as xr



# ncdf_rv850name="X"
# ncdf_rv700name="X"

# ncdf_u850name="X"
# ncdf_v850name="X"
# ncdf_u700name="X"
# ncdf_v700name="X"
# ncdf_u500name="X"
# ncdf_v500name="X"
# ncdf_u200name="X"
# ncdf_v200name="X"

# ncdf_mslpname="X"
# ncdf_usfcname="X"
# ncdf_vsfcname="X"
# ncdf_lmaskname="X"

# ncdf_z900name="X"
# ncdf_z850name="X"
# ncdf_z800name="X"
# ncdf_z750name="X"
# ncdf_z700name="X"
# ncdf_z650name="X"
# ncdf_z600name="X"
# ncdf_z550name="X"
# ncdf_z500name="X"
# ncdf_z450name="X"
# ncdf_z400name="X"
# ncdf_z350name="X"
# ncdf_z300name="X"
# ncdf_z200name="X"

# ncdf_time_name="X"
# ncdf_lon_name="X"
# ncdf_lat_name="X"
# ncdf_sstname="X"

# ncdf_q850name="X"
# ncdf_rh1000name="X"
# ncdf_rh925name="X"
# ncdf_rh800name="X"
# ncdf_rh750name="X"
# ncdf_rh700name="X"
# ncdf_rh650name="X"
# ncdf_rh600name="X"

# ncdf_spfh1000name="X"
# ncdf_spfh925name="X"
# ncdf_spfh800name="X"
# ncdf_spfh750name="X"
# ncdf_spfh700name="X"
# ncdf_spfh650name="X"
# ncdf_spfh600name="X"

# ncdf_temp1000name="X"
# ncdf_temp925name="X"
# ncdf_temp800name="X"
# ncdf_temp750name="X"
# ncdf_temp700name="X"
# ncdf_temp650name="X"
# ncdf_temp600name="X"
# ncdf_tmean_300_500_name="X

# ncdf_omega500name="X"



def main(filename):
    ds = xr.open_dataset(filename)
    ods=xr.Dataset()
    for level in [ 850, 700, 500, 200]:
        ods[f"u{level}"] = ds['u'].sel(level=level)
        ods[f"v{level}"] = ds['v'].sel(level=level)
    for level in [ 850, 700, 600, 500, 400, 300, 200]:
        ods[f"z{level}"] = ds['z'].sel(level=level)
    #for level in [1000, 925, 850, 700, 600]:
    #    ods[f"q{level}"] = ds['q'].sel(level=level)
    #    ods[f"t{level}"] = ds['t'].sel(level=level)
    #ods['w500'] = ds['w'].sel(level=500)
    ods['msl'] = ds['msl']
    ods['v10'] = ds['v10']
    ods['u10'] = ds['u10']
    ods['time'] = ods['time'].astype("float64")
    ods['time'] = (ods['time'] - ods['time'].isel({'time':0})) / (60*60*1e9)
    ods['time'].attrs['units'] = "hours"

    ods.to_netcdf("track_file.nc")

import sys
main(sys.argv[1])



