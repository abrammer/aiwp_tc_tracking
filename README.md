# 🌊 AI-WP use of the GFDL Vortex Tracker 🌀

This repo contains helper scripts to run the GFDL Vortex Tracker on AI-WP netcdf model output grids. 
This was built on top of the github repo for the tracker, and scripts have been modified or added to simplify 
running on netcdf grids from the CIRA outputs of AI models.  


## Dependices, Installation, Compiling, Running, Testing

To simplify the installation and dependency management, I'd recommend using conda.  
An environment is provided. 

```
conda env create -f environment.yml
conda activate gfdl_tracking
```

The tracker code can then be built with the helper scripts in `/code`
```
cd libs/
./build_all.sh
```

## Running the tracker

A run script is provided at `run/run_cira_tracker.sh`
This takes a combination of command line arguments to choose date, model version, initial fields etc.  Details are found at the top of the script.
Assuming the same files and the same directory structure, then changing `run/config` should be all that's needed to source input files and select output destination. 


## More Info:

The submodule repos contain more information about each aspect of the code that is use.  Find the respective readmes under libs/...

