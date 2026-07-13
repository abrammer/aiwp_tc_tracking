#!/usr/bin/env bash
#--------------------------------------------------------------
# Script written by Tim Marchok --> timothy.marchok@noaa.gov
# Edited by Caitlyn McAllister  --> caitlyn.mcallister@noaa.gov
#--------------------------------------------------------------

# edited by A Brammer to run off ai-weather model outputs at CIRA
# Call datetime and up to 4 optional args
#1 = YYYYMMDDHHmm e.g. 2024081100
#2 = AI MODEL NAME -> GRAP, PANG, FOUR
#3 = ai version -> 100, 200  (defaults as 100)
#4 = ATCF Tech (defaults to #1)
#5 = inital condition source => GFS / ERA

export curymdh=${1:-2024081100} # USER - date from model initilization date
ainame=${2:-GRAP}
srcname=${3:-GFS}
aiversion=${4:-100}

declare -A atcfarr=(
 ["GRAP_GFS"]="NGRP"
 ["GRAP_IFS"]="EGRP"
 ["PANG_GFS"]="NPNG"
 ["PANG_IFS"]="EPNG"
 ["FOUR_GFS"]="NFOR"
 ["FOUR_IFS"]="EFOR"
 ["AURO_GFS"]="NAUR"
 ["AURO_IFS"]="EAUR"
)
atcfname=${atcfarr[${ainame}_${srcname}]}

#input file name will be constructed as such:
#modelfname=${#2}_v${#3}_${#5}_${#1}_f000_f240_06.nc
#######

# USER - add paths to location of repository (i.e. home=) and location of workroot
# no other paths should need to be changed
# do not add spaces next to = (ex. home=/home/...)
export home=$(dirname $(dirname $(readlink -fm $0)))
export workroot=${home}/work
export rundir=${home}/run
export execdir=${home}/exec
export vitaldir=${home}/files/vitals

source ${rundir}/config
echo "DESTINATION: "${DESTINATION}
echo "MODEL_SRC_DIR: "${MODEL_SRC_DIR}
echo "SAVE_OUTPUT: "${SAVE_OUTPUT}

${PYTHON_EXE} -V
which ${PYTHON_EXE}
#-----------------------------------------------------------
# Set critical initial variables and directories
#-----------------------------------------------------------

# everything below should "just run" given the correct environment and input files
export PS4=' + run_tracker.sh line $LINENO: '
set -e
ulimit -c unlimited


ATCFNAME=` echo "${atcfname}" | tr '[a-z]' '[A-Z]'`
MODEL_SRC=${MODEL_SRC_DIR}/${ainame}_v${aiversion}_${srcname}
#if [ ${srcname} != "GFS" ]; then
#	MODEL_SRC="${MODEL_SRC}_${srcname}"
#	curymdh=${curymdh}00
#fi
modelfname=${ainame}_v${aiversion}_${srcname}_${curymdh}_f000_f240_06.nc
# this next variable specifies the name of a seperate land-sea mask file
# that can be used in case the main input netcdf file does not contain its own
# land-sea mask record
export ncdf_ls_mask_filename=

export tcvit_date=${home}/run/tcvit_date
export NDATE=${home}/files/bin/ndate.x

export gribver=1
export basin=al
# USER - please choose "tracker" or "tcgen"
# tracker denotes regular tracker run, tcgen denotes genesis run
export trkrtype=tracker #cgen


# loads any module/packages needed for cmake build

export PDY=`     echo $curymdh | cut -c1-8`
export yyyy=`    echo $curymdh | cut -c1-4`
export cyc=`     echo $curymdh | cut -c9-10`
export ymdh=${PDY}${cyc}

echo "Checking ${MODEL_SRC}/${yyyy}/${PDY:4:4}/${modelfname}"
mkdir -p ${workroot}

if [ -f ${DESTINATION}/${yyyy}/${PDY:4:4}${cyc}/trak.${atcfname}.all.${ymdh} ];
then 
        echo ${DESTINATION}/${yyyy}/${PDY:4:4}${cyc}/trak.${atcfname}.all.${ymdh} 
	echo "output exists"
	exit 0
fi
if [ -f ${DESTINATION}/${yyyy}/${PDY:4:4}${cyc}/trak.${atcfname}.all.altg.${ymdh} ];
then 
	echo ${DESTINATION}/${yyyy}/${PDY:4:4}${cyc}/trak.${atcfname}.all.altg.${ymdh}
	echo "output exists"
	exit 0
fi
if [ ! -f ${MODEL_SRC}/${yyyy}/${PDY:4:4}/${modelfname} ];
then
	echo "no input file available"
	echo "${MODEL_SRC}/${yyyy}/${PDY:4:4}/${mdoelfname}" >> ${workroot}/missing_files
	exit 0
fi

wdir=${workroot}/${atcfname}_${curymdh}
echo ${wdir}
if [ ! -d ${wdir} ]; then mkdir -p ${wdir}; fi

echo " "
echo "+++ Top of run_grap.sh, time= `date`"
echo "    curymdh=    $curymdh"
echo "    trkrtype=   $trkrtype"
echo "    gribver=    ${gribver}"
echo "    wdir=       ${wdir}"
echo " "

export DATA=${wdir}  # ${workroot}/${PDY}${cyc}
data_dir=${wdir}
cd $wdir

#--------------------------------------------------------------------------------
# Check the TC Vitals to see if there are any observed storms for the input ymdh.
#--------------------------------------------------------------------------------
tcvit_logfile=${rundir}/tcvit_logfile.${yyyy}.txt

${tcvit_date} ${curymdh} ${vitaldir} | egrep "JTWC|NHC"           | \
grep -v TEST | awk 'substr($0,6,1) !~ /8/ {print $0}'   \
>${wdir}/vitals.${curymdh}

num_storms=` cat ${wdir}/vitals.${curymdh} | wc -l`

# A quirk of the I/O for the tracker program is that the
# vitals file must exist, even if it's empty (i.e., there
# are no storms).  So this next IF statement checks to see if there
# are any storms for the current YMDH.  If there are, then we simply
# continue after catting the vitals file out for display in the
# output file.  If storms do not exist, then do a touch to just
# create an empty file.

if [ ${num_storms} -gt 0 ]; then
  echo " "
  echo "+++ ${num_storms} Observed storms exist for ${curymdh}: " | tee -a  ${tcvit_logfile}
  cat ${wdir}/vitals.${curymdh}
  cat ${wdir}/vitals.${curymdh} >> ${tcvit_logfile}
  echo " "
else
  echo "No storms exist"
  rm -rf ${wdir}
  exit 0 
fi

#----------------
#  get the model output and transform it into gfdl friendly structure
#---------------

#set -x
if [ ! -f ${modelfname} ]; then
    #wget https://noaa-oar-mlwp-data.s3.amazonaws.com/FOUR_v200/${yyyy}/${PDY:4:4}/FOUR_v200_GFS_${curymdh}_f000_f240_06.nc
    #scp dorian:/mnt/mlnas01/ai-models/GRAP_v100/${yyyy}/${PDY:4:4}/GRAP_v100_GFS_${curymdh}_f000_f240_06.nc ./
    ln -s ${MODEL_SRC}/${yyyy}/${PDY:4:4}/${modelfname} ./ 
    echo "linking local file in to work directory"
fi
if [ ! -f track_file.nc ];then
    echo "running python preprocess to make compatible netcdf"
    if [[ ${modelfname} == *.nc ]]; then
    	${PYTHON_EXE} ${rundir}/expand_netcdf.py ${modelfname}
    elif [[ ${modelfname} == *.grib ]]; then
    	${PYTHON_EXE} ${rundir}/expand_grib.py ${modelfname}
   else
	echo "file type not recognised, expects .nc or .grib "
	exit 1
   fi
    if [ $? -ne 0 ]; then
        exit 1
    fi
fi
#set +x
data_file1=track_file.nc #GRAP_v100_gfs_2024010400_f000_f240_06.nc

#------------------------------------------------------------------------
# Set variables & parameters for the input namelist for T-SHiELD...
#------------------------------------------------------------------------

export trkrebd=359.0   # boundary only used by tracker if trkrtype = tcgen or midlat
export trkrwbd=0.0   # boundary only used by tracker if trkrtype = tcgen or midlat
export trkrnbd=40.0    # boundary only used by tracker if trkrtype = tcgen or midlat
export trkrsbd=-40.0     # boundary only used by tracker if trkrtype = tcgen or midlat
export regtype=altg    # This variable is only needed if trkrtype = tcgen or midlat

COM=${DATA}
atcfnum=15
atcfymdh=${PDY}${cyc}
max_mslp_850=400.0
mslpthresh=0.0015
v850thresh=1.5000
v850_qwc_thresh=1.0000
cint_grid_bound_check=0.50
modtyp='global'
nest_type='fixed'
export WCORE_DEPTH=1.0
export PHASEFLAG=n
export PHASE_SCHEME=both
#export PHASE_SCHEME=vtt
#export PHASE_SCHEME=cps
export STRUCTFLAG=n
export IKEFLAG=n
export genflag=y
export sstflag=n
export shear_calc_flag=y

export gen_read_rh_fields=n
# export use_land_mask=y
# export read_separate_land_mask_file=y
export use_land_mask=n
export read_separate_land_mask_file=n
export need_to_compute_rh_from_q=y
export smoothe_mslp_for_gen_scan=y
atcfnum=15
atcffreq=600
rundescr="xxxx"
atcfdescr="xxxx"
file_sequence="onebig"
# For netCDF files, the lead time units are determined below in
# an ncdump scan of the file, so leave this blank.
lead_time_units=' '
#       gribver=2     # N/A since we are using NetCDF data for T-SHiELD;
# g2_jpdtn sets the variable that will be used as "JPDTN" for
# the call to getgb2, if gribver=2.  jpdtn=1 for ens data,
# jpdtn=0 for deterministic data.
g2_jpdtn=0
inp_data_type=netcdf
model=99


export atcfymdh=${PDY}${cyc}

export use_land_mask=${use_land_mask:-no}
# contour_interval=100.0
contour_interval=1.0
radii_pctile=95.0
radii_free_pass_pctile=67.0
radii_width_thresh=15.0
# radii_width_thresh=30.0
write_vit=y
want_oci=.TRUE.
use_backup_mslp_grad_check=${use_backup_mslp_grad_check:-y}
user_wants_to_track_zeta850=y
use_backup_850_vt_check=${use_backup_850_vt_check:-y}

#------------------------------------------------------------------------------
# USER - These next definitions declare the names of the variables inside
# the input data files. This allows the tracker to know the exact name of the
# record to look for. Please match these to the variables within the netcdf
# data files.
# By default they are all set to "X", user will need to change these variables
# according to what atmospheric data is in netcdf file.
# Example: geopotential height @ 500m will need to be changed from
# ncdf_z500name="X" --> ncdf_z500name=h500
#------------------------------------------------------------------------------
ncdf_num_netcdf_vars=999
ncdf_rv850name="X"
ncdf_rv700name="X"
ncdf_u850name="u850"
ncdf_v850name="v850"
ncdf_u700name="u700"
ncdf_v700name="v700"
ncdf_z850name="z850"
ncdf_z700name="z700"
ncdf_mslpname="msl"
ncdf_usfcname="u10"
ncdf_vsfcname="v10"
ncdf_u500name="u500"
ncdf_v500name="v500"
ncdf_u200name="u200"
ncdf_v200name="v200"
ncdf_tmean_300_500_name="X"
ncdf_z500name="z500"
ncdf_z200name="z200"
ncdf_lmaskname="X"
ncdf_z900name="z900"
ncdf_z800name="z800"
ncdf_z750name="z750"
ncdf_z650name="z650"
ncdf_z600name="z600"
ncdf_z550name="z550"
ncdf_z500name="z500"
ncdf_z450name="z450"
ncdf_z400name="z400"
ncdf_z350name="z350"
ncdf_z300name="z300"
ncdf_time_name="time"
ncdf_lon_name="longitude"
ncdf_lat_name="latitude"
ncdf_sstname="X"
ncdf_q850name="X"
ncdf_rh1000name="X"
ncdf_rh925name="X"
ncdf_rh800name="X"
ncdf_rh750name="X"
ncdf_rh700name="X"
ncdf_rh650name="X"
ncdf_rh600name="X"
ncdf_spfh1000name="q1000"
ncdf_spfh925name="q925"
ncdf_spfh800name="q800"
ncdf_spfh750name="q750"
ncdf_spfh700name="q700"
ncdf_spfh650name="q650"
ncdf_spfh600name="q600"
ncdf_temp1000name="t1000"
ncdf_temp925name="t925"
ncdf_temp800name="t800"
ncdf_temp750name="t750"
ncdf_temp700name="t700"
ncdf_temp650name="t650"
ncdf_temp600name="t600"
ncdf_omega500name="w500"

netcdffile=${data_dir}/${data_file1}

# This next ncdf_time_units variable is going to either be
# "hours" or "days".  If it's "hours", then all the time data
# values are for hours since the initial time.  Same thing
# for "days", however if it is "days", then know that a value
# of 0.25 will be the same as a 6-hour lead time.

ncdf_time_units=` ncdump -h ${netcdffile} | \
                  grep "time:units"          | \
                  awk -F= '{print $2}'       | \
                  awk -F\" '{print $2}'      | \
                  awk '{print $1}'`
echo " "
echo "NetCDF time units pulled from data file = ${ncdf_time_units}"
echo " "

#####################################################
# Populate the namelist, using the variables that
# were declared above.
#####################################################

namelist=${DATA}/input.${atcfname}.${PDY}${cyc}

echo "&datein inp%bcc=${scc},inp%byy=${syy},inp%bmm=${smm},"      >${namelist}
echo "        inp%bdd=${sdd},inp%bhh=${shh},inp%model=${model}," >>${namelist}
echo "        inp%modtyp='${modtyp}',"                           >>${namelist}
echo "        inp%lt_units='${lead_time_units}',"                >>${namelist}
echo "        inp%file_seq='${file_sequence}',"                  >>${namelist}
echo "        inp%nesttyp='${nest_type}'/"                       >>${namelist}
echo "&atcfinfo atcfnum=${atcfnum},atcfname='${ATCFNAME}',"      >>${namelist}
echo "          atcfymdh=${atcfymdh},atcffreq=${atcffreq}/"      >>${namelist}
echo "&trackerinfo trkrinfo%westbd=${trkrwbd},"                  >>${namelist}
echo "      trkrinfo%eastbd=${trkrebd},"                         >>${namelist}
echo "      trkrinfo%northbd=${trkrnbd},"                        >>${namelist}
echo "      trkrinfo%southbd=${trkrsbd},"                        >>${namelist}
echo "      trkrinfo%type='${trkrtype}',"                        >>${namelist}
echo "      trkrinfo%mslpthresh=${mslpthresh},"                  >>${namelist}
echo "      trkrinfo%use_backup_mslp_grad_check='${use_backup_mslp_grad_check}',"  >>${namelist}
echo "      trkrinfo%max_mslp_850=${max_mslp_850},"              >>${namelist}
echo "      trkrinfo%v850thresh=${v850thresh},"                  >>${namelist}
echo "      trkrinfo%v850_qwc_thresh=${v850_qwc_thresh},"        >>${namelist}
echo "      trkrinfo%use_backup_850_vt_check='${use_backup_850_vt_check}',"  >>${namelist}
echo "      trkrinfo%gridtype='${modtyp}',"                      >>${namelist}
echo "      trkrinfo%enable_timing=0,"                           >>${namelist}
echo "      trkrinfo%contint=${contour_interval},"               >>${namelist}
echo "      trkrinfo%want_oci=${want_oci},"                      >>${namelist}
echo "      trkrinfo%out_vit='${write_vit}',"                    >>${namelist}
echo "      trkrinfo%use_land_mask='${use_land_mask}',"          >>${namelist}
echo "      trkrinfo%read_separate_land_mask_file='${read_separate_land_mask_file}',"   >>${namelist}
echo "      trkrinfo%inp_data_type='${inp_data_type}',"          >>${namelist}
echo "      trkrinfo%gribver=${gribver},"                        >>${namelist}
echo "      trkrinfo%g2_jpdtn=${g2_jpdtn},"                      >>${namelist}
echo "      trkrinfo%g2_mslp_parm_id=${g2_mslp_parm_id},"        >>${namelist}
echo "      trkrinfo%g1_mslp_parm_id=${g1_mslp_parm_id},"        >>${namelist}
echo "      trkrinfo%g1_sfcwind_lev_typ=${g1_sfcwind_lev_typ},"  >>${namelist}
echo "      trkrinfo%g1_sfcwind_lev_val=${g1_sfcwind_lev_val}/"  >>${namelist}
echo "&phaseinfo phaseflag='${PHASEFLAG}',"                      >>${namelist}
echo "           phasescheme='${PHASE_SCHEME}',"                 >>${namelist}
echo "           wcore_depth=${WCORE_DEPTH}/"                    >>${namelist}
echo "&structinfo structflag='${STRUCTFLAG}',"                   >>${namelist}
echo "            ikeflag='${IKEFLAG}',"                         >>${namelist}
echo "            radii_pctile=${radii_pctile},"                 >>${namelist}
echo "            radii_free_pass_pctile=${radii_free_pass_pctile},"  >>${namelist}
echo "            radii_width_thresh=${radii_width_thresh}/"     >>${namelist}
echo "&fnameinfo  gmodname='${atcfname}',"                       >>${namelist}
echo "            rundescr='${rundescr}',"                       >>${namelist}
echo "            atcfdescr='${atcfdescr}'/"                     >>${namelist}
echo "&cintinfo contint_grid_bound_check=${cint_grid_bound_check}/" >>${namelist}
echo "&waitinfo use_waitfor='n',"                                >>${namelist}
echo "          wait_min_age=10,"                                >>${namelist}
echo "          wait_min_size=100,"                              >>${namelist}
echo "          wait_max_wait=1800,"                             >>${namelist}
echo "          wait_sleeptime=5,"                               >>${namelist}
echo "          per_fcst_command=''/"                            >>${namelist}
echo "&netcdflist netcdfinfo%num_netcdf_vars=${ncdf_num_netcdf_vars}," >>${namelist}
echo "      netcdfinfo%netcdf_filename='${netcdffile}',"                   >>${namelist}
echo "      netcdfinfo%netcdf_lsmask_filename='${ncdf_ls_mask_filename}'," >>${namelist}
echo "      netcdfinfo%rv850name='${ncdf_rv850name}',"             >>${namelist}
echo "      netcdfinfo%rv700name='${ncdf_rv700name}',"             >>${namelist}
echo "      netcdfinfo%u850name='${ncdf_u850name}',"               >>${namelist}
echo "      netcdfinfo%v850name='${ncdf_v850name}',"               >>${namelist}
echo "      netcdfinfo%u700name='${ncdf_u700name}',"               >>${namelist}
echo "      netcdfinfo%v700name='${ncdf_v700name}',"               >>${namelist}
echo "      netcdfinfo%z850name='${ncdf_z850name}',"               >>${namelist}
echo "      netcdfinfo%z700name='${ncdf_z700name}',"               >>${namelist}
echo "      netcdfinfo%mslpname='${ncdf_mslpname}',"               >>${namelist}
echo "      netcdfinfo%usfcname='${ncdf_usfcname}',"               >>${namelist}
echo "      netcdfinfo%vsfcname='${ncdf_vsfcname}',"               >>${namelist}
echo "      netcdfinfo%u500name='${ncdf_u500name}',"               >>${namelist}
echo "      netcdfinfo%v500name='${ncdf_v500name}',"               >>${namelist}
echo "      netcdfinfo%u200name='${ncdf_u200name}',"               >>${namelist}
echo "      netcdfinfo%v200name='${ncdf_v200name}',"               >>${namelist}
echo "      netcdfinfo%tmean_300_500_name='${ncdf_tmean_300_500_name}',"  >>${namelist}
echo "      netcdfinfo%z500name='${ncdf_z500name}',"               >>${namelist}
echo "      netcdfinfo%z200name='${ncdf_z200name}',"               >>${namelist}
echo "      netcdfinfo%lmaskname='${ncdf_lmaskname}',"             >>${namelist}
echo "      netcdfinfo%z900name='${ncdf_z900name}',"               >>${namelist}
echo "      netcdfinfo%z850name='${ncdf_z850name}',"               >>${namelist}
echo "      netcdfinfo%z800name='${ncdf_z800name}',"               >>${namelist}
echo "      netcdfinfo%z750name='${ncdf_z750name}',"               >>${namelist}
echo "      netcdfinfo%z700name='${ncdf_z700name}',"               >>${namelist}
echo "      netcdfinfo%z650name='${ncdf_z650name}',"               >>${namelist}
echo "      netcdfinfo%z600name='${ncdf_z600name}',"               >>${namelist}
echo "      netcdfinfo%z550name='${ncdf_z550name}',"               >>${namelist}
echo "      netcdfinfo%z500name='${ncdf_z500name}',"               >>${namelist}
echo "      netcdfinfo%z450name='${ncdf_z450name}',"               >>${namelist}
echo "      netcdfinfo%z400name='${ncdf_z400name}',"               >>${namelist}
echo "      netcdfinfo%z350name='${ncdf_z350name}',"               >>${namelist}
echo "      netcdfinfo%z300name='${ncdf_z300name}',"               >>${namelist}
echo "      netcdfinfo%time_name='${ncdf_time_name}',"             >>${namelist}
echo "      netcdfinfo%lon_name='${ncdf_lon_name}',"               >>${namelist}
echo "      netcdfinfo%lat_name='${ncdf_lat_name}',"               >>${namelist}
echo "      netcdfinfo%time_units='${ncdf_time_units}',"           >>${namelist}
echo "      netcdfinfo%sstname='${ncdf_sstname}',"                 >>${namelist}
echo "      netcdfinfo%q850name='${ncdf_q850name}',"               >>${namelist}
echo "      netcdfinfo%rh1000name='${ncdf_rh1000name}',"           >>${namelist}
echo "      netcdfinfo%rh925name='${ncdf_rh925name}',"             >>${namelist}
echo "      netcdfinfo%rh800name='${ncdf_rh800name}',"             >>${namelist}
echo "      netcdfinfo%rh750name='${ncdf_rh750name}',"             >>${namelist}
echo "      netcdfinfo%rh700name='${ncdf_rh700name}',"             >>${namelist}
echo "      netcdfinfo%rh650name='${ncdf_rh650name}',"             >>${namelist}
echo "      netcdfinfo%rh600name='${ncdf_rh600name}',"             >>${namelist}
echo "      netcdfinfo%spfh1000name='${ncdf_spfh1000name}',"       >>${namelist}
echo "      netcdfinfo%spfh925name='${ncdf_spfh925name}',"         >>${namelist}
echo "      netcdfinfo%spfh800name='${ncdf_spfh800name}',"         >>${namelist}
echo "      netcdfinfo%spfh750name='${ncdf_spfh750name}',"         >>${namelist}
echo "      netcdfinfo%spfh700name='${ncdf_spfh700name}',"         >>${namelist}
echo "      netcdfinfo%spfh650name='${ncdf_spfh650name}',"         >>${namelist}
echo "      netcdfinfo%spfh600name='${ncdf_spfh600name}',"         >>${namelist}
echo "      netcdfinfo%temp1000name='${ncdf_temp1000name}',"       >>${namelist}
echo "      netcdfinfo%temp925name='${ncdf_temp925name}',"         >>${namelist}
echo "      netcdfinfo%temp800name='${ncdf_temp800name}',"         >>${namelist}
echo "      netcdfinfo%temp750name='${ncdf_temp750name}',"         >>${namelist}
echo "      netcdfinfo%temp700name='${ncdf_temp700name}',"         >>${namelist}
echo "      netcdfinfo%temp650name='${ncdf_temp650name}',"         >>${namelist}
echo "      netcdfinfo%temp600name='${ncdf_temp600name}',"         >>${namelist}
echo "      netcdfinfo%omega500name='${ncdf_omega500name}'/"       >>${namelist}
echo "&parmpreflist user_wants_to_track_zeta850='${user_wants_to_track_zeta850}'," >>${namelist}
echo "      user_wants_to_track_zeta700='${user_wants_to_track_zeta700}',"         >>${namelist}
echo "      user_wants_to_track_wcirc850='${user_wants_to_track_wcirc850}',"       >>${namelist}
echo "      user_wants_to_track_wcirc700='${user_wants_to_track_wcirc700}',"       >>${namelist}
echo "      user_wants_to_track_gph850='${user_wants_to_track_gph850}',"           >>${namelist}
echo "      user_wants_to_track_gph700='${user_wants_to_track_gph700}',"           >>${namelist}
echo "      user_wants_to_track_mslp='${user_wants_to_track_mslp}',"               >>${namelist}
echo "      user_wants_to_track_wcircsfc='${user_wants_to_track_wcircsfc}',"       >>${namelist}
echo "      user_wants_to_track_zetasfc='${user_wants_to_track_zetasfc}',"         >>${namelist}
echo "      user_wants_to_track_thick500850='${user_wants_to_track_thick500850}'," >>${namelist}
echo "      user_wants_to_track_thick200500='${user_wants_to_track_thick200500}'," >>${namelist}
echo "      user_wants_to_track_thick200850='${user_wants_to_track_thick200850}'/" >>${namelist}
echo "&verbose verb=3,verb_g2=0/"                                      >>${namelist}
echo "&sheardiaginfo shearflag='${shear_calc_flag}'/"                  >>${namelist}
echo "&sstdiaginfo sstflag='${sstflag}'/"                              >>${namelist}
echo "&gendiaginfo genflag='${genflag}',"                              >>${namelist}
echo "             gen_read_rh_fields='${gen_read_rh_fields}',"        >>${namelist}
echo "             need_to_compute_rh_from_q='${need_to_compute_rh_from_q}',"  >>${namelist}
echo "             smoothe_mslp_for_gen_scan='${smoothe_mslp_for_gen_scan}'/"  >>${namelist}

##########################################################################
# Now link various files that are either needed as input to the tracker,
# or are output from the tracker.  Note that the namelist file is linked
# to a fortran unit, instead of using the standard way of redirect on the
# the command line (e.g., gettrk.exe < namelist_file).  The reason for
# this is that someone from NCEP told me that they encountered an issue
# on one of the platforms running the tracker where the operating system
# balked at the use of the redirect.  So, to make things easy, the
# namelist is just fortran-unit-linked to unit 555 now.
#
# With the exception of unit 555 for the namelist, all unit numbers < 50
# are for input, and all unit numbers > 50 are for output.
##########################################################################

cp ${namelist} namelist.gettrk
ln -s -f namelist.gettrk                                             fort.555

if [ ${inp_data_type} = 'grib' ]; then
  ln -s -f ${gribfile}                                               fort.11
else
  ln -s -f ${netcdffile}                                             fort.11
  if [ ${read_separate_land_mask_file} = 'y' ]; then
    ln -s -f ${ncdf_ls_mask_filename}                                fort.17
  fi
fi

if [ -s ${wdir}/vitals.${curymdh} ]; then
  cp ${wdir}/vitals.${curymdh} \
     ${DATA}/tcvit_rsmc_storms.txt
else
  >${DATA}/tcvit_rsmc_storms.txt
fi

if [ -s ${DATA}/genvitals.upd.${atcfname}.${PDY}${shh} ]; then
  cp ${DATA}/genvitals.upd.${atcfname}.${PDY}${shh} \
     ${DATA}/tcvit_genesis_storms.txt
else
  >${DATA}/tcvit_genesis_storms.txt
fi

ln -s -f ${rundir}/tracker_leadtimes                       fort.15

if [ ${inp_data_type} = 'grib' ]; then
  ln -s -f ${ixfile}                                                 fort.31
fi

if [ ${trkrtype} = 'tracker' ]; then
  ln -s -f ${DATA}/trak.${atcfname}.all.${PDY}${cyc}          fort.61
  ln -s -f ${DATA}/trak.${atcfname}.atcf.${PDY}${cyc}         fort.62
  ln -s -f ${DATA}/trak.${atcfname}.radii.${PDY}${cyc}        fort.63
  ln -s -f ${DATA}/trak.${atcfname}.atcfunix.${PDY}${cyc}     fort.64
  ln -s -f ${DATA}/trak.${atcfname}.atcf_gen.${PDY}${cyc}     fort.66
  ln -s -f ${DATA}/trak.${atcfname}.atcfunix_ext.${PDY}${cyc} fort.68
  ln -s -f ${DATA}/trak.${atcfname}.atcf_hfip.${PDY}${cyc}    fort.69
  ln -s -f ${DATA}/trak.${atcfname}.parmfix.${PDY}${cyc}      fort.81
else
  ln -s -f ${DATA}/trak.${atcfname}.all.${regtype}.${PDY}${cyc}          fort.61
  ln -s -f ${DATA}/trak.${atcfname}.atcf.${regtype}.${PDY}${cyc}         fort.62
  ln -s -f ${DATA}/trak.${atcfname}.radii.${regtype}.${PDY}${cyc}        fort.63
  ln -s -f ${DATA}/trak.${atcfname}.atcfunix.${PDY}${cyc}     fort.64
  ln -s -f ${DATA}/trak.${atcfname}.atcf_gen.${regtype}.${PDY}${cyc}     fort.66
  ln -s -f ${DATA}/trak.${atcfname}.atcfunix_ext.${regtype}.${PDY}${cyc} fort.68
  ln -s -f ${DATA}/trak.${atcfname}.atcf_hfip.${regtype}.${PDY}${cyc}    fort.69
  ln -s -f ${DATA}/trak.${atcfname}.parmfix.${regtype}.${PDY}${cyc}      fort.81
fi

if [ ${atcfname} = 'aear' ]
then
  ln -s -f ${DATA}/trak.${atcfname}.initvitl.${PDY}${cyc}           fort.65
fi

if [ ${write_vit} = 'y' ]
then
  ln -s -f ${DATA}/output_genvitals.${atcfname}.${PDY}${shh}        fort.67
fi

if [ ${PHASEFLAG} = 'y' ]; then
  ln -s -f ${DATA}/trak.${atcfname}.cps_parms.${PDY}${cyc}          fort.71
fi

if [ ${STRUCTFLAG} = 'y' ]; then
  ln -s -f ${DATA}/trak.${atcfname}.structure.${regtype}.${PDY}${cyc}          fort.72
  ln -s -f ${DATA}/trak.${atcfname}.fractwind.${regtype}.${PDY}${cyc}          fort.73
  ln -s -f ${DATA}/trak.${atcfname}.pdfwind.${regtype}.${PDY}${cyc}            fort.76
fi

if [ ${IKEFLAG} = 'y' ]; then
  ln -s -f ${DATA}/trak.${atcfname}.ike.${regtype}.${PDY}${cyc}                fort.74
fi

if [ ${trkrtype} = 'midlat' -o ${trkrtype} = 'tcgen' -o ${trkrtype} = 'tracker' ]; then
  ln -s -f ${DATA}/trkrmask.${atcfname}.${regtype}.${PDY}${cyc}     fort.77
fi

########################################################################
# Now run the tracker....
########################################################################

#set +x
echo " "
echo " -----------------------------------------------"
echo "           NOW EXECUTING TRACKER......"
echo " -----------------------------------------------"
echo " "
echo "gettrk start for $atcfname at ${cyc}z at `date`"
echo "+++ TIMING: BEFORE gettrk  ---> `date`"

export FOR_DUMP_CORE_FILE=TRUE
ulimit -s unlimited

#echo " "
#echo "before gettrk, Output of ulimit command follows...."
#ulimit -a
#echo "before gettrk, Done: Output of ulimit command."

${execdir}/gettrk.x >> gettrk.log
gettrk_rcc=$?

echo "+++ TIMING: AFTER  gettrk  ---> `date`"
echo "   "
echo "   Return code from tracker= gettrk_rcc= ${gettrk_rcc}"
echo "   "

if [ ! -f ${DATA}/trak.${atcfname}.atcfunix.${PDY}${cyc} ]; then
	exit 0
fi
while read line; 
do  
    if [ "${line:0:1}" != "T" ]; then 
	    basin=${line:0:2}; 
	    echo ${line}
	    if [ ${trkrtype} == 'tracker' ];then
#	    	echo ${DATA}/a${basin,,}${line:4:2}${line:8:4}.${atcfname}.${line:8:10}.dat
	    	echo  "${line}" >> ${DATA}/a${basin,,}${line:4:2}${line:8:4}.${atcfname}.${line:8:10}.dat ;
	    else
#		echo ${DATA}/a${basin,,}${line:5:2}${line:10:4}.${atcfname}.${line:10:10}.dat
		echo "${line}" >> ${DATA}/a${basin,,}${line:5:2}${line:10:4}.${atcfname}.${line:10:10}.dat
           fi
	    
    fi; 
done <  ${DATA}/trak.${atcfname}.atcfunix.${PDY}${cyc}

if [ "$SAVE_OUTPUT" = true ]; then
    mkdir -p ${DESTINATION}/${yyyy}/${PDY:4:4}${cyc}/
    cp -v ${DATA}/trak.* ${DESTINATION}/${yyyy}/${PDY:4:4}${cyc}/
    cp -v ${DATA}/a*.dat ${DESTINATION}/${yyyy}/${PDY:4:4}${cyc}/
fi 

rm -rf ${wdir}

